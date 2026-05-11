package dashboard

import (
	"context"
	"errors"
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

// ═══════════════════════════════════════════════════════════════════════════════
// sortCategoryItems — pure function tests
// ═══════════════════════════════════════════════════════════════════════════════

func TestSortCategoryItems_Basic(t *testing.T) {
	items := []*pb.CategoryItem{
		{CategoryId: "c1", Amount: 100},
		{CategoryId: "c3", Amount: 300},
		{CategoryId: "c2", Amount: 200},
	}
	sortCategoryItems(items)
	assert.Equal(t, "c3", items[0].CategoryId)
	assert.Equal(t, "c2", items[1].CategoryId)
	assert.Equal(t, "c1", items[2].CategoryId)
}

func TestSortCategoryItems_WithChildren(t *testing.T) {
	items := []*pb.CategoryItem{
		{
			CategoryId: "parent1",
			Amount:     500,
			Children: []*pb.CategoryItem{
				{CategoryId: "child-a", Amount: 100},
				{CategoryId: "child-c", Amount: 300},
				{CategoryId: "child-b", Amount: 200},
			},
		},
		{
			CategoryId: "parent2",
			Amount:     1000,
			Children: []*pb.CategoryItem{
				{CategoryId: "child-x", Amount: 50},
			},
		},
	}
	sortCategoryItems(items)

	// Parents sorted by amount desc
	assert.Equal(t, "parent2", items[0].CategoryId)
	assert.Equal(t, "parent1", items[1].CategoryId)

	// Children of parent1 sorted by amount desc
	assert.Equal(t, "child-c", items[1].Children[0].CategoryId)
	assert.Equal(t, "child-b", items[1].Children[1].CategoryId)
	assert.Equal(t, "child-a", items[1].Children[2].CategoryId)

	// Single child — no reorder needed
	assert.Equal(t, "child-x", items[0].Children[0].CategoryId)
}

func TestSortCategoryItems_Empty(t *testing.T) {
	var items []*pb.CategoryItem
	sortCategoryItems(items) // should not panic
	assert.Nil(t, items)
}

func TestSortCategoryItems_NoChildren(t *testing.T) {
	items := []*pb.CategoryItem{
		{CategoryId: "a", Amount: 50},
		{CategoryId: "b", Amount: 150},
	}
	sortCategoryItems(items)
	assert.Equal(t, "b", items[0].CategoryId)
	assert.Equal(t, "a", items[1].CategoryId)
}

// ═══════════════════════════════════════════════════════════════════════════════
// GetCategoryBreakdown — subcategory aggregation, income mode, defaults, errors
// ═══════════════════════════════════════════════════════════════════════════════

func TestGetCategoryBreakdown_IncomeType(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	icon := "💰"
	iconKey := "salary"
	rows := pgxmock.NewRows([]string{"category_id", "name", "icon", "icon_key", "parent_id", "amount"}).
		AddRow("cat-income-1", "工资", &icon, &iconKey, (*string)(nil), int64(100000))

	mock.ExpectQuery("SELECT t.category_id").
		WithArgs(testUserID, "income", pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(rows)

	resp, err := svc.GetCategoryBreakdown(authedCtx(), &pb.CategoryBreakdownRequest{
		Year:  2026,
		Month: 5,
		Type:  "income",
	})
	require.NoError(t, err)
	assert.Equal(t, int64(100000), resp.Total)
	require.Len(t, resp.Items, 1)
	assert.Equal(t, "工资", resp.Items[0].CategoryName)
}

func TestGetCategoryBreakdown_DefaultYearMonth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	mock.ExpectQuery("SELECT t.category_id").
		WithArgs(testUserID, "expense", pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"category_id", "name", "icon", "icon_key", "parent_id", "amount"}))

	resp, err := svc.GetCategoryBreakdown(authedCtx(), &pb.CategoryBreakdownRequest{
		// Year=0, Month=0 → should default to current
		Type: "expense",
	})
	require.NoError(t, err)
	assert.Equal(t, int64(0), resp.Total)
}

