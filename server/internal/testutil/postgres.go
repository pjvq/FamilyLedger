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
	// Check Docker is available — in CI, Docker is mandatory.
	if err := exec.Command("docker", "info").Run(); err != nil {
		if os.Getenv("CI") != "" {
			fmt.Println("FATAL: Docker is required in CI but not available")
			os.Exit(1)
		}
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

	// Run all migrations
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

// TruncateAllExceptSeeds dynamically queries all public tables and truncates them,
// excluding schema_migrations and seed data tables (categories).
// This approach is resilient to new migrations adding tables.
func (db *TestDB) TruncateAllExceptSeeds(t *testing.T) {
	t.Helper()
	ctx := context.Background()

	// Dynamically discover tables, excluding system/seed tables
	const q = `SELECT tablename FROM pg_tables
	           WHERE schemaname = 'public'
	           AND tablename NOT IN ('schema_migrations', 'categories')`

	rows, err := db.Pool.Query(ctx, q)
	if err != nil {
		t.Fatalf("failed to query table list: %v", err)
	}
	defer rows.Close()

	var tables []string
	for rows.Next() {
		var name string
		if err := rows.Scan(&name); err != nil {
			t.Fatalf("failed to scan table name: %v", err)
		}
		tables = append(tables, name)
	}

	for _, table := range tables {
		_, err := db.Pool.Exec(ctx, fmt.Sprintf("TRUNCATE TABLE %s RESTART IDENTITY CASCADE", table))
		if err != nil {
			t.Logf("note: truncate %s: %v", table, err)
		}
	}
}

// MustExec executes SQL or fails the test.
func MustExec(t *testing.T, pool *pgxpool.Pool, sql string, args ...any) {
	t.Helper()
	_, err := pool.Exec(context.Background(), sql, args...)
	if err != nil {
		t.Fatalf("MustExec failed: %v\nSQL: %s", err, sql)
	}
}
