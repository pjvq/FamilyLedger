//go:build integration

package benchmark

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/exec"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/modules/postgres"
	"github.com/testcontainers/testcontainers-go/wait"

	"github.com/golang-migrate/migrate/v4"
	_ "github.com/golang-migrate/migrate/v4/database/postgres"
	_ "github.com/golang-migrate/migrate/v4/source/file"
)

var sharedPool *pgxpool.Pool
var sharedContainer testcontainers.Container

func TestMain(m *testing.M) {
	if err := exec.Command("docker", "info").Run(); err != nil {
		fmt.Println("SKIP: Docker not available. Run: go test -tags=integration -count=1 -v ./internal/benchmark/...")
		os.Exit(0)
	}

	ctx := context.Background()

	pgContainer, err := postgres.Run(ctx,
		"postgres:16-alpine",
		postgres.WithDatabase("benchdb"),
		postgres.WithUsername("benchuser"),
		postgres.WithPassword("benchpass"),
		testcontainers.WithWaitStrategy(
			wait.ForLog("database system is ready to accept connections").
				WithOccurrence(2).
				WithStartupTimeout(30*time.Second),
		),
	)
	if err != nil {
		log.Fatalf("failed to start PostgreSQL container: %v", err)
	}

	connStr, err := pgContainer.ConnectionString(ctx, "sslmode=disable")
	if err != nil {
		log.Fatalf("failed to get connection string: %v", err)
	}

	// Run migrations
	mig, err := migrate.New("file://../../migrations", connStr)
	if err != nil {
		log.Fatalf("failed to create migrate instance: %v", err)
	}
	if err := mig.Up(); err != nil && err.Error() != "no change" {
		log.Fatalf("failed to run migrations: %v", err)
	}
	mig.Close()

	pool, err := pgxpool.New(ctx, connStr)
	if err != nil {
		log.Fatalf("failed to create pgxpool: %v", err)
	}

	sharedPool = pool
	sharedContainer = pgContainer

	code := m.Run()

	pool.Close()
	if err := pgContainer.Terminate(ctx); err != nil {
		log.Printf("failed to terminate container: %v", err)
	}
	os.Exit(code)
}

// seedTestUser creates a user and returns its UUID.
func seedTestUser(t *testing.T, ctx context.Context) uuid.UUID {
	t.Helper()
	userID := uuid.New()
	_, err := sharedPool.Exec(ctx,
		`INSERT INTO users (id, email, password_hash)
		 VALUES ($1, $2, 'hash')
		 ON CONFLICT (id) DO NOTHING`,
		userID, fmt.Sprintf("bench_%s@test.com", userID.String()[:8]),
	)
	require.NoError(t, err)
	return userID
}

// seedTestAccount creates an account for the given user.
func seedTestAccount(t *testing.T, ctx context.Context, userID uuid.UUID) uuid.UUID {
	t.Helper()
	accountID := uuid.New()
	_, err := sharedPool.Exec(ctx,
		`INSERT INTO accounts (id, user_id, name, type, balance, currency)
		 VALUES ($1, $2, 'Bench Account', 'bank_card', 0, 'CNY')`,
		accountID, userID,
	)
	require.NoError(t, err)
	return accountID
}

// seedTestCategory returns the first available category ID.
func seedTestCategory(t *testing.T, ctx context.Context) uuid.UUID {
	t.Helper()
	var catID uuid.UUID
	err := sharedPool.QueryRow(ctx,
		`SELECT id FROM categories LIMIT 1`,
	).Scan(&catID)
	require.NoError(t, err, "need at least one seeded category")
	return catID
}

// ═══════════════════════════════════════════════════════════════════════════════
// Large Dataset Tests
// ═══════════════════════════════════════════════════════════════════════════════

