package loan

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	pb "github.com/familyledger/server/proto/loan"
)

// ── ExecutePrepayment: validation ────────────────────────────────────────────

func TestExecutePrepayment_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	_, err = svc.ExecutePrepayment(context.Background(), &pb.ExecutePrepaymentRequest{
		LoanId:           uuid.New().String(),
		PrepaymentAmount: 10000,
		Strategy:         pb.PrepaymentStrategy_PREPAYMENT_STRATEGY_REDUCE_MONTHS,
	})
	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestExecutePrepayment_EmptyLoanId(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	_, err = svc.ExecutePrepayment(authedCtx(), &pb.ExecutePrepaymentRequest{
		LoanId:           "",
		PrepaymentAmount: 10000,
		Strategy:         pb.PrepaymentStrategy_PREPAYMENT_STRATEGY_REDUCE_MONTHS,
	})
	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestExecutePrepayment_ZeroAmount(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	_, err = svc.ExecutePrepayment(authedCtx(), &pb.ExecutePrepaymentRequest{
		LoanId:           uuid.New().String(),
		PrepaymentAmount: 0,
		Strategy:         pb.PrepaymentStrategy_PREPAYMENT_STRATEGY_REDUCE_MONTHS,
	})
	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestExecutePrepayment_UnspecifiedStrategy(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	_, err = svc.ExecutePrepayment(authedCtx(), &pb.ExecutePrepaymentRequest{
		LoanId:           uuid.New().String(),
		PrepaymentAmount: 10000,
		Strategy:         pb.PrepaymentStrategy_PREPAYMENT_STRATEGY_UNSPECIFIED,
	})
	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestExecutePrepayment_ExceedsRemainingPrincipal(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	loanID := uuid.New()
	startDate := time.Date(2024, 1, 15, 0, 0, 0, 0, time.UTC)

	mock.ExpectQuery(`SELECT .+ FROM loans WHERE id=\$1 AND deleted_at IS NULL`).
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows([]string{
			"id", "user_id", "name", "loan_type", "principal", "remaining_principal",
			"annual_rate", "total_months", "paid_months", "repayment_method", "payment_day",
			"start_date", "created_at", "updated_at", "account_id",
			"group_id", "sub_type", "rate_type", "lpr_base", "lpr_spread", "rate_adjust_month",
			"family_id", "repayment_category_id", "interest_calc_method",
		}).AddRow(
			loanID, testUserUUID, "房贷", "mortgage",
			int64(1000000_00), int64(500000_00),
			4.9, int32(360), int32(120),
			pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT, int32(15),
			startDate, startDate, startDate, nil,
			nil, nil, nil, nil, nil, nil, nil, nil, "monthly",
		))

	_, err = svc.ExecutePrepayment(authedCtx(), &pb.ExecutePrepaymentRequest{
		LoanId:           loanID.String(),
		PrepaymentAmount: 600000_00, // exceeds remaining 500000_00
		Strategy:         pb.PrepaymentStrategy_PREPAYMENT_STRATEGY_REDUCE_MONTHS,
	})
	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
	assert.Contains(t, err.Error(), "exceeds")
}

// ── ExecutePrepayment: success ───────────────────────────────────────────────

func TestExecutePrepayment_ReduceMonths_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	// Strict ordered matching
	//mock.MatchExpectationsInOrder(false)

	svc := NewService(mock)
	loanID := uuid.New()
	accountID := uuid.New()
	startDate := time.Date(2024, 1, 15, 0, 0, 0, 0, time.UTC)

	// loadLoan mock: 10万, 12期, 4.9%, equal_installment, 已还 2 期
	loanRow := pgxmock.NewRows([]string{
		"id", "user_id", "name", "loan_type", "principal", "remaining_principal",
		"annual_rate", "total_months", "paid_months", "repayment_method", "payment_day",
		"start_date", "created_at", "updated_at", "account_id",
		"group_id", "sub_type", "rate_type", "lpr_base", "lpr_spread", "rate_adjust_month",
		"family_id", "repayment_category_id", "interest_calc_method",
	}).AddRow(
		loanID, testUserUUID, "消费贷", "consumer",
		int64(100000_00), int64(85000_00),
		4.9, int32(12), int32(2),
		pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT, int32(15),
		startDate, startDate, startDate, &accountID,
		nil, nil, nil, nil, nil, nil, nil, nil, "monthly",
	)
	mock.ExpectQuery(`SELECT .+ FROM loans WHERE id=\$1 AND deleted_at IS NULL`).
		WithArgs(loanID.String()).
		WillReturnRows(loanRow)

	// loadSchedule: 12 items, 2 paid
	scheduleRows := pgxmock.NewRows([]string{
		"month_number", "payment", "principal_part", "interest_part",
		"remaining_principal", "is_paid", "due_date", "paid_date",
	})
	for i := 1; i <= 12; i++ {
		isPaid := i <= 2
		var paidDate *time.Time
		if isPaid {
			pd := startDate.AddDate(0, i, 0)
			paidDate = &pd
		}
		dueDate := startDate.AddDate(0, i, 0)
		scheduleRows.AddRow(
			int32(i), int64(855800), int64(814200), int64(41600),
			int64(100000_00)-int64(i)*int64(814200), isPaid, dueDate, paidDate,
		)
	}
	mock.ExpectQuery(`SELECT .+ FROM loan_schedules WHERE loan_id=\$1 ORDER BY month_number`).
		WithArgs(loanID.String()).
		WillReturnRows(scheduleRows)

	// Transaction
	mock.ExpectBegin()
	mock.ExpectExec(`UPDATE loans SET remaining_principal`).
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), loanID.String()).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectExec(`DELETE FROM loan_schedules WHERE loan_id`).
		WithArgs(loanID.String()).
		WillReturnResult(pgxmock.NewResult("DELETE", 10))

	// New schedule inserts — 提前还 3万 from 8.5万, 剩 5.5万
	// generateWithFixedPayment produces 7 items for this scenario
	for i := 0; i < 7; i++ {
		mock.ExpectExec(`INSERT INTO loan_schedules`).
			WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(),
				pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
			WillReturnResult(pgxmock.NewResult("INSERT", 1))
	}

	// Account deduction
	mock.ExpectExec(`UPDATE accounts SET balance`).
		WithArgs(int64(30000_00), accountID.String()).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	// Transaction record
	mock.ExpectQuery(`SELECT repayment_category_id FROM loans`).
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows([]string{"repayment_category_id"}).AddRow(nil))
	catID := uuid.New()
	mock.ExpectQuery(`SELECT id FROM categories WHERE name = '还款'`).
		WillReturnRows(pgxmock.NewRows([]string{"id"}).AddRow(catID.String()))
	mock.ExpectExec(`INSERT INTO transactions`).
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(),
			pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	mock.ExpectCommit()

	resp, err := svc.ExecutePrepayment(authedCtx(), &pb.ExecutePrepaymentRequest{
		LoanId:           loanID.String(),
		PrepaymentAmount: 30000_00,
		Strategy:         pb.PrepaymentStrategy_PREPAYMENT_STRATEGY_REDUCE_MONTHS,
	})

	require.NoError(t, err)
	require.NotNil(t, resp)
	require.NotNil(t, resp.Loan)
	require.NotNil(t, resp.Simulation)
	assert.Equal(t, int64(30000_00), resp.Simulation.PrepaymentAmount)
	assert.Positive(t, resp.Simulation.InterestSaved)
	assert.NotEmpty(t, resp.NewSchedule)
}

