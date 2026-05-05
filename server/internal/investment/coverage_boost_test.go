package investment

import (
	"context"
	"errors"
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

	pb "github.com/familyledger/server/proto/investment"
)

// ═══════════════════════════════════════════════════════════════════════════
// CreateInvestment — additional branches
// ═══════════════════════════════════════════════════════════════════════════

func TestCB_CreateInvestment_MissingMarketType(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	_, err := svc.CreateInvestment(authedCtx(), &pb.CreateInvestmentRequest{
		Symbol: "AAPL", Name: "Apple Inc",
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestCB_CreateInvestment_InvalidFamilyID(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	_, err := svc.CreateInvestment(authedCtx(), &pb.CreateInvestmentRequest{
		Symbol: "AAPL", Name: "Apple", MarketType: pb.MarketType_MARKET_TYPE_US_STOCK,
		FamilyId: "not-a-uuid",
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestCB_CreateInvestment_FamilyPermDenied(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	fid := uuid.New()
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnError(pgx.ErrNoRows)
	_, err := svc.CreateInvestment(authedCtx(), &pb.CreateInvestmentRequest{
		Symbol: "AAPL", Name: "Apple", MarketType: pb.MarketType_MARKET_TYPE_US_STOCK,
		FamilyId: fid.String(),
	})
	assert.Error(t, err)
}

func TestCB_CreateInvestment_InsertError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectQuery("INSERT INTO investments").
		WithArgs(testUserID, "AAPL", "Apple", "us_stock", (*uuid.UUID)(nil)).
		WillReturnError(errors.New("db error"))
	_, err := svc.CreateInvestment(authedCtx(), &pb.CreateInvestmentRequest{
		Symbol: "AAPL", Name: "Apple", MarketType: pb.MarketType_MARKET_TYPE_US_STOCK,
	})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_CreateInvestment_DuplicateError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectQuery("INSERT INTO investments").
		WithArgs(testUserID, "AAPL", "Apple", "us_stock", (*uuid.UUID)(nil)).
		WillReturnError(errors.New("duplicate key value violates unique constraint"))
	_, err := svc.CreateInvestment(authedCtx(), &pb.CreateInvestmentRequest{
		Symbol: "AAPL", Name: "Apple", MarketType: pb.MarketType_MARKET_TYPE_US_STOCK,
	})
	assert.Equal(t, codes.AlreadyExists, status.Code(err))
}

func TestCB_CreateInvestment_WithFamily(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	fid := uuid.New()
	id := uuid.New()
	now := time.Now()

	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).AddRow("owner", []byte(`{}`)))
	mock.ExpectQuery("INSERT INTO investments").
		WithArgs(testUserID, "AAPL", "Apple", "us_stock", &fid).
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at", "updated_at"}).AddRow(id, now, now))

	resp, err := svc.CreateInvestment(authedCtx(), &pb.CreateInvestmentRequest{
		Symbol: "AAPL", Name: "Apple", MarketType: pb.MarketType_MARKET_TYPE_US_STOCK,
		FamilyId: fid.String(),
	})
	require.NoError(t, err)
	assert.Equal(t, "AAPL", resp.Symbol)
}

// ═══════════════════════════════════════════════════════════════════════════
// ListInvestments — additional branches
// ═══════════════════════════════════════════════════════════════════════════

func TestCB_ListInvestments_NoAuth(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	_, err := svc.ListInvestments(context.Background(), &pb.ListInvestmentsRequest{})
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestCB_ListInvestments_FamilyMode(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	fid := uuid.New()
	invID := uuid.New()
	now := time.Now()

	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(fid.String(), testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))

	listCols := []string{"id", "user_id", "symbol", "name", "market_type", "quantity", "cost_basis",
		"created_at", "updated_at", "current_price"}
	var price int64 = 15000
	mock.ExpectQuery("SELECT i.id").
		WithArgs(fid.String()).
		WillReturnRows(pgxmock.NewRows(listCols).AddRow(
			invID, testUserID, "AAPL", "Apple", "us_stock", 100.0, int64(1500000),
			now, now, &price,
		))
	resp, err := svc.ListInvestments(authedCtx(), &pb.ListInvestmentsRequest{FamilyId: fid.String()})
	require.NoError(t, err)
	assert.Len(t, resp.Investments, 1)
}

func TestCB_ListInvestments_FamilyNotMember(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	fid := uuid.New()
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(fid.String(), testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(false))
	_, err := svc.ListInvestments(authedCtx(), &pb.ListInvestmentsRequest{FamilyId: fid.String()})
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

func TestCB_ListInvestments_FamilyMemberQueryErr(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	fid := uuid.New()
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(fid.String(), testUserID).
		WillReturnError(errors.New("db fail"))
	_, err := svc.ListInvestments(authedCtx(), &pb.ListInvestmentsRequest{FamilyId: fid.String()})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_ListInvestments_ByMarketType(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	invID := uuid.New()
	now := time.Now()

	listCols := []string{"id", "user_id", "symbol", "name", "market_type", "quantity", "cost_basis",
		"created_at", "updated_at", "current_price"}
	var price int64 = 15000
	mock.ExpectQuery("SELECT i.id").
		WithArgs(testUserID, "us_stock").
		WillReturnRows(pgxmock.NewRows(listCols).AddRow(
			invID, testUserID, "AAPL", "Apple", "us_stock", 100.0, int64(1500000),
			now, now, &price,
		))
	resp, err := svc.ListInvestments(authedCtx(), &pb.ListInvestmentsRequest{
		MarketType: pb.MarketType_MARKET_TYPE_US_STOCK,
	})
	require.NoError(t, err)
	assert.Len(t, resp.Investments, 1)
}

func TestCB_ListInvestments_QueryError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectQuery("SELECT i.id").
		WithArgs(testUserID).
		WillReturnError(errors.New("query fail"))
	_, err := svc.ListInvestments(authedCtx(), &pb.ListInvestmentsRequest{})
	assert.Equal(t, codes.Internal, status.Code(err))
}

// ═══════════════════════════════════════════════════════════════════════════
// UpdateInvestment — additional branches
// ═══════════════════════════════════════════════════════════════════════════

func TestCB_UpdateInvestment_NoAuth(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	_, err := svc.UpdateInvestment(context.Background(), &pb.UpdateInvestmentRequest{InvestmentId: "x"})
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestCB_UpdateInvestment_NotFound(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectQuery("SELECT user_id, family_id FROM investments").
		WithArgs("x").WillReturnError(pgx.ErrNoRows)
	_, err := svc.UpdateInvestment(authedCtx(), &pb.UpdateInvestmentRequest{
		InvestmentId: "x", Name: "new",
	})
	assert.Equal(t, codes.NotFound, status.Code(err))
}

func TestCB_UpdateInvestment_QueryError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectQuery("SELECT user_id, family_id FROM investments").
		WithArgs("x").WillReturnError(errors.New("db err"))
	_, err := svc.UpdateInvestment(authedCtx(), &pb.UpdateInvestmentRequest{
		InvestmentId: "x", Name: "new",
	})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_UpdateInvestment_NotOwner_NoFamily(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectQuery("SELECT user_id, family_id FROM investments").
		WithArgs("x").
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow("other", (*string)(nil)))
	_, err := svc.UpdateInvestment(authedCtx(), &pb.UpdateInvestmentRequest{
		InvestmentId: "x", Name: "new",
	})
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

func TestCB_UpdateInvestment_NotOwner_FamilyPerm(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	fid := uuid.New().String()
	mock.ExpectQuery("SELECT user_id, family_id FROM investments").
		WithArgs("x").
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow("other", &fid))
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).AddRow("owner", []byte(`{}`)))
	id := uuid.New()
	mock.ExpectExec("UPDATE investments SET name").
		WithArgs("new", "x").
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	// loadInvestmentWithMarket
	now := time.Now()
	famUID := uuid.MustParse(fid)
	var price int64 = 15000
	mock.ExpectQuery("SELECT i.id, i.user_id").
		WithArgs("x").
		WillReturnRows(pgxmock.NewRows(invCols()).AddRow(
			id, "other", "AAPL", "new", "us_stock", 100.0, int64(1500000),
			now, now, &price, &famUID,
		))
	// loadInvestmentWithMarket permission check
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).AddRow("owner", []byte(`{}`)))

	resp, err := svc.UpdateInvestment(authedCtx(), &pb.UpdateInvestmentRequest{
		InvestmentId: "x", Name: "new",
	})
	require.NoError(t, err)
	assert.Equal(t, "new", resp.Name)
}

