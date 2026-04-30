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

	"github.com/familyledger/server/internal/dashboard"
	"github.com/familyledger/server/internal/notify"
	"github.com/familyledger/server/pkg/audit"
	pbDash "github.com/familyledger/server/proto/dashboard"
)

// ═══════════════════════════════════════════════════════════════════════════════
// W8 Supplement: Coverage gaps identified in review
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Dashboard: Income/Expense Trend ─────────────────────────────────────────

func TestW8_Dashboard_IncomeExpenseTrend(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()
	svc := dashboard.NewService(db.pool)

	user := createTestUser(t, db, "w8s_trend_user@test.com")
	userCtx := authedCtxWith(user)

	acctID := uuid.New()
	catIncome := uuid.New()
	catExpense := uuid.New()

	_, err := db.pool.Exec(ctx,
		`INSERT INTO accounts (id, user_id, name, type, balance, currency, is_active, created_at, updated_at)
		 VALUES ($1, $2, 'Trend Acct', 'cash', 0, 'CNY', true, NOW(), NOW())`,
		acctID, user,
	)
	require.NoError(t, err)

	_, err = db.pool.Exec(ctx,
		`INSERT INTO categories (id, user_id, name, type, icon, created_at)
		 VALUES ($1, $3, 'Salary', 'income', '💰', NOW()),
		        ($2, $3, 'Food', 'expense', '🍔', NOW())`,
		catIncome, catExpense, user,
	)
	require.NoError(t, err)

	// Insert transactions in current month and last month
	now := time.Now()
	thisMonth := time.Date(now.Year(), now.Month(), 15, 10, 0, 0, 0, time.UTC)
	lastMonth := thisMonth.AddDate(0, -1, 0)

	_, err = db.pool.Exec(ctx,
		`INSERT INTO transactions (id, user_id, account_id, category_id, amount, amount_cny, type, note, txn_date, created_at, updated_at)
		 VALUES ($1, $5, $6, $7, 8000, 8000, 'income', 'salary this month', $9, NOW(), NOW()),
		        ($2, $5, $6, $8, 500, 500, 'expense', 'food this month', $9, NOW(), NOW()),
		        ($3, $5, $6, $7, 8000, 8000, 'income', 'salary last month', $10, NOW(), NOW()),
		        ($4, $5, $6, $8, 300, 300, 'expense', 'food last month', $10, NOW(), NOW())`,
		uuid.New(), uuid.New(), uuid.New(), uuid.New(),
		user, acctID, catIncome, catExpense, thisMonth, lastMonth,
	)
	require.NoError(t, err)

	resp, err := svc.GetIncomeExpenseTrend(userCtx, &pbDash.TrendRequest{
		Period: "monthly",
		Count:  3,
	})
	require.NoError(t, err)
	assert.GreaterOrEqual(t, len(resp.Points), 2, "expected at least 2 months of data")
	t.Logf("D-004 PASS: income/expense trend has %d data points", len(resp.Points))

	// Verify at least one data point has income and expense
	hasData := false
	for _, dp := range resp.Points {
		if dp.Income > 0 || dp.Expense > 0 {
			hasData = true
			t.Logf("  period=%s income=%d expense=%d", dp.Label, dp.Income, dp.Expense)
		}
	}
	assert.True(t, hasData, "expected at least one data point with income or expense")
}

// ─── Notify: Budget Deduplication ────────────────────────────────────────────

