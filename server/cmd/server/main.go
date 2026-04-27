package main

import (
	"context"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"

	"github.com/familyledger/server/internal/account"
	"github.com/familyledger/server/internal/asset"
	"github.com/familyledger/server/internal/auth"
	"github.com/familyledger/server/internal/budget"
	"github.com/familyledger/server/internal/dashboard"
	"github.com/familyledger/server/internal/export"
	"github.com/familyledger/server/internal/family"
	"github.com/familyledger/server/internal/importcsv"
	"github.com/familyledger/server/internal/investment"
	"github.com/familyledger/server/internal/loan"
	"github.com/familyledger/server/internal/market"
	"github.com/familyledger/server/internal/notify"
	syncsvc "github.com/familyledger/server/internal/sync"
	"github.com/familyledger/server/internal/transaction"
	"github.com/familyledger/server/pkg/config"
	"github.com/familyledger/server/pkg/db"
	jwtpkg "github.com/familyledger/server/pkg/jwt"
	"github.com/familyledger/server/pkg/middleware"
	"github.com/familyledger/server/pkg/ws"

	acctpb "github.com/familyledger/server/proto/account"
	assetpb "github.com/familyledger/server/proto/asset"
	authpb "github.com/familyledger/server/proto/auth"
	budgetpb "github.com/familyledger/server/proto/budget"
	dashpb "github.com/familyledger/server/proto/dashboard"
	exportpb "github.com/familyledger/server/proto/export"
	familypb "github.com/familyledger/server/proto/family"
	importpbpb "github.com/familyledger/server/proto/importpb"
	investpb "github.com/familyledger/server/proto/investment"
	loanpb "github.com/familyledger/server/proto/loan"
	notifypb "github.com/familyledger/server/proto/notify"
	syncpb "github.com/familyledger/server/proto/sync"
	txnpb "github.com/familyledger/server/proto/transaction"
)

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Config from environment
	dbCfg := db.Config{
		Host:     getEnv("DB_HOST", "localhost"),
		Port:     5432,
		User:     getEnv("DB_USER", "familyledger"),
		Password: getEnv("DB_PASSWORD", "familyledger"),
		DBName:   getEnv("DB_NAME", "familyledger"),
		SSLMode:  getEnv("DB_SSLMODE", "disable"),
	}

	jwtSecret := config.ValidateJWTSecret()
	grpcPort := getEnv("GRPC_PORT", "50051")
	wsPort := getEnv("WS_PORT", "8080")

	// Database
	pool, err := db.NewPool(ctx, dbCfg)
	if err != nil {
		log.Fatalf("failed to connect to database: %v", err)
	}
	defer pool.Close()
	log.Println("connected to database")

	// JWT Manager
	jwtManager := jwtpkg.NewManager(jwtSecret)

	// WebSocket Hub
	hub := ws.NewHub(jwtManager)

	// Services
	authService := auth.NewService(pool, jwtManager)
	txnService := transaction.NewService(pool)
	syncService := syncsvc.NewService(pool, hub)
	familyService := family.NewService(pool)
	accountService := account.NewService(pool)
	budgetService := budget.NewService(pool)
	loanService := loan.NewService(pool)
	notifyService := notify.NewService(pool)
	investmentService := investment.NewService(pool)
	assetService := asset.NewService(pool)
	marketFetcher := market.NewRealFetcher()
	marketService := market.NewService(pool, marketFetcher)
	exchangeService := market.NewExchangeService(pool)
	dashboardService := dashboard.NewService(pool)
	exportService := export.NewService(pool)
	importService := importcsv.NewService(pool)

	// gRPC Server
	grpcServer := grpc.NewServer(
		grpc.UnaryInterceptor(middleware.UnaryAuthInterceptor(jwtManager)),
		grpc.StreamInterceptor(middleware.StreamAuthInterceptor(jwtManager)),
	)

	authpb.RegisterAuthServiceServer(grpcServer, authService)
	txnpb.RegisterTransactionServiceServer(grpcServer, txnService)
	syncpb.RegisterSyncServiceServer(grpcServer, syncService)
	familypb.RegisterFamilyServiceServer(grpcServer, familyService)
	acctpb.RegisterAccountServiceServer(grpcServer, accountService)
	budgetpb.RegisterBudgetServiceServer(grpcServer, budgetService)
	loanpb.RegisterLoanServiceServer(grpcServer, loanService)
	notifypb.RegisterNotifyServiceServer(grpcServer, notifyService)
	investpb.RegisterInvestmentServiceServer(grpcServer, investmentService)
	investpb.RegisterMarketDataServiceServer(grpcServer, marketService)
	assetpb.RegisterAssetServiceServer(grpcServer, assetService)
	dashpb.RegisterDashboardServiceServer(grpcServer, dashboardService)
	exportpb.RegisterExportServiceServer(grpcServer, exportService)
	importpbpb.RegisterImportServiceServer(grpcServer, importService)
	reflection.Register(grpcServer)

	// Start gRPC
	grpcLis, err := net.Listen("tcp4", fmt.Sprintf("0.0.0.0:%s", grpcPort))
	if err != nil {
		log.Fatalf("failed to listen on port %s: %v", grpcPort, err)
	}

	go func() {
		log.Printf("gRPC server listening on :%s", grpcPort)
		if err := grpcServer.Serve(grpcLis); err != nil {
			log.Fatalf("gRPC server error: %v", err)
		}
	}()

	// Start WebSocket server
	mux := http.NewServeMux()
	mux.HandleFunc("/ws", hub.HandleWebSocket)
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})

	wsServer := &http.Server{
		Addr:    fmt.Sprintf("0.0.0.0:%s", wsPort),
		Handler: mux,
	}

	go func() {
		log.Printf("WebSocket server listening on :%s", wsPort)
		if err := wsServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("WebSocket server error: %v", err)
		}
	}()

	// Start scheduled tasks
	go runScheduledTasks(ctx, notifyService)
	go runMarketRefreshTasks(ctx, marketService)
	go runDepreciationTask(ctx, assetService)
	go runExchangeRateRefreshTask(ctx, exchangeService)
	go runImportSessionCleanupTask(ctx, importService)

	// Graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("shutting down...")
	cancel() // signal scheduled tasks to stop
	grpcServer.GracefulStop()
	wsServer.Shutdown(context.Background())
	log.Println("server stopped")
}

