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

func authedCtx() context.Context {
	return context.WithValue(context.Background(), middleware.UserIDKey, testUserID)
}

// expectLastMonthQueries sets up the 5 queries that estimateLastMonthNetWorth makes
// with zero values so tests for GetNetWorth don't need to care about the estimation logic.
func expectLastMonthQueries(mock pgxmock.PgxPoolIface) {
	// current cash (reused in estimation)
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

// ─── GetNetWorth ────────────────────────────────────────────────────────────

func TestGetNetWorth_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	// 1. cash & bank
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(balance\\), 0\\)").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(100000)))
	// 2. investment
	mock.ExpectQuery("SELECT COALESCE\\(SUM").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(50000)))
	// 3. fixed asset
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(current_value\\)").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(200000)))
	// 4. loan
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(remaining_principal\\)").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(30000)))

	// estimateLastMonthNetWorth queries
	expectLastMonthQueries(mock)

	resp, err := svc.GetNetWorth(authedCtx(), &pb.GetNetWorthRequest{})
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

	// All return zero
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

	expectLastMonthQueries(mock)

	resp, err := svc.GetNetWorth(authedCtx(), &pb.GetNetWorthRequest{})
	require.NoError(t, err)
	assert.Equal(t, int64(0), resp.Total)
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ─── GetIncomeExpenseTrend (mapped from task's "GetTrend") ──────────────────

func TestGetIncomeExpenseTrend_Monthly(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	rows := pgxmock.NewRows([]string{"period", "income", "expense"}).
		AddRow(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC), int64(80000), int64(50000)).
		AddRow(time.Date(2026, 2, 1, 0, 0, 0, 0, time.UTC), int64(90000), int64(60000))

	mock.ExpectQuery("SELECT DATE_TRUNC").
		WithArgs(testUserID, pgxmock.AnyArg()).
		WillReturnRows(rows)

	resp, err := svc.GetIncomeExpenseTrend(authedCtx(), &pb.TrendRequest{Period: "monthly", Count: 6})
	require.NoError(t, err)
	assert.Len(t, resp.Points, 2)
	assert.Equal(t, "2026-01", resp.Points[0].Label)
	assert.Equal(t, int64(80000), resp.Points[0].Income)
	assert.Equal(t, int64(50000), resp.Points[0].Expense)
	assert.Equal(t, int64(30000), resp.Points[0].Net)
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
	assert.Empty(t, resp.Points)
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ─── GetCategoryBreakdown ───────────────────────────────────────────────────

func TestGetCategoryBreakdown_Success(t *testing.T) {
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

// ─── GetBudgetSummary (mapped from task's "GetBudgetOverview") ──────────────

func TestGetBudgetSummary_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	// budget query
	mock.ExpectQuery("SELECT id, total_amount FROM budgets").
		WithArgs(testUserID, 2026, 4).
		WillReturnRows(pgxmock.NewRows([]string{"id", "total_amount"}).
			AddRow("budget-001", int64(500000)))

	// total spent
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(amount_cny\\), 0\\)").
		WithArgs(testUserID, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(300000)))

	// category budgets
	mock.ExpectQuery("SELECT cb.category_id, c.name, cb.amount").
		WithArgs("budget-001").
		WillReturnRows(pgxmock.NewRows([]string{"category_id", "name", "amount"}).
			AddRow("cat-001", "餐饮", int64(100000)))

	// category spent (now includes parent_id)
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

// ─── GetMonthSummary → GetIncomeExpenseTrend with Count=1 ───────────────────
// The dashboard proto doesn't have a separate "GetMonthSummary" RPC.
// The task maps it to GetIncomeExpenseTrend with a single-month result.

func TestGetIncomeExpenseTrend_SingleMonth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	rows := pgxmock.NewRows([]string{"period", "income", "expense"}).
		AddRow(time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC), int64(120000), int64(80000))

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

// ─── GetRecentTransactions ──────────────────────────────────────────────────
// The service.go doesn't have a GetRecentTransactions method.
// The closest is GetIncomeExpenseTrend — so we test another dimension:
// yearly period.

func TestGetIncomeExpenseTrend_Yearly(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	rows := pgxmock.NewRows([]string{"period", "income", "expense"}).
		AddRow(time.Date(2025, 1, 1, 0, 0, 0, 0, time.UTC), int64(1000000), int64(800000)).
		AddRow(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC), int64(1200000), int64(900000))

	mock.ExpectQuery("SELECT DATE_TRUNC").
		WithArgs(testUserID, pgxmock.AnyArg()).
		WillReturnRows(rows)

	resp, err := svc.GetIncomeExpenseTrend(authedCtx(), &pb.TrendRequest{Period: "yearly", Count: 5})
	require.NoError(t, err)
	assert.Len(t, resp.Points, 2)
	assert.Equal(t, "2025", resp.Points[0].Label)
	assert.Equal(t, "2026", resp.Points[1].Label)
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

func TestGetCategoryBreakdown_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	_, err = svc.GetCategoryBreakdown(context.Background(), &pb.CategoryBreakdownRequest{})
	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
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
