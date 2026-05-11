package dashboard

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"github.com/familyledger/server/pkg/middleware"
	pb "github.com/familyledger/server/proto/dashboard"
)

const testUserID = "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"
const testFamilyID = "f1234567-9c0b-4ef8-bb6d-6bb9bd380a22"

func authedCtx() context.Context {
	return context.WithValue(context.Background(), middleware.UserIDKey, testUserID)
}

// ─── Helper: expect family membership check ─────────────────────────────────

func expectFamilyMembershipCheck(mock pgxmock.PgxPoolIface, familyID, userID string, isMember bool) {
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(familyID, userID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(isMember))
}

// ─── Helper: expect last month queries (personal mode) ──────────────────────

func expectLastMonthQueriesPersonal(mock pgxmock.PgxPoolIface) {
	// current cash (personal mode with family_id IS NULL)
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(balance\\), 0\\)").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(0)))
	// month income/expense
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(CASE").
		WithArgs(testUserID, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"income", "expense"}).AddRow(int64(0), int64(0)))
	// last month investment
	mock.ExpectQuery("SELECT COALESCE\\(SUM").
		WithArgs(testUserID, pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(0)))
	// last month fixed asset
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(latest_val").
		WithArgs(testUserID, pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(0)))
	// last month loan
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(remaining_principal\\)").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(0)))
}

// ─── Helper: expect last month queries (family mode) ────────────────────────

func expectLastMonthQueriesFamily(mock pgxmock.PgxPoolIface) {
	// current cash (family mode)
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(balance\\), 0\\)").
		WithArgs(testFamilyID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(0)))
	// month income/expense (family mode joins accounts)
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(CASE").
		WithArgs(testFamilyID, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"income", "expense"}).AddRow(int64(0), int64(0)))
	// last month investment
	mock.ExpectQuery("SELECT COALESCE\\(SUM").
		WithArgs(testFamilyID, pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(0)))
	// last month fixed asset
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(latest_val").
		WithArgs(testFamilyID, pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(0)))
	// last month loan
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(remaining_principal\\)").
		WithArgs(testFamilyID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(0)))
}

// ═══════════════════════════════════════════════════════════════════════════════
// GetNetWorth Tests
// ═══════════════════════════════════════════════════════════════════════════════

func TestGetNetWorth_PersonalMode_ExcludesFamilyData(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	// Personal mode: no family membership check needed
	// 1. cash & bank (with family_id IS NULL filter)
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(balance\\), 0\\)").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(100000)))
	// 2. investment (with family_id IS NULL)
	mock.ExpectQuery("SELECT COALESCE\\(SUM").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(50000)))
	// 3. fixed asset (with family_id IS NULL)
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(current_value\\)").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(200000)))
	// 4. loan (with family_id IS NULL)
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(remaining_principal\\)").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(30000)))

	// estimateLastMonthNetWorth queries (personal)
	expectLastMonthQueriesPersonal(mock)

	resp, err := svc.GetNetWorth(authedCtx(), &pb.GetNetWorthRequest{FamilyId: ""})
	require.NoError(t, err)

	// total = 100000 + 50000 + 200000 - 30000 = 320000
	assert.Equal(t, int64(320000), resp.Total)
	assert.Equal(t, int64(100000), resp.CashAndBank)
	assert.Equal(t, int64(50000), resp.InvestmentValue)
	assert.Equal(t, int64(200000), resp.FixedAssetValue)
	assert.Equal(t, int64(-30000), resp.LoanBalance)
	assert.Len(t, resp.Composition, 4)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGetNetWorth_FamilyMode_ReturnsAllFamilyMemberData(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	// Family membership check
	expectFamilyMembershipCheck(mock, testFamilyID, testUserID, true)

	// 1. cash & bank (family_id filter, includes all family members' accounts)
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(balance\\), 0\\)").
		WithArgs(testFamilyID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(500000)))
	// 2. investment (family_id filter)
	mock.ExpectQuery("SELECT COALESCE\\(SUM").
		WithArgs(testFamilyID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(200000)))
	// 3. fixed asset (family_id filter)
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(current_value\\)").
		WithArgs(testFamilyID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(1000000)))
	// 4. loan (family_id filter)
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(remaining_principal\\)").
		WithArgs(testFamilyID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(100000)))

	// estimateLastMonthNetWorth queries (family)
	expectLastMonthQueriesFamily(mock)

	resp, err := svc.GetNetWorth(authedCtx(), &pb.GetNetWorthRequest{FamilyId: testFamilyID})
	require.NoError(t, err)

	// total = 500000 + 200000 + 1000000 - 100000 = 1600000
	assert.Equal(t, int64(1600000), resp.Total)
	assert.Equal(t, int64(500000), resp.CashAndBank)
	assert.Equal(t, int64(200000), resp.InvestmentValue)
	assert.Equal(t, int64(1000000), resp.FixedAssetValue)
	assert.Equal(t, int64(-100000), resp.LoanBalance)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGetNetWorth_FamilyMode_NotMember_PermissionDenied(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	// Family membership check: NOT a member
	expectFamilyMembershipCheck(mock, testFamilyID, testUserID, false)

	_, err = svc.GetNetWorth(authedCtx(), &pb.GetNetWorthRequest{FamilyId: testFamilyID})
	require.Error(t, err)
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGetNetWorth_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	_, err = svc.GetNetWorth(context.Background(), &pb.GetNetWorthRequest{})
	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestGetNetWorth_NoAccounts(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	// All return zero (personal mode)
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(balance\\), 0\\)").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(0)))
	mock.ExpectQuery("SELECT COALESCE\\(SUM").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(0)))
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(current_value\\)").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(0)))
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(remaining_principal\\)").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(0)))

	expectLastMonthQueriesPersonal(mock)

	resp, err := svc.GetNetWorth(authedCtx(), &pb.GetNetWorthRequest{})
	require.NoError(t, err)
	assert.Equal(t, int64(0), resp.Total)
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ═══════════════════════════════════════════════════════════════════════════════
// GetIncomeExpenseTrend Tests
// ═══════════════════════════════════════════════════════════════════════════════