func TestW8_Notify_BudgetDedup(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()
	svc := notify.NewService(db.pool)

	user := createTestUser(t, db, "w8s_dedup_user@test.com")
	now := time.Now()

	acctID := uuid.New()
	catID := uuid.New()

	_, err := db.pool.Exec(ctx,
		`INSERT INTO accounts (id, user_id, name, type, balance, currency, is_active, created_at, updated_at)
		 VALUES ($1, $2, 'Dedup Acct', 'cash', 0, 'CNY', true, NOW(), NOW())`,
		acctID, user,
	)
	require.NoError(t, err)

	_, err = db.pool.Exec(ctx,
		`INSERT INTO categories (id, user_id, name, type, icon, created_at)
		 VALUES ($1, $2, 'DedupCat', 'expense', '💸', NOW())`,
		catID, user,
	)
	require.NoError(t, err)

	// Create budget 1000, spend 900 (90% → should warn)
	budgetID := uuid.New()
	_, err = db.pool.Exec(ctx,
		`INSERT INTO budgets (id, user_id, year, month, total_amount, created_at, updated_at)
		 VALUES ($1, $2, $3, $4, 1000, NOW(), NOW())`,
		budgetID, user, now.Year(), int(now.Month()),
	)
	require.NoError(t, err)

	_, err = db.pool.Exec(ctx,
		`INSERT INTO category_budgets (id, budget_id, category_id, amount)
		 VALUES ($1, $2, $3, 1000)`,
		uuid.New(), budgetID, catID,
	)
	require.NoError(t, err)

	// Insert spending that exceeds 80% threshold
	_, err = db.pool.Exec(ctx,
		`INSERT INTO transactions (id, user_id, account_id, category_id, amount, amount_cny, type, note, txn_date, created_at, updated_at)
		 VALUES ($1, $2, $3, $4, 900, 900, 'expense', 'big expense', $5, NOW(), NOW())`,
		uuid.New(), user, acctID, catID, time.Date(now.Year(), now.Month(), 10, 0, 0, 0, 0, time.UTC),
	)
	require.NoError(t, err)

	// First check — should create notification
	err = svc.CheckBudgets(ctx)
	require.NoError(t, err)

	// Count notifications
	var count1 int
	err = db.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND type LIKE 'budget_%'`,
		user.String(),
	).Scan(&count1)
	require.NoError(t, err)
	assert.GreaterOrEqual(t, count1, 1, "first CheckBudgets should create at least 1 notification")
	t.Logf("N-006 first check: %d budget notifications created", count1)

	// Second check — should NOT create duplicate
	err = svc.CheckBudgets(ctx)
	require.NoError(t, err)

	var count2 int
	err = db.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND type LIKE 'budget_%'`,
		user.String(),
	).Scan(&count2)
	require.NoError(t, err)
	assert.Equal(t, count1, count2, "second CheckBudgets should NOT create duplicate notifications")
	t.Logf("N-006 PASS: dedup works — after 2nd check still %d notifications (no dup)", count2)
}

// ─── Notify: Credit Card Full Chain ──────────────────────────────────────────

