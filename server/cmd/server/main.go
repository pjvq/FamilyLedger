package main

import (
	"context"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
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
	"github.com/familyledger/server/pkg/logger"
	"github.com/familyledger/server/pkg/middleware"
	"github.com/familyledger/server/pkg/tlsconf"
	"github.com/familyledger/server/pkg/ws"
	acctpb "github.com/familyledger/server/proto/account"
	assetpb "github.com/familyledger/server/proto/asset"
	authpb "github.com/familyledger/server/proto/auth"
	budgetpb "github.com/familyledger/server/proto/budget"
	dashpb "github.com/familyledger/server/proto/dashboard"
	exportpb "github.com/familyledger/server/proto/export"
	familypb "github.com/familyledger/server/proto/family"
	importpb "github.com/familyledger/server/proto/importpb"
	investpb "github.com/familyledger/server/proto/investment"
	loanpb "github.com/familyledger/server/proto/loan"
	notifypb "github.com/familyledger/server/proto/notify"
	syncpb "github.com/familyledger/server/proto/sync"
	txnpb "github.com/familyledger/server/proto/transaction"
)

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Initialize structured logging
	logger.Setup(getEnv("APP_ENV", "development"))

	// Config from environment — no hardcoded defaults for sensitive fields
	dbUser := os.Getenv("DB_USER")
	dbPassword := os.Getenv("DB_PASSWORD")
	if dbUser == "" || dbPassword == "" {
		logger.Fatal("DB_USER and DB_PASSWORD environment variables are required")
	}
	dbPort := 5432
	if p := os.Getenv("DB_PORT"); p != "" {
		v, err := strconv.Atoi(p)
		if err != nil || v < 1 || v > 65535 {
			logger.Fatalf("invalid DB_PORT %q (must be 1-65535)", p)
		}
		dbPort = v
	}
	dbCfg := db.Config{
		Host:     getEnv("DB_HOST", "localhost"),
		Port:     dbPort,
		User:     dbUser,
		Password: dbPassword,
		DBName:   getEnv("DB_NAME", "familyledger"),
		SSLMode:  getEnv("DB_SSLMODE", "require"),
		MaxConns: getEnvInt32("DB_MAX_CONNS", db.DefaultMaxConns),
		MinConns: getEnvInt32("DB_MIN_CONNS", db.DefaultMinConns),
	}

	jwtSecret := config.ValidateJWTSecret()
	grpcPort := getEnv("GRPC_PORT", "50051")
	wsPort := getEnv("WS_PORT", "8080")

	// Database
	pool, err := db.NewPool(ctx, dbCfg)
	if err != nil {
		logger.Fatalf("failed to connect to database: %v", err)
	}
	defer pool.Close()
	logger.Infof("connected to database")

	// JWT Manager
	jwtManager := jwtpkg.NewManager(jwtSecret)

	// WebSocket Hub
	hubCfg := ws.DefaultHubConfig()
	if v := os.Getenv("WS_TOKEN_CHECK_INTERVAL"); v != "" {
		if d, err := time.ParseDuration(v); err == nil {
			hubCfg.TokenCheckInterval = d
			logger.Infof("ws: token check interval set to %v", d)
		}
	}
	if v := os.Getenv("WS_PONG_WAIT"); v != "" {
		if d, err := time.ParseDuration(v); err == nil {
			hubCfg.PongWait = d
			hubCfg.PingPeriod = d / 2 // ping must be < pong wait
			logger.Infof("ws: pong wait set to %v, ping period %v", d, d/2)
		}
	}
	hub := ws.NewHub(jwtManager, hubCfg)

	// Services
	authService := auth.NewService(pool, jwtManager)
	txnService := transaction.NewService(pool, transaction.WithHub(hub))
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

	// Rate limiter
	rlCfg := middleware.DefaultRateLimiterConfig()
	rlCfg.TrustProxy = strings.EqualFold(getEnv("TRUST_PROXY", ""), "true")
	rateLimiter := middleware.NewRateLimiter(rlCfg)
	defer rateLimiter.Stop()

	// Unified TLS configuration (shared between gRPC and WebSocket)
	var tlsProvider *tlsconf.Provider
	tlsCfg, tlsErr := tlsconf.LoadFromEnv()
	if tlsErr != nil {
		logger.Fatalf("invalid TLS configuration: %v", tlsErr)
	}
	if tlsCfg != nil {
		var err error
		tlsProvider, err = tlsconf.NewProvider(*tlsCfg)
		if err != nil {
			logger.Fatalf("failed to initialize TLS: %v", err)
		}
		logger.Infof("TLS: enabled for gRPC and WebSocket")

		// Reload certificates on SIGHUP (zero-downtime rotation).
		// The goroutine exits when ctx is canceled during graceful shutdown.
		go func() {
			sighup := make(chan os.Signal, 1)
			signal.Notify(sighup, syscall.SIGHUP)
			defer signal.Stop(sighup)
			for {
				select {
				case <-sighup:
					if err := tlsProvider.Reload(); err != nil {
						logger.Errorf("TLS: cert reload failed: %v", err)
					} else {
						logger.Infof("TLS: certificates reloaded successfully")
					}
				case <-ctx.Done():
					return
				}
			}
		}()
	} else {
		logger.Warnf("TLS: DISABLED (set TLS_CERT_FILE/TLS_KEY_FILE for production)")
	}

	// gRPC Server
	var grpcOpts []grpc.ServerOption
	if tlsProvider != nil {
		creds := credentials.NewTLS(tlsProvider.TLSConfig())
		grpcOpts = append(grpcOpts, grpc.Creds(creds))
	}

	grpcOpts = append(grpcOpts,
		grpc.ChainUnaryInterceptor(
			middleware.UnaryRequestIDInterceptor(),
			middleware.UnaryRateLimitInterceptor(rateLimiter),
			middleware.UnaryValidationInterceptor(),
			middleware.UnaryAuthInterceptor(jwtManager),
		),
		grpc.StreamInterceptor(middleware.StreamAuthInterceptor(jwtManager)),
	)
	grpcServer := grpc.NewServer(grpcOpts...)

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
	importpb.RegisterImportServiceServer(grpcServer, importService)
	// Only enable gRPC reflection in dev/staging (default off for security)
	if os.Getenv("ENABLE_GRPC_REFLECTION") == "true" {
		reflection.Register(grpcServer)
		logger.Infof("gRPC reflection enabled (ENABLE_GRPC_REFLECTION=true)")
	}

	// serverErr carries a fatal error from a server goroutine back to main so
	// it can shut down gracefully (running defers) instead of os.Exit-ing from
	// the goroutine and skipping pool.Close / context cancel / WS close.
	// Buffered for the two server goroutines (gRPC + WebSocket) so neither
	// blocks if main has already begun shutting down for the other reason.
	serverErr := make(chan error, 2)

	// Start gRPC
	grpcLis, err := net.Listen("tcp4", fmt.Sprintf("0.0.0.0:%s", grpcPort))
	if err != nil {
		logger.Fatalf("failed to listen on port %s: %v", grpcPort, err)
	}

	go func() {
		logger.Infof("gRPC server listening on :%s", grpcPort)
		if err := grpcServer.Serve(grpcLis); err != nil {
			logger.Errorf("gRPC server error: %v", err)
			serverErr <- err
		}
	}()

	// Start WebSocket server
	mux := http.NewServeMux()
	mux.HandleFunc("/ws", hub.HandleWebSocket)
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		// Independent 3s timeout — never inherit LB timeout
		ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		defer cancel()
		if err := pool.Ping(ctx); err != nil {
			w.WriteHeader(http.StatusServiceUnavailable)
			w.Write([]byte("db unhealthy"))
			return
		}
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})

	wsServer := &http.Server{
		Addr:    fmt.Sprintf("0.0.0.0:%s", wsPort),
		Handler: mux,
	}

	go func() {
		if tlsProvider != nil {
			wsServer.TLSConfig = tlsProvider.TLSConfig()
			logger.Infof("WebSocket server listening on :%s (TLS)", wsPort)
			// Empty cert/key paths: TLS is handled by TLSConfig.GetCertificate
			// which serves the hot-reloadable certificate via atomic.Pointer.
			if err := wsServer.ListenAndServeTLS("", ""); err != nil && err != http.ErrServerClosed {
				logger.Errorf("WebSocket server error: %v", err)
				serverErr <- err
			}
		} else {
			logger.Infof("WebSocket server listening on :%s (plaintext)", wsPort)
			if err := wsServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
				logger.Errorf("WebSocket server error: %v", err)
				serverErr <- err
			}
		}
	}()

	// Start scheduled tasks
	go runScheduledTasks(ctx, notifyService)
	go runMarketRefreshTasks(ctx, marketService)
	go runDepreciationTask(ctx, assetService)
	go runExchangeRateRefreshTask(ctx, exchangeService)
	go runImportSessionCleanupTask(ctx, importService)

	// Graceful shutdown: triggered by an OS signal or a fatal server error.
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	select {
	case <-quit:
		logger.Infof("shutting down...")
	case err := <-serverErr:
		logger.Errorf("fatal server error, shutting down: %v", err)
	}
	cancel() // signal scheduled tasks to stop

	// Graceful stop with timeout
	stopped := make(chan struct{})
	go func() {
		grpcServer.GracefulStop()
		close(stopped)
	}()
	select {
	case <-stopped:
		logger.Infof("gRPC server stopped gracefully")
	case <-time.After(10 * time.Second):
		logger.Warnf("gRPC graceful stop timed out, forcing...")
		grpcServer.Stop()
	}

	wsServer.Shutdown(context.Background())
	logger.Infof("server stopped")
}