func TestCB_UpdateInvestment_ExecError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectQuery("SELECT user_id, family_id FROM investments").
		WithArgs("x").
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(testUserID, (*string)(nil)))
	mock.ExpectExec("UPDATE investments SET name").
		WithArgs("new", "x").
		WillReturnError(errors.New("exec fail"))
	_, err := svc.UpdateInvestment(authedCtx(), &pb.UpdateInvestmentRequest{
		InvestmentId: "x", Name: "new",
	})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_UpdateInvestment_ZeroRows(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectQuery("SELECT user_id, family_id FROM investments").
		WithArgs("x").
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(testUserID, (*string)(nil)))
	mock.ExpectExec("UPDATE investments SET name").
		WithArgs("new", "x").
		WillReturnResult(pgxmock.NewResult("UPDATE", 0))
	_, err := svc.UpdateInvestment(authedCtx(), &pb.UpdateInvestmentRequest{
		InvestmentId: "x", Name: "new",
	})
	assert.Equal(t, codes.NotFound, status.Code(err))
}

// ═══════════════════════════════════════════════════════════════════════════
// DeleteInvestment — additional branches
// ═══════════════════════════════════════════════════════════════════════════

func TestCB_DeleteInvestment_NoAuth(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	_, err := svc.DeleteInvestment(context.Background(), &pb.DeleteInvestmentRequest{InvestmentId: "x"})
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestCB_DeleteInvestment_QueryError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectQuery("SELECT user_id, family_id FROM investments").
		WithArgs("x").WillReturnError(errors.New("db err"))
	_, err := svc.DeleteInvestment(authedCtx(), &pb.DeleteInvestmentRequest{InvestmentId: "x"})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_DeleteInvestment_NotOwner_NoFamily(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectQuery("SELECT user_id, family_id FROM investments").
		WithArgs("x").
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow("other", (*string)(nil)))
	_, err := svc.DeleteInvestment(authedCtx(), &pb.DeleteInvestmentRequest{InvestmentId: "x"})
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

func TestCB_DeleteInvestment_NotOwner_FamilyPerm(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	fid := uuid.New().String()
	mock.ExpectQuery("SELECT user_id, family_id FROM investments").
		WithArgs("x").
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow("other", &fid))
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).AddRow("owner", []byte(`{}`)))
	mock.ExpectExec("UPDATE investments SET deleted_at").
		WithArgs("x").
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	resp, err := svc.DeleteInvestment(authedCtx(), &pb.DeleteInvestmentRequest{InvestmentId: "x"})
	require.NoError(t, err)
	assert.NotNil(t, resp)
}

