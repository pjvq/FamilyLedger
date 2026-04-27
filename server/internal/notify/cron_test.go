package notify

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// ═══════════════════════════════════════════════════════════════════════════════
// CheckBudgets — Boundary Tests
// ═══════════════════════════════════════════════════════════════════════════════

func TestCheckBudgets_NoBudgets_NoPanic(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	now := time.Now()
	year := int32(now.Year())
	month := int32(now.Month())

	// No budgets for current month
	mock.ExpectQuery("SELECT b.id, b.user_id, b.family_id, b.total_amount").
		WithArgs(year, month).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "total_amount"}))

	assert.NotPanics(t, func() {
		err := svc.CheckBudgets(context.Background())
		assert.NoError(t, err)
	})
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestCheckBudgets_ZeroBudgetAmount_NoDivideByZero(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	budgetID := uuid.New()
	userUUID := uuid.MustParse(testUserID)
	now := time.Now()
	year := int32(now.Year())
	month := int32(now.Month())

	// Budget with zero amount
	mock.ExpectQuery("SELECT b.id, b.user_id, b.family_id, b.total_amount").
		WithArgs(year, month).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "total_amount"}).
			AddRow(budgetID, userUUID, nil, int64(0)))

	// Compute spent
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(amount_cny\\), 0\\)").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(5000)))

	assert.NotPanics(t, func() {
		err := svc.CheckBudgets(context.Background())
		assert.NoError(t, err)
	})
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestCheckBudgets_FirstDayOfMonth_NoTransactions(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	budgetID := uuid.New()
	userUUID := uuid.MustParse(testUserID)
	now := time.Now()
	year := int32(now.Year())
	month := int32(now.Month())

	// Budget exists with positive amount
	mock.ExpectQuery("SELECT b.id, b.user_id, b.family_id, b.total_amount").
		WithArgs(year, month).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "total_amount"}).
			AddRow(budgetID, userUUID, nil, int64(100000)))

	// No transactions this month (first day, nothing yet)
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(amount_cny\\), 0\\)").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(0)))

	// rate = 0, should not trigger any notification
	assert.NotPanics(t, func() {
		err := svc.CheckBudgets(context.Background())
		assert.NoError(t, err)
	})
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestCheckBudgets_FamilyBudget_NoMembers_NoPanic(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	budgetID := uuid.New()
	userUUID := uuid.MustParse(testUserID)
	familyID := uuid.New()

	now := time.Now()
	year := int32(now.Year())
	month := int32(now.Month())

	// Family budget at 100% execution
	mock.ExpectQuery("SELECT b.id, b.user_id, b.family_id, b.total_amount").
		WithArgs(year, month).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "total_amount"}).
			AddRow(budgetID, userUUID, &familyID, int64(10000)))

	// Family spent equals budget
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(t.amount_cny\\), 0\\)").
		WithArgs(familyID.String(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(10000)))

	// getBudgetNotificationRecipients: query family members → empty
	mock.ExpectQuery("SELECT fm.user_id FROM family_members").
		WithArgs(familyID.String()).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}))

	// Fallback to owner: check dedup → no existing notification
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(false))

	// Create notification for owner
	mock.ExpectExec("INSERT INTO notifications").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	assert.NotPanics(t, func() {
		err := svc.CheckBudgets(context.Background())
		assert.NoError(t, err)
	})
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ═══════════════════════════════════════════════════════════════════════════════
// CheckCreditCardReminders — Boundary Tests
// ═══════════════════════════════════════════════════════════════════════════════

