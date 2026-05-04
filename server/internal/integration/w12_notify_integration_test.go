//go:build integration

package integration

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/familyledger/server/internal/notify"
)

// ═══════════════════════════════════════════════════════════════════════════════
// W12: Credit Card Reminder Integration Tests
//
// billing_day is NOT exposed via the gRPC API (CreateAccount proto). It can only
// be set via direct SQL, so these tests exercise CheckCreditCardReminders with a
// real PostgreSQL database (testcontainers).
// ═══════════════════════════════════════════════════════════════════════════════

func TestW12_CreditCardReminder_BillingDayToday(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()

	// Setup: create user + credit card account
	userID := createTestUser(t, db, "w12_cc_billing@test.com")
	acctID := createTestAccount(t, db, userID, "W12招商信用卡", nil)

	// Set account type to credit_card and billing_day to today
	today := time.Now().Day()
	_, err := db.pool.Exec(ctx,
		`UPDATE accounts SET type = 'credit_card', billing_day = $1 WHERE id = $2`,
		today, acctID,
	)
	require.NoError(t, err)

	// Call CheckCreditCardReminders
	svc := notify.NewService(db.pool)
	err = svc.CheckCreditCardReminders(ctx)
	require.NoError(t, err)

	// Verify: billing_day_reminder notification was created
	var count int
	err = db.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM notifications
		 WHERE user_id = $1 AND type = 'billing_day_reminder'`,
		userID.String(),
	).Scan(&count)
	require.NoError(t, err)
	assert.Equal(t, 1, count, "should create exactly one billing_day_reminder notification")
	t.Logf("CC-001 PASS: billing_day_reminder created for day %d", today)
}

func TestW12_CreditCardReminder_BillingDayNotToday(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()

	userID := createTestUser(t, db, "w12_cc_noremind@test.com")
	acctID := createTestAccount(t, db, userID, "W12工行信用卡", nil)

	// Set billing_day to a different day
	today := time.Now().Day()
	otherDay := (today + 15) % 28
	if otherDay == 0 {
		otherDay = 1
	}
	_, err := db.pool.Exec(ctx,
		`UPDATE accounts SET type = 'credit_card', billing_day = $1 WHERE id = $2`,
		otherDay, acctID,
	)
	require.NoError(t, err)

	svc := notify.NewService(db.pool)
	err = svc.CheckCreditCardReminders(ctx)
	require.NoError(t, err)

	// Verify: no notification created
	var count int
	err = db.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM notifications
		 WHERE user_id = $1 AND type = 'billing_day_reminder'`,
		userID.String(),
	).Scan(&count)
	require.NoError(t, err)
	assert.Equal(t, 0, count, "should NOT create notification when billing_day != today")
	t.Logf("CC-002 PASS: no notification for billing_day=%d (today=%d)", otherDay, today)
}

func TestW12_CreditCardReminder_PaymentDueToday(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()

	userID := createTestUser(t, db, "w12_cc_due@test.com")
	acctID := createTestAccount(t, db, userID, "W12还款卡", nil)

	today := time.Now().Day()
	_, err := db.pool.Exec(ctx,
		`UPDATE accounts SET type = 'credit_card', payment_due_day = $1 WHERE id = $2`,
		today, acctID,
	)
	require.NoError(t, err)

	svc := notify.NewService(db.pool)
	err = svc.CheckCreditCardReminders(ctx)
	require.NoError(t, err)

	// Verify: payment_due_reminder notification was created
	var count int
	err = db.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM notifications
		 WHERE user_id = $1 AND type = 'payment_due_reminder'`,
		userID.String(),
	).Scan(&count)
	require.NoError(t, err)
	assert.Equal(t, 1, count, "should create payment_due_reminder when due day = today")
	t.Logf("CC-003 PASS: payment_due_reminder created for day %d", today)
}

func TestW12_CreditCardReminder_Dedup(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()

	userID := createTestUser(t, db, "w12_cc_dedup@test.com")
	acctID := createTestAccount(t, db, userID, "W12去重卡", nil)

	today := time.Now().Day()
	_, err := db.pool.Exec(ctx,
		`UPDATE accounts SET type = 'credit_card', billing_day = $1 WHERE id = $2`,
		today, acctID,
	)
	require.NoError(t, err)

	svc := notify.NewService(db.pool)

	// First call: should create notification
	err = svc.CheckCreditCardReminders(ctx)
	require.NoError(t, err)

	// Second call: should NOT create a duplicate
	err = svc.CheckCreditCardReminders(ctx)
	require.NoError(t, err)

	var count int
	err = db.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM notifications
		 WHERE user_id = $1 AND type = 'billing_day_reminder'`,
		userID.String(),
	).Scan(&count)
	require.NoError(t, err)
	assert.Equal(t, 1, count, "dedup: second call should not create duplicate notification")
	t.Log("CC-004 PASS: dedup prevents duplicate credit card notifications")
}