func TestCB_DeleteInvestment_ExecError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectQuery("SELECT user_id, family_id FROM investments").
		WithArgs("x").
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(testUserID, (*string)(nil)))
	mock.ExpectExec("UPDATE investments SET deleted_at").
		WithArgs("x").
		WillReturnError(errors.New("exec fail"))
	_, err := svc.DeleteInvestment(authedCtx(), &pb.DeleteInvestmentRequest{InvestmentId: "x"})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_DeleteInvestment_ZeroRows(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectQuery("SELECT user_id, family_id FROM investments").
		WithArgs("x").
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(testUserID, (*string)(nil)))
	mock.ExpectExec("UPDATE investments SET deleted_at").
		WithArgs("x").
		WillReturnResult(pgxmock.NewResult("UPDATE", 0))
	_, err := svc.DeleteInvestment(authedCtx(), &pb.DeleteInvestmentRequest{InvestmentId: "x"})
	assert.Equal(t, codes.NotFound, status.Code(err))
}

// ═══════════════════════════════════════════════════════════════════════════
// RecordTrade — additional branches
// ═══════════════════════════════════════════════════════════════════════════

func TestCB_RecordTrade_NoAuth(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	_, err := svc.RecordTrade(context.Background(), &pb.RecordTradeRequest{InvestmentId: "x"})
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestCB_RecordTrade_BeginFail(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectBegin().WillReturnError(errors.New("conn fail"))
	_, err := svc.RecordTrade(authedCtx(), &pb.RecordTradeRequest{
		InvestmentId: "x", TradeType: pb.TradeType_TRADE_TYPE_BUY, Quantity: 10, Price: 100,
	})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_RecordTrade_NotFound(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectBegin()
	mock.ExpectQuery("SELECT quantity, cost_basis FROM investments").
		WithArgs("x", testUserID).WillReturnError(pgx.ErrNoRows)
	mock.ExpectRollback()
	_, err := svc.RecordTrade(authedCtx(), &pb.RecordTradeRequest{
		InvestmentId: "x", TradeType: pb.TradeType_TRADE_TYPE_BUY, Quantity: 10, Price: 100,
	})
	assert.Equal(t, codes.NotFound, status.Code(err))
}

func TestCB_RecordTrade_QueryError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectBegin()
	mock.ExpectQuery("SELECT quantity, cost_basis FROM investments").
		WithArgs("x", testUserID).WillReturnError(errors.New("db err"))
	mock.ExpectRollback()
	_, err := svc.RecordTrade(authedCtx(), &pb.RecordTradeRequest{
		InvestmentId: "x", TradeType: pb.TradeType_TRADE_TYPE_BUY, Quantity: 10, Price: 100,
	})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_RecordTrade_UpdateError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectBegin()
	mock.ExpectQuery("SELECT quantity, cost_basis FROM investments").
		WithArgs("x", testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"quantity", "cost_basis"}).AddRow(100.0, int64(1500000)))
	mock.ExpectExec("UPDATE investments SET quantity").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), "x").
		WillReturnError(errors.New("update fail"))
	mock.ExpectRollback()
	_, err := svc.RecordTrade(authedCtx(), &pb.RecordTradeRequest{
		InvestmentId: "x", TradeType: pb.TradeType_TRADE_TYPE_BUY, Quantity: 10, Price: 100,
	})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_RecordTrade_InsertTradeError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectBegin()
	mock.ExpectQuery("SELECT quantity, cost_basis FROM investments").
		WithArgs("x", testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"quantity", "cost_basis"}).AddRow(100.0, int64(1500000)))
	mock.ExpectExec("UPDATE investments SET quantity").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), "x").
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectQuery("INSERT INTO investment_trades").
		WithArgs("x", "buy", 10.0, int64(100), pgxmock.AnyArg(), int64(0), pgxmock.AnyArg()).
		WillReturnError(errors.New("insert fail"))
	mock.ExpectRollback()
	_, err := svc.RecordTrade(authedCtx(), &pb.RecordTradeRequest{
		InvestmentId: "x", TradeType: pb.TradeType_TRADE_TYPE_BUY, Quantity: 10, Price: 100,
	})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_RecordTrade_CommitError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	tradeID := uuid.New()
	mock.ExpectBegin()
	mock.ExpectQuery("SELECT quantity, cost_basis FROM investments").
		WithArgs("x", testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"quantity", "cost_basis"}).AddRow(100.0, int64(1500000)))
	mock.ExpectExec("UPDATE investments SET quantity").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), "x").
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectQuery("INSERT INTO investment_trades").
		WithArgs("x", "buy", 10.0, int64(100), pgxmock.AnyArg(), int64(0), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id"}).AddRow(tradeID))
	mock.ExpectCommit().WillReturnError(errors.New("commit fail"))
	mock.ExpectRollback()
	_, err := svc.RecordTrade(authedCtx(), &pb.RecordTradeRequest{
		InvestmentId: "x", TradeType: pb.TradeType_TRADE_TYPE_BUY, Quantity: 10, Price: 100,
	})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_RecordTrade_SellSuccess(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	tradeID := uuid.New()
	mock.ExpectBegin()
	mock.ExpectQuery("SELECT quantity, cost_basis FROM investments").
		WithArgs("x", testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"quantity", "cost_basis"}).AddRow(100.0, int64(1500000)))
	mock.ExpectExec("UPDATE investments SET quantity").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), "x").
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectQuery("INSERT INTO investment_trades").
		WithArgs("x", "sell", 50.0, int64(200), pgxmock.AnyArg(), int64(10), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id"}).AddRow(tradeID))
	mock.ExpectCommit()
	resp, err := svc.RecordTrade(authedCtx(), &pb.RecordTradeRequest{
		InvestmentId: "x", TradeType: pb.TradeType_TRADE_TYPE_SELL,
		Quantity: 50, Price: 200, Fee: 10,
	})
	require.NoError(t, err)
	assert.Equal(t, pb.TradeType_TRADE_TYPE_SELL, resp.TradeType)
}

