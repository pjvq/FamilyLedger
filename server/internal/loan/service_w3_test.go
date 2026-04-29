package loan

import (
	"testing"
	"time"

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