func TestGetCategoryBreakdown_SubcategoryAggregation(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	parentID := "cat-food"
	icon1 := "🍔"
	icon2 := "🍜"
	iconKey1 := "fastfood"
	iconKey2 := "noodles"

	rows := pgxmock.NewRows([]string{"category_id", "name", "icon", "icon_key", "parent_id", "amount"}).
		// Parent with direct spend
		AddRow("cat-food", "餐饮", &icon1, &iconKey1, (*string)(nil), int64(10000)).
		// Two subcategories
		AddRow("cat-food-fast", "快餐", &icon1, &iconKey1, &parentID, int64(20000)).
		AddRow("cat-food-noodle", "面食", &icon2, &iconKey2, &parentID, int64(5000))

	mock.ExpectQuery("SELECT t.category_id").
		WithArgs(testUserID, "expense", pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(rows)

	resp, err := svc.GetCategoryBreakdown(authedCtx(), &pb.CategoryBreakdownRequest{
		Year:  2026,
		Month: 4,
		Type:  "expense",
	})
	require.NoError(t, err)
	// Total = 10000 + 20000 + 5000 = 35000
	assert.Equal(t, int64(35000), resp.Total)
	require.Len(t, resp.Items, 1) // subcats merged into parent
	assert.Equal(t, "cat-food", resp.Items[0].CategoryId)
	// Parent amount = direct 10000 + subcats (20000+5000) = 35000
	assert.Equal(t, int64(35000), resp.Items[0].Amount)
	require.Len(t, resp.Items[0].Children, 2)
}

func TestGetCategoryBreakdown_SubcategoryOnly_SyntheticParent(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	parentID := "cat-transport"
	icon := "🚗"
	iconKey := "car"

	// Only subcategories, no direct parent spend
	rows := pgxmock.NewRows([]string{"category_id", "name", "icon", "icon_key", "parent_id", "amount"}).
		AddRow("cat-bus", "公交", &icon, &iconKey, &parentID, int64(3000)).
		AddRow("cat-taxi", "出租车", &icon, &iconKey, &parentID, int64(7000))

	mock.ExpectQuery("SELECT t.category_id").
		WithArgs(testUserID, "expense", pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(rows)

	// Synthetic parent lookup
	pIcon := "🚌"
	pIconKey := "transport"
	mock.ExpectQuery("SELECT name, icon, icon_key FROM categories WHERE id").
		WithArgs("cat-transport").
		WillReturnRows(pgxmock.NewRows([]string{"name", "icon", "icon_key"}).
			AddRow("交通", &pIcon, &pIconKey))

	resp, err := svc.GetCategoryBreakdown(authedCtx(), &pb.CategoryBreakdownRequest{
		Year:  2026,
		Month: 4,
		Type:  "expense",
	})
	require.NoError(t, err)
	assert.Equal(t, int64(10000), resp.Total)
	require.Len(t, resp.Items, 1)
	assert.Equal(t, "cat-transport", resp.Items[0].CategoryId)
	assert.Equal(t, "交通", resp.Items[0].CategoryName)
	assert.Equal(t, int64(10000), resp.Items[0].Amount)
	assert.Equal(t, "🚌", resp.Items[0].Icon)
	assert.Equal(t, "transport", resp.Items[0].IconKey)
	require.Len(t, resp.Items[0].Children, 2)
}

func TestGetCategoryBreakdown_SyntheticParent_DBError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	parentID := "cat-unknown"
	icon := "❓"
	iconKey := "unknown"

	rows := pgxmock.NewRows([]string{"category_id", "name", "icon", "icon_key", "parent_id", "amount"}).
		AddRow("cat-sub", "子分类", &icon, &iconKey, &parentID, int64(5000))

	mock.ExpectQuery("SELECT t.category_id").
		WithArgs(testUserID, "expense", pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(rows)

	// Parent lookup fails
	mock.ExpectQuery("SELECT name, icon, icon_key FROM categories WHERE id").
		WithArgs("cat-unknown").
		WillReturnError(errors.New("not found"))

	resp, err := svc.GetCategoryBreakdown(authedCtx(), &pb.CategoryBreakdownRequest{
		Year:  2026,
		Month: 4,
		Type:  "expense",
	})
	require.NoError(t, err)
	require.Len(t, resp.Items, 1)
	assert.Equal(t, "未知", resp.Items[0].CategoryName) // fallback name
}

func TestGetCategoryBreakdown_NullIconFields(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	// Icon and icon_key are NULL
	rows := pgxmock.NewRows([]string{"category_id", "name", "icon", "icon_key", "parent_id", "amount"}).
		AddRow("cat-misc", "其他", (*string)(nil), (*string)(nil), (*string)(nil), int64(2000))

	mock.ExpectQuery("SELECT t.category_id").
		WithArgs(testUserID, "expense", pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(rows)

	resp, err := svc.GetCategoryBreakdown(authedCtx(), &pb.CategoryBreakdownRequest{
		Year:  2026,
		Month: 4,
		Type:  "expense",
	})
	require.NoError(t, err)
	require.Len(t, resp.Items, 1)
	assert.Equal(t, "", resp.Items[0].Icon)
	assert.Equal(t, "", resp.Items[0].IconKey)
}

func TestGetCategoryBreakdown_QueryError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	mock.ExpectQuery("SELECT t.category_id").
		WithArgs(testUserID, "expense", pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnError(errors.New("db error"))

	_, err = svc.GetCategoryBreakdown(authedCtx(), &pb.CategoryBreakdownRequest{
		Year:  2026,
		Month: 4,
		Type:  "expense",
	})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestGetCategoryBreakdown_ScanError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	// Return wrong number of columns to trigger scan error
	rows := pgxmock.NewRows([]string{"category_id", "name", "icon", "icon_key", "parent_id", "amount"}).
		RowError(0, errors.New("scan error")).
		AddRow("cat-001", "餐饮", (*string)(nil), (*string)(nil), (*string)(nil), int64(100))

	mock.ExpectQuery("SELECT t.category_id").
		WithArgs(testUserID, "expense", pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(rows)

	_, err = svc.GetCategoryBreakdown(authedCtx(), &pb.CategoryBreakdownRequest{
		Year:  2026,
		Month: 4,
		Type:  "expense",
	})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestGetCategoryBreakdown_FamilyMode_QueryError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	expectFamilyMembershipCheck(mock, testFamilyID, testUserID, true)

	mock.ExpectQuery("SELECT t.category_id").
		WithArgs(testFamilyID, "expense", pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnError(errors.New("db error"))

	_, err = svc.GetCategoryBreakdown(authedCtx(), &pb.CategoryBreakdownRequest{
		Year:     2026,
		Month:    4,
		Type:     "expense",
		FamilyId: testFamilyID,
	})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

// ═══════════════════════════════════════════════════════════════════════════════
// GetInvestmentTrend — family mode, various month counts, error paths
// ═══════════════════════════════════════════════════════════════════════════════

func TestGetInvestmentTrend_FamilyMode(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	expectFamilyMembershipCheck(mock, testFamilyID, testUserID, true)

	// 3 months: 2 historical + 1 current
	for i := 0; i < 2; i++ {
		mock.ExpectQuery("SELECT COALESCE").
			WithArgs(testFamilyID, pgxmock.AnyArg()).
			WillReturnRows(pgxmock.NewRows([]string{"cost", "value"}).
				AddRow(int64(10000), int64(12000)))
	}
	// Current month (uses market_quotes, no timestamp arg)
	mock.ExpectQuery("SELECT COALESCE").
		WithArgs(testFamilyID).
		WillReturnRows(pgxmock.NewRows([]string{"cost", "value"}).
			AddRow(int64(10000), int64(15000)))

	resp, err := svc.GetInvestmentTrend(authedCtx(), &pb.InvestmentTrendRequest{
		FamilyId: testFamilyID,
		Months:   3,
	})
	require.NoError(t, err)
	require.Len(t, resp.Points, 3)

	// Historical: returnRate = (12000-10000)/10000 = 0.2
	assert.Equal(t, int64(12000), resp.Points[0].TotalValue)
	assert.Equal(t, int64(10000), resp.Points[0].TotalCost)
	assert.InDelta(t, 0.2, resp.Points[0].ReturnRate, 0.01)

	// Current: returnRate = (15000-10000)/10000 = 0.5
	assert.Equal(t, int64(15000), resp.Points[2].TotalValue)
	assert.InDelta(t, 0.5, resp.Points[2].ReturnRate, 0.01)
}

func TestGetInvestmentTrend_FamilyNotMember(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	expectFamilyMembershipCheck(mock, testFamilyID, testUserID, false)

	_, err = svc.GetInvestmentTrend(authedCtx(), &pb.InvestmentTrendRequest{
		FamilyId: testFamilyID,
		Months:   3,
	})
	require.Error(t, err)
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

func TestGetInvestmentTrend_SingleMonth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	// Single month = current month
	mock.ExpectQuery("SELECT COALESCE").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"cost", "value"}).
			AddRow(int64(50000), int64(48000)))

	resp, err := svc.GetInvestmentTrend(authedCtx(), &pb.InvestmentTrendRequest{Months: 1})
	require.NoError(t, err)
	require.Len(t, resp.Points, 1)
	assert.Equal(t, int64(48000), resp.Points[0].TotalValue)
	// returnRate = (48000-50000)/50000 = -0.04
	assert.InDelta(t, -0.04, resp.Points[0].ReturnRate, 0.01)
}

func TestGetInvestmentTrend_ZeroCostBasis(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	// Current month, zero cost → returnRate should be 0
	mock.ExpectQuery("SELECT COALESCE").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"cost", "value"}).
			AddRow(int64(0), int64(0)))

	resp, err := svc.GetInvestmentTrend(authedCtx(), &pb.InvestmentTrendRequest{Months: 1})
	require.NoError(t, err)
	require.Len(t, resp.Points, 1)
	assert.Equal(t, 0.0, resp.Points[0].ReturnRate)
}