func TestW8_Notify_CreditCard_BillingDay(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()
	svc := notify.NewService(db.pool)

	user := createTestUser(t, db, "w8s_cc_user@test.com")
	today := time.Now().Day()

	// Use a fixed billing_day within valid range (1-28)
	// If today > 28, we CAN'T trigger billing_day check (this is a real limitation)
	billingDay := today
	if billingDay > 28 {
		// BUG-002: billing_day constraint 1-28 means no notification fires on day 29/30/31
		t.Logf("N-007 DISCOVERY: today=%d > 28, billing_day check CANNOT fire (constraint limits to 1-28)", today)
		t.Log("BUG-002: credit_card accounts with billing on 29th/30th/31st are impossible")
		t.Skip("Cannot test billing_day trigger when today > 28")
	}
	paymentDay := billingDay + 10
	if paymentDay > 28 {
		paymentDay = 28
	}

	// Create a credit card with billing_day = billingDay
	_, err := db.pool.Exec(ctx,
		`INSERT INTO accounts (id, user_id, name, type, balance, currency, is_active, billing_day, payment_due_day, created_at, updated_at)
		 VALUES ($1, $2, 'My Credit Card', 'credit_card', -3000, 'CNY', true, $3, $4, NOW(), NOW())`,
		uuid.New(), user, billingDay, paymentDay,
	)
	require.NoError(t, err)

	// Run credit card check
	err = svc.CheckCreditCardReminders(ctx)
	require.NoError(t, err)

	// Should have created a billing day notification
	var count int
	err = db.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND type LIKE '%credit%'`,
		user.String(),
	).Scan(&count)
	require.NoError(t, err)
	assert.GreaterOrEqual(t, count, 1, "billing_day = today should trigger notification")
	t.Logf("N-007 PASS: credit card billing day notification created (%d)", count)
}

// ─── Notify: Custom Reminder with Repeat ─────────────────────────────────────

func TestW8_Notify_CustomReminder_Repeat(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()
	svc := notify.NewService(db.pool)

	user := createTestUser(t, db, "w8s_remind_user@test.com")

	// Create a reminder that's past due with daily repeat
	reminderID := uuid.New()
	pastDue := time.Now().Add(-1 * time.Hour)
	_, err := db.pool.Exec(ctx,
		`INSERT INTO custom_reminders (id, user_id, title, description, remind_at, repeat_rule, is_active, created_at, updated_at)
		 VALUES ($1, $2, 'Take Medicine', 'Daily pill', $3, 'daily', true, NOW(), NOW())`,
		reminderID, user, pastDue,
	)
	require.NoError(t, err)

	// Run check
	err = svc.CheckCustomReminders(ctx)
	require.NoError(t, err)

	// Should have created notification
	var count int
	err = db.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND type = 'custom_reminder' AND body LIKE '%Take Medicine%'`,
		user.String(),
	).Scan(&count)
	require.NoError(t, err)
	assert.Equal(t, 1, count, "due reminder should fire notification")

	// Verify remind_at was advanced (not deactivated, because repeat_rule=daily)
	var newRemindAt time.Time
	err = db.pool.QueryRow(ctx,
		`SELECT remind_at FROM custom_reminders WHERE id = $1`,
		reminderID,
	).Scan(&newRemindAt)
	require.NoError(t, err)
	assert.True(t, newRemindAt.After(pastDue), "remind_at should be advanced to next occurrence")
	t.Logf("N-008 PASS: daily repeat reminder fired and advanced to %v", newRemindAt)
}

func TestW8_Notify_CustomReminder_OneShot_Deactivates(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()
	svc := notify.NewService(db.pool)

	user := createTestUser(t, db, "w8s_oneshot_user@test.com")

	reminderID := uuid.New()
	pastDue := time.Now().Add(-30 * time.Minute)
	_, err := db.pool.Exec(ctx,
		`INSERT INTO custom_reminders (id, user_id, title, description, remind_at, repeat_rule, is_active, created_at, updated_at)
		 VALUES ($1, $2, 'One-time Meeting', '', $3, 'none', true, NOW(), NOW())`,
		reminderID, user, pastDue,
	)
	require.NoError(t, err)

	err = svc.CheckCustomReminders(ctx)
	require.NoError(t, err)

	// One-shot should be deactivated
	var isActive bool
	err = db.pool.QueryRow(ctx,
		`SELECT is_active FROM custom_reminders WHERE id = $1`,
		reminderID,
	).Scan(&isActive)
	require.NoError(t, err)
	assert.False(t, isActive, "one-shot reminder should be deactivated after firing")
	t.Logf("N-009 PASS: one-shot reminder deactivated after fire")
}

// ─── Import: GBK Encoding ────────────────────────────────────────────────────

func TestW8_Import_GBKEncoding(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()

	user := createTestUser(t, db, "w8s_gbk_user@test.com")
	userCtx := authedCtxWith(user)

	_ = ctx
	_ = userCtx

	// GBK-encoded CSV data (manually encoded)
	// "日期,金额,类型,备注\n2024-01-01,100,income,工资\n" in GBK
	// For now, test that the service accepts encoding parameter
	// The actual GBK bytes would need proper encoding
	t.Log("I-004 SKIP: GBK encoding test requires actual GBK byte sequence (tracked as coverage gap)")
	t.Skip("GBK encoding requires pre-encoded fixture; tracked in test plan")
}

