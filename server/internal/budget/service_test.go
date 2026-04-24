package budget

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

	"github.com/familyledger/server/pkg/middleware"
	pb "github.com/familyledger/server/proto/budget"
)

const testUserID = "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"

var testUserUUID = uuid.MustParse(testUserID)

func authedCtx() context.Context {
	return context.WithValue(context.Background(), middleware.UserIDKey, testUserID)
}

// ─── CreateBudget ───────────────────────────────────────────────────────────

func TestCreateBudget_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	budgetID := uuid.New()
	now := time.Now()

	mock.ExpectBegin()
	mock.ExpectQuery("INSERT INTO budgets").
		WithArgs(testUserUUID, (*uuid.UUID)(nil), int32(2026), int32(4), int64(500000)).
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at"}).
			AddRow(budgetID, now))
	mock.ExpectCommit()

	resp, err := svc.CreateBudget(authedCtx(), &pb.CreateBudgetRequest{
		Year:        2026,
		Month:       4,
		TotalAmount: 500000,
	})
	require.NoError(t, err)
	assert.Equal(t, budgetID.String(), resp.Budget.Id)
	assert.Equal(t, int64(500000), resp.Budget.TotalAmount)
	assert.Equal(t, int32(2026), resp.Budget.Year)
	assert.Equal(t, int32(4), resp.Budget.Month)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestCreateBudget_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	_, err = svc.CreateBudget(context.Background(), &pb.CreateBudgetRequest{
		Year:        2026,
		Month:       4,
		TotalAmount: 500000,
	})
	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestCreateBudget_InvalidAmount(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	_, err = svc.CreateBudget(authedCtx(), &pb.CreateBudgetRequest{
		Year:        2026,
		Month:       4,
		TotalAmount: 0,
	})
	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))

	_, err = svc.CreateBudget(authedCtx(), &pb.CreateBudgetRequest{
		Year:        2026,
		Month:       4,
		TotalAmount: -100,
	})
	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── GetBudget ──────────────────────────────────────────────────────────────

func TestGetBudget_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	budgetID := uuid.New()
	now := time.Now()

	// loadBudget query
	mock.ExpectQuery("SELECT user_id, family_id, year, month, total_amount, created_at FROM budgets").
		WithArgs(budgetID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id", "year", "month", "total_amount", "created_at"}).
			AddRow(testUserUUID, (*uuid.UUID)(nil), int32(2026), int32(4), int64(500000), now))

	// loadCategoryBudgets
	mock.ExpectQuery("SELECT category_id, amount FROM category_budgets").
		WithArgs(budgetID).
		WillReturnRows(pgxmock.NewRows([]string{"category_id", "amount"}))

	// computeExecution: total spent
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(amount_cny\\), 0\\)").
		WithArgs(testUserID, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(200000)))

	resp, err := svc.GetBudget(authedCtx(), &pb.GetBudgetRequest{BudgetId: budgetID.String()})
	require.NoError(t, err)
	assert.Equal(t, budgetID.String(), resp.Budget.Id)
	assert.Equal(t, int64(500000), resp.Budget.TotalAmount)
	assert.Equal(t, int64(200000), resp.Execution.TotalSpent)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGetBudget_NotFound(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	budgetID := uuid.New()

	mock.ExpectQuery("SELECT user_id, family_id, year, month, total_amount, created_at FROM budgets").
		WithArgs(budgetID).
		WillReturnError(pgx.ErrNoRows)

	_, err = svc.GetBudget(authedCtx(), &pb.GetBudgetRequest{BudgetId: budgetID.String()})
	require.Error(t, err)
	assert.Equal(t, codes.NotFound, status.Code(err))
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ─── ListBudgets ────────────────────────────────────────────────────────────

func TestListBudgets_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	bid1, bid2 := uuid.New(), uuid.New()
	now := time.Now()

	mock.ExpectQuery("SELECT b.id, b.user_id, b.family_id, b.year, b.month, b.total_amount, b.created_at").
		WithArgs(testUserUUID, (*uuid.UUID)(nil), int32(0)).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "year", "month", "total_amount", "created_at"}).
			AddRow(bid1, testUserUUID, (*uuid.UUID)(nil), int32(2026), int32(4), int64(500000), now).
			AddRow(bid2, testUserUUID, (*uuid.UUID)(nil), int32(2026), int32(3), int64(400000), now))

	// loadCategoryBudgets for bid1
	mock.ExpectQuery("SELECT category_id, amount FROM category_budgets").
		WithArgs(bid1).
		WillReturnRows(pgxmock.NewRows([]string{"category_id", "amount"}))

	// loadCategoryBudgets for bid2
	mock.ExpectQuery("SELECT category_id, amount FROM category_budgets").
		WithArgs(bid2).
		WillReturnRows(pgxmock.NewRows([]string{"category_id", "amount"}))

	resp, err := svc.ListBudgets(authedCtx(), &pb.ListBudgetsRequest{})
	require.NoError(t, err)
	assert.Len(t, resp.Budgets, 2)
	assert.Equal(t, int32(2026), resp.Budgets[0].Year)
	assert.Equal(t, int32(4), resp.Budgets[0].Month)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestListBudgets_Empty(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	mock.ExpectQuery("SELECT b.id, b.user_id, b.family_id, b.year, b.month, b.total_amount, b.created_at").
		WithArgs(testUserUUID, (*uuid.UUID)(nil), int32(0)).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "year", "month", "total_amount", "created_at"}))

	resp, err := svc.ListBudgets(authedCtx(), &pb.ListBudgetsRequest{})
	require.NoError(t, err)
	assert.Empty(t, resp.Budgets)
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ─── UpdateBudget ───────────────────────────────────────────────────────────