func TestCB_RecordTrade_SellAllToZero(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	tradeID := uuid.New()
	mock.ExpectBegin()
	mock.ExpectQuery("SELECT quantity, cost_basis FROM investments").
		WithArgs("x", testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"quantity", "cost_basis"}).AddRow(100.0, int64(1500000)))
	mock.ExpectExec("UPDATE investments SET quantity").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), "x").
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectQuery("INSERT INTO investment_trades").
		WithArgs("x", "sell", 100.0, int64(200), pgxmock.AnyArg(), int64(0), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id"}).AddRow(tradeID))
	mock.ExpectCommit()
	resp, err := svc.RecordTrade(authedCtx(), &pb.RecordTradeRequest{
		InvestmentId: "x", TradeType: pb.TradeType_TRADE_TYPE_SELL,
		Quantity: 100, Price: 200,
	})
	require.NoError(t, err)
	assert.Equal(t, pb.TradeType_TRADE_TYPE_SELL, resp.TradeType)
}

func TestCB_RecordTrade_WithTradeDate(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	tradeID := uuid.New()
	tradeDate := timestamppb.New(time.Date(2025, 1, 15, 0, 0, 0, 0, time.UTC))
	mock.ExpectBegin()
	mock.ExpectQuery("SELECT quantity, cost_basis FROM investments").
		WithArgs("x", testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"quantity", "cost_basis"}).AddRow(100.0, int64(1500000)))
	mock.ExpectExec("UPDATE investments SET quantity").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), "x").
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectQuery("INSERT INTO investment_trades").
		WithArgs("x", "buy", 10.0, int64(100), pgxmock.AnyArg(), int64(0), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id"}).AddRow(tradeID))
	mock.ExpectCommit()
	resp, err := svc.RecordTrade(authedCtx(), &pb.RecordTradeRequest{
		InvestmentId: "x", TradeType: pb.TradeType_TRADE_TYPE_BUY,
		Quantity: 10, Price: 100, TradeDate: tradeDate,
	})
	require.NoError(t, err)
	assert.NotNil(t, resp)
}