// ═══════════════════════════════════════════════════════════════════════════════
// W12: Budget Notification Integration Tests
//
// CheckBudgets is cron-only (not a gRPC RPC). These tests exercise the full
// pipeline: create user, budget, expenses → CheckBudgets → verify notifications.
// ═══════════════════════════════════════════════════════════════════════════════

func TestW12_Budget_WarningAt85Percent(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()

	userID := createTestUser(t, db, "w12_bud_warn@test.com")
	acctID := createTestAccount(t, db, userID, "W12预算账户", nil)
	catID := getCategoryID(t, db)

	now := time.Now()
	year := int32(now.Year())
	month := int32(now.Month())

	// Create budget: 100,000 cents (1,000 CNY)
	var budgetID uuid.UUID
	err := db.pool.QueryRow(ctx,
		`INSERT INTO budgets (user_id, year, month, total_amount)
		 VALUES ($1, $2, $3, 100000) RETURNING id`,
		userID, year, month,
	).Scan(&budgetID)
	require.NoError(t, err)

	// Create expenses totaling 85,000 cents (85% of budget)
	txnDate := time.Date(int(year), time.Month(month), 1, 12, 0, 0, 0, time.UTC)
	_, err = db.pool.Exec(ctx,
		`INSERT INTO transactions (user_id, account_id, category_id, amount, currency, amount_cny, exchange_rate, type, note, txn_date, tags, image_urls)
		 VALUES ($1, $2, $3, 50000, 'CNY', 50000, 1.0, 'expense', 'W12大额消费', $4, '{}', '{}'),
		        ($1, $2, $3, 35000, 'CNY', 35000, 1.0, 'expense', 'W12日常消费', $4, '{}', '{}')`,
		userID, acctID, catID, txnDate,
	)
	require.NoError(t, err)

	// Run CheckBudgets
	svc := notify.NewService(db.pool)
	err = svc.CheckBudgets(ctx)
	require.NoError(t, err)

	// Verify: budget_warning notification exists (rate ≥ 80% but < 100%)
	var count int
	err = db.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM notifications
		 WHERE user_id = $1 AND type = 'budget_warning'`,
		userID.String(),
	).Scan(&count)
	require.NoError(t, err)
	assert.Equal(t, 1, count, "should create budget_warning at 85%% execution")
	t.Logf("BUD-001 PASS: budget_warning created at 85%% of 100000")
}

func TestW12_Budget_ExceededAt105Percent(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()

	userID := createTestUser(t, db, "w12_bud_exceed@test.com")
	acctID := createTestAccount(t, db, userID, "W12超支账户", nil)
	catID := getCategoryID(t, db)

	now := time.Now()
	year := int32(now.Year())
	month := int32(now.Month())

	// Create budget: 100,000 cents
	var budgetID uuid.UUID
	err := db.pool.QueryRow(ctx,
		`INSERT INTO budgets (user_id, year, month, total_amount)
		 VALUES ($1, $2, $3, 100000) RETURNING id`,
		userID, year, month,
	).Scan(&budgetID)
	require.NoError(t, err)

	// Create expenses at 85% first
	txnDate := time.Date(int(year), time.Month(month), 1, 12, 0, 0, 0, time.UTC)
	_, err = db.pool.Exec(ctx,
		`INSERT INTO transactions (user_id, account_id, category_id, amount, currency, amount_cny, exchange_rate, type, note, txn_date, tags, image_urls)
		 VALUES ($1, $2, $3, 85000, 'CNY', 85000, 1.0, 'expense', 'W12近满消费', $4, '{}', '{}')`,
		userID, acctID, catID, txnDate,
	)
	require.NoError(t, err)

	// First check: should trigger budget_warning
	svc := notify.NewService(db.pool)
	err = svc.CheckBudgets(ctx)
	require.NoError(t, err)

	var warningCount int
	err = db.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM notifications
		 WHERE user_id = $1 AND type = 'budget_warning'`,
		userID.String(),
	).Scan(&warningCount)
	require.NoError(t, err)
	assert.Equal(t, 1, warningCount, "should have budget_warning at 85%%")

	// Add more expenses to push past 100% (total = 105%)
	_, err = db.pool.Exec(ctx,
		`INSERT INTO transactions (user_id, account_id, category_id, amount, currency, amount_cny, exchange_rate, type, note, txn_date, tags, image_urls)
		 VALUES ($1, $2, $3, 20000, 'CNY', 20000, 1.0, 'expense', 'W12超支消费', $4, '{}', '{}')`,
		userID, acctID, catID, txnDate,
	)
	require.NoError(t, err)

	// Second check: should trigger budget_exceeded
	err = svc.CheckBudgets(ctx)
	require.NoError(t, err)

	var exceededCount int
	err = db.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM notifications
		 WHERE user_id = $1 AND type = 'budget_exceeded'`,
		userID.String(),
	).Scan(&exceededCount)
	require.NoError(t, err)
	assert.Equal(t, 1, exceededCount, "should have budget_exceeded at 105%%")
	t.Logf("BUD-002 PASS: budget_exceeded created after total spending exceeded budget")
}

func TestW12_Budget_BelowThreshold_NoNotification(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()

	userID := createTestUser(t, db, "w12_bud_low@test.com")
	acctID := createTestAccount(t, db, userID, "W12低消费账户", nil)
	catID := getCategoryID(t, db)

	now := time.Now()
	year := int32(now.Year())
	month := int32(now.Month())

	// Create budget: 100,000 cents
	_, err := db.pool.Exec(ctx,
		`INSERT INTO budgets (user_id, year, month, total_amount)
		 VALUES ($1, $2, $3, 100000)`,
		userID, year, month,
	)
	require.NoError(t, err)

	// Create expenses at only 50%
	txnDate := time.Date(int(year), time.Month(month), 1, 12, 0, 0, 0, time.UTC)
	_, err = db.pool.Exec(ctx,
		`INSERT INTO transactions (user_id, account_id, category_id, amount, currency, amount_cny, exchange_rate, type, note, txn_date, tags, image_urls)
		 VALUES ($1, $2, $3, 50000, 'CNY', 50000, 1.0, 'expense', 'W12半额消费', $4, '{}', '{}')`,
		userID, acctID, catID, txnDate,
	)
	require.NoError(t, err)

	svc := notify.NewService(db.pool)
	err = svc.CheckBudgets(ctx)
	require.NoError(t, err)

	// Verify: NO notification
	var count int
	err = db.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM notifications
		 WHERE user_id = $1 AND (type = 'budget_warning' OR type = 'budget_exceeded')`,
		userID.String(),
	).Scan(&count)
	require.NoError(t, err)
	assert.Equal(t, 0, count, "should NOT create notification when spending is below 80%%")
	t.Log("BUD-003 PASS: no notification at 50% budget execution")
}

