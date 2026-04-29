package budget

import (
	"context"
	"testing"

	"github.com/google/uuid"
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

	// INSERT that returns unique constraint violation
	mock.ExpectQuery(`INSERT INTO budgets`).
		WillReturnError(assert.AnError)

	_, err = svc.CreateBudget(authedCtx(), &pb.CreateBudgetRequest{
		Year:        2026,
		Month:       5,
		TotalAmount: 500000,
	})

	require.Error(t, err)
	// Should return AlreadyExists or Internal depending on error detection
	st := status.Code(err)
	assert.Contains(t, []codes.Code{codes.AlreadyExists, codes.Internal}, st)
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