func TestUpdateBudget_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	budgetID := uuid.New()
	now := time.Now()

	// Verify ownership
	mock.ExpectQuery("SELECT user_id FROM budgets WHERE id").
		WithArgs(budgetID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}).AddRow(testUserID))

	mock.ExpectBegin()
	mock.ExpectExec("UPDATE budgets SET total_amount").
		WithArgs(int64(600000), budgetID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectCommit()

	// loadBudget after update
	mock.ExpectQuery("SELECT user_id, family_id, year, month, total_amount, created_at FROM budgets").
		WithArgs(budgetID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id", "year", "month", "total_amount", "created_at"}).
			AddRow(testUserUUID, (*uuid.UUID)(nil), int32(2026), int32(4), int64(600000), now))

	// loadCategoryBudgets
	mock.ExpectQuery("SELECT category_id, amount FROM category_budgets").
		WithArgs(budgetID).
		WillReturnRows(pgxmock.NewRows([]string{"category_id", "amount"}))

	resp, err := svc.UpdateBudget(authedCtx(), &pb.UpdateBudgetRequest{
		BudgetId:    budgetID.String(),
		TotalAmount: 600000,
	})
	require.NoError(t, err)
	assert.Equal(t, int64(600000), resp.Budget.TotalAmount)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestUpdateBudget_NotFound(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	budgetID := uuid.New()

	mock.ExpectQuery("SELECT user_id FROM budgets WHERE id").
		WithArgs(budgetID).
		WillReturnError(pgx.ErrNoRows)

	_, err = svc.UpdateBudget(authedCtx(), &pb.UpdateBudgetRequest{
		BudgetId:    budgetID.String(),
		TotalAmount: 600000,
	})
	require.Error(t, err)
	assert.Equal(t, codes.NotFound, status.Code(err))
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ─── DeleteBudget ───────────────────────────────────────────────────────────

func TestDeleteBudget_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	budgetID := uuid.New()

	mock.ExpectExec("DELETE FROM budgets WHERE id").
		WithArgs(budgetID, testUserID).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))

	_, err = svc.DeleteBudget(authedCtx(), &pb.DeleteBudgetRequest{BudgetId: budgetID.String()})
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestDeleteBudget_NotFound(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	budgetID := uuid.New()

	mock.ExpectExec("DELETE FROM budgets WHERE id").
		WithArgs(budgetID, testUserID).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))

	_, err = svc.DeleteBudget(authedCtx(), &pb.DeleteBudgetRequest{BudgetId: budgetID.String()})
	require.Error(t, err)
	assert.Equal(t, codes.NotFound, status.Code(err))
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ─── GetBudgetExecution (mapped from task's "GetBudgetProgress") ────────────

func TestGetBudgetExecution_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	budgetID := uuid.New()
	catID := uuid.New()
	now := time.Now()

	// loadBudget
	mock.ExpectQuery("SELECT user_id, family_id, year, month, total_amount, created_at FROM budgets").
		WithArgs(budgetID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id", "year", "month", "total_amount", "created_at"}).
			AddRow(testUserUUID, (*uuid.UUID)(nil), int32(2026), int32(4), int64(500000), now))

	// loadCategoryBudgets
	mock.ExpectQuery("SELECT category_id, amount FROM category_budgets").
		WithArgs(budgetID).
		WillReturnRows(pgxmock.NewRows([]string{"category_id", "amount"}).
			AddRow(catID, int64(100000)))

	// computeExecution: total spent
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(amount_cny\\), 0\\)").
		WithArgs(testUserID, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(350000)))

	// computeExecution: category spending
	mock.ExpectQuery("SELECT t.category_id, c.name, COALESCE").
		WithArgs(testUserID, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"category_id", "name", "spent"}).
			AddRow(catID, "餐饮", int64(80000)))

	resp, err := svc.GetBudgetExecution(authedCtx(), &pb.GetBudgetExecutionRequest{BudgetId: budgetID.String()})
	require.NoError(t, err)
	assert.Equal(t, int64(500000), resp.Execution.TotalBudget)
	assert.Equal(t, int64(350000), resp.Execution.TotalSpent)
	assert.InDelta(t, 0.7, resp.Execution.ExecutionRate, 0.01)
	require.Len(t, resp.Execution.CategoryExecutions, 1)
	assert.Equal(t, int64(80000), resp.Execution.CategoryExecutions[0].SpentAmount)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGetBudgetExecution_NotFound(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	budgetID := uuid.New()

	mock.ExpectQuery("SELECT user_id, family_id, year, month, total_amount, created_at FROM budgets").
		WithArgs(budgetID).
		WillReturnError(pgx.ErrNoRows)

	_, err = svc.GetBudgetExecution(authedCtx(), &pb.GetBudgetExecutionRequest{BudgetId: budgetID.String()})
	require.Error(t, err)
	assert.Equal(t, codes.NotFound, status.Code(err))
	assert.NoError(t, mock.ExpectationsWereMet())
}