// runScheduledTasks runs periodic tasks. Currently checks budgets daily at 21:00 CST.
func runScheduledTasks(ctx context.Context, notifyService *notify.Service) {
	cst, err := time.LoadLocation("Asia/Shanghai")
	if err != nil {
		logger.Warnf("scheduler: failed to load CST timezone, falling back to UTC+8: %v", err)
		cst = time.FixedZone("CST", 8*60*60)
	}

	logger.Infof("scheduler: started, budget+loan check scheduled daily at 21:00 CST")

	for {
		now := time.Now().In(cst)
		// Next 21:00 CST
		next := time.Date(now.Year(), now.Month(), now.Day(), 21, 0, 0, 0, cst)
		if now.After(next) {
			next = next.Add(24 * time.Hour)
		}
		waitDuration := time.Until(next)
		logger.Infof("scheduler: next budget check at %s (in %s)", next.Format(time.RFC3339), waitDuration.Round(time.Minute))

		select {
		case <-ctx.Done():
			logger.Infof("scheduler: stopped")
			return
		case <-time.After(waitDuration):
			logger.Infof("scheduler: running budget check...")
			checkCtx, checkCancel := context.WithTimeout(ctx, 5*time.Minute)
			if err := notifyService.CheckBudgets(checkCtx); err != nil {
				logger.Errorf("scheduler: budget check error: %v", err)
			}
			checkCancel()

			if ctx.Err() != nil {
				logger.Infof("scheduler: shutdown during checks, aborting remaining")
				return
			}

			logger.Infof("scheduler: running loan reminder check...")
			loanCtx, loanCancel := context.WithTimeout(ctx, 5*time.Minute)
			if err := notifyService.CheckLoanReminders(loanCtx); err != nil {
				logger.Errorf("scheduler: loan reminder check error: %v", err)
			}
			loanCancel()

			if ctx.Err() != nil {
				logger.Infof("scheduler: shutdown during checks, aborting remaining")
				return
			}

			logger.Infof("scheduler: running custom reminder check...")
			reminderCtx, reminderCancel := context.WithTimeout(ctx, 5*time.Minute)
			if err := notifyService.CheckCustomReminders(reminderCtx); err != nil {
				logger.Errorf("scheduler: custom reminder check error: %v", err)
			}
			reminderCancel()

			if ctx.Err() != nil {
				logger.Infof("scheduler: shutdown during checks, aborting remaining")
				return
			}

			logger.Infof("scheduler: all checks complete")
		}
	}
}

