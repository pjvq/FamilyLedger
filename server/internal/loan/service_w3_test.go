package loan

import (
	"testing"
	"time"

	"github.com/google/uuid"
	pgxmock "github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	pb "github.com/familyledger/server/proto/loan"
)

// ═══════════════════════════════════════════════════════════════════════════════
// W3: Loan Business Logic Tests
// Covers: LPR rate change validation, negative rate, effective_date required
// ═══════════════════════════════════════════════════════════════════════════════

// ─── RecordRateChange: negative rate rejected ───────────────────────────────

func TestW3_RecordRateChange_NegativeRate(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.RecordRateChange(extAuthedCtx(), &pb.RecordRateChangeRequest{
		LoanId:        "550e8400-e29b-41d4-a716-446655440000",
		NewRate:       -1.5,
		EffectiveDate: timestamppb.New(time.Now()),
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
	assert.Contains(t, err.Error(), "new_rate must be positive")
}

// ─── RecordRateChange: zero rate rejected ───────────────────────────────────

func TestW3_RecordRateChange_ZeroRate(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.RecordRateChange(extAuthedCtx(), &pb.RecordRateChangeRequest{
		LoanId:        "550e8400-e29b-41d4-a716-446655440000",
		NewRate:       0,
		EffectiveDate: timestamppb.New(time.Now()),
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── RecordRateChange: missing effective_date rejected ──────────────────────

func TestW3_RecordRateChange_MissingEffectiveDate(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.RecordRateChange(extAuthedCtx(), &pb.RecordRateChangeRequest{
		LoanId:  "550e8400-e29b-41d4-a716-446655440000",
		NewRate: 3.85,
		// EffectiveDate: nil
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
	assert.Contains(t, err.Error(), "effective_date")
}

// ─── SimulatePrepayment: empty loan_id rejected ─────────────────────────────

func TestW3_SimulatePrepayment_EmptyLoanId(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.SimulatePrepayment(extAuthedCtx(), &pb.SimulatePrepaymentRequest{
		LoanId:           "",
		PrepaymentAmount: 50000,
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── Schedule generation: equal installment (等额本息) ───────────────────────

func TestW3_GenerateSchedule_EqualInstallment_paymentConsistency(t *testing.T) {
	// 100万, 30年, 4.9%
	schedule := generateSchedule(1000000_00, 0.049, 360, "equal_installment", 15, time.Date(2024, 1, 15, 0, 0, 0, 0, time.UTC))

	require.NotEmpty(t, schedule)
	assert.Len(t, schedule, 360)

	// All monthly payments should be equal (±100 分 due to rounding in last period)
	firstPayment := schedule[0].payment
	for i, item := range schedule {
		diff := item.payment - firstPayment
		if diff < -100 || diff > 100 {
			t.Errorf("period %d: payment %d differs from first %d by %d",
				i+1, item.payment, firstPayment, diff)
		}
	}

	// Total interest should be positive and significant for 30y mortgage
	totalinterestPart := int64(0)
	for _, item := range schedule {
		totalinterestPart += item.interestPart
	}
	assert.Positive(t, totalinterestPart)
}

// ─── Schedule generation: equal principal (等额本金) ─────────────────────────

func TestW3_GenerateSchedule_EqualPrincipal_DecreasingPayments(t *testing.T) {
	// 100万, 360月, 4.9%
	schedule := generateSchedule(1000000_00, 0.049, 360, "equal_principal", 15, time.Date(2024, 1, 15, 0, 0, 0, 0, time.UTC))

	require.NotEmpty(t, schedule)
	assert.Len(t, schedule, 360)

	// Payments should decrease over time (each period <= previous)
	for i := 1; i < len(schedule); i++ {
		assert.LessOrEqual(t, schedule[i].payment, schedule[i-1].payment,
			"period %d payment should be <= period %d", i+1, i)
	}

	// First payment should be larger than last
	assert.Greater(t, schedule[0].payment, schedule[len(schedule)-1].payment)
}

// ─── Schedule: final balance should be zero ─────────────────────────────────

func TestW3_GenerateSchedule_FinalBalanceZero(t *testing.T) {
	methods := []string{"equal_installment", "equal_principal"}

	for _, method := range methods {
		t.Run(method, func(t *testing.T) {
			schedule := generateSchedule(500000_00, 0.035, 120, method, 20, time.Date(2024, 1, 20, 0, 0, 0, 0, time.UTC))
			require.NotEmpty(t, schedule)

			lastItem := schedule[len(schedule)-1]
			assert.LessOrEqual(t, lastItem.remainingPrincipal, int64(1),
				"final remaining principal should be 0 (±1 rounding)")
		})
	}
}

// ═══════════════════════════════════════════════════════════════════════════════
// Loan Prepayment Simulation
// ═══════════════════════════════════════════════════════════════════════════════

func TestW3_SimulatePrepayment_ReduceMonths_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	loanID := uuid.New()
	startDate := time.Date(2024, 1, 15, 0, 0, 0, 0, time.UTC)

	// loadLoan mock: 100万, 360月, 4.9%, equal_installment, 已还12期
	mock.ExpectQuery(`SELECT .+ FROM loans WHERE id=\$1 AND deleted_at IS NULL`).
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows([]string{
			"id", "user_id", "name", "loan_type", "principal", "remaining_principal",
			"annual_rate", "total_months", "paid_months", "repayment_method", "payment_day",
			"start_date", "created_at", "updated_at", "account_id",
			"group_id", "sub_type", "rate_type", "lpr_base", "lpr_spread", "rate_adjust_month",
			"family_id", "repayment_category_id",
		}).AddRow(
			loanID, uuid.MustParse(testUserID), "房贷", "mortgage",
			int64(1000000_00), int64(970000_00), // remaining after 12 months
			4.9, int32(360), int32(12),
			pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT, int32(15),
			startDate, startDate, startDate, nil,
			nil, nil, nil, nil, nil, nil, nil, nil,
		))

	// loadSchedule: build 360 items (12 paid + 348 unpaid)
	scheduleRows := pgxmock.NewRows([]string{
		"month_number", "payment", "principal_part", "interest_part",
		"remaining_principal", "is_paid", "due_date", "paid_date",
	})
	for i := 1; i <= 360; i++ {
		isPaid := i <= 12
		var paidDate *time.Time
		if isPaid {
			pd := startDate.AddDate(0, i, 0)
			paidDate = &pd
		}
		dueDate := startDate.AddDate(0, i, 0)
		scheduleRows.AddRow(
			int32(i), int64(531300), int64(122500), int64(408800),
			int64(1000000_00)-int64(i)*int64(122500), isPaid, dueDate, paidDate,
		)
	}
	mock.ExpectQuery(`SELECT .+ FROM loan_schedules WHERE loan_id=\$1 ORDER BY month_number`).
		WithArgs(loanID.String()).
		WillReturnRows(scheduleRows)

	resp, err := svc.SimulatePrepayment(extAuthedCtx(), &pb.SimulatePrepaymentRequest{
		LoanId:           loanID.String(),
		PrepaymentAmount: 200000_00, // 提前还20万
		Strategy:         pb.PrepaymentStrategy_PREPAYMENT_STRATEGY_REDUCE_MONTHS,
	})

	require.NoError(t, err)
	// Reduce months: fewer months, interest saved > 0
	assert.Positive(t, resp.InterestSaved, "prepayment should save interest")
	assert.Positive(t, resp.MonthsReduced, "reduce_months strategy should reduce months")
	assert.NotEmpty(t, resp.NewSchedule, "should generate new schedule")
	assert.Less(t, int32(len(resp.NewSchedule)), int32(348), "new schedule should have fewer months than 348")
}

func TestW3_SimulatePrepayment_ReducePayment_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	loanID := uuid.New()
	startDate := time.Date(2024, 1, 15, 0, 0, 0, 0, time.UTC)

	// Same loan setup
	mock.ExpectQuery(`SELECT .+ FROM loans WHERE id=\$1 AND deleted_at IS NULL`).
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows([]string{
			"id", "user_id", "name", "loan_type", "principal", "remaining_principal",
			"annual_rate", "total_months", "paid_months", "repayment_method", "payment_day",
			"start_date", "created_at", "updated_at", "account_id",
			"group_id", "sub_type", "rate_type", "lpr_base", "lpr_spread", "rate_adjust_month",
			"family_id", "repayment_category_id",
		}).AddRow(
			loanID, uuid.MustParse(testUserID), "房贷", "mortgage",
			int64(1000000_00), int64(970000_00),
			4.9, int32(360), int32(12),
			pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT, int32(15),
			startDate, startDate, startDate, nil,
			nil, nil, nil, nil, nil, nil, nil, nil,
		))

	scheduleRows := pgxmock.NewRows([]string{
		"month_number", "payment", "principal_part", "interest_part",
		"remaining_principal", "is_paid", "due_date", "paid_date",
	})
	for i := 1; i <= 360; i++ {
		isPaid := i <= 12
		var paidDate *time.Time
		if isPaid {
			pd := startDate.AddDate(0, i, 0)
			paidDate = &pd
		}
		dueDate := startDate.AddDate(0, i, 0)
		scheduleRows.AddRow(
			int32(i), int64(531300), int64(122500), int64(408800),
			int64(1000000_00)-int64(i)*int64(122500), isPaid, dueDate, paidDate,
		)
	}
	mock.ExpectQuery(`SELECT .+ FROM loan_schedules WHERE loan_id=\$1 ORDER BY month_number`).
		WithArgs(loanID.String()).
		WillReturnRows(scheduleRows)

	resp, err := svc.SimulatePrepayment(extAuthedCtx(), &pb.SimulatePrepaymentRequest{
		LoanId:           loanID.String(),
		PrepaymentAmount: 200000_00,
		Strategy:         pb.PrepaymentStrategy_PREPAYMENT_STRATEGY_REDUCE_PAYMENT,
	})

	require.NoError(t, err)
	// Reduce payment: same months, lower monthly payment, interest saved > 0
	assert.Positive(t, resp.InterestSaved, "prepayment should save interest")
	assert.Positive(t, resp.NewMonthlyPayment, "should have new monthly payment")
	assert.Equal(t, int32(len(resp.NewSchedule)), int32(348), "reduce_payment keeps same number of months")
}

func TestW3_SimulatePrepayment_ExceedsRemaining_Rejected(t *testing.T) {
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
			"family_id", "repayment_category_id",
		}).AddRow(
			loanID, uuid.MustParse(testUserID), "房贷", "mortgage",
			int64(1000000_00), int64(500000_00), // remaining 50万
			4.9, int32(360), int32(180),
			pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT, int32(15),
			startDate, startDate, startDate, nil,
			nil, nil, nil, nil, nil, nil, nil, nil,
		))

	_, err = svc.SimulatePrepayment(extAuthedCtx(), &pb.SimulatePrepaymentRequest{
		LoanId:           loanID.String(),
		PrepaymentAmount: 600000_00, // 60万 > remaining 50万
		Strategy:         pb.PrepaymentStrategy_PREPAYMENT_STRATEGY_REDUCE_MONTHS,
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
	assert.Contains(t, err.Error(), "exceeds remaining principal")
}