func TestLargeDataset_ListTransactions_Pagination(t *testing.T) {
	ctx := context.Background()

	// Clean up before test
	_, _ = sharedPool.Exec(ctx, "TRUNCATE transactions CASCADE")
	_, _ = sharedPool.Exec(ctx, "DELETE FROM accounts WHERE name = 'Bench Account'")
	_, _ = sharedPool.Exec(ctx, "DELETE FROM users WHERE email LIKE 'bench_%@test.com'")

	userID := seedTestUser(t, ctx)
	accountID := seedTestAccount(t, ctx, userID)
	categoryID := seedTestCategory(t, ctx)

	// Insert 100,000 transactions in batches of 1000
	const totalTransactions = 100000
	const batchSize = 1000
	t.Logf("Inserting %d transactions...", totalTransactions)

	startInsert := time.Now()
	for batch := 0; batch < totalTransactions/batchSize; batch++ {
		tx, err := sharedPool.Begin(ctx)
		require.NoError(t, err)

		for i := 0; i < batchSize; i++ {
			idx := batch*batchSize + i
			txnDate := time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC).Add(time.Duration(idx) * time.Minute)
			_, err = tx.Exec(ctx,
				`INSERT INTO transactions (user_id, account_id, category_id, amount, currency, amount_cny, exchange_rate, type, note, txn_date)
				 VALUES ($1, $2, $3, $4, 'CNY', $4, 1.0, 'expense', $5, $6)`,
				userID, accountID, categoryID, int64(100+idx%9900),
				fmt.Sprintf("transaction-%d", idx), txnDate,
			)
			require.NoError(t, err)
		}
		require.NoError(t, tx.Commit(ctx))
	}
	t.Logf("Insert complete in %v", time.Since(startInsert))

	// Test: Verify total count
	var count int64
	err := sharedPool.QueryRow(ctx,
		"SELECT COUNT(*) FROM transactions WHERE user_id = $1 AND deleted_at IS NULL",
		userID,
	).Scan(&count)
	require.NoError(t, err)
	assert.Equal(t, int64(totalTransactions), count)

	// Test: First page with LIMIT/OFFSET
	t.Run("first_page", func(t *testing.T) {
		start := time.Now()
		rows, err := sharedPool.Query(ctx,
			`SELECT id, amount, txn_date FROM transactions
			 WHERE user_id = $1 AND deleted_at IS NULL
			 ORDER BY txn_date DESC, id DESC
			 LIMIT 20`,
			userID,
		)
		require.NoError(t, err)
		defer rows.Close()

		var results []uuid.UUID
		for rows.Next() {
			var id uuid.UUID
			var amount int64
			var txnDate time.Time
			require.NoError(t, rows.Scan(&id, &amount, &txnDate))
			results = append(results, id)
		}
		assert.Len(t, results, 20)
		t.Logf("First page query: %v", time.Since(start))
	})

	// Test: Deep pagination with OFFSET
	t.Run("deep_offset_pagination", func(t *testing.T) {
		offsets := []int{0, 1000, 10000, 50000, 99980}
		for _, offset := range offsets {
			start := time.Now()
			rows, err := sharedPool.Query(ctx,
				`SELECT id FROM transactions
				 WHERE user_id = $1 AND deleted_at IS NULL
				 ORDER BY txn_date DESC, id DESC
				 LIMIT 20 OFFSET $2`,
				userID, offset,
			)
			require.NoError(t, err)

			var results []uuid.UUID
			for rows.Next() {
				var id uuid.UUID
				require.NoError(t, rows.Scan(&id))
				results = append(results, id)
			}
			rows.Close()

			expectedLen := 20
			if offset == 99980 {
				expectedLen = 20 // 100000 - 99980 = 20
			}
			assert.Len(t, results, expectedLen, "offset=%d", offset)
			t.Logf("OFFSET %d query: %v", offset, time.Since(start))
		}
	})

	// Test: Cursor-based pagination consistency
	t.Run("cursor_pagination_no_duplicates", func(t *testing.T) {
		var allIDs []uuid.UUID
		var cursorDate *time.Time
		var cursorID *uuid.UUID
		pageCount := 0

		for {
			var query string
			var args []interface{}

			if cursorDate == nil {
				query = `SELECT id, txn_date FROM transactions
						 WHERE user_id = $1 AND deleted_at IS NULL
						 ORDER BY txn_date DESC, id DESC LIMIT 100`
				args = []interface{}{userID}
			} else {
				query = `SELECT id, txn_date FROM transactions
						 WHERE user_id = $1 AND deleted_at IS NULL
						   AND (txn_date, id) < ($2, $3)
						 ORDER BY txn_date DESC, id DESC LIMIT 100`
				args = []interface{}{userID, *cursorDate, *cursorID}
			}

			rows, err := sharedPool.Query(ctx, query, args...)
			require.NoError(t, err)

			var pageIDs []uuid.UUID
			var lastDate time.Time
			var lastID uuid.UUID
			for rows.Next() {
				var id uuid.UUID
				var txnDate time.Time
				require.NoError(t, rows.Scan(&id, &txnDate))
				pageIDs = append(pageIDs, id)
				lastDate = txnDate
				lastID = id
			}
			rows.Close()

			if len(pageIDs) == 0 {
				break
			}
			allIDs = append(allIDs, pageIDs...)
			cursorDate = &lastDate
			cursorID = &lastID
			pageCount++

			// Safety: don't loop forever
			if pageCount > 1100 {
				t.Fatal("too many pages")
			}
		}

		// Verify no duplicates
		seen := make(map[uuid.UUID]bool, len(allIDs))
		for _, id := range allIDs {
			assert.False(t, seen[id], "duplicate ID found: %s", id)
			seen[id] = true
		}
		assert.Equal(t, totalTransactions, len(allIDs), "cursor pagination should return all records")
		t.Logf("Cursor pagination: %d pages, %d total records", pageCount, len(allIDs))
	})
}