// runScheduledTasks runs periodic tasks. Currently checks budgets daily at 21:00 CST.
func runScheduledTasks(ctx context.Context, notifyService *notify.Service) {
	cst, err := time.LoadLocation("Asia/Shanghai")
	if err != nil {
		log.Printf("scheduler: failed to load CST timezone, falling back to UTC+8: %v", err)
		cst = time.FixedZone("CST", 8*60*60)
	}

	log.Println("scheduler: started, budget+loan check scheduled daily at 21:00 CST")

	for {
		now := time.Now().In(cst)
		// Next 21:00 CST
		next := time.Date(now.Year(), now.Month(), now.Day(), 21, 0, 0, 0, cst)
		if now.After(next) {
			next = next.Add(24 * time.Hour)
		}
		waitDuration := time.Until(next)
		log.Printf("scheduler: next budget check at %s (in %s)", next.Format(time.RFC3339), waitDuration.Round(time.Minute))

		select {
		case <-ctx.Done():
			log.Println("scheduler: stopped")
			return
		case <-time.After(waitDuration):
			log.Println("scheduler: running budget check...")
			checkCtx, checkCancel := context.WithTimeout(context.Background(), 5*time.Minute)
			if err := notifyService.CheckBudgets(checkCtx); err != nil {
				log.Printf("scheduler: budget check error: %v", err)
			}
			checkCancel()

			log.Println("scheduler: running loan reminder check...")
			loanCtx, loanCancel := context.WithTimeout(context.Background(), 5*time.Minute)
			if err := notifyService.CheckLoanReminders(loanCtx); err != nil {
				log.Printf("scheduler: loan reminder check error: %v", err)
			}
			loanCancel()

			log.Println("scheduler: running custom reminder check...")
			reminderCtx, reminderCancel := context.WithTimeout(context.Background(), 5*time.Minute)
			if err := notifyService.CheckCustomReminders(reminderCtx); err != nil {
				log.Printf("scheduler: custom reminder check error: %v", err)
			}
			reminderCancel()

			// TODO: Push notifications via FCM/APNs (placeholder — just logged for now)
			log.Println("scheduler: all checks complete")
		}
	}
}