func TestCB_RecordTrade_NegativeFee(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	_, err := svc.RecordTrade(authedCtx(), &pb.RecordTradeRequest{
		InvestmentId: "x", TradeType: pb.TradeType_TRADE_TYPE_BUY,
		Quantity: 10, Price: 100, Fee: -1,
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ═══════════════════════════════════════════════════════════════════════════
// GetInvestmentIRR — additional branches
// ═══════════════════════════════════════════════════════════════════════════

func TestCB_GetInvestmentIRR_SingleInvestment_NotFound(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectQuery("SELECT i.user_id, i.quantity").
		WithArgs("inv-1").
		WillReturnError(pgx.ErrNoRows)
	_, err := svc.GetInvestmentIRR(authedCtx(), &pb.GetIRRRequest{InvestmentId: "inv-1"})
	assert.Equal(t, codes.NotFound, status.Code(err))
}

func TestCB_GetInvestmentIRR_SingleInvestment_QueryError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectQuery("SELECT i.user_id, i.quantity").
		WithArgs("inv-1").
		WillReturnError(errors.New("db err"))
	_, err := svc.GetInvestmentIRR(authedCtx(), &pb.GetIRRRequest{InvestmentId: "inv-1"})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_GetInvestmentIRR_SingleInvestment_NotOwner(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	var price int64 = 15000
	mock.ExpectQuery("SELECT i.user_id, i.quantity").
		WithArgs("inv-1").
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "quantity", "current_price"}).
			AddRow("other-user", 100.0, &price))
	_, err := svc.GetInvestmentIRR(authedCtx(), &pb.GetIRRRequest{InvestmentId: "inv-1"})
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

func TestCB_GetInvestmentIRR_SingleInvestment_TradesQueryError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	var price int64 = 15000
	mock.ExpectQuery("SELECT i.user_id, i.quantity").
		WithArgs("inv-1").
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "quantity", "current_price"}).
			AddRow(testUserID, 100.0, &price))
	mock.ExpectQuery("SELECT trade_type, total_amount, fee, trade_date").
		WithArgs("inv-1").
		WillReturnError(errors.New("trades query fail"))
	_, err := svc.GetInvestmentIRR(authedCtx(), &pb.GetIRRRequest{InvestmentId: "inv-1"})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_GetInvestmentIRR_SingleInvestment_Success(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	var price int64 = 15000
	mock.ExpectQuery("SELECT i.user_id, i.quantity").
		WithArgs("inv-1").
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "quantity", "current_price"}).
			AddRow(testUserID, 100.0, &price))
	tradeCols := []string{"trade_type", "total_amount", "fee", "trade_date"}
	mock.ExpectQuery("SELECT trade_type, total_amount, fee, trade_date").
		WithArgs("inv-1").
		WillReturnRows(pgxmock.NewRows(tradeCols).
			AddRow("buy", int64(1000000), int64(100), time.Now().AddDate(-1, 0, 0)))
	resp, err := svc.GetInvestmentIRR(authedCtx(), &pb.GetIRRRequest{InvestmentId: "inv-1"})
	require.NoError(t, err)
	assert.NotZero(t, resp.AnnualizedIrr)
	assert.True(t, len(resp.CashFlows) > 0)
}