func TestExecutePrepayment_ReducePayment_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	loanID := uuid.New()
	startDate := time.Date(2024, 1, 15, 0, 0, 0, 0, time.UTC)

	mock.ExpectQuery(`SELECT .+ FROM loans WHERE id=\$1 AND deleted_at IS NULL`).
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows([]string{
			"id", "user_id", "name", "loan_type", "principal", "remaining_principal",
			"annual_rate", "total_months", "paid_months", "repayment_method", "payment_day",
			"start_date", "created_at", "updated_at", "account_id",
			"group_id", "sub_type", "rate_type", "lpr_base", "lpr_spread", "rate_adjust_month",
			"family_id", "repayment_category_id", "interest_calc_method",
		}).AddRow(
			loanID, testUserUUID, "房贷", "mortgage",
			int64(500000_00), int64(400000_00),
			3.5, int32(120), int32(24),
			pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT, int32(20),
			startDate, startDate, startDate, nil, // no account
			nil, nil, nil, nil, nil, nil, nil, nil, "monthly",
		))

	scheduleRows := pgxmock.NewRows([]string{
		"month_number", "payment", "principal_part", "interest_part",
		"remaining_principal", "is_paid", "due_date", "paid_date",
	})
	for i := 1; i <= 120; i++ {
		isPaid := i <= 24
		var paidDate *time.Time
		if isPaid {
			pd := startDate.AddDate(0, i, 0)
			paidDate = &pd
		}
		dueDate := startDate.AddDate(0, i, 0)
		scheduleRows.AddRow(
			int32(i), int64(496700), int64(351000), int64(145700),
			int64(500000_00)-int64(i)*int64(351000), isPaid, dueDate, paidDate,
		)
	}
	mock.ExpectQuery(`SELECT .+ FROM loan_schedules WHERE loan_id=\$1 ORDER BY month_number`).
		WithArgs(loanID.String()).
		WillReturnRows(scheduleRows)

	mock.MatchExpectationsInOrder(false)
	mock.ExpectBegin()
	mock.ExpectExec(`UPDATE loans SET remaining_principal`).
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), loanID.String()).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectExec(`DELETE FROM loan_schedules`).
		WithArgs(loanID.String()).
		WillReturnResult(pgxmock.NewResult("DELETE", 96))

	for i := 0; i < 120; i++ {
		mock.ExpectExec(`INSERT INTO loan_schedules`).
			WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(),
				pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
			WillReturnResult(pgxmock.NewResult("INSERT", 1)).Maybe()
	}

	// No account, so no account deduction
	// Transaction record - repayment_category_id
	mock.ExpectQuery(`SELECT repayment_category_id FROM loans`).
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows([]string{"repayment_category_id"}).AddRow(nil))
	mock.ExpectQuery(`SELECT id FROM categories WHERE name = '还款'`).
		WillReturnRows(pgxmock.NewRows([]string{"id"})) // no rows
	mock.ExpectQuery(`SELECT id FROM categories WHERE name = '房贷'`).
		WillReturnRows(pgxmock.NewRows([]string{"id"})) // no rows

	// No category found → skip transaction insert
	// No account → skip account fallback... actually it tries:
	mock.ExpectQuery(`SELECT id FROM accounts WHERE user_id`).
		WillReturnRows(pgxmock.NewRows([]string{"id"})) // no rows

	mock.ExpectCommit()

	resp, err := svc.ExecutePrepayment(authedCtx(), &pb.ExecutePrepaymentRequest{
		LoanId:           loanID.String(),
		PrepaymentAmount: 100000_00,
		Strategy:         pb.PrepaymentStrategy_PREPAYMENT_STRATEGY_REDUCE_PAYMENT,
	})

	require.NoError(t, err)
	require.NotNil(t, resp)
	assert.Equal(t, int64(100000_00), resp.Simulation.PrepaymentAmount)
	assert.NotEmpty(t, resp.NewSchedule)
	assert.Len(t, resp.NewSchedule, 96) // same months (reduce payment keeps months)
}