func TestCheckCreditCardReminders_NoAccounts_NoPanic(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	// No credit card accounts
	mock.ExpectQuery("SELECT id, user_id, family_id, name, billing_day, payment_due_day").
		WillReturnRows(pgxmock.NewRows([]string{
			"id", "user_id", "family_id", "name", "billing_day", "payment_due_day",
		}))

	assert.NotPanics(t, func() {
		err := svc.CheckCreditCardReminders(context.Background())
		assert.NoError(t, err)
	})
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestCheckCreditCardReminders_BillingDayMatchesToday(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	accountID := uuid.New()
	userUUID := uuid.MustParse(testUserID)
	today := time.Now().Day()

	// Credit card with billing_day = today
	billingDay := today
	mock.ExpectQuery("SELECT id, user_id, family_id, name, billing_day, payment_due_day").
		WillReturnRows(pgxmock.NewRows([]string{
			"id", "user_id", "family_id", "name", "billing_day", "payment_due_day",
		}).AddRow(accountID, userUUID, nil, "Test Card", &billingDay, nil))

	// getCreditCardRecipients: personal account → just owner
	// hasCreditCardNotification: no existing notification today
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(false))

	// Create billing_day_reminder notification
	mock.ExpectExec("INSERT INTO notifications").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	assert.NotPanics(t, func() {
		err := svc.CheckCreditCardReminders(context.Background())
		assert.NoError(t, err)
	})
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestCheckCreditCardReminders_BillingDayNotToday_NoReminder(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	accountID := uuid.New()
	userUUID := uuid.MustParse(testUserID)
	today := time.Now().Day()

	// billing_day is NOT today (use yesterday or some other day)
	otherDay := (today + 15) % 28
	if otherDay == 0 {
		otherDay = 1
	}

	mock.ExpectQuery("SELECT id, user_id, family_id, name, billing_day, payment_due_day").
		WillReturnRows(pgxmock.NewRows([]string{
			"id", "user_id", "family_id", "name", "billing_day", "payment_due_day",
		}).AddRow(accountID, userUUID, nil, "Test Card", &otherDay, nil))

	// billing_day != today → no notification should be created
	assert.NotPanics(t, func() {
		err := svc.CheckCreditCardReminders(context.Background())
		assert.NoError(t, err)
	})
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestCheckCreditCardReminders_PaymentDueToday_TriggersReminder(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	accountID := uuid.New()
	userUUID := uuid.MustParse(testUserID)
	today := time.Now().Day()

	// payment_due_day = today (daysUntilDue = 0, which is <= 3)
	paymentDueDay := today
	mock.ExpectQuery("SELECT id, user_id, family_id, name, billing_day, payment_due_day").
		WillReturnRows(pgxmock.NewRows([]string{
			"id", "user_id", "family_id", "name", "billing_day", "payment_due_day",
		}).AddRow(accountID, userUUID, nil, "Test Card", nil, &paymentDueDay))

	// hasCreditCardNotification: no existing
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(false))

	// Create payment_due_reminder
	mock.ExpectExec("INSERT INTO notifications").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	assert.NotPanics(t, func() {
		err := svc.CheckCreditCardReminders(context.Background())
		assert.NoError(t, err)
	})
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ═══════════════════════════════════════════════════════════════════════════════
// Cross-year boundary test
// ═══════════════════════════════════════════════════════════════════════════════

func TestCheckBudgets_CrossYearBoundary(t *testing.T) {
	// This test verifies that CheckBudgets uses the current year/month correctly.
	// The function internally uses time.Now() to determine year/month,
	// so we verify it queries with the right parameters.

	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	now := time.Now()
	year := int32(now.Year())
	month := int32(now.Month())

	// Expect query with current year and month
	mock.ExpectQuery("SELECT b.id, b.user_id, b.family_id, b.total_amount").
		WithArgs(year, month).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "total_amount"}))

	err = svc.CheckBudgets(context.Background())
	assert.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ═══════════════════════════════════════════════════════════════════════════════
// CheckLoanReminders — Boundary Tests
// ═══════════════════════════════════════════════════════════════════════════════

func TestCheckLoanReminders_NoSettings_NoPanic(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	// No users with loan_reminder enabled
	mock.ExpectQuery("SELECT user_id, reminder_days_before FROM notification_settings").
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "reminder_days_before"}))

	// No upcoming payments (uses default maxDays=3)
	mock.ExpectQuery("SELECT l.id, l.user_id, l.name, ls.month_number, ls.payment, ls.due_date").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()). // now, cutoff
		WillReturnRows(pgxmock.NewRows([]string{
			"id", "user_id", "name", "month_number", "payment", "due_date",
		}))

	assert.NotPanics(t, func() {
		err := svc.CheckLoanReminders(context.Background())
		assert.NoError(t, err)
	})
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ═══════════════════════════════════════════════════════════════════════════════
// CheckCustomReminders — Boundary Tests
// ═══════════════════════════════════════════════════════════════════════════════