func TestCB_GetInvestmentIRR_SingleInvestment_NoCashFlows(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	var price int64 = 15000
	mock.ExpectQuery("SELECT i.user_id, i.quantity").
		WithArgs("inv-1").
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "quantity", "current_price"}).
			AddRow(testUserID, 100.0, &price))
	tradeCols := []string{"trade_type", "total_amount", "fee", "trade_date"}
	mock.ExpectQuery("SELECT trade_type, total_amount, fee, trade_date").
		WithArgs("inv-1").
		WillReturnRows(pgxmock.NewRows(tradeCols)) // empty
	resp, err := svc.GetInvestmentIRR(authedCtx(), &pb.GetIRRRequest{InvestmentId: "inv-1"})
	require.NoError(t, err)
	assert.Equal(t, float64(0), resp.AnnualizedIrr)
}

func TestCB_GetInvestmentIRR_Portfolio_Personal(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	tradeCols := []string{"trade_type", "total_amount", "fee", "trade_date"}
	mock.ExpectQuery("SELECT it.trade_type, it.total_amount, it.fee, it.trade_date").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows(tradeCols).
			AddRow("buy", int64(1000000), int64(100), time.Now().AddDate(-1, 0, 0)))
	// Portfolio value query
	mock.ExpectQuery("SELECT COALESCE").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"sum"}).AddRow(int64(1200000)))
	resp, err := svc.GetInvestmentIRR(authedCtx(), &pb.GetIRRRequest{})
	require.NoError(t, err)
	assert.True(t, len(resp.CashFlows) > 0)
}

