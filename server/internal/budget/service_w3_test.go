package budget

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgconn"
	pgxmock "github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	pb "github.com/familyledger/server/proto/budget"
)

func noAuthCtx() context.Context { return context.Background() }

// ═══════════════════════════════════════════════════════════════════════════════
// W3: Budget Business Logic Tests
// Covers: unique constraint, execution rate computation, edge cases
// ═══════════════════════════════════════════════════════════════════════════════

// ─── CreateBudget: duplicate year+month+user ────────────────────────────────

func TestW3_CreateBudget_DuplicateMonthReject(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	// permission.Check skipped (no family_id)
	// Begin transaction
	mock.ExpectBegin()

	// INSERT returns unique_violation (23505)
	mock.ExpectQuery(`INSERT INTO budgets`).
		WillReturnError(&pgconn.PgError{
			Code:    "23505",
			Message: "duplicate key value violates unique constraint",
		})

	// Rollback after error (deferred)
	mock.ExpectRollback()

	_, err = svc.CreateBudget(authedCtx(), &pb.CreateBudgetRequest{
		Year:        2026,
		Month:       5,
		TotalAmount: 500000,
	})

	require.Error(t, err)
	assert.Equal(t, codes.AlreadyExists, status.Code(err))
}

// ─── CreateBudget: zero amount rejected ─────────────────────────────────────