func TestW12_Budget_Dedup(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()

	userID := createTestUser(t, db, "w12_bud_dedup@test.com")
	acctID := createTestAccount(t, db, userID, "W12去重预算", nil)
	catID := getCategoryID(t, db)

	now := time.Now()
	year := int32(now.Year())
	month := int32(now.Month())

	_, err := db.pool.Exec(ctx,
		`INSERT INTO budgets (user_id, year, month, total_amount)
		 VALUES ($1, $2, $3, 100000)`,
		userID, year, month,
	)
	require.NoError(t, err)

	// Expenses at 110% to trigger budget_exceeded
	txnDate := time.Date(int(year), time.Month(month), 1, 12, 0, 0, 0, time.UTC)
	_, err = db.pool.Exec(ctx,
		fmt.Sprintf(
			`INSERT INTO transactions (user_id, account_id, category_id, amount, currency, amount_cny, exchange_rate, type, note, txn_date, tags, image_urls)
			 VALUES ($1, $2, $3, 110000, 'CNY', 110000, 1.0, 'expense', 'W12超额', $4, '{}', '{}')`),
		userID, acctID, catID, txnDate,
	)
	require.NoError(t, err)

	svc := notify.NewService(db.pool)

	// First call
	err = svc.CheckBudgets(ctx)
	require.NoError(t, err)

	// Second call — should not create duplicate
	err = svc.CheckBudgets(ctx)
	require.NoError(t, err)

	var count int
	err = db.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM notifications
		 WHERE user_id = $1 AND type = 'budget_exceeded'`,
		userID.String(),
	).Scan(&count)
	require.NoError(t, err)
	assert.Equal(t, 1, count, "dedup: second CheckBudgets should not create duplicate notification")
	t.Log("BUD-004 PASS: dedup prevents duplicate budget notifications")
}