func TestLargeDataset_Dashboard_Aggregation(t *testing.T) {
	ctx := context.Background()

	// Clean up
	_, _ = sharedPool.Exec(ctx, "TRUNCATE transactions CASCADE")
	_, _ = sharedPool.Exec(ctx, "DELETE FROM accounts WHERE name LIKE 'Bench%'")
	_, _ = sharedPool.Exec(ctx, "DELETE FROM users WHERE email LIKE 'bench_%@test.com'")

	userID := seedTestUser(t, ctx)
	accountID := seedTestAccount(t, ctx, userID)

	// Insert 1000 categories
	t.Log("Inserting 1000 categories...")
	categoryIDs := make([]uuid.UUID, 1000)
	for i := 0; i < 1000; i++ {
		categoryIDs[i] = uuid.New()
		_, err := sharedPool.Exec(ctx,
			`INSERT INTO categories (id, name, icon, type, is_preset, sort_order)
			 VALUES ($1, $2, '📁', 'expense', false, $3)`,
			categoryIDs[i], fmt.Sprintf("category-%d", i), i+1000,
		)
		require.NoError(t, err)
	}

	// Insert transactions spread across all categories
	t.Log("Inserting 10000 transactions across 1000 categories...")
	tx, err := sharedPool.Begin(ctx)
	require.NoError(t, err)
	for i := 0; i < 10000; i++ {
		catIdx := i % 1000
		txnDate := time.Date(2024, time.Month(i%12+1), i%28+1, 0, 0, 0, 0, time.UTC)
		_, err = tx.Exec(ctx,
			`INSERT INTO transactions (user_id, account_id, category_id, amount, currency, amount_cny, exchange_rate, type, note, txn_date)
			 VALUES ($1, $2, $3, $4, 'CNY', $4, 1.0, 'expense', $5, $6)`,
			userID, accountID, categoryIDs[catIdx], int64(100*(catIdx+1)),
			fmt.Sprintf("txn-%d", i), txnDate,
		)
		require.NoError(t, err)
	}
	require.NoError(t, tx.Commit(ctx))

	// Test: Category aggregation with timeout
	t.Run("category_aggregation_1000_categories", func(t *testing.T) {
		start := time.Now()

		// Simulate dashboard category breakdown query
		rows, err := sharedPool.Query(ctx,
			`SELECT t.category_id, c.name, COALESCE(SUM(t.amount_cny), 0) AS amount
			 FROM transactions t
			 JOIN categories c ON c.id = t.category_id
			 WHERE t.user_id = $1 AND t.type = 'expense' AND t.deleted_at IS NULL
			   AND t.txn_date >= $2 AND t.txn_date < $3
			 GROUP BY t.category_id, c.name
			 ORDER BY amount DESC`,
			userID,
			time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC),
			time.Date(2025, 1, 1, 0, 0, 0, 0, time.UTC),
		)
		require.NoError(t, err)
		defer rows.Close()

		var categoryCount int
		for rows.Next() {
			var catID uuid.UUID
			var name string
			var amount int64
			require.NoError(t, rows.Scan(&catID, &name, &amount))
			categoryCount++
		}
		elapsed := time.Since(start)
		t.Logf("Aggregation over %d categories: %v", categoryCount, elapsed)

		assert.Greater(t, categoryCount, 0)
		// Should complete within 5 seconds even with 1000 categories
		assert.Less(t, elapsed, 5*time.Second, "aggregation should not timeout")
	})

	// Cleanup custom categories
	_, _ = sharedPool.Exec(ctx, "DELETE FROM categories WHERE name LIKE 'category-%'")
}