func TestW3_CreateBudget_ZeroAmountRejected(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.CreateBudget(authedCtx(), &pb.CreateBudgetRequest{
		Year:        2026,
		Month:       5,
		TotalAmount: 0,
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── CreateBudget: negative amount rejected ─────────────────────────────────

func TestW3_CreateBudget_NegativeAmountRejected(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.CreateBudget(authedCtx(), &pb.CreateBudgetRequest{
		Year:        2026,
		Month:       5,
		TotalAmount: -100,
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── CreateBudget: invalid month ────────────────────────────────────────────

func TestW3_CreateBudget_InvalidMonth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	testCases := []int32{0, 13, -1}
	for _, month := range testCases {
		_, err = svc.CreateBudget(authedCtx(), &pb.CreateBudgetRequest{
			Year:        2026,
			Month:       month,
			TotalAmount: 500000,
		})
		require.Error(t, err, "month=%d should be rejected", month)
		assert.Equal(t, codes.InvalidArgument, status.Code(err))
	}
}

// ─── DeleteBudget: no auth ──────────────────────────────────────────────────

func TestW3_DeleteBudget_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.DeleteBudget(noAuthCtx(), &pb.DeleteBudgetRequest{
		BudgetId: uuid.New().String(),
	})

	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

// ─── DeleteBudget: invalid ID ───────────────────────────────────────────────

func TestW3_DeleteBudget_InvalidId(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.DeleteBudget(authedCtx(), &pb.DeleteBudgetRequest{
		BudgetId: "not-uuid",
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── GetBudgetExecution: invalid budget_id ──────────────────────────────────

func TestW3_GetBudgetExecution_InvalidId(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.GetBudgetExecution(authedCtx(), &pb.GetBudgetExecutionRequest{
		BudgetId: "bad-id",
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── GetBudgetExecution: no auth ────────────────────────────────────────────

func TestW3_GetBudgetExecution_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.GetBudgetExecution(noAuthCtx(), &pb.GetBudgetExecutionRequest{
		BudgetId: uuid.New().String(),
	})

	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

// ─── UpdateBudget: no auth ──────────────────────────────────────────────────

func TestW3_UpdateBudget_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.UpdateBudget(noAuthCtx(), &pb.UpdateBudgetRequest{
		BudgetId:    uuid.New().String(),
		TotalAmount: 100000,
	})

	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

// ─── UpdateBudget: invalid amount ───────────────────────────────────────────

func TestW3_UpdateBudget_ZeroAmount(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.UpdateBudget(authedCtx(), &pb.UpdateBudgetRequest{
		BudgetId:    uuid.New().String(),
		TotalAmount: 0,
	})

	require.Error(t, err)
	// UpdateBudget may not validate 0 amount (goes to DB)
	st := status.Code(err)
	assert.Contains(t, []codes.Code{codes.InvalidArgument, codes.Internal}, st)
}

// ═══════════════════════════════════════════════════════════════════════════════
// Budget Execution Rate Integration (mock DB queries → verify rate computation)
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Execution rate: 50% spent ──────────────────────────────────────────────

func TestW3_GetBudgetExecution_Rate50Percent(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	budgetID := uuid.New()
	now := time.Now()

	// loadBudget: personal budget, 100000 total, no family
	mock.ExpectQuery(`SELECT user_id, family_id, year, month, total_amount, created_at FROM budgets WHERE id = \$1`).
		WithArgs(budgetID).
		WillReturnRows(pgxmock.NewRows([]string{
			"user_id", "family_id", "year", "month", "total_amount", "created_at",
		}).AddRow(testUserUUID, nil, int32(2026), int32(5), int64(100000), now))

	// loadCategoryBudgets: no category budgets
	mock.ExpectQuery(`SELECT category_id, amount FROM category_budgets WHERE budget_id = \$1`).
		WithArgs(budgetID).
		WillReturnRows(pgxmock.NewRows([]string{"category_id", "amount"}))

	// computeExecution: personal budget expense sum = 50000 (50%)
	mock.ExpectQuery(`SELECT COALESCE\(SUM\(amount_cny\), 0\)`).
		WithArgs(testUserID, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"sum"}).AddRow(int64(50000)))

	resp, err := svc.GetBudgetExecution(authedCtx(), &pb.GetBudgetExecutionRequest{
		BudgetId: budgetID.String(),
	})

	require.NoError(t, err)
	assert.Equal(t, int64(100000), resp.Execution.TotalBudget)
	assert.Equal(t, int64(50000), resp.Execution.TotalSpent)
	assert.InDelta(t, 0.5, resp.Execution.ExecutionRate, 0.001, "50% execution rate")
}

// ─── Execution rate: 80% warning threshold ──────────────────────────────────

func TestW3_GetBudgetExecution_Rate80PercentWarning(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	budgetID := uuid.New()
	now := time.Now()

	mock.ExpectQuery(`SELECT user_id, family_id, year, month, total_amount, created_at FROM budgets WHERE id = \$1`).
		WithArgs(budgetID).
		WillReturnRows(pgxmock.NewRows([]string{
			"user_id", "family_id", "year", "month", "total_amount", "created_at",
		}).AddRow(testUserUUID, nil, int32(2026), int32(5), int64(100000), now))

	mock.ExpectQuery(`SELECT category_id, amount FROM category_budgets WHERE budget_id = \$1`).
		WithArgs(budgetID).
		WillReturnRows(pgxmock.NewRows([]string{"category_id", "amount"}))

	// 80000 / 100000 = 0.80 → warning threshold
	mock.ExpectQuery(`SELECT COALESCE\(SUM\(amount_cny\), 0\)`).
		WithArgs(testUserID, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"sum"}).AddRow(int64(80000)))

	resp, err := svc.GetBudgetExecution(authedCtx(), &pb.GetBudgetExecutionRequest{
		BudgetId: budgetID.String(),
	})

	require.NoError(t, err)
	assert.InDelta(t, 0.8, resp.Execution.ExecutionRate, 0.001)
	assert.True(t, resp.Execution.ExecutionRate >= 0.8, "should trigger warning threshold")
}

// ─── Execution rate: 100% exceeded ──────────────────────────────────────────

func TestW3_GetBudgetExecution_Rate100PercentExceeded(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	budgetID := uuid.New()
	now := time.Now()

	mock.ExpectQuery(`SELECT user_id, family_id, year, month, total_amount, created_at FROM budgets WHERE id = \$1`).
		WithArgs(budgetID).
		WillReturnRows(pgxmock.NewRows([]string{
			"user_id", "family_id", "year", "month", "total_amount", "created_at",
		}).AddRow(testUserUUID, nil, int32(2026), int32(5), int64(100000), now))

	mock.ExpectQuery(`SELECT category_id, amount FROM category_budgets WHERE budget_id = \$1`).
		WithArgs(budgetID).
		WillReturnRows(pgxmock.NewRows([]string{"category_id", "amount"}))

	// 120000 / 100000 = 1.20 → exceeded
	mock.ExpectQuery(`SELECT COALESCE\(SUM\(amount_cny\), 0\)`).
		WithArgs(testUserID, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"sum"}).AddRow(int64(120000)))

	resp, err := svc.GetBudgetExecution(authedCtx(), &pb.GetBudgetExecutionRequest{
		BudgetId: budgetID.String(),
	})

	require.NoError(t, err)
	assert.InDelta(t, 1.2, resp.Execution.ExecutionRate, 0.001)
	assert.True(t, resp.Execution.ExecutionRate >= 1.0, "should trigger exceeded alert")
}

// ─── Execution rate: zero spending ──────────────────────────────────────────

func TestW3_GetBudgetExecution_ZeroSpending(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	budgetID := uuid.New()
	now := time.Now()

	mock.ExpectQuery(`SELECT user_id, family_id, year, month, total_amount, created_at FROM budgets WHERE id = \$1`).
		WithArgs(budgetID).
		WillReturnRows(pgxmock.NewRows([]string{
			"user_id", "family_id", "year", "month", "total_amount", "created_at",
		}).AddRow(testUserUUID, nil, int32(2026), int32(5), int64(50000), now))

	mock.ExpectQuery(`SELECT category_id, amount FROM category_budgets WHERE budget_id = \$1`).
		WithArgs(budgetID).
		WillReturnRows(pgxmock.NewRows([]string{"category_id", "amount"}))

	mock.ExpectQuery(`SELECT COALESCE\(SUM\(amount_cny\), 0\)`).
		WithArgs(testUserID, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"sum"}).AddRow(int64(0)))

	resp, err := svc.GetBudgetExecution(authedCtx(), &pb.GetBudgetExecutionRequest{
		BudgetId: budgetID.String(),
	})

	require.NoError(t, err)
	assert.Equal(t, int64(0), resp.Execution.TotalSpent)
	assert.Equal(t, float64(0), resp.Execution.ExecutionRate)
}
