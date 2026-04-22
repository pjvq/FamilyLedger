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
	"github.com/familyledger/server/internal/auth"
	"github.com/familyledger/server/internal/budget"
	"github.com/familyledger/server/internal/family"
	"github.com/familyledger/server/internal/loan"
	"github.com/familyledger/server/internal/notify"
	syncsvc "github.com/familyledger/server/internal/sync"
	"github.com/familyledger/server/internal/transaction"
	"github.com/familyledger/server/pkg/db"
	jwtpkg "github.com/familyledger/server/pkg/jwt"
	"github.com/familyledger/server/pkg/middleware"
	"github.com/familyledger/server/pkg/ws"

	acctpb "github.com/familyledger/server/proto/account"
	authpb "github.com/familyledger/server/proto/auth"
	budgetpb "github.com/familyledger/server/proto/budget"
	familypb "github.com/familyledger/server/proto/family"
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

	jwtSecret := getEnv("JWT_SECRET", "familyledger-dev-secret-change-in-production")
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
	hub := ws.NewHub()

	// Services
	authService := auth.NewService(pool, jwtManager)
	txnService := transaction.NewService(pool)
	syncService := syncsvc.NewService(pool, hub)
	familyService := family.NewService(pool)
	accountService := account.NewService(pool)
	budgetService := budget.NewService(pool)
	loanService := loan.NewService(pool)
	notifyService := notify.NewService(pool)

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
	reflection.Register(grpcServer)

	// Start gRPC
	grpcLis, err := net.Listen("tcp", fmt.Sprintf(":%s", grpcPort))
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
		Addr:    fmt.Sprintf(":%s", wsPort),
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

			// TODO: Push notifications via FCM/APNs (placeholder — just logged for now)
			log.Println("scheduler: all checks complete")
		}
	}
}

func getEnv(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok {
		return value
	}
	return fallback
}