func TestCB_GetInvestmentIRR_Portfolio_Family(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	fid := uuid.New().String()
	tradeCols := []string{"trade_type", "total_amount", "fee", "trade_date"}
	mock.ExpectQuery("SELECT it.trade_type, it.total_amount, it.fee, it.trade_date").
		WithArgs(fid).
		WillReturnRows(pgxmock.NewRows(tradeCols).
			AddRow("buy", int64(500000), int64(50), time.Now().AddDate(-1, 0, 0)))
	mock.ExpectQuery("SELECT COALESCE").
		WithArgs(fid).
		WillReturnRows(pgxmock.NewRows([]string{"sum"}).AddRow(int64(600000)))
	resp, err := svc.GetInvestmentIRR(authedCtx(), &pb.GetIRRRequest{FamilyId: fid})
	require.NoError(t, err)
	assert.True(t, len(resp.CashFlows) > 0)
}

func TestCB_GetInvestmentIRR_Portfolio_TradesQueryError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectQuery("SELECT it.trade_type").
		WithArgs(testUserID).
		WillReturnError(errors.New("trades fail"))
	_, err := svc.GetInvestmentIRR(authedCtx(), &pb.GetIRRRequest{})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_GetInvestmentIRR_SingleInvestment_SellTrade(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	var price int64 = 15000
	mock.ExpectQuery("SELECT i.user_id, i.quantity").
		WithArgs("inv-1").
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "quantity", "current_price"}).
			AddRow(testUserID, 50.0, &price))
	tradeCols := []string{"trade_type", "total_amount", "fee", "trade_date"}
	mock.ExpectQuery("SELECT trade_type, total_amount, fee, trade_date").
		WithArgs("inv-1").
		WillReturnRows(pgxmock.NewRows(tradeCols).
			AddRow("buy", int64(1000000), int64(100), time.Now().AddDate(-1, 0, 0)).
			AddRow("sell", int64(500000), int64(50), time.Now().AddDate(0, -6, 0)))
	resp, err := svc.GetInvestmentIRR(authedCtx(), &pb.GetIRRRequest{InvestmentId: "inv-1"})
	require.NoError(t, err)
	assert.True(t, len(resp.CashFlows) > 0)
}

// ═══════════════════════════════════════════════════════════════════════════
// Type conversions — remaining branches
// ═══════════════════════════════════════════════════════════════════════════

func TestCB_MarketTypeToString_Extra(t *testing.T) {
	assert.Equal(t, "a_share", marketTypeToString(pb.MarketType_MARKET_TYPE_A_SHARE))
	assert.Equal(t, "hk_stock", marketTypeToString(pb.MarketType_MARKET_TYPE_HK_STOCK))
	assert.Equal(t, "crypto", marketTypeToString(pb.MarketType_MARKET_TYPE_CRYPTO))
	assert.Equal(t, "fund", marketTypeToString(pb.MarketType_MARKET_TYPE_FUND))
	assert.Equal(t, "unspecified", marketTypeToString(pb.MarketType(999)))
}

func TestCB_StringToMarketType_Extra(t *testing.T) {
	assert.Equal(t, pb.MarketType_MARKET_TYPE_A_SHARE, stringToMarketType("a_share"))
	assert.Equal(t, pb.MarketType_MARKET_TYPE_HK_STOCK, stringToMarketType("hk_stock"))
	assert.Equal(t, pb.MarketType_MARKET_TYPE_CRYPTO, stringToMarketType("crypto"))
	assert.Equal(t, pb.MarketType_MARKET_TYPE_FUND, stringToMarketType("fund"))
	assert.Equal(t, pb.MarketType_MARKET_TYPE_UNSPECIFIED, stringToMarketType("unknown"))
}

func TestCB_TradeTypeToString_Extra(t *testing.T) {
	assert.Equal(t, "unspecified", tradeTypeToString(pb.TradeType(999)))
}

func TestCB_StringToTradeType_Extra(t *testing.T) {
	assert.Equal(t, pb.TradeType_TRADE_TYPE_UNSPECIFIED, stringToTradeType("unknown"))
}