func TestGetInvestmentTrend_ClampMax60(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	// Request 100 months, should be clamped to 60
	for i := 0; i < 60; i++ {
		mock.ExpectQuery("SELECT COALESCE").
			WillReturnRows(pgxmock.NewRows([]string{"cost", "value"}).
				AddRow(int64(0), int64(0)))
	}

	resp, err := svc.GetInvestmentTrend(authedCtx(), &pb.InvestmentTrendRequest{Months: 100})
	require.NoError(t, err)
	assert.Len(t, resp.Points, 60)
}

func TestGetInvestmentTrend_PersonalWithData(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	// 2 months: 1 historical + 1 current
	// Historical
	mock.ExpectQuery("SELECT COALESCE").
		WithArgs(testUserID, pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"cost", "value"}).
			AddRow(int64(100000), int64(110000)))
	// Current
	mock.ExpectQuery("SELECT COALESCE").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"cost", "value"}).
			AddRow(int64(100000), int64(120000)))

	resp, err := svc.GetInvestmentTrend(authedCtx(), &pb.InvestmentTrendRequest{Months: 2})
	require.NoError(t, err)
	require.Len(t, resp.Points, 2)
	assert.Equal(t, int64(110000), resp.Points[0].TotalValue)
	assert.Equal(t, int64(120000), resp.Points[1].TotalValue)
}