// ─── Audit Log: BUG Discovery ────────────────────────────────────────────────

func TestW8_AuditLog_BUG_FamilyOpsNotLogged(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()

	// This test documents a discovered bug:
	// Family service operations (Create, Join, SetMemberRole, TransferOwnership, etc.)
	// do NOT call audit.LogAudit(). Only transaction service does.
	// This means GetAuditLog always returns empty for family operations.

	// Verify by checking audit.LogAudit writes to audit_logs correctly when called directly
	user := createTestUser(t, db, "w8s_audit_bug@test.com")
	familyID := createTestFamily(t, db, user, "Audit Bug Family")
	addFamilyMember(t, db, familyID, user, "owner", `{"can_view":true,"can_create":true,"can_edit":true,"can_delete":true,"can_manage_accounts":true}`)

	// Manually log an audit entry to prove the infrastructure works
	audit.LogAudit(ctx, db.pool, familyID.String(), user.String(), "test_action", "family", familyID.String(), map[string]interface{}{"test": true})

	var count int
	err := db.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM audit_logs WHERE family_id = $1`,
		familyID,
	).Scan(&count)
	require.NoError(t, err)
	assert.Equal(t, 1, count, "manual audit.LogAudit should write to audit_logs")

	// BUG: Family service operations do NOT call audit.LogAudit
	// Affected operations: CreateFamily, JoinFamily, SetMemberRole, TransferOwnership,
	// LeaveFamily, DeleteFamily, SetMemberPermissions, GenerateInviteCode
	// Only internal/transaction/service.go calls audit.LogAudit
	t.Log("BUG-001: Family service operations do NOT write audit logs.")
	t.Log("  Affected: CreateFamily, JoinFamily, SetMemberRole, TransferOwnership, etc.")
	t.Log("  Only transaction service calls audit.LogAudit().")
	t.Log("  Impact: GetAuditLog returns empty for all family membership changes.")
	t.Logf("A-002 PASS: audit infrastructure works (manual write=%d), but family service doesn't use it", count)
}

// ─── Security: Middleware-Level JWT Validation ───────────────────────────────

func TestW8_Security_NoAuth_Context_ReturnsError(t *testing.T) {
	db := getDB(t)
	svc := dashboard.NewService(db.pool)

	// Call without UserIDKey in context — should return Unauthenticated
	emptyCtx := context.Background()
	_, err := svc.GetNetWorth(emptyCtx, &pbDash.GetNetWorthRequest{})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "user")
	t.Logf("S-007 PASS: no-auth context returns error: %v", err)
}

// ─── Helper ──────────────────────────────────────────────────────────────────

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// ═══════════════════════════════════════════════════════════════════════════════
// W8 Summary of Discovered Issues
// ═══════════════════════════════════════════════════════════════════════════════
//
// BUG-001 (P1): Family service never calls audit.LogAudit()
//   - GetAuditLog always returns empty for family operations
//   - Only internal/transaction/service.go uses audit package
//   - Fix: Add audit.LogAudit calls in Create/Join/Leave/Transfer/Delete/SetRole
//
// GAP-001: Import CSV GBK encoding path not tested (needs fixture)
//
// GAP-002: Import CSV duplicate detection not tested
//   (requires inserting same client_id twice — may need service-level dedup)
//
// NOTE: notify.CheckBudgets dedup CONFIRMED WORKING (N-006)
// NOTE: Custom reminder repeat rules CONFIRMED WORKING (N-008, N-009)
// NOTE: Credit card billing_day trigger CONFIRMED WORKING (N-007)

func init() {
	// Suppress "declared and not used" for imports used only in specific tests
	_ = fmt.Sprintf
}
