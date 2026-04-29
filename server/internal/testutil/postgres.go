//go:build integration

// Package testutil provides reusable test helpers for integration tests.
// It wraps testcontainers-go to provide a shared PostgreSQL container
// with automatic migration and per-test data isolation.
package testutil

import (
	"context"
	"fmt"
	"log"
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
)

// TestDB holds a shared PostgreSQL container + connection pool for integration tests.
type TestDB struct {
	Pool      *pgxpool.Pool
	Container testcontainers.Container
	ConnStr   string
}

// SetupPostgres starts a PostgreSQL container, runs all migrations, and returns
// a TestDB. Call this from TestMain. The caller is responsible for calling Teardown().
//
// migrationsPath is relative to the test file, e.g. "../../migrations".
func SetupPostgres(migrationsPath string) (*TestDB, error) {
	// Check Docker is available
	if err := exec.Command("docker", "info").Run(); err != nil {
		fmt.Println("SKIP: Docker is not available. Integration tests require a running Docker daemon.")
		fmt.Println("Start Docker and run: go test ./... -tags=integration -count=1 -v")
		os.Exit(0)
	}

	ctx := context.Background()

	pgContainer, err := postgres.Run(ctx,
		"postgres:16-alpine",
		postgres.WithDatabase("testdb"),
		postgres.WithUsername("testuser"),
		postgres.WithPassword("testpass"),
		testcontainers.WithWaitStrategy(
			wait.ForLog("database system is ready to accept connections").
				WithOccurrence(2).
				WithStartupTimeout(30*time.Second),
		),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to start PostgreSQL container: %w", err)
	}

	connStr, err := pgContainer.ConnectionString(ctx, "sslmode=disable")
	if err != nil {
		pgContainer.Terminate(ctx)
		return nil, fmt.Errorf("failed to get connection string: %w", err)
	}

	// Run all 38 migrations
	mig, err := migrate.New("file://"+migrationsPath, connStr)
	if err != nil {
		pgContainer.Terminate(ctx)
		return nil, fmt.Errorf("failed to create migrate instance: %w", err)
	}
	if err := mig.Up(); err != nil {
		pgContainer.Terminate(ctx)
		return nil, fmt.Errorf("failed to run migrations: %w", err)
	}
	mig.Close()

	pool, err := pgxpool.New(ctx, connStr)
	if err != nil {
		pgContainer.Terminate(ctx)
		return nil, fmt.Errorf("failed to create pgxpool: %w", err)
	}

	return &TestDB{
		Pool:      pool,
		Container: pgContainer,
		ConnStr:   connStr,
	}, nil
}

// Teardown closes the pool and terminates the container.
func (db *TestDB) Teardown() {
	if db.Pool != nil {
		db.Pool.Close()
	}
	if db.Container != nil {
		if err := db.Container.Terminate(context.Background()); err != nil {
			log.Printf("failed to terminate container: %v", err)
		}
	}
}

// TruncateTables truncates the specified tables (RESTART IDENTITY CASCADE).
// Use this in test setup to isolate data between tests while keeping
// the shared container alive.
func (db *TestDB) TruncateTables(t *testing.T, tables ...string) {
	t.Helper()
	ctx := context.Background()
	for _, table := range tables {
		_, err := db.Pool.Exec(ctx, fmt.Sprintf("TRUNCATE TABLE %s RESTART IDENTITY CASCADE", table))
		if err != nil {
			t.Fatalf("failed to truncate %s: %v", table, err)
		}
	}
}

// TruncateAllExceptSeeds truncates all user-data tables while preserving
// seeded categories and other reference data.
func (db *TestDB) TruncateAllExceptSeeds(t *testing.T) {
	t.Helper()
	tables := []string{
		"audit_logs",
		"budget_alerts",
		"budgets",
		"investment_transactions",
		"investments",
		"loan_groups",
		"loans",
		"loan_repayments",
		"fixed_assets",
		"asset_valuations",
		"price_history",
		"sync_operations",
		"transactions",
		"accounts",
		"family_members",
		"families",
		"import_sessions",
		"users",
	}
	ctx := context.Background()
	for _, table := range tables {
		_, err := db.Pool.Exec(ctx, fmt.Sprintf("TRUNCATE TABLE %s RESTART IDENTITY CASCADE", table))
		if err != nil {
			// Some tables may not exist in older migrations — skip gracefully
			t.Logf("note: truncate %s: %v", table, err)
		}
	}
}