// ═══════════════════════════════════════════════════════════════════════════════
// GetIncomeExpenseTrend — query error
// ═══════════════════════════════════════════════════════════════════════════════

func TestGetIncomeExpenseTrend_QueryError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	mock.ExpectQuery("SELECT DATE_TRUNC").
		WithArgs(testUserID, pgxmock.AnyArg()).
		WillReturnError(errors.New("query error"))

	_, err = svc.GetIncomeExpenseTrend(authedCtx(), &pb.TrendRequest{Period: "monthly", Count: 6})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestGetIncomeExpenseTrend_ScanError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	rows := pgxmock.NewRows([]string{"period", "income", "expense"}).
		RowError(0, errors.New("scan error")).
		AddRow(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC), int64(80000), int64(50000))

	mock.ExpectQuery("SELECT DATE_TRUNC").
		WithArgs(testUserID, pgxmock.AnyArg()).
		WillReturnRows(rows)

	_, err = svc.GetIncomeExpenseTrend(authedCtx(), &pb.TrendRequest{Period: "monthly", Count: 6})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestGetIncomeExpenseTrend_DefaultCount(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	mock.ExpectQuery("SELECT DATE_TRUNC").
		WithArgs(testUserID, pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"period", "income", "expense"}))

	resp, err := svc.GetIncomeExpenseTrend(authedCtx(), &pb.TrendRequest{
		// Count=0 → default 12
	})
	require.NoError(t, err)
	// Returns 12 zero-filled points
	assert.Len(t, resp.Points, 12)
}