func TestGetIncomeExpenseTrend_PersonalMode(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	now := time.Now()
	// Use current month to ensure the mock data falls within the generated range
	m1 := time.Date(now.Year(), now.Month()-1, 1, 0, 0, 0, 0, time.UTC)
	m2 := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.UTC)

	rows := pgxmock.NewRows([]string{"period", "income", "expense"}).
		AddRow(m1, int64(80000), int64(50000)).
		AddRow(m2, int64(90000), int64(60000))

	mock.ExpectQuery("SELECT DATE_TRUNC").
		WithArgs(testUserID, pgxmock.AnyArg()).
		WillReturnRows(rows)

	resp, err := svc.GetIncomeExpenseTrend(authedCtx(), &pb.TrendRequest{Period: "monthly", Count: 6})
	require.NoError(t, err)
	// Should return 6 points (complete time series)
	assert.Len(t, resp.Points, 6)
	// Last two points should have data
	assert.Equal(t, int64(80000), resp.Points[4].Income)
	assert.Equal(t, int64(50000), resp.Points[4].Expense)
	assert.Equal(t, int64(30000), resp.Points[4].Net)
	assert.Equal(t, int64(90000), resp.Points[5].Income)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGetIncomeExpenseTrend_FamilyMode(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	// Family membership check
	expectFamilyMembershipCheck(mock, testFamilyID, testUserID, true)

	now := time.Now()
	// Query returns family data for current month
	rows := pgxmock.NewRows([]string{"period", "income", "expense"}).
		AddRow(time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.UTC), int64(200000), int64(150000))

	mock.ExpectQuery("SELECT DATE_TRUNC").
		WithArgs(testFamilyID, pgxmock.AnyArg()).
		WillReturnRows(rows)

	resp, err := svc.GetIncomeExpenseTrend(authedCtx(), &pb.TrendRequest{
		Period:   "monthly",
		Count:    6,
		FamilyId: testFamilyID,
	})
	require.NoError(t, err)
	require.Len(t, resp.Points, 6)
	// Last point (current month) should have data
	assert.Equal(t, int64(200000), resp.Points[5].Income)
	assert.Equal(t, int64(150000), resp.Points[5].Expense)
	assert.Equal(t, int64(50000), resp.Points[5].Net)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGetIncomeExpenseTrend_FamilyMode_NotMember(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	expectFamilyMembershipCheck(mock, testFamilyID, testUserID, false)

	_, err = svc.GetIncomeExpenseTrend(authedCtx(), &pb.TrendRequest{
		Period:   "monthly",
		Count:    6,
		FamilyId: testFamilyID,
	})
	require.Error(t, err)
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGetIncomeExpenseTrend_Empty(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	mock.ExpectQuery("SELECT DATE_TRUNC").
		WithArgs(testUserID, pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"period", "income", "expense"}))

	resp, err := svc.GetIncomeExpenseTrend(authedCtx(), &pb.TrendRequest{Period: "monthly", Count: 6})
	require.NoError(t, err)
	// Returns complete time series even with no data (all zeros)
	assert.Len(t, resp.Points, 6)
	for _, p := range resp.Points {
		assert.Equal(t, int64(0), p.Income)
		assert.Equal(t, int64(0), p.Expense)
	}
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGetIncomeExpenseTrend_Yearly(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	now := time.Now()
	rows := pgxmock.NewRows([]string{"period", "income", "expense"}).
		AddRow(time.Date(now.Year(), 1, 1, 0, 0, 0, 0, time.UTC), int64(1000000), int64(800000))

	mock.ExpectQuery("SELECT DATE_TRUNC").
		WithArgs(testUserID, pgxmock.AnyArg()).
		WillReturnRows(rows)

	resp, err := svc.GetIncomeExpenseTrend(authedCtx(), &pb.TrendRequest{Period: "yearly", Count: 5})
	require.NoError(t, err)
	// Should return 5 points (gaps filled with zeros)
	assert.Len(t, resp.Points, 5)
	// Current year should have data
	currentYearLabel := fmt.Sprintf("%d", now.Year())
	found := false
	for _, p := range resp.Points {
		if p.Label == currentYearLabel {
			assert.Equal(t, int64(1000000), p.Income)
			assert.Equal(t, int64(800000), p.Expense)
			found = true
		}
	}
	assert.True(t, found, "current year point not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGetIncomeExpenseTrend_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	_, err = svc.GetIncomeExpenseTrend(context.Background(), &pb.TrendRequest{})
	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

// ═══════════════════════════════════════════════════════════════════════════════
// GetCategoryBreakdown Tests
// ═══════════════════════════════════════════════════════════════════════════════

func TestGetCategoryBreakdown_PersonalMode(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	icon1 := "🍔"
	icon2 := "🚗"
	iconKey1 := "food"
	iconKey2 := "transport"
	rows := pgxmock.NewRows([]string{"category_id", "name", "icon", "icon_key", "parent_id", "amount"}).
		AddRow("cat-001", "餐饮", &icon1, &iconKey1, (*string)(nil), int64(30000)).
		AddRow("cat-002", "交通", &icon2, &iconKey2, (*string)(nil), int64(10000))

	mock.ExpectQuery("SELECT t.category_id").
		WithArgs(testUserID, "expense", pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(rows)

	resp, err := svc.GetCategoryBreakdown(authedCtx(), &pb.CategoryBreakdownRequest{
		Year:  2026,
		Month: 4,
		Type:  "expense",
	})
	require.NoError(t, err)
	assert.Equal(t, int64(40000), resp.Total)
	require.Len(t, resp.Items, 2)
	assert.Equal(t, "cat-001", resp.Items[0].CategoryId)
	assert.Equal(t, "餐饮", resp.Items[0].CategoryName)
	assert.Equal(t, int64(30000), resp.Items[0].Amount)
	assert.InDelta(t, 0.75, resp.Items[0].Weight, 0.01)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGetCategoryBreakdown_FamilyMode(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	// Family membership check
	expectFamilyMembershipCheck(mock, testFamilyID, testUserID, true)

	icon1 := "🍔"
	iconKey1 := "food"
	rows := pgxmock.NewRows([]string{"category_id", "name", "icon", "icon_key", "parent_id", "amount"}).
		AddRow("cat-001", "餐饮", &icon1, &iconKey1, (*string)(nil), int64(80000))

	mock.ExpectQuery("SELECT t.category_id").
		WithArgs(testFamilyID, "expense", pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(rows)

	resp, err := svc.GetCategoryBreakdown(authedCtx(), &pb.CategoryBreakdownRequest{
		Year:     2026,
		Month:    4,
		Type:     "expense",
		FamilyId: testFamilyID,
	})
	require.NoError(t, err)
	assert.Equal(t, int64(80000), resp.Total)
	require.Len(t, resp.Items, 1)
	assert.Equal(t, "cat-001", resp.Items[0].CategoryId)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGetCategoryBreakdown_FamilyMode_NotMember(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	expectFamilyMembershipCheck(mock, testFamilyID, testUserID, false)

	_, err = svc.GetCategoryBreakdown(authedCtx(), &pb.CategoryBreakdownRequest{
		Year:     2026,
		Month:    4,
		Type:     "expense",
		FamilyId: testFamilyID,
	})
	require.Error(t, err)
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGetCategoryBreakdown_NoData(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	mock.ExpectQuery("SELECT t.category_id").
		WithArgs(testUserID, "expense", pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"category_id", "name", "icon", "icon_key", "parent_id", "amount"}))

	resp, err := svc.GetCategoryBreakdown(authedCtx(), &pb.CategoryBreakdownRequest{
		Year:  2026,
		Month: 4,
		Type:  "expense",
	})
	require.NoError(t, err)
	assert.Equal(t, int64(0), resp.Total)
	assert.Empty(t, resp.Items)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGetCategoryBreakdown_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	_, err = svc.GetCategoryBreakdown(context.Background(), &pb.CategoryBreakdownRequest{})
	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

// ═══════════════════════════════════════════════════════════════════════════════
// GetBudgetSummary Tests
// ═══════════════════════════════════════════════════════════════════════════════

func TestGetBudgetSummary_PersonalMode(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	// budget query (personal: user_id + family_id IS NULL)
	mock.ExpectQuery("SELECT id, total_amount FROM budgets").
		WithArgs(testUserID, 2026, 4).
		WillReturnRows(pgxmock.NewRows([]string{"id", "total_amount"}).
			AddRow("budget-001", int64(500000)))

	// total spent (personal)
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(amount_cny\\), 0\\)").
		WithArgs(testUserID, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(300000)))

	// category budgets
	mock.ExpectQuery("SELECT cb.category_id, c.name, cb.amount").
		WithArgs("budget-001").
		WillReturnRows(pgxmock.NewRows([]string{"category_id", "name", "amount"}).
			AddRow("cat-001", "餐饮", int64(100000)))

	// category spent (personal)
	mock.ExpectQuery("SELECT t.category_id").
		WithArgs(testUserID, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"category_id", "parent_id", "spent"}).
			AddRow("cat-001", (*string)(nil), int64(80000)))

	resp, err := svc.GetBudgetSummary(authedCtx(), &pb.BudgetSummaryRequest{
		Year:  2026,
		Month: 4,
	})
	require.NoError(t, err)
	assert.Equal(t, int64(500000), resp.TotalBudget)
	assert.Equal(t, int64(300000), resp.TotalSpent)
	assert.InDelta(t, 0.6, resp.ExecutionRate, 0.01)
	require.Len(t, resp.Categories, 1)
	assert.Equal(t, "cat-001", resp.Categories[0].CategoryId)
	assert.Equal(t, int64(80000), resp.Categories[0].SpentAmount)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGetBudgetSummary_FamilyMode(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	// Family membership check
	expectFamilyMembershipCheck(mock, testFamilyID, testUserID, true)

	// budget query (family: family_id filter)
	mock.ExpectQuery("SELECT id, total_amount FROM budgets").
		WithArgs(testFamilyID, 2026, 4).
		WillReturnRows(pgxmock.NewRows([]string{"id", "total_amount"}).
			AddRow("budget-fam-001", int64(1000000)))

	// total spent (family)
	mock.ExpectQuery("SELECT COALESCE\\(SUM").
		WithArgs(testFamilyID, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(600000)))

	// category budgets
	mock.ExpectQuery("SELECT cb.category_id, c.name, cb.amount").
		WithArgs("budget-fam-001").
		WillReturnRows(pgxmock.NewRows([]string{"category_id", "name", "amount"}).
			AddRow("cat-001", "餐饮", int64(200000)))

	// category spent (family)
	mock.ExpectQuery("SELECT t.category_id").
		WithArgs(testFamilyID, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"category_id", "parent_id", "spent"}).
			AddRow("cat-001", (*string)(nil), int64(180000)))

	resp, err := svc.GetBudgetSummary(authedCtx(), &pb.BudgetSummaryRequest{
		Year:     2026,
		Month:    4,
		FamilyId: testFamilyID,
	})
	require.NoError(t, err)
	assert.Equal(t, int64(1000000), resp.TotalBudget)
	assert.Equal(t, int64(600000), resp.TotalSpent)
	assert.InDelta(t, 0.6, resp.ExecutionRate, 0.01)
	require.Len(t, resp.Categories, 1)
	assert.Equal(t, int64(180000), resp.Categories[0].SpentAmount)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGetBudgetSummary_FamilyMode_NotMember(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	expectFamilyMembershipCheck(mock, testFamilyID, testUserID, false)

	_, err = svc.GetBudgetSummary(authedCtx(), &pb.BudgetSummaryRequest{
		Year:     2026,
		Month:    4,
		FamilyId: testFamilyID,
	})
	require.Error(t, err)
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGetBudgetSummary_NoBudgets(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	// budget not found → pgx.ErrNoRows
	mock.ExpectQuery("SELECT id, total_amount FROM budgets").
		WithArgs(testUserID, 2026, 4).
		WillReturnError(fmt.Errorf("no rows")) // any error triggers empty response

	resp, err := svc.GetBudgetSummary(authedCtx(), &pb.BudgetSummaryRequest{
		Year:  2026,
		Month: 4,
	})
	require.NoError(t, err)
	assert.Equal(t, int64(0), resp.TotalBudget)
	assert.Nil(t, resp.Categories)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGetBudgetSummary_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	_, err = svc.GetBudgetSummary(context.Background(), &pb.BudgetSummaryRequest{})
	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

// ═══════════════════════════════════════════════════════════════════════════════
// GetNetWorthTrend Tests
// ═══════════════════════════════════════════════════════════════════════════════

func TestGetNetWorthTrend_PersonalMode_ReturnsNonEmptyPoints(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	// GetNetWorthTrend calls GetNetWorth first (personal mode)
	// → GetNetWorth personal queries:
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(balance\\), 0\\)").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(100000)))
	mock.ExpectQuery("SELECT COALESCE\\(SUM").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(50000)))
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(current_value\\)").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(0)))
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(remaining_principal\\)").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(0)))
	expectLastMonthQueriesPersonal(mock)

	// Then GetNetWorthTrend queries monthly net
	now := time.Now()
	rows := pgxmock.NewRows([]string{"period", "income", "expense"}).
		AddRow(time.Date(now.Year(), now.Month()-1, 1, 0, 0, 0, 0, time.UTC), int64(50000), int64(30000)).
		AddRow(time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.UTC), int64(60000), int64(40000))

	mock.ExpectQuery("SELECT DATE_TRUNC").
		WithArgs(testUserID, pgxmock.AnyArg()).
		WillReturnRows(rows)

	resp, err := svc.GetNetWorthTrend(authedCtx(), &pb.TrendRequest{Count: 3})
	require.NoError(t, err)
	require.NotEmpty(t, resp.Points, "GetNetWorthTrend should return non-empty data points")
	assert.Equal(t, 3, len(resp.Points))

	// The last point should be the current net worth
	lastPoint := resp.Points[len(resp.Points)-1]
	assert.Equal(t, int64(150000), lastPoint.Net) // 100000 + 50000 + 0 - 0
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGetNetWorthTrend_FamilyMode(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	// GetNetWorthTrend → GetNetWorth (family mode)
	// First: resolveFamilyFilter for GetNetWorthTrend
	expectFamilyMembershipCheck(mock, testFamilyID, testUserID, true)

	// Second: GetNetWorth is called internally with FamilyId, which calls resolveFamilyFilter again
	expectFamilyMembershipCheck(mock, testFamilyID, testUserID, true)

	// GetNetWorth family queries:
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(balance\\), 0\\)").
		WithArgs(testFamilyID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(300000)))
	mock.ExpectQuery("SELECT COALESCE\\(SUM").
		WithArgs(testFamilyID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(100000)))
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(current_value\\)").
		WithArgs(testFamilyID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(0)))
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(remaining_principal\\)").
		WithArgs(testFamilyID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(0)))
	expectLastMonthQueriesFamily(mock)

	// GetNetWorthTrend query monthly net (family mode)
	now := time.Now()
	rows := pgxmock.NewRows([]string{"period", "income", "expense"}).
		AddRow(time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.UTC), int64(100000), int64(50000))

	mock.ExpectQuery("SELECT DATE_TRUNC").
		WithArgs(testFamilyID, pgxmock.AnyArg()).
		WillReturnRows(rows)

	resp, err := svc.GetNetWorthTrend(authedCtx(), &pb.TrendRequest{Count: 2, FamilyId: testFamilyID})
	require.NoError(t, err)
	require.NotEmpty(t, resp.Points)
	assert.Equal(t, 2, len(resp.Points))

	// Last point should be current net worth = 300000 + 100000 = 400000
	lastPoint := resp.Points[len(resp.Points)-1]
	assert.Equal(t, int64(400000), lastPoint.Net)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGetNetWorthTrend_FamilyMode_NotMember(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	// Membership check in resolveFamilyFilter for GetNetWorthTrend itself
	expectFamilyMembershipCheck(mock, testFamilyID, testUserID, false)

	_, err = svc.GetNetWorthTrend(authedCtx(), &pb.TrendRequest{Count: 3, FamilyId: testFamilyID})
	require.Error(t, err)
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGetNetWorthTrend_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	_, err = svc.GetNetWorthTrend(context.Background(), &pb.TrendRequest{})
	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

// ═══════════════════════════════════════════════════════════════════════════════
// GetIncomeExpenseTrend — SingleMonth (regression)
// ═══════════════════════════════════════════════════════════════════════════════

func TestGetIncomeExpenseTrend_SingleMonth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	now := time.Now()
	rows := pgxmock.NewRows([]string{"period", "income", "expense"}).
		AddRow(time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.UTC), int64(120000), int64(80000))

	mock.ExpectQuery("SELECT DATE_TRUNC").
		WithArgs(testUserID, pgxmock.AnyArg()).
		WillReturnRows(rows)

	resp, err := svc.GetIncomeExpenseTrend(authedCtx(), &pb.TrendRequest{Period: "monthly", Count: 1})
	require.NoError(t, err)
	require.Len(t, resp.Points, 1)
	assert.Equal(t, int64(120000), resp.Points[0].Income)
	assert.Equal(t, int64(80000), resp.Points[0].Expense)
	assert.Equal(t, int64(40000), resp.Points[0].Net)
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ═══════════════════════════════════════════════════════════════════════════════
// GetExchangeRates
// ═══════════════════════════════════════════════════════════════════════════════

