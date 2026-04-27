package investment

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/familyledger/server/pkg/middleware"
	pb "github.com/familyledger/server/proto/investment"
)

const testUserID = "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"

func authedCtx() context.Context {
	return context.WithValue(context.Background(), middleware.UserIDKey, testUserID)
}

func invCols() []string {
	return []string{"id", "user_id", "symbol", "name", "market_type", "quantity", "cost_basis",
		"created_at", "updated_at", "current_price", "family_id"}
}

func invRow(id uuid.UUID) []interface{} {
	now := time.Now()
	var price int64 = 15000
	return []interface{}{id, testUserID, "AAPL", "Apple Inc", "us_stock",
		float64(100), int64(1500000), now, now, &price, (*uuid.UUID)(nil)}
}

// ─── CreateInvestment ───────────────────────────────────────────────────────

func TestCreateInvestment_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	id := uuid.New()
	now := time.Now()

	mock.ExpectQuery("INSERT INTO investments").
		WithArgs(testUserID, "AAPL", "Apple Inc", "us_stock", (*uuid.UUID)(nil)).
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at", "updated_at"}).AddRow(id, now, now))

	resp, err := svc.CreateInvestment(authedCtx(), &pb.CreateInvestmentRequest{
		Symbol:     "AAPL",
		Name:       "Apple Inc",
		MarketType: pb.MarketType_MARKET_TYPE_US_STOCK,
	})
	require.NoError(t, err)
	assert.Equal(t, "AAPL", resp.Symbol)
	assert.Equal(t, "Apple Inc", resp.Name)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestCreateInvestment_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.CreateInvestment(context.Background(), &pb.CreateInvestmentRequest{})
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestCreateInvestment_MissingSymbol(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.CreateInvestment(authedCtx(), &pb.CreateInvestmentRequest{
		Name:       "x",
		MarketType: pb.MarketType_MARKET_TYPE_A_SHARE,
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestCreateInvestment_MissingName(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.CreateInvestment(authedCtx(), &pb.CreateInvestmentRequest{
		Symbol:     "AAPL",
		MarketType: pb.MarketType_MARKET_TYPE_US_STOCK,
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── GetInvestment ──────────────────────────────────────────────────────────

func TestGetInvestment_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	id := uuid.New()

	mock.ExpectQuery("SELECT .+ FROM investments").
		WithArgs(id.String()).
		WillReturnRows(pgxmock.NewRows(invCols()).AddRow(invRow(id)...))

	resp, err := svc.GetInvestment(authedCtx(), &pb.GetInvestmentRequest{InvestmentId: id.String()})
	require.NoError(t, err)
	assert.Equal(t, "AAPL", resp.Symbol)
}

func TestGetInvestment_NotFound(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	id := uuid.New()

	mock.ExpectQuery("SELECT .+ FROM investments").
		WithArgs(id.String()).
		WillReturnError(pgx.ErrNoRows)

	_, err = svc.GetInvestment(authedCtx(), &pb.GetInvestmentRequest{InvestmentId: id.String()})
	assert.Equal(t, codes.NotFound, status.Code(err))
}

func TestGetInvestment_EmptyID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.GetInvestment(authedCtx(), &pb.GetInvestmentRequest{InvestmentId: ""})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestGetInvestment_PermissionDenied(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	id := uuid.New()
	now := time.Now()
	var price int64 = 15000

	row := []interface{}{id, uuid.New().String(), "AAPL", "Apple", "us_stock",
		float64(100), int64(1500000), now, now, &price, (*uuid.UUID)(nil)}
	mock.ExpectQuery("SELECT .+ FROM investments").
		WithArgs(id.String()).
		WillReturnRows(pgxmock.NewRows(invCols()).AddRow(row...))

	_, err = svc.GetInvestment(authedCtx(), &pb.GetInvestmentRequest{InvestmentId: id.String()})
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

// ─── ListInvestments ────────────────────────────────────────────────────────

func TestListInvestments_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	listCols := []string{"id", "user_id", "symbol", "name", "market_type", "quantity", "cost_basis",
		"created_at", "updated_at", "current_price"}
	now := time.Now()
	var price int64 = 15000

	mock.ExpectQuery("SELECT .+ FROM investments").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows(listCols).
			AddRow(uuid.New(), testUserID, "AAPL", "Apple", "us_stock", float64(100), int64(1500000), now, now, &price).
			AddRow(uuid.New(), testUserID, "600519", "贵州茅台", "a_share", float64(10), int64(200000), now, now, (*int64)(nil)))

	resp, err := svc.ListInvestments(authedCtx(), &pb.ListInvestmentsRequest{})
	require.NoError(t, err)
	assert.Len(t, resp.Investments, 2)
}

func TestListInvestments_Empty(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	listCols := []string{"id", "user_id", "symbol", "name", "market_type", "quantity", "cost_basis",
		"created_at", "updated_at", "current_price"}
	mock.ExpectQuery("SELECT .+ FROM investments").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows(listCols))

	resp, err := svc.ListInvestments(authedCtx(), &pb.ListInvestmentsRequest{})
	require.NoError(t, err)
	assert.Empty(t, resp.Investments)
}

// ─── UpdateInvestment ───────────────────────────────────────────────────────

func TestUpdateInvestment_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	id := uuid.New()

	// ownership check
	mock.ExpectQuery("SELECT user_id, family_id FROM investments").
		WithArgs(id.String()).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(testUserID, (*string)(nil)))
	// update
	mock.ExpectExec("UPDATE investments SET name").
		WithArgs("New Name", id.String()).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	// reload
	mock.ExpectQuery("SELECT .+ FROM investments").
		WithArgs(id.String()).
		WillReturnRows(pgxmock.NewRows(invCols()).AddRow(invRow(id)...))

	resp, err := svc.UpdateInvestment(authedCtx(), &pb.UpdateInvestmentRequest{
		InvestmentId: id.String(),
		Name:         "New Name",
	})
	require.NoError(t, err)
	assert.NotNil(t, resp)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestUpdateInvestment_EmptyID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.UpdateInvestment(authedCtx(), &pb.UpdateInvestmentRequest{InvestmentId: "", Name: "x"})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestUpdateInvestment_EmptyName(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.UpdateInvestment(authedCtx(), &pb.UpdateInvestmentRequest{InvestmentId: uuid.New().String(), Name: ""})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── DeleteInvestment ───────────────────────────────────────────────────────

func TestDeleteInvestment_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	id := uuid.New()

	mock.ExpectQuery("SELECT user_id, family_id FROM investments").
		WithArgs(id.String()).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(testUserID, (*string)(nil)))
	mock.ExpectExec("UPDATE investments SET deleted_at").
		WithArgs(id.String()).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	_, err = svc.DeleteInvestment(authedCtx(), &pb.DeleteInvestmentRequest{InvestmentId: id.String()})
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestDeleteInvestment_NotFound(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	id := uuid.New()

	mock.ExpectQuery("SELECT user_id, family_id FROM investments").
		WithArgs(id.String()).
		WillReturnError(pgx.ErrNoRows)

	_, err = svc.DeleteInvestment(authedCtx(), &pb.DeleteInvestmentRequest{InvestmentId: id.String()})
	assert.Equal(t, codes.NotFound, status.Code(err))
}

func TestDeleteInvestment_EmptyID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.DeleteInvestment(authedCtx(), &pb.DeleteInvestmentRequest{InvestmentId: ""})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── RecordTrade ────────────────────────────────────────────────────────────

func TestRecordTrade_Buy(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	id := uuid.New()
	tradeID := uuid.New()

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT quantity, cost_basis FROM investments").
		WithArgs(id.String(), testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"quantity", "cost_basis"}).AddRow(float64(100), int64(1500000)))
	mock.ExpectExec("UPDATE investments SET quantity").
		WithArgs(float64(200), int64(3000500), id.String()).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectQuery("INSERT INTO investment_trades").
		WithArgs(id.String(), "buy", float64(100), int64(15000), int64(1500000), int64(500), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id"}).AddRow(tradeID))
	mock.ExpectCommit()

	resp, err := svc.RecordTrade(authedCtx(), &pb.RecordTradeRequest{
		InvestmentId: id.String(),
		TradeType:    pb.TradeType_TRADE_TYPE_BUY,
		Quantity:     100,
		Price:        15000,
		Fee:          500,
	})
	require.NoError(t, err)
	assert.Equal(t, pb.TradeType_TRADE_TYPE_BUY, resp.TradeType)
	assert.Equal(t, float64(100), resp.Quantity)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRecordTrade_SellExceedsHolding(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	id := uuid.New()

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT quantity, cost_basis FROM investments").
		WithArgs(id.String(), testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"quantity", "cost_basis"}).AddRow(float64(10), int64(150000)))
	mock.ExpectRollback()

	_, err = svc.RecordTrade(authedCtx(), &pb.RecordTradeRequest{
		InvestmentId: id.String(),
		TradeType:    pb.TradeType_TRADE_TYPE_SELL,
		Quantity:     100, // > 10
		Price:        15000,
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestRecordTrade_MissingParams(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.RecordTrade(authedCtx(), &pb.RecordTradeRequest{})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── ListTrades ─────────────────────────────────────────────────────────────

func TestListTrades_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	invID := uuid.New()
	now := time.Now()

	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(invID.String(), testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))
	mock.ExpectQuery("SELECT .+ FROM investment_trades").
		WithArgs(invID.String()).
		WillReturnRows(pgxmock.NewRows([]string{"id", "investment_id", "trade_type", "quantity", "price", "total_amount", "fee", "trade_date"}).
			AddRow(uuid.New(), invID.String(), "buy", float64(100), int64(15000), int64(1500000), int64(500), now))

	resp, err := svc.ListTrades(authedCtx(), &pb.ListTradesRequest{InvestmentId: invID.String()})
	require.NoError(t, err)
	assert.Len(t, resp.Trades, 1)
}

func TestListTrades_EmptyID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.ListTrades(authedCtx(), &pb.ListTradesRequest{InvestmentId: ""})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── Validation ─────────────────────────────────────────────────────────────

func TestValidateTradeRequest(t *testing.T) {
	tests := []struct {
		name    string
		req     *pb.RecordTradeRequest
		wantErr bool
	}{
		{
			name: "valid buy",
			req: &pb.RecordTradeRequest{
				InvestmentId: uuid.New().String(),
				TradeType:    pb.TradeType_TRADE_TYPE_BUY,
				Quantity:     100,
				Price:        15000,
			},
			wantErr: false,
		},
		{name: "empty id", req: &pb.RecordTradeRequest{InvestmentId: ""}, wantErr: true},
		{
			name: "negative qty",
			req: &pb.RecordTradeRequest{
				InvestmentId: "x", TradeType: pb.TradeType_TRADE_TYPE_BUY, Quantity: -1, Price: 100,
			},
			wantErr: true,
		},
		{
			name: "negative fee",
			req: &pb.RecordTradeRequest{
				InvestmentId: "x", TradeType: pb.TradeType_TRADE_TYPE_BUY, Quantity: 1, Price: 100, Fee: -1,
			},
			wantErr: true,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validateTradeRequest(tt.req)
			if tt.wantErr {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
			}
		})
	}
}

// ─── Type conversions ───────────────────────────────────────────────────────

func TestMarketTypeConversions(t *testing.T) {
	types := []struct {
		str string
		val pb.MarketType
	}{
		{"a_share", pb.MarketType_MARKET_TYPE_A_SHARE},
		{"hk_stock", pb.MarketType_MARKET_TYPE_HK_STOCK},
		{"us_stock", pb.MarketType_MARKET_TYPE_US_STOCK},
		{"crypto", pb.MarketType_MARKET_TYPE_CRYPTO},
		{"fund", pb.MarketType_MARKET_TYPE_FUND},
	}
	for _, tt := range types {
		assert.Equal(t, tt.str, marketTypeToString(tt.val))
		assert.Equal(t, tt.val, stringToMarketType(tt.str))
	}
}

func TestTradeTypeConversions(t *testing.T) {
	assert.Equal(t, "buy", tradeTypeToString(pb.TradeType_TRADE_TYPE_BUY))
	assert.Equal(t, "sell", tradeTypeToString(pb.TradeType_TRADE_TYPE_SELL))
	assert.Equal(t, pb.TradeType_TRADE_TYPE_BUY, stringToTradeType("buy"))
	assert.Equal(t, pb.TradeType_TRADE_TYPE_SELL, stringToTradeType("sell"))
}

func TestIsDuplicateError(t *testing.T) {
	assert.True(t, isDuplicateError(status.Error(codes.Internal, "duplicate key value")))
	assert.True(t, isDuplicateError(status.Error(codes.Internal, "unique constraint")))
	assert.False(t, isDuplicateError(status.Error(codes.Internal, "something else")))
	assert.False(t, isDuplicateError(nil))
}

// ─── GetPortfolioSummary ────────────────────────────────────────────────────

func portfolioCols() []string {
	return []string{"id", "symbol", "name", "market_type", "quantity", "cost_basis", "created_at", "current_price"}
}

func TestGetPortfolioSummary_PersonalMode(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	now := time.Now()
	id1 := uuid.New()
	var price int64 = 15000

	mock.ExpectQuery(`SELECT i.id, i.symbol, i.name, i.market_type, i.quantity, i.cost_basis`).
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows(portfolioCols()).
			AddRow(id1, "AAPL", "Apple Inc", "us_stock", float64(10), int64(100000), now, &price))

	resp, err := svc.GetPortfolioSummary(authedCtx(), &pb.GetPortfolioSummaryRequest{})
	require.NoError(t, err)
	require.NotNil(t, resp)
	assert.Equal(t, int64(150000), resp.TotalValue) // 10 * 15000
	assert.Equal(t, int64(100000), resp.TotalCost)
	assert.Equal(t, int64(50000), resp.TotalProfit)
	assert.Len(t, resp.Holdings, 1)
	assert.Equal(t, "AAPL", resp.Holdings[0].Symbol)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGetPortfolioSummary_FamilyMode(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	now := time.Now()
	familyID := uuid.New()
	id1 := uuid.New()
	id2 := uuid.New()
	var price1 int64 = 20000
	var price2 int64 = 5000

	// Verify membership
	mock.ExpectQuery(`SELECT EXISTS`).WithArgs(familyID, testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))

	// Query investments for family members
	mock.ExpectQuery(`SELECT i.id, i.symbol, i.name, i.market_type, i.quantity, i.cost_basis`).
		WithArgs(familyID).
		WillReturnRows(pgxmock.NewRows(portfolioCols()).
			AddRow(id1, "AAPL", "Apple Inc", "us_stock", float64(10), int64(100000), now, &price1).
			AddRow(id2, "GOOGL", "Google", "us_stock", float64(5), int64(50000), now, &price2))

	resp, err := svc.GetPortfolioSummary(authedCtx(), &pb.GetPortfolioSummaryRequest{FamilyId: familyID.String()})
	require.NoError(t, err)
	require.NotNil(t, resp)
	assert.Equal(t, int64(225000), resp.TotalValue) // 10*20000 + 5*5000
	assert.Equal(t, int64(150000), resp.TotalCost)  // 100000 + 50000
	assert.Len(t, resp.Holdings, 2)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGetPortfolioSummary_FamilyMode_NotMember(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	familyID := uuid.New()

	// Verify membership — not a member
	mock.ExpectQuery(`SELECT EXISTS`).WithArgs(familyID, testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(false))

	_, err = svc.GetPortfolioSummary(authedCtx(), &pb.GetPortfolioSummaryRequest{FamilyId: familyID.String()})
	require.Error(t, err)
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGetPortfolioSummary_Empty(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	mock.ExpectQuery(`SELECT i.id, i.symbol, i.name, i.market_type, i.quantity, i.cost_basis`).
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows(portfolioCols()))

	resp, err := svc.GetPortfolioSummary(authedCtx(), &pb.GetPortfolioSummaryRequest{})
	require.NoError(t, err)
	require.NotNil(t, resp)
	assert.Equal(t, int64(0), resp.TotalValue)
	assert.Len(t, resp.Holdings, 0)
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ─── calculateXIRR ────────────────────────────────────────────────────────────────

func TestCalculateXIRR_SimpleBuyAndSell(t *testing.T) {
	// Buy 100 shares at $10 on day 0, sell at $11 on day 365 => 10% annual
	base := time.Date(2025, 1, 1, 0, 0, 0, 0, time.UTC)
	cashFlows := []*pb.CashFlow{
		{Date: timestamppb.New(base), Amount: -100000},                               // buy: $1000
		{Date: timestamppb.New(base.AddDate(1, 0, 0)), Amount: 110000}, // sell: $1100
	}

	irr := calculateXIRR(cashFlows)
	// Should be approximately 0.10 (10%)
	assert.InDelta(t, 0.10, irr, 0.001)
}

func TestCalculateXIRR_EmptyCashFlows(t *testing.T) {
	irr := calculateXIRR([]*pb.CashFlow{})
	assert.Equal(t, 0.0, irr)
}

func TestCalculateXIRR_SingleCashFlow(t *testing.T) {
	irr := calculateXIRR([]*pb.CashFlow{
		{Date: timestamppb.Now(), Amount: -10000},
	})
	assert.Equal(t, 0.0, irr)
}

func TestCalculateXIRR_HighReturn(t *testing.T) {
	// Buy $1000 on Jan 1, worth $2000 on Jul 1 (~182 days) => ~100% annualized
	base := time.Date(2025, 1, 1, 0, 0, 0, 0, time.UTC)
	cashFlows := []*pb.CashFlow{
		{Date: timestamppb.New(base), Amount: -100000},
		{Date: timestamppb.New(base.AddDate(0, 6, 0)), Amount: 200000},
	}

	irr := calculateXIRR(cashFlows)
	// Should be > 100% annualized (approximately 300% for doubling in 6 months)
	assert.Greater(t, irr, 1.0)
}

func TestGetInvestmentIRR_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.GetInvestmentIRR(context.Background(), &pb.GetIRRRequest{InvestmentId: "test"})
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}