// runMarketRefreshTasks refreshes market quotes on a schedule.
// Uses market.IsTradingHours to determine per-market refresh:
// - Trading hours: every 15 min
// - Off-hours: every 4 hours (stocks), crypto always 15 min
func runMarketRefreshTasks(ctx context.Context, marketService *market.Service) {
	logger.Infof("market-scheduler: started")

	for {
		now := time.Now()

		// Determine interval based on what markets are active
		// Crypto is always active → always 15 min base interval
		interval := market.ComputeMarketIntervalForTypes(now, []string{"crypto"})

		select {
		case <-ctx.Done():
			logger.Infof("market-scheduler: stopped")
			return
		case <-time.After(interval):
			now = time.Now()
			refreshCtx, cancel := context.WithTimeout(ctx, 2*time.Minute)

			// Always refresh crypto (24/7)
			if err := marketService.RefreshQuotes(refreshCtx, []string{"crypto"}); err != nil {
				logger.Errorf("market-scheduler: crypto refresh error: %v", err)
			}

			if ctx.Err() != nil {
				logger.Infof("market-scheduler: shutdown during refresh, aborting remaining")
				cancel()
				return
			}

			// Refresh A-share/fund only during CN trading hours
			if market.IsTradingHours(now, "a_share") {
				if err := marketService.RefreshQuotes(refreshCtx, []string{"a_share", "fund"}); err != nil {
					logger.Errorf("market-scheduler: a_share/fund refresh error: %v", err)
				}
			}

			if ctx.Err() != nil {
				logger.Infof("market-scheduler: shutdown during refresh, aborting remaining")
				cancel()
				return
			}

			// Refresh HK stocks only during HK trading hours
			if market.IsTradingHours(now, "hk_stock") {
				if err := marketService.RefreshQuotes(refreshCtx, []string{"hk_stock"}); err != nil {
					logger.Errorf("market-scheduler: hk_stock refresh error: %v", err)
				}
			}

			if ctx.Err() != nil {
				logger.Infof("market-scheduler: shutdown during refresh, aborting remaining")
				cancel()
				return
			}

			// Refresh US stocks only during US trading hours
			if market.IsTradingHours(now, "us_stock") {
				if err := marketService.RefreshQuotes(refreshCtx, []string{"us_stock"}); err != nil {
					logger.Errorf("market-scheduler: us_stock refresh error: %v", err)
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
		logger.Warnf("depreciation-scheduler: failed to load CST timezone, falling back to UTC+8: %v", err)
		cst = time.FixedZone("CST", 8*60*60)
	}

	logger.Infof("depreciation-scheduler: started, monthly depreciation on 1st at 00:05 CST")

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
		logger.Infof("depreciation-scheduler: next run at %s (in %s)", next.Format(time.RFC3339), waitDuration.Round(time.Minute))

		select {
		case <-ctx.Done():
			logger.Infof("depreciation-scheduler: stopped")
			return
		case <-time.After(waitDuration):
			logger.Infof("depreciation-scheduler: running monthly depreciation...")
			depCtx, depCancel := context.WithTimeout(ctx, 10*time.Minute)
			if err := assetService.RunMonthlyDepreciationAll(depCtx); err != nil {
				logger.Errorf("depreciation-scheduler: error: %v", err)
			}
			depCancel()
			logger.Infof("depreciation-scheduler: complete")
		}
	}
}

func getEnv(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok {
		return value
	}
	return fallback
}

func getEnvInt(key string, fallback int) int {
	if value, ok := os.LookupEnv(key); ok {
		n, err := strconv.Atoi(value)
		if err != nil {
			logger.Warnf("env %s=%q is not a valid integer, using default %d", key, value, fallback)
			return fallback
		}
		return n
	}
	return fallback
}

// getEnvInt32 reads an env var as int32, clamped to [1, math.MaxInt32].
func getEnvInt32(key string, fallback int32) int32 {
	n := getEnvInt(key, int(fallback))
	if n <= 0 {
		logger.Warnf("env %s=%d is not positive, using default %d", key, n, fallback)
		return fallback
	}
	if n > int(^int32(0)>>1) { // math.MaxInt32 without importing math
		logger.Warnf("env %s=%d exceeds int32 max, using default %d", key, n, fallback)
		return fallback
	}
	return int32(n)
}

// runExchangeRateRefreshTask refreshes exchange rates every hour.
func runExchangeRateRefreshTask(ctx context.Context, exchangeService *market.ExchangeService) {
	logger.Infof("exchange-scheduler: started, refresh every hour")

	// Initial refresh on startup
	refreshCtx, cancel := context.WithTimeout(ctx, 1*time.Minute)
	if err := exchangeService.RefreshExchangeRates(refreshCtx); err != nil {
		logger.Errorf("exchange-scheduler: initial refresh error: %v", err)
	}
	cancel()

	for {
		select {
		case <-ctx.Done():
			logger.Infof("exchange-scheduler: stopped")
			return
		case <-time.After(1 * time.Hour):
			refreshCtx, cancel := context.WithTimeout(ctx, 1*time.Minute)
			if err := exchangeService.RefreshExchangeRates(refreshCtx); err != nil {
				logger.Errorf("exchange-scheduler: refresh error: %v", err)
			}
			cancel()
		}
	}
}

// runImportSessionCleanupTask cleans up expired import sessions every hour.
func runImportSessionCleanupTask(ctx context.Context, importService *importcsv.Service) {
	logger.Infof("import-cleanup-scheduler: started, cleanup every hour")

	for {
		select {
		case <-ctx.Done():
			logger.Infof("import-cleanup-scheduler: stopped")
			return
		case <-time.After(1 * time.Hour):
			cleanCtx, cancel := context.WithTimeout(ctx, 1*time.Minute)
			if err := importService.CleanupExpiredSessions(cleanCtx); err != nil {
				logger.Errorf("import-cleanup-scheduler: error: %v", err)
			}
			cancel()
		}
	}
}