// ── ExecuteGroupPrepayment ──────────────────────────────────────────────────

func TestExecuteGroupPrepayment_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	_, err = svc.ExecuteGroupPrepayment(context.Background(), &pb.ExecuteGroupPrepaymentRequest{
		GroupId:          uuid.New().String(),
		PrepaymentAmount: 10000,
		Strategy:         pb.PrepaymentStrategy_PREPAYMENT_STRATEGY_REDUCE_MONTHS,
	})
	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestExecuteGroupPrepayment_EmptyGroupId(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	_, err = svc.ExecuteGroupPrepayment(authedCtx(), &pb.ExecuteGroupPrepaymentRequest{
		GroupId:          "",
		PrepaymentAmount: 10000,
		Strategy:         pb.PrepaymentStrategy_PREPAYMENT_STRATEGY_REDUCE_MONTHS,
	})
	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestExecuteGroupPrepayment_ZeroAmount(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	_, err = svc.ExecuteGroupPrepayment(authedCtx(), &pb.ExecuteGroupPrepaymentRequest{
		GroupId:          uuid.New().String(),
		PrepaymentAmount: 0,
		Strategy:         pb.PrepaymentStrategy_PREPAYMENT_STRATEGY_REDUCE_MONTHS,
	})
	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestExecuteGroupPrepayment_UnspecifiedStrategy(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	_, err = svc.ExecuteGroupPrepayment(authedCtx(), &pb.ExecuteGroupPrepaymentRequest{
		GroupId:          uuid.New().String(),
		PrepaymentAmount: 10000,
		Strategy:         pb.PrepaymentStrategy_PREPAYMENT_STRATEGY_UNSPECIFIED,
	})
	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}