func TestGetIncomeExpenseTrend_ClampMax60(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	mock.ExpectQuery("SELECT DATE_TRUNC").
		WithArgs(testUserID, pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"period", "income", "expense"}))

	resp, err := svc.GetIncomeExpenseTrend(authedCtx(), &pb.TrendRequest{
		Count: 200, // should be clamped to 60
	})
	require.NoError(t, err)
	// Clamped to 60 zero-filled points
	assert.Len(t, resp.Points, 60)
}

// ═══════════════════════════════════════════════════════════════════════════════
// resolveFamilyFilter — DB error path
// ═══════════════════════════════════════════════════════════════════════════════

func TestResolveFamilyFilter_DBError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(testFamilyID, testUserID).
		WillReturnError(errors.New("db error"))

	ctx := context.WithValue(context.Background(), middleware.UserIDKey, testUserID)
	_, err = svc.GetNetWorth(ctx, &pb.GetNetWorthRequest{FamilyId: testFamilyID})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

// ═══════════════════════════════════════════════════════════════════════════════
// GetNetWorth — error paths
// ═══════════════════════════════════════════════════════════════════════════════

func TestGetNetWorth_CashQueryError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(balance\\), 0\\)").
		WithArgs(testUserID).
		WillReturnError(errors.New("db error"))

	_, err = svc.GetNetWorth(authedCtx(), &pb.GetNetWorthRequest{})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestGetNetWorth_InvestmentQueryError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(balance\\), 0\\)").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(100)))
	mock.ExpectQuery("SELECT COALESCE\\(SUM").
		WithArgs(testUserID).
		WillReturnError(errors.New("db error"))

	_, err = svc.GetNetWorth(authedCtx(), &pb.GetNetWorthRequest{})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestGetNetWorth_FixedAssetQueryError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(balance\\), 0\\)").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(100)))
	mock.ExpectQuery("SELECT COALESCE\\(SUM").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(100)))
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(current_value\\)").
		WithArgs(testUserID).
		WillReturnError(errors.New("db error"))

	_, err = svc.GetNetWorth(authedCtx(), &pb.GetNetWorthRequest{})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestGetNetWorth_LoanQueryError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(balance\\), 0\\)").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(100)))
	mock.ExpectQuery("SELECT COALESCE\\(SUM").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(100)))
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(current_value\\)").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(100)))
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(remaining_principal\\)").
		WithArgs(testUserID).
		WillReturnError(errors.New("db error"))

	_, err = svc.GetNetWorth(authedCtx(), &pb.GetNetWorthRequest{})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

// ═══════════════════════════════════════════════════════════════════════════════
// GetExchangeRates — additional coverage
// ═══════════════════════════════════════════════════════════════════════════════