func TestGetExchangeRates_DefaultCNY(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	now := time.Now()

	mock.ExpectQuery("SELECT currency_pair, rate, updated_at FROM exchange_rates").
		WillReturnRows(pgxmock.NewRows([]string{"currency_pair", "rate", "updated_at"}).
			AddRow("USD_CNY", 7.25, now).
			AddRow("EUR_CNY", 7.89, now))

	resp, err := svc.GetExchangeRates(authedCtx(), &pb.GetExchangeRatesRequest{})
	require.NoError(t, err)
	assert.Equal(t, "CNY", resp.BaseCurrency)
	assert.Len(t, resp.Rates, 2)
	assert.Equal(t, now.Unix(), resp.UpdatedAt)

	// Verify rates are inverted (1 CNY = ? USD)
	for _, r := range resp.Rates {
		if r.Currency == "USD" {
			assert.InDelta(t, 1.0/7.25, r.Rate, 0.001)
			assert.Equal(t, "美元", r.Name)
		}
		if r.Currency == "EUR" {
			assert.InDelta(t, 1.0/7.89, r.Rate, 0.001)
			assert.Equal(t, "欧元", r.Name)
		}
	}
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGetExchangeRates_EmptyRates(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	mock.ExpectQuery("SELECT currency_pair, rate, updated_at FROM exchange_rates").
		WillReturnRows(pgxmock.NewRows([]string{"currency_pair", "rate", "updated_at"}))

	resp, err := svc.GetExchangeRates(authedCtx(), &pb.GetExchangeRatesRequest{BaseCurrency: "CNY"})
	require.NoError(t, err)
	assert.Equal(t, "CNY", resp.BaseCurrency)
	assert.Empty(t, resp.Rates)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGetExchangeRates_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	_, err = svc.GetExchangeRates(context.Background(), &pb.GetExchangeRatesRequest{})
	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

// ─── GetInvestmentTrend ───────────────────────────────────────────────────────────

func TestGetInvestmentTrend_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	_, err = svc.GetInvestmentTrend(context.Background(), &pb.InvestmentTrendRequest{})
	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestGetInvestmentTrend_PersonalEmpty(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	// For each month (default 12), expect cost+value query
	for i := 0; i < 12; i++ {
		mock.ExpectQuery("SELECT COALESCE").
			WillReturnRows(pgxmock.NewRows([]string{"cost", "value"}).AddRow(int64(0), int64(0)))
	}

	resp, err := svc.GetInvestmentTrend(authedCtx(), &pb.InvestmentTrendRequest{})
	require.NoError(t, err)
	assert.Len(t, resp.Points, 12)
	for _, p := range resp.Points {
		assert.Equal(t, int64(0), p.TotalValue)
		assert.Equal(t, int64(0), p.TotalCost)
		assert.Equal(t, 0.0, p.ReturnRate)
	}
}
