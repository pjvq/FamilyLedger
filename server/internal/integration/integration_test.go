//go:build integration

package integration

import (
	"context"
	"database/sql"
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

// sharedDB is the single PostgreSQL container shared across all tests.
var sharedDB *testDB

// testDB holds the shared database connection.
type testDB struct {
	pool      *pgxpool.Pool
	container testcontainers.Container
	connStr   string
}

// TestMain starts a single PostgreSQL container, runs migrations, and executes all tests.
func TestMain(m *testing.M) {
	// Check Docker is available
	if err := exec.Command("docker", "info").Run(); err != nil {
		fmt.Println("SKIP: Docker is not available. Integration tests require a running Docker daemon.")
		fmt.Println("Start Docker and run: go test ./internal/integration/... -tags=integration -count=1 -v")
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
	if err := mig.Up(); err != nil {
		log.Fatalf("failed to run migrations: %v", err)
	}
	mig.Close()

	// Create pgxpool connection
	pool, err := pgxpool.New(ctx, connStr)
	if err != nil {
		log.Fatalf("failed to create pgxpool: %v", err)
	}

	sharedDB = &testDB{pool: pool, container: pgContainer, connStr: connStr}

	code := m.Run()

	// Cleanup
	pool.Close()
	if err := pgContainer.Terminate(ctx); err != nil {
		log.Printf("failed to terminate container: %v", err)
	}
	os.Exit(code)
}

// getDB returns the shared test database (cleaned before each test).
func getDB(t *testing.T) *testDB {
	t.Helper()
	truncateAll(t, sharedDB)
	return sharedDB
}

// truncateAll removes all data from key tables while preserving seeded categories.
// categories references users via user_id (migration 033), so we must be careful
// not to CASCADE from users which would wipe seeded preset categories.
func truncateAll(t *testing.T, db *testDB) {
	t.Helper()
	ctx := context.Background()
	_, err := db.pool.Exec(ctx, `
		TRUNCATE sync_operations, transactions, family_members, families, accounts CASCADE;
		DELETE FROM categories WHERE user_id IS NOT NULL;
		DELETE FROM users;
	`)
	require.NoError(t, err, "failed to truncate tables")
}

// ═══════════════════════════════════════════════════════════════════════════════
// Test Helpers
// ═══════════════════════════════════════════════════════════════════════════════

// createTestUser inserts a user and returns the user ID.
func createTestUser(t *testing.T, db *testDB, email string) uuid.UUID {
	t.Helper()
	ctx := context.Background()
	var id uuid.UUID
	err := db.pool.QueryRow(ctx,
		`INSERT INTO users (email, password_hash) VALUES ($1, 'hash') RETURNING id`,
		email,
	).Scan(&id)
	require.NoError(t, err)
	return id
}

// createTestAccount inserts an account and returns the account ID.
func createTestAccount(t *testing.T, db *testDB, userID uuid.UUID, name string, familyID *uuid.UUID) uuid.UUID {
	t.Helper()
	ctx := context.Background()
	var id uuid.UUID
	err := db.pool.QueryRow(ctx,
		`INSERT INTO accounts (user_id, name, type, balance, currency, is_active, family_id)
		 VALUES ($1, $2, 'cash', 0, 'CNY', true, $3) RETURNING id`,
		userID, name, familyID,
	).Scan(&id)
	require.NoError(t, err)
	return id
}

// createTestFamily inserts a family and returns its ID.
func createTestFamily(t *testing.T, db *testDB, ownerID uuid.UUID, name string) uuid.UUID {
	t.Helper()
	ctx := context.Background()
	var id uuid.UUID
	err := db.pool.QueryRow(ctx,
		`INSERT INTO families (name, owner_id) VALUES ($1, $2) RETURNING id`,
		name, ownerID,
	).Scan(&id)
	require.NoError(t, err)
	return id
}

// addFamilyMember adds a user to a family with the given role and permissions JSON.
func addFamilyMember(t *testing.T, db *testDB, familyID, userID uuid.UUID, role string, permissions string) {
	t.Helper()
	ctx := context.Background()
	_, err := db.pool.Exec(ctx,
		`INSERT INTO family_members (family_id, user_id, role, permissions)
		 VALUES ($1, $2, $3, $4::jsonb)`,
		familyID, userID, role, permissions,
	)
	require.NoError(t, err)
}

// getCategoryID returns the first preset category ID.
func getCategoryID(t *testing.T, db *testDB) uuid.UUID {
	t.Helper()
	ctx := context.Background()
	var id uuid.UUID
	err := db.pool.QueryRow(ctx,
		`SELECT id FROM categories WHERE is_preset = true LIMIT 1`,
	).Scan(&id)
	require.NoError(t, err)
	return id
}

// ═══════════════════════════════════════════════════════════════════════════════
// Transaction Service Tests
// ═══════════════════════════════════════════════════════════════════════════════

func TestTransaction_CreateAndQuery(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()

	userID := createTestUser(t, db, "txn_user@test.com")
	acctID := createTestAccount(t, db, userID, "Test Account", nil)
	catID := getCategoryID(t, db)

	// Insert a transaction
	var txnID uuid.UUID
	var createdAt time.Time
	err := db.pool.QueryRow(ctx,
		`INSERT INTO transactions (user_id, account_id, category_id, amount, currency, amount_cny, exchange_rate, type, note, txn_date, tags, image_urls)
		 VALUES ($1, $2, $3, 10000, 'CNY', 10000, 1.0, 'expense'::transaction_type, 'lunch', NOW(), '{}', '{}')
		 RETURNING id, created_at`,
		userID, acctID, catID,
	).Scan(&txnID, &createdAt)
	require.NoError(t, err)
	assert.NotEqual(t, uuid.Nil, txnID)

	// Query it back
	var amount int64
	var note string
	var txnType string
	err = db.pool.QueryRow(ctx,
		`SELECT amount, note, type FROM transactions WHERE id = $1 AND deleted_at IS NULL`,
		txnID,
	).Scan(&amount, &note, &txnType)
	require.NoError(t, err)
	assert.Equal(t, int64(10000), amount)
	assert.Equal(t, "lunch", note)
	assert.Equal(t, "expense", txnType)
}

func TestTransaction_ListByUserID(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()

	user1 := createTestUser(t, db, "user1@test.com")
	user2 := createTestUser(t, db, "user2@test.com")
	acct1 := createTestAccount(t, db, user1, "Account1", nil)
	acct2 := createTestAccount(t, db, user2, "Account2", nil)
	catID := getCategoryID(t, db)

	// Insert transactions for each user
	_, err := db.pool.Exec(ctx,
		`INSERT INTO transactions (user_id, account_id, category_id, amount, currency, amount_cny, exchange_rate, type, note, txn_date, tags, image_urls)
		 VALUES ($1, $2, $3, 100, 'CNY', 100, 1.0, 'expense', 'u1 txn1', NOW(), '{}', '{}'),
		        ($1, $2, $3, 200, 'CNY', 200, 1.0, 'income', 'u1 txn2', NOW(), '{}', '{}')`,
		user1, acct1, catID,
	)
	require.NoError(t, err)

	_, err = db.pool.Exec(ctx,
		`INSERT INTO transactions (user_id, account_id, category_id, amount, currency, amount_cny, exchange_rate, type, note, txn_date, tags, image_urls)
		 VALUES ($1, $2, $3, 300, 'CNY', 300, 1.0, 'expense', 'u2 txn1', NOW(), '{}', '{}')`,
		user2, acct2, catID,
	)
	require.NoError(t, err)

	// List for user1 with personal mode (family_id IS NULL join)
	rows, err := db.pool.Query(ctx,
		`SELECT t.id, t.amount, t.note FROM transactions t
		 JOIN accounts a ON a.id = t.account_id
		 WHERE t.user_id = $1 AND t.deleted_at IS NULL AND a.family_id IS NULL
		 ORDER BY t.txn_date DESC`,
		user1,
	)
	require.NoError(t, err)
	defer rows.Close()

	var count int
	for rows.Next() {
		var id uuid.UUID
		var amt int64
		var n string
		require.NoError(t, rows.Scan(&id, &amt, &n))
		count++
	}
	assert.Equal(t, 2, count, "user1 should see 2 transactions")
}

func TestTransaction_ListByFamilyID(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()

	user1 := createTestUser(t, db, "owner@test.com")
	user2 := createTestUser(t, db, "member@test.com")
	familyID := createTestFamily(t, db, user1, "Test Family")
	addFamilyMember(t, db, familyID, user1, "owner", `{"can_view":true,"can_create":true,"can_edit":true,"can_delete":true,"can_manage_accounts":true}`)
	addFamilyMember(t, db, familyID, user2, "member", `{"can_view":true,"can_create":true,"can_edit":false,"can_delete":false,"can_manage_accounts":false}`)

	// Family account
	familyAcct := createTestAccount(t, db, user1, "Family Account", &familyID)
	// Personal account
	personalAcct := createTestAccount(t, db, user1, "Personal Account", nil)
	catID := getCategoryID(t, db)

	// Insert transaction in family account (from user1)
	_, err := db.pool.Exec(ctx,
		`INSERT INTO transactions (user_id, account_id, category_id, amount, currency, amount_cny, exchange_rate, type, note, txn_date, tags, image_urls)
		 VALUES ($1, $2, $3, 500, 'CNY', 500, 1.0, 'expense', 'family txn', NOW(), '{}', '{}')`,
		user1, familyAcct, catID,
	)
	require.NoError(t, err)

	// Insert transaction in family account (from user2)
	_, err = db.pool.Exec(ctx,
		`INSERT INTO transactions (user_id, account_id, category_id, amount, currency, amount_cny, exchange_rate, type, note, txn_date, tags, image_urls)
		 VALUES ($1, $2, $3, 700, 'CNY', 700, 1.0, 'income', 'family income', NOW(), '{}', '{}')`,
		user2, familyAcct, catID,
	)
	require.NoError(t, err)

	// Insert personal transaction (should NOT appear in family query)
	_, err = db.pool.Exec(ctx,
		`INSERT INTO transactions (user_id, account_id, category_id, amount, currency, amount_cny, exchange_rate, type, note, txn_date, tags, image_urls)
		 VALUES ($1, $2, $3, 999, 'CNY', 999, 1.0, 'expense', 'personal txn', NOW(), '{}', '{}')`,
		user1, personalAcct, catID,
	)
	require.NoError(t, err)

	// Query family transactions (the real SQL from ListTransactions)
	rows, err := db.pool.Query(ctx,
		`SELECT t.id, t.amount, t.note FROM transactions t
		 JOIN accounts a ON a.id = t.account_id
		 WHERE t.deleted_at IS NULL AND a.family_id = $1
		 ORDER BY t.txn_date DESC`,
		familyID,
	)
	require.NoError(t, err)
	defer rows.Close()

	var results []string
	for rows.Next() {
		var id uuid.UUID
		var amt int64
		var n string
		require.NoError(t, rows.Scan(&id, &amt, &n))
		results = append(results, n)
	}
	assert.Equal(t, 2, len(results), "family query should return 2 transactions")
	assert.NotContains(t, results, "personal txn", "personal transaction should not appear in family query")
}

func TestTransaction_Pagination(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()

	userID := createTestUser(t, db, "page_user@test.com")
	acctID := createTestAccount(t, db, userID, "Paged Account", nil)
	catID := getCategoryID(t, db)

	// Insert 5 transactions with different dates
	for i := 0; i < 5; i++ {
		txnDate := time.Date(2024, 1, i+1, 12, 0, 0, 0, time.UTC)
		_, err := db.pool.Exec(ctx,
			`INSERT INTO transactions (user_id, account_id, category_id, amount, currency, amount_cny, exchange_rate, type, note, txn_date, tags, image_urls)
			 VALUES ($1, $2, $3, $4, 'CNY', $4, 1.0, 'expense', $5, $6, '{}', '{}')`,
			userID, acctID, catID, int64((i+1)*100), fmt.Sprintf("txn_%d", i+1), txnDate,
		)
		require.NoError(t, err)
	}

	// Page 1: get first 2 (DESC order, so latest first)
	rows, err := db.pool.Query(ctx,
		`SELECT t.id, t.amount, t.note, t.txn_date FROM transactions t
		 JOIN accounts a ON a.id = t.account_id
		 WHERE t.user_id = $1 AND t.deleted_at IS NULL AND a.family_id IS NULL
		 ORDER BY t.txn_date DESC, t.id DESC
		 LIMIT $2`,
		userID, 2,
	)
	require.NoError(t, err)

	var page1Notes []string
	var lastDate time.Time
	var lastID uuid.UUID
	for rows.Next() {
		var id uuid.UUID
		var amt int64
		var n string
		var d time.Time
		require.NoError(t, rows.Scan(&id, &amt, &n, &d))
		page1Notes = append(page1Notes, n)
		lastDate = d
		lastID = id
	}
	rows.Close()
	assert.Equal(t, 2, len(page1Notes))
	assert.Equal(t, "txn_5", page1Notes[0]) // latest first

	// Page 2: cursor-based pagination
	rows, err = db.pool.Query(ctx,
		`SELECT t.id, t.amount, t.note, t.txn_date FROM transactions t
		 JOIN accounts a ON a.id = t.account_id
		 WHERE t.user_id = $1 AND t.deleted_at IS NULL AND a.family_id IS NULL
		 AND (t.txn_date, t.id) < ($2, $3)
		 ORDER BY t.txn_date DESC, t.id DESC
		 LIMIT $4`,
		userID, lastDate, lastID, 2,
	)
	require.NoError(t, err)

	var page2Notes []string
	for rows.Next() {
		var id uuid.UUID
		var amt int64
		var n string
		var d time.Time
		require.NoError(t, rows.Scan(&id, &amt, &n, &d))
		page2Notes = append(page2Notes, n)
	}
	rows.Close()
	assert.Equal(t, 2, len(page2Notes))
	assert.Equal(t, "txn_3", page2Notes[0])
	assert.Equal(t, "txn_2", page2Notes[1])
}

func TestTransaction_Update(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()

	userID := createTestUser(t, db, "upd_user@test.com")
	acctID := createTestAccount(t, db, userID, "Upd Account", nil)
	catID := getCategoryID(t, db)

	var txnID uuid.UUID
	err := db.pool.QueryRow(ctx,
		`INSERT INTO transactions (user_id, account_id, category_id, amount, currency, amount_cny, exchange_rate, type, note, txn_date, tags, image_urls)
		 VALUES ($1, $2, $3, 1000, 'CNY', 1000, 1.0, 'expense', 'original', NOW(), '{}', '{}')
		 RETURNING id`,
		userID, acctID, catID,
	).Scan(&txnID)
	require.NoError(t, err)

	// Update note and amount
	_, err = db.pool.Exec(ctx,
		`UPDATE transactions SET note = $1, amount = $2, amount_cny = $2, updated_at = NOW()
		 WHERE id = $3 AND deleted_at IS NULL`,
		"updated note", int64(2000), txnID,
	)
	require.NoError(t, err)

	// Verify
	var note string
	var amount int64
	err = db.pool.QueryRow(ctx,
		`SELECT note, amount FROM transactions WHERE id = $1`,
		txnID,
	).Scan(&note, &amount)
	require.NoError(t, err)
	assert.Equal(t, "updated note", note)
	assert.Equal(t, int64(2000), amount)
}

func TestTransaction_SoftDelete(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()

	userID := createTestUser(t, db, "del_user@test.com")
	acctID := createTestAccount(t, db, userID, "Del Account", nil)
	catID := getCategoryID(t, db)

	var txnID uuid.UUID
	err := db.pool.QueryRow(ctx,
		`INSERT INTO transactions (user_id, account_id, category_id, amount, currency, amount_cny, exchange_rate, type, note, txn_date, tags, image_urls)
		 VALUES ($1, $2, $3, 500, 'CNY', 500, 1.0, 'expense', 'to delete', NOW(), '{}', '{}')
		 RETURNING id`,
		userID, acctID, catID,
	).Scan(&txnID)
	require.NoError(t, err)

	// Soft delete
	_, err = db.pool.Exec(ctx,
		`UPDATE transactions SET deleted_at = NOW(), updated_at = NOW() WHERE id = $1`,
		txnID,
	)
	require.NoError(t, err)

	// Verify: deleted_at is set
	var deletedAt sql.NullTime
	err = db.pool.QueryRow(ctx,
		`SELECT deleted_at FROM transactions WHERE id = $1`,
		txnID,
	).Scan(&deletedAt)
	require.NoError(t, err)
	assert.True(t, deletedAt.Valid, "deleted_at should be set after soft delete")

	// Verify: not returned by normal queries (deleted_at IS NULL filter)
	var count int
	err = db.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM transactions WHERE user_id = $1 AND deleted_at IS NULL`,
		userID,
	).Scan(&count)
	require.NoError(t, err)
	assert.Equal(t, 0, count, "soft-deleted transaction should not appear in normal queries")
}

// ═══════════════════════════════════════════════════════════════════════════════
// Dashboard Service Tests
// ═══════════════════════════════════════════════════════════════════════════════

func TestDashboard_PersonalModeSUM(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()

	userID := createTestUser(t, db, "dash_user@test.com")
	otherUser := createTestUser(t, db, "other@test.com")
	familyID := createTestFamily(t, db, userID, "Dash Family")
	addFamilyMember(t, db, familyID, userID, "owner", `{"can_view":true,"can_create":true,"can_edit":true,"can_delete":true,"can_manage_accounts":true}`)

	personalAcct := createTestAccount(t, db, userID, "Personal", nil)
	familyAcct := createTestAccount(t, db, userID, "Family Acct", &familyID)
	otherAcct := createTestAccount(t, db, otherUser, "Other Personal", nil)
	catID := getCategoryID(t, db)

	// Personal transactions
	_, err := db.pool.Exec(ctx,
		`INSERT INTO transactions (user_id, account_id, category_id, amount, currency, amount_cny, exchange_rate, type, note, txn_date, tags, image_urls)
		 VALUES ($1, $2, $3, 1000, 'CNY', 1000, 1.0, 'expense', 'personal expense', NOW(), '{}', '{}'),
		        ($1, $2, $3, 2000, 'CNY', 2000, 1.0, 'income', 'personal income', NOW(), '{}', '{}')`,
		userID, personalAcct, catID,
	)
	require.NoError(t, err)

	// Family transactions (should NOT be counted in personal mode)
	_, err = db.pool.Exec(ctx,
		`INSERT INTO transactions (user_id, account_id, category_id, amount, currency, amount_cny, exchange_rate, type, note, txn_date, tags, image_urls)
		 VALUES ($1, $2, $3, 5000, 'CNY', 5000, 1.0, 'expense', 'family expense', NOW(), '{}', '{}')`,
		userID, familyAcct, catID,
	)
	require.NoError(t, err)

	// Other user's transactions (should NOT be counted)
	_, err = db.pool.Exec(ctx,
		`INSERT INTO transactions (user_id, account_id, category_id, amount, currency, amount_cny, exchange_rate, type, note, txn_date, tags, image_urls)
		 VALUES ($1, $2, $3, 9999, 'CNY', 9999, 1.0, 'expense', 'other user', NOW(), '{}', '{}')`,
		otherUser, otherAcct, catID,
	)
	require.NoError(t, err)

	// Personal mode query: SUM where user_id matches AND account family_id IS NULL
	var totalIncome, totalExpense int64
	err = db.pool.QueryRow(ctx,
		`SELECT COALESCE(SUM(CASE WHEN t.type = 'income' THEN t.amount_cny ELSE 0 END), 0),
		        COALESCE(SUM(CASE WHEN t.type = 'expense' THEN t.amount_cny ELSE 0 END), 0)
		 FROM transactions t
		 JOIN accounts a ON a.id = t.account_id
		 WHERE t.user_id = $1 AND t.deleted_at IS NULL AND a.family_id IS NULL`,
		userID,
	).Scan(&totalIncome, &totalExpense)
	require.NoError(t, err)
	assert.Equal(t, int64(2000), totalIncome, "personal income should be 2000")
	assert.Equal(t, int64(1000), totalExpense, "personal expense should be 1000")
}

func TestDashboard_FamilyModeSUM(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()

	user1 := createTestUser(t, db, "fam_user1@test.com")
	user2 := createTestUser(t, db, "fam_user2@test.com")
	familyID := createTestFamily(t, db, user1, "Budget Family")
	addFamilyMember(t, db, familyID, user1, "owner", `{"can_view":true,"can_create":true,"can_edit":true,"can_delete":true,"can_manage_accounts":true}`)
	addFamilyMember(t, db, familyID, user2, "member", `{"can_view":true,"can_create":true,"can_edit":false,"can_delete":false,"can_manage_accounts":false}`)

	familyAcct := createTestAccount(t, db, user1, "Family Cash", &familyID)
	personalAcct := createTestAccount(t, db, user1, "My Personal", nil)
	catID := getCategoryID(t, db)

	// Family transactions from both members
	_, err := db.pool.Exec(ctx,
		`INSERT INTO transactions (user_id, account_id, category_id, amount, currency, amount_cny, exchange_rate, type, note, txn_date, tags, image_urls)
		 VALUES ($1, $2, $3, 3000, 'CNY', 3000, 1.0, 'expense', 'user1 family', NOW(), '{}', '{}'),
		        ($4, $2, $3, 4000, 'CNY', 4000, 1.0, 'expense', 'user2 family', NOW(), '{}', '{}')`,
		user1, familyAcct, catID, user2,
	)
	require.NoError(t, err)

	// Personal transaction (should NOT appear in family sum)
	_, err = db.pool.Exec(ctx,
		`INSERT INTO transactions (user_id, account_id, category_id, amount, currency, amount_cny, exchange_rate, type, note, txn_date, tags, image_urls)
		 VALUES ($1, $2, $3, 9000, 'CNY', 9000, 1.0, 'expense', 'personal hidden', NOW(), '{}', '{}')`,
		user1, personalAcct, catID,
	)
	require.NoError(t, err)

	// Family mode query: SUM by family_id
	var totalExpense int64
	err = db.pool.QueryRow(ctx,
		`SELECT COALESCE(SUM(CASE WHEN t.type = 'expense' THEN t.amount_cny ELSE 0 END), 0)
		 FROM transactions t
		 JOIN accounts a ON a.id = t.account_id
		 WHERE a.family_id = $1 AND t.deleted_at IS NULL`,
		familyID,
	).Scan(&totalExpense)
	require.NoError(t, err)
	assert.Equal(t, int64(7000), totalExpense, "family expense should be 3000+4000=7000")
}

// ═══════════════════════════════════════════════════════════════════════════════
// Sync Service Tests
// ═══════════════════════════════════════════════════════════════════════════════

func TestSync_PullChanges_SinceTimestamp(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()

	userID := createTestUser(t, db, "sync_user@test.com")

	// Insert operations at different timestamps
	t1 := time.Date(2024, 1, 1, 10, 0, 0, 0, time.UTC)
	t2 := time.Date(2024, 1, 2, 10, 0, 0, 0, time.UTC)
	t3 := time.Date(2024, 1, 3, 10, 0, 0, 0, time.UTC)

	entityID1 := uuid.New()
	entityID2 := uuid.New()
	entityID3 := uuid.New()

	_, err := db.pool.Exec(ctx,
		`INSERT INTO sync_operations (user_id, entity_type, entity_id, op_type, payload, client_id, timestamp)
		 VALUES ($1, 'transaction', $2, 'create', '{}', 'client-a', $5),
		        ($1, 'transaction', $3, 'update', '{}', 'client-a', $6),
		        ($1, 'transaction', $4, 'delete', '{}', 'client-a', $7)`,
		userID, entityID1, entityID2, entityID3, t1, t2, t3,
	)
	require.NoError(t, err)

	// Pull since t1 (should exclude t1 itself due to > comparison)
	since := t1
	clientID := "client-b" // different client
	rows, err := db.pool.Query(ctx,
		`SELECT id, entity_type, entity_id, op_type, payload, client_id, timestamp
		 FROM sync_operations
		 WHERE user_id = $1 AND timestamp > $2 AND client_id != $3
		 ORDER BY timestamp ASC`,
		userID, since, clientID,
	)
	require.NoError(t, err)
	defer rows.Close()

	var count int
	for rows.Next() {
		var id, eID uuid.UUID
		var eType, opType, payload, cID string
		var ts time.Time
		require.NoError(t, rows.Scan(&id, &eType, &eID, &opType, &payload, &cID, &ts))
		count++
	}
	assert.Equal(t, 2, count, "should get 2 operations after t1")

	// Pull since t2 with same client_id (should filter out same client)
	rows2, err := db.pool.Query(ctx,
		`SELECT id FROM sync_operations
		 WHERE user_id = $1 AND timestamp > $2 AND client_id != $3
		 ORDER BY timestamp ASC`,
		userID, t2, "client-a",
	)
	require.NoError(t, err)
	defer rows2.Close()

	var countSameClient int
	for rows2.Next() {
		var id uuid.UUID
		require.NoError(t, rows2.Scan(&id))
		countSameClient++
	}
	assert.Equal(t, 0, countSameClient, "same client_id should be filtered out")
}

func TestSync_PushOperations(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()

	userID := createTestUser(t, db, "push_user@test.com")
	entityID := uuid.New()

	// Simulate PushOperations: insert into sync_operations
	_, err := db.pool.Exec(ctx,
		`INSERT INTO sync_operations (user_id, entity_type, entity_id, op_type, payload, client_id, timestamp)
		 VALUES ($1, 'account', $2, 'create'::sync_op_type, '{"name":"new account"}', 'mobile-1', NOW())`,
		userID, entityID,
	)
	require.NoError(t, err)

	// Verify the operation is stored
	var opType, payload, clientID string
	err = db.pool.QueryRow(ctx,
		`SELECT op_type, payload, client_id FROM sync_operations WHERE entity_id = $1`,
		entityID,
	).Scan(&opType, &payload, &clientID)
	require.NoError(t, err)
	assert.Equal(t, "create", opType)
	assert.Contains(t, payload, "new account")
	assert.Equal(t, "mobile-1", clientID)
}

// ═══════════════════════════════════════════════════════════════════════════════
// Family + Permission Tests
// ═══════════════════════════════════════════════════════════════════════════════

func TestFamily_NonMemberQueryReturnsEmpty(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()

	owner := createTestUser(t, db, "fam_owner@test.com")
	nonMember := createTestUser(t, db, "non_member@test.com")
	familyID := createTestFamily(t, db, owner, "Private Family")
	addFamilyMember(t, db, familyID, owner, "owner", `{"can_view":true,"can_create":true,"can_edit":true,"can_delete":true,"can_manage_accounts":true}`)

	// Non-member checks membership
	var isMember bool
	err := db.pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM family_members WHERE family_id = $1 AND user_id = $2)`,
		familyID, nonMember,
	).Scan(&isMember)
	require.NoError(t, err)
	assert.False(t, isMember, "non-member should not be a family member")

	// Query family transactions as non-member (the app would reject, but DB-level there's nothing)
	familyAcct := createTestAccount(t, db, owner, "Owner Acct", &familyID)
	catID := getCategoryID(t, db)
	_, err = db.pool.Exec(ctx,
		`INSERT INTO transactions (user_id, account_id, category_id, amount, currency, amount_cny, exchange_rate, type, note, txn_date, tags, image_urls)
		 VALUES ($1, $2, $3, 1000, 'CNY', 1000, 1.0, 'expense', 'secret', NOW(), '{}', '{}')`,
		owner, familyAcct, catID,
	)
	require.NoError(t, err)

	// If the non-member tries the personal query (user_id = their own, family_id IS NULL)
	// they should see nothing from the family
	var count int
	err = db.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM transactions t
		 JOIN accounts a ON a.id = t.account_id
		 WHERE t.user_id = $1 AND t.deleted_at IS NULL AND a.family_id IS NULL`,
		nonMember,
	).Scan(&count)
	require.NoError(t, err)
	assert.Equal(t, 0, count, "non-member should see 0 personal transactions")
}

func TestFamily_OwnerRoleBypassesPermissions(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()

	owner := createTestUser(t, db, "bypass_owner@test.com")
	familyID := createTestFamily(t, db, owner, "Owner Family")

	// Even with minimal permissions JSON, owner role bypasses in app logic
	// Here we verify the DB correctly stores and retrieves owner's permissions
	addFamilyMember(t, db, familyID, owner, "owner", `{"can_view":false,"can_create":false,"can_edit":false,"can_delete":false,"can_manage_accounts":false}`)

	var role string
	var permsJSON string
	err := db.pool.QueryRow(ctx,
		`SELECT role, permissions::text FROM family_members WHERE family_id = $1 AND user_id = $2`,
		familyID, owner,
	).Scan(&role, &permsJSON)
	require.NoError(t, err)
	assert.Equal(t, "owner", role)
	// The app-level permission.Check bypasses for "owner" role regardless of JSON
	// PostgreSQL JSONB normalizes spacing: "key": value
	assert.Contains(t, permsJSON, `"can_view": false`) // stored as-is
}

func TestFamily_MemberPermissionsParsing(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()

	owner := createTestUser(t, db, "perm_owner@test.com")
	member := createTestUser(t, db, "perm_member@test.com")
	familyID := createTestFamily(t, db, owner, "Perms Family")
	addFamilyMember(t, db, familyID, owner, "owner", `{"can_view":true,"can_create":true,"can_edit":true,"can_delete":true,"can_manage_accounts":true}`)
	addFamilyMember(t, db, familyID, member, "member", `{"can_view":true,"can_create":true,"can_edit":false,"can_delete":false,"can_manage_accounts":false}`)

	// Parse member permissions from DB
	var permsJSON string
	err := db.pool.QueryRow(ctx,
		`SELECT permissions::text FROM family_members WHERE family_id = $1 AND user_id = $2`,
		familyID, member,
	).Scan(&permsJSON)
	require.NoError(t, err)

	// Verify JSON structure (PostgreSQL JSONB normalizes with spaces after colons)
	assert.Contains(t, permsJSON, `"can_view": true`)
	assert.Contains(t, permsJSON, `"can_create": true`)
	assert.Contains(t, permsJSON, `"can_edit": false`)
	assert.Contains(t, permsJSON, `"can_delete": false`)
	assert.Contains(t, permsJSON, `"can_manage_accounts": false`)

	// Verify we can use permissions in WHERE clause (JSON extraction)
	var canEdit bool
	err = db.pool.QueryRow(ctx,
		`SELECT (permissions->>'can_edit')::boolean FROM family_members WHERE family_id = $1 AND user_id = $2`,
		familyID, member,
	).Scan(&canEdit)
	require.NoError(t, err)
	assert.False(t, canEdit, "member should not have can_edit permission")
}

// ═══════════════════════════════════════════════════════════════════════════════
// Account Tests
// ═══════════════════════════════════════════════════════════════════════════════

func TestAccount_PersonalHasNullFamilyID(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()

	userID := createTestUser(t, db, "acct_user@test.com")
	acctID := createTestAccount(t, db, userID, "My Wallet", nil)

	var familyID *string
	err := db.pool.QueryRow(ctx,
		`SELECT family_id::text FROM accounts WHERE id = $1`,
		acctID,
	).Scan(&familyID)
	require.NoError(t, err)
	assert.Nil(t, familyID, "personal account should have NULL family_id")
}

func TestAccount_FamilyAccountHasFamilyID(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()

	userID := createTestUser(t, db, "fam_acct_user@test.com")
	familyID := createTestFamily(t, db, userID, "Account Family")
	addFamilyMember(t, db, familyID, userID, "owner", `{"can_view":true,"can_create":true,"can_edit":true,"can_delete":true,"can_manage_accounts":true}`)
	acctID := createTestAccount(t, db, userID, "Family Savings", &familyID)

	var storedFamilyID *string
	err := db.pool.QueryRow(ctx,
		`SELECT family_id::text FROM accounts WHERE id = $1`,
		acctID,
	).Scan(&storedFamilyID)
	require.NoError(t, err)
	require.NotNil(t, storedFamilyID, "family account should have non-NULL family_id")
	assert.Equal(t, familyID.String(), *storedFamilyID)
}

func TestAccount_PersonalNotVisibleInFamilyQuery(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()

	userID := createTestUser(t, db, "vis_user@test.com")
	familyID := createTestFamily(t, db, userID, "Visibility Family")
	addFamilyMember(t, db, familyID, userID, "owner", `{"can_view":true,"can_create":true,"can_edit":true,"can_delete":true,"can_manage_accounts":true}`)

	createTestAccount(t, db, userID, "Personal Wallet", nil)
	createTestAccount(t, db, userID, "Family Wallet", &familyID)

	// Query family accounts
	rows, err := db.pool.Query(ctx,
		`SELECT id, name FROM accounts WHERE family_id = $1 AND deleted_at IS NULL AND is_active = true`,
		familyID,
	)
	require.NoError(t, err)
	defer rows.Close()

	var names []string
	for rows.Next() {
		var id uuid.UUID
		var name string
		require.NoError(t, rows.Scan(&id, &name))
		names = append(names, name)
	}
	assert.Equal(t, 1, len(names))
	assert.Equal(t, "Family Wallet", names[0])

	// Query personal accounts
	rows2, err := db.pool.Query(ctx,
		`SELECT id, name FROM accounts WHERE user_id = $1 AND family_id IS NULL AND deleted_at IS NULL AND is_active = true`,
		userID,
	)
	require.NoError(t, err)
	defer rows2.Close()

	var personalNames []string
	for rows2.Next() {
		var id uuid.UUID
		var name string
		require.NoError(t, rows2.Scan(&id, &name))
		personalNames = append(personalNames, name)
	}
	assert.Equal(t, 1, len(personalNames))
	assert.Equal(t, "Personal Wallet", personalNames[0])
}