func TestGetExchangeRates_QueryError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	mock.ExpectQuery("SELECT currency_pair, rate, updated_at FROM exchange_rates").
		WillReturnError(errors.New("db error"))

	_, err = svc.GetExchangeRates(authedCtx(), &pb.GetExchangeRatesRequest{})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestGetExchangeRates_ShortPairSkipped(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	now := time.Now()

	mock.ExpectQuery("SELECT currency_pair, rate, updated_at FROM exchange_rates").
		WillReturnRows(pgxmock.NewRows([]string{"currency_pair", "rate", "updated_at"}).
			AddRow("AB", 1.0, now). // short pair, should be skipped
			AddRow("USD_CNY", 7.25, now))

	resp, err := svc.GetExchangeRates(authedCtx(), &pb.GetExchangeRatesRequest{})
	require.NoError(t, err)
	assert.Len(t, resp.Rates, 1) // only USD_CNY
}

func TestGetExchangeRates_NonBasePairSkipped(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	now := time.Now()

	mock.ExpectQuery("SELECT currency_pair, rate, updated_at FROM exchange_rates").
		WillReturnRows(pgxmock.NewRows([]string{"currency_pair", "rate", "updated_at"}).
			AddRow("EUR_USD", 1.1, now). // doesn't involve CNY
			AddRow("USD_CNY", 7.25, now))

	resp, err := svc.GetExchangeRates(authedCtx(), &pb.GetExchangeRatesRequest{BaseCurrency: "CNY"})
	require.NoError(t, err)
	assert.Len(t, resp.Rates, 1) // only USD
}

func TestGetExchangeRates_ZeroRate(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	now := time.Now()

	mock.ExpectQuery("SELECT currency_pair, rate, updated_at FROM exchange_rates").
		WillReturnRows(pgxmock.NewRows([]string{"currency_pair", "rate", "updated_at"}).
			AddRow("USD_CNY", 0.0, now)) // zero rate

	resp, err := svc.GetExchangeRates(authedCtx(), &pb.GetExchangeRatesRequest{})
	require.NoError(t, err)
	assert.Len(t, resp.Rates, 1)
	assert.Equal(t, 0.0, resp.Rates[0].Rate) // 1/0 = 0 (guarded)
}

func TestGetExchangeRates_UnknownCurrencyName(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	now := time.Now()

	mock.ExpectQuery("SELECT currency_pair, rate, updated_at FROM exchange_rates").
		WillReturnRows(pgxmock.NewRows([]string{"currency_pair", "rate", "updated_at"}).
			AddRow("XYZ_CNY", 1.5, now))

	resp, err := svc.GetExchangeRates(authedCtx(), &pb.GetExchangeRatesRequest{})
	require.NoError(t, err)
	require.Len(t, resp.Rates, 1)
	assert.Equal(t, "XYZ", resp.Rates[0].Currency)
	assert.Equal(t, "XYZ", resp.Rates[0].Name) // fallback to currency code
}

func TestGetExchangeRates_BaseCurrencyUSD(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	now := time.Now()

	// DB stores X_CNY pairs. BaseCurrency=USD → only USD_CNY matches (from=USD=baseCurrency)
	mock.ExpectQuery("SELECT currency_pair, rate, updated_at FROM exchange_rates").
		WillReturnRows(pgxmock.NewRows([]string{"currency_pair", "rate", "updated_at"}).
			AddRow("USD_CNY", 7.25, now).
			AddRow("EUR_CNY", 7.89, now))

	resp, err := svc.GetExchangeRates(authedCtx(), &pb.GetExchangeRatesRequest{BaseCurrency: "USD"})
	require.NoError(t, err)
	assert.Equal(t, "USD", resp.BaseCurrency)
	// USD_CNY: from=USD=baseCurrency → target=CNY, rate=7.25 (direct)
	require.Len(t, resp.Rates, 1)
	assert.Equal(t, "CNY", resp.Rates[0].Currency)
	assert.InDelta(t, 7.25, resp.Rates[0].Rate, 0.01)
}

// ═══════════════════════════════════════════════════════════════════════════════
// GetNetWorthTrend — query/scan errors
// ═══════════════════════════════════════════════════════════════════════════════