func TestCheckCustomReminders_NoDueReminders_NoPanic(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	// No reminders due
	mock.ExpectQuery("SELECT id, user_id, family_id, title, description, remind_at, repeat_rule, repeat_end_at").
		WithArgs(pgxmock.AnyArg()). // now
		WillReturnRows(pgxmock.NewRows([]string{
			"id", "user_id", "family_id", "title", "description", "remind_at", "repeat_rule", "repeat_end_at",
		}))

	assert.NotPanics(t, func() {
		err := svc.CheckCustomReminders(context.Background())
		assert.NoError(t, err)
	})
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestCheckCustomReminders_OneTimeReminder_Deactivates(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	reminderID := uuid.New()
	userUUID := uuid.MustParse(testUserID)

	mock.ExpectQuery("SELECT id, user_id, family_id, title, description, remind_at, repeat_rule, repeat_end_at").
		WithArgs(pgxmock.AnyArg()). // now
		WillReturnRows(pgxmock.NewRows([]string{
			"id", "user_id", "family_id", "title", "description", "remind_at", "repeat_rule", "repeat_end_at",
		}).AddRow(
			reminderID, userUUID, nil, "Test Reminder", "desc",
			time.Now().Add(-time.Minute), "none", nil,
		))

	// Create notification (5 args: userID, type, title, body, data_json)
	mock.ExpectExec("INSERT INTO notifications").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	// Deactivate one-time reminder
	mock.ExpectExec("UPDATE custom_reminders SET is_active = false").
		WithArgs(reminderID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	assert.NotPanics(t, func() {
		err := svc.CheckCustomReminders(context.Background())
		assert.NoError(t, err)
	})
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ═══════════════════════════════════════════════════════════════════════════════
// Helper function tests
// ═══════════════════════════════════════════════════════════════════════════════

func TestDaysInMonth_Boundaries(t *testing.T) {
	tests := []struct {
		time     time.Time
		expected int
	}{
		{time.Date(2024, 1, 15, 0, 0, 0, 0, time.UTC), 31},  // Jan
		{time.Date(2024, 2, 15, 0, 0, 0, 0, time.UTC), 29},  // Feb leap year
		{time.Date(2023, 2, 15, 0, 0, 0, 0, time.UTC), 28},  // Feb non-leap
		{time.Date(2024, 4, 15, 0, 0, 0, 0, time.UTC), 30},  // Apr
		{time.Date(2024, 12, 15, 0, 0, 0, 0, time.UTC), 31}, // Dec
	}

	for _, tc := range tests {
		result := daysInMonth(tc.time)
		assert.Equal(t, tc.expected, result, "daysInMonth(%v)", tc.time)
	}
}

func TestNextOccurrence_CrossYear(t *testing.T) {
	base := time.Date(2024, 12, 31, 10, 0, 0, 0, time.UTC)

	tests := []struct {
		rule     string
		expected time.Time
	}{
		{"daily", time.Date(2025, 1, 1, 10, 0, 0, 0, time.UTC)},         // cross year
		{"weekly", time.Date(2025, 1, 7, 10, 0, 0, 0, time.UTC)},        // cross year
		{"monthly", time.Date(2025, 1, 31, 10, 0, 0, 0, time.UTC)},      // cross year
		{"yearly", time.Date(2025, 12, 31, 10, 0, 0, 0, time.UTC)},      // next year
		{"none", time.Date(2024, 12, 31, 10, 0, 0, 0, time.UTC)},        // no change
	}

	for _, tc := range tests {
		result := nextOccurrence(base, tc.rule)
		assert.Equal(t, tc.expected, result, "nextOccurrence(%v, %s)", base, tc.rule)
	}
}
