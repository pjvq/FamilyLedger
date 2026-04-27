//go:build bench

package bench

import (
	"context"
	"fmt"
	"log"
	"net"
	"os"
	"os/exec"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/modules/postgres"
	"github.com/testcontainers/testcontainers-go/wait"

	"github.com/golang-migrate/migrate/v4"
	_ "github.com/golang-migrate/migrate/v4/database/postgres"
	_ "github.com/golang-migrate/migrate/v4/source/file"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/reflection"

	"github.com/familyledger/server/internal/auth"
	"github.com/familyledger/server/internal/dashboard"
	syncsvc "github.com/familyledger/server/internal/sync"
	"github.com/familyledger/server/internal/transaction"

	authpb "github.com/familyledger/server/proto/auth"
	dashpb "github.com/familyledger/server/proto/dashboard"
	syncpb "github.com/familyledger/server/proto/sync"
	txnpb "github.com/familyledger/server/proto/transaction"
)

const (
	benchPort      = ":50061" // Use different port to avoid conflicts
	benchDBName    = "familyledger_bench"
	benchMigration = "../../migrations"
)

// TestBenchServer starts a full gRPC server with testcontainers PostgreSQL
// and runs ghz load tests against it.
//
// Usage:
//
//	cd server/bench
//	go test -tags bench -run TestBenchServer -v -timeout 300s
func TestBenchServer(t *testing.T) {
	if err := exec.Command("docker", "info").Run(); err != nil {
		t.Skip("SKIP: Docker not available. Bench tests require Docker.")
	}

	if _, err := exec.LookPath("ghz"); err != nil {
		t.Skip("SKIP: ghz not installed. Run: brew install ghz")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	// ─── Start PostgreSQL ─────────────────────────────────────
	t.Log("Starting PostgreSQL container...")
	pgContainer, err := postgres.Run(ctx,
		"postgres:16-alpine",
		postgres.WithDatabase(benchDBName),
		postgres.WithUsername("bench"),
		postgres.WithPassword("bench"),
		testcontainers.WithWaitStrategy(
			wait.ForLog("database system is ready to accept connections").
				WithOccurrence(2).
				WithStartupTimeout(30*time.Second),
		),
	)
	if err != nil {
		t.Fatalf("Failed to start postgres container: %v", err)
	}
	defer func() {
		if err := pgContainer.Terminate(ctx); err != nil {
			t.Logf("Failed to terminate container: %v", err)
		}
	}()

	connStr, err := pgContainer.ConnectionString(ctx, "sslmode=disable")
	if err != nil {
		t.Fatalf("Failed to get connection string: %v", err)
	}
	t.Logf("PostgreSQL connection: %s", connStr)

	// ─── Run Migrations ───────────────────────────────────────
	t.Log("Running migrations...")
	m, err := migrate.New(
		fmt.Sprintf("file://%s", benchMigration),
		connStr,
	)
	if err != nil {
		t.Fatalf("Failed to create migrator: %v", err)
	}
	if err := m.Up(); err != nil && err != migrate.ErrNoChange {
		t.Fatalf("Migration failed: %v", err)
	}

	// ─── Connect to DB ────────────────────────────────────────
	pool, err := pgxpool.New(ctx, connStr)
	if err != nil {
		t.Fatalf("Failed to connect to database: %v", err)
	}
	defer pool.Close()

	// ─── Start gRPC Server ────────────────────────────────────
	t.Log("Starting gRPC server...")
	lis, err := net.Listen("tcp", benchPort)
	if err != nil {
		t.Fatalf("Failed to listen on %s: %v", benchPort, err)
	}

	srv := grpc.NewServer()
	reflection.Register(srv)

	// Register services — adapt based on actual constructor signatures
	// These are placeholder registrations; adjust to match actual project code
	os.Setenv("DATABASE_URL", connStr)
	os.Setenv("JWT_SECRET", "bench-test-secret-key-for-testing")

	registerServices(t, srv, pool)

	go func() {
		if err := srv.Serve(lis); err != nil {
			log.Printf("gRPC server stopped: %v", err)
		}
	}()
	defer srv.GracefulStop()

	// Wait for server to be ready
	time.Sleep(500 * time.Millisecond)
	verifyServerReady(t, benchPort)

	// ─── Seed Test Data ───────────────────────────────────────
	seedBenchData(t, pool)

	// ─── Run ghz Benchmarks ───────────────────────────────────
	addr := "localhost" + benchPort
	protoDir := "../../proto"
	importPath := "/opt/homebrew/include"
	resultsDir := "./results"
	os.MkdirAll(resultsDir, 0o755)

	benchmarks := []struct {
		name  string
		proto string
		call  string
		data  string
	}{
		{
			name:  "auth-login",
			proto: "auth.proto",
			call:  "familyledger.auth.v1.AuthService/Login",
			data:  `{"email":"bench@test.com","password":"benchtest123"}`,
		},
		{
			name:  "transaction-list",
			proto: "transaction.proto",
			call:  "familyledger.transaction.v1.TransactionService/ListTransactions",
			data:  `{"page_size":20}`,
		},
		{
			name:  "dashboard-networth",
			proto: "dashboard.proto",
			call:  "familyledger.dashboard.v1.DashboardService/GetNetWorth",
			data:  `{}`,
		},
		{
			name:  "sync-pull",
			proto: "sync.proto",
			call:  "familyledger.sync.v1.SyncService/PullChanges",
			data:  `{"client_id":"bench-client"}`,
		},
	}

	for _, bm := range benchmarks {
		t.Run(bm.name, func(t *testing.T) {
			outputFile := fmt.Sprintf("%s/%s.json", resultsDir, bm.name)
			cmd := exec.CommandContext(ctx, "ghz",
				"--insecure",
				"--proto", fmt.Sprintf("%s/%s", protoDir, bm.proto),
				"--import-paths", fmt.Sprintf("%s,%s", protoDir, importPath),
				"--call", bm.call,
				"--data", bm.data,
				"--total", "500",
				"--concurrency", "10",
				"--connections", "5",
				"--format", "pretty",
				"--output", outputFile,
				addr,
			)
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr

			if err := cmd.Run(); err != nil {
				t.Errorf("ghz benchmark %s failed: %v", bm.name, err)
			}
		})
	}
}

// registerServices registers gRPC services on the server.
// Adjust constructor calls to match actual project code.
func registerServices(t *testing.T, srv *grpc.Server, pool *pgxpool.Pool) {
	t.Helper()

	// NOTE: These registrations depend on your actual service constructors.
	// Adjust the constructor arguments based on your codebase.
	// Common patterns:
	//   authSvc := auth.NewService(pool, jwtSecret)
	//   txnSvc := transaction.NewService(pool)
	//   dashSvc := dashboard.NewService(pool)
	//   syncSvc := syncsvc.NewService(pool)

	// Suppress unused import warnings — remove these when wiring is complete
	_ = auth.Service{}
	_ = transaction.Service{}
	_ = dashboard.Service{}
	_ = syncsvc.Service{}
	_ = authpb.AuthServiceServer(nil)
	_ = txnpb.TransactionServiceServer(nil)
	_ = dashpb.DashboardServiceServer(nil)
	_ = syncpb.SyncServiceServer(nil)

	t.Log("TODO: Wire actual service constructors here")
	t.Log("Example: authpb.RegisterAuthServiceServer(srv, auth.NewService(pool, secret))")
}

func verifyServerReady(t *testing.T, port string) {
	t.Helper()
	conn, err := grpc.NewClient("localhost"+port, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		t.Fatalf("Cannot connect to bench server: %v", err)
	}
	conn.Close()
}

func seedBenchData(t *testing.T, pool *pgxpool.Pool) {
	t.Helper()
	ctx := context.Background()

	// Create a test user for auth benchmarks
	_, err := pool.Exec(ctx, `
		INSERT INTO users (id, email, password_hash, name, created_at, updated_at)
		VALUES ('bench-user-id', 'bench@test.com', '$2a$10$benchhashedpassword', 'Bench User', NOW(), NOW())
		ON CONFLICT (email) DO NOTHING
	`)
	if err != nil {
		t.Logf("Warning: failed to seed user (table may not exist yet): %v", err)
	}

	t.Log("Bench data seeded (or skipped if tables don't exist)")
}