// runMarketRefreshTasks refreshes market quotes on a schedule.
// Uses market.IsTradingHours to determine per-market refresh:
// - Trading hours: every 15 min
// - Off-hours: every 4 hours (stocks), crypto always 15 min
func runMarketRefreshTasks(ctx context.Context, marketService *market.Service) {
	log.Println("market-scheduler: started")

	for {
		now := time.Now()

		// Determine interval based on what markets are active
		// Crypto is always active → always 15 min base interval
		interval := market.ComputeMarketIntervalForTypes(now, []string{"crypto"})

		select {
		case <-ctx.Done():
			log.Println("market-scheduler: stopped")
			return
		case <-time.After(interval):
			now = time.Now()
			refreshCtx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)

			// Always refresh crypto (24/7)
			if err := marketService.RefreshQuotes(refreshCtx, []string{"crypto"}); err != nil {
				log.Printf("market-scheduler: crypto refresh error: %v", err)
			}

			// Refresh A-share/fund only during CN trading hours
			if market.IsTradingHours(now, "a_share") {
				if err := marketService.RefreshQuotes(refreshCtx, []string{"a_share", "fund"}); err != nil {
					log.Printf("market-scheduler: a_share/fund refresh error: %v", err)
				}
			}

			// Refresh HK stocks only during HK trading hours
			if market.IsTradingHours(now, "hk_stock") {
				if err := marketService.RefreshQuotes(refreshCtx, []string{"hk_stock"}); err != nil {
					log.Printf("market-scheduler: hk_stock refresh error: %v", err)
				}
			}

			// Refresh US stocks only during US trading hours
			if market.IsTradingHours(now, "us_stock") {
				if err := marketService.RefreshQuotes(refreshCtx, []string{"us_stock"}); err != nil {
					log.Printf("market-scheduler: us_stock refresh error: %v", err)
				}
			}

			cancel()
		}
	}
}

// runDepreciationTask runs monthly depreciation on the 1st of each month at 00:05 CST.
func runDepreciationTask(ctx context.Context, assetService *asset.Service) {
	cst, err := time.LoadLocation("Asia/Shanghai")
	if err != nil {
		log.Printf("depreciation-scheduler: failed to load CST timezone, falling back to UTC+8: %v", err)
		cst = time.FixedZone("CST", 8*60*60)
	}

	log.Println("depreciation-scheduler: started, monthly depreciation on 1st at 00:05 CST")

	for {
		now := time.Now().In(cst)
		// Next 1st of month, 00:05
		next := time.Date(now.Year(), now.Month()+1, 1, 0, 5, 0, 0, cst)
		// If we're before the 1st 00:05 this month, use this month
		thisMonth1st := time.Date(now.Year(), now.Month(), 1, 0, 5, 0, 0, cst)
		if now.Before(thisMonth1st) {
			next = thisMonth1st
		}

		waitDuration := time.Until(next)
		log.Printf("depreciation-scheduler: next run at %s (in %s)", next.Format(time.RFC3339), waitDuration.Round(time.Minute))

		select {
		case <-ctx.Done():
			log.Println("depreciation-scheduler: stopped")
			return
		case <-time.After(waitDuration):
			log.Println("depreciation-scheduler: running monthly depreciation...")
			depCtx, depCancel := context.WithTimeout(context.Background(), 10*time.Minute)
			if err := assetService.RunMonthlyDepreciationAll(depCtx); err != nil {
				log.Printf("depreciation-scheduler: error: %v", err)
			}
			depCancel()
			log.Println("depreciation-scheduler: complete")
		}
	}
}

func getEnv(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok {
		return value
	}
	return fallback
}

// runExchangeRateRefreshTask refreshes exchange rates every hour.
func runExchangeRateRefreshTask(ctx context.Context, exchangeService *market.ExchangeService) {
	log.Println("exchange-scheduler: started, refresh every hour")

	// Initial refresh on startup
	refreshCtx, cancel := context.WithTimeout(context.Background(), 1*time.Minute)
	if err := exchangeService.RefreshExchangeRates(refreshCtx); err != nil {
		log.Printf("exchange-scheduler: initial refresh error: %v", err)
	}
	cancel()

	for {
		select {
		case <-ctx.Done():
			log.Println("exchange-scheduler: stopped")
			return
		case <-time.After(1 * time.Hour):
			refreshCtx, cancel := context.WithTimeout(context.Background(), 1*time.Minute)
			if err := exchangeService.RefreshExchangeRates(refreshCtx); err != nil {
				log.Printf("exchange-scheduler: refresh error: %v", err)
			}
			cancel()
		}
	}
}

// runImportSessionCleanupTask cleans up expired import sessions every hour.
func runImportSessionCleanupTask(ctx context.Context, importService *importcsv.Service) {
	log.Println("import-cleanup-scheduler: started, cleanup every hour")

	for {
		select {
		case <-ctx.Done():
			log.Println("import-cleanup-scheduler: stopped")
			return
		case <-time.After(1 * time.Hour):
			cleanCtx, cancel := context.WithTimeout(context.Background(), 1*time.Minute)
			if err := importService.CleanupExpiredSessions(cleanCtx); err != nil {
				log.Printf("import-cleanup-scheduler: error: %v", err)
			}
			cancel()
		}
	}
}