func TestGetNetWorthTrend_QueryError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	// GetNetWorthTrend → GetNetWorth (personal mode) succeeds
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(balance\\), 0\\)").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(100000)))
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

	// Then the trend query fails
	mock.ExpectQuery("SELECT DATE_TRUNC").
		WithArgs(testUserID, pgxmock.AnyArg()).
		WillReturnError(errors.New("query error"))

	_, err = svc.GetNetWorthTrend(authedCtx(), &pb.TrendRequest{Count: 3})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestGetNetWorthTrend_ScanError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	// GetNetWorth personal mode succeeds
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(balance\\), 0\\)").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(100000)))
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

	// Trend query returns but scan fails
	rows := pgxmock.NewRows([]string{"period", "income", "expense"}).
		RowError(0, errors.New("scan error")).
		AddRow(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC), int64(50000), int64(30000))

	mock.ExpectQuery("SELECT DATE_TRUNC").
		WithArgs(testUserID, pgxmock.AnyArg()).
		WillReturnRows(rows)

	_, err = svc.GetNetWorthTrend(authedCtx(), &pb.TrendRequest{Count: 3})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

// ═══════════════════════════════════════════════════════════════════════════════
// GetBudgetSummary — additional error paths
// ═══════════════════════════════════════════════════════════════════════════════

func TestGetBudgetSummary_DefaultYearMonth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	now := time.Now()

	// Year=0, Month=0 → defaults to current
	mock.ExpectQuery("SELECT id, total_amount FROM budgets").
		WithArgs(testUserID, now.Year(), int(now.Month())).
		WillReturnError(errors.New("no rows"))

	resp, err := svc.GetBudgetSummary(authedCtx(), &pb.BudgetSummaryRequest{})
	require.NoError(t, err)
	assert.Equal(t, int64(0), resp.TotalBudget)
}

func TestGetBudgetSummary_CatBudgetQueryError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	mock.ExpectQuery("SELECT id, total_amount FROM budgets").
		WithArgs(testUserID, 2026, 5).
		WillReturnRows(pgxmock.NewRows([]string{"id", "total_amount"}).
			AddRow("budget-001", int64(500000)))

	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(amount_cny\\), 0\\)").
		WithArgs(testUserID, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(300000)))

	mock.ExpectQuery("SELECT cb.category_id, c.name, cb.amount").
		WithArgs("budget-001").
		WillReturnError(errors.New("db error"))

	_, err = svc.GetBudgetSummary(authedCtx(), &pb.BudgetSummaryRequest{
		Year:  2026,
		Month: 5,
	})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestGetBudgetSummary_SubcategorySpent(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	mock.ExpectQuery("SELECT id, total_amount FROM budgets").
		WithArgs(testUserID, 2026, 5).
		WillReturnRows(pgxmock.NewRows([]string{"id", "total_amount"}).
			AddRow("budget-001", int64(500000)))

	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(amount_cny\\), 0\\)").
		WithArgs(testUserID, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(300000)))

	mock.ExpectQuery("SELECT cb.category_id, c.name, cb.amount").
		WithArgs("budget-001").
		WillReturnRows(pgxmock.NewRows([]string{"category_id", "name", "amount"}).
			AddRow("cat-food", "餐饮", int64(100000)))

	// Category spent includes subcategory aggregation
	parentID := "cat-food"
	mock.ExpectQuery("SELECT t.category_id").
		WithArgs(testUserID, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"category_id", "parent_id", "spent"}).
			AddRow("cat-food", (*string)(nil), int64(30000)).         // direct spend on parent
			AddRow("cat-food-fast", &parentID, int64(20000))) // subcategory spend

	resp, err := svc.GetBudgetSummary(authedCtx(), &pb.BudgetSummaryRequest{
		Year:  2026,
		Month: 5,
	})
	require.NoError(t, err)
	require.Len(t, resp.Categories, 1)
	// Spent = direct(30000) + subcategory(20000) = 50000
	assert.Equal(t, int64(50000), resp.Categories[0].SpentAmount)
}
