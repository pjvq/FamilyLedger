package loan

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/types/known/timestamppb"

	pb "github.com/familyledger/server/proto/loan"
)

func TestCalcPrepaymentSchedule_ReduceMonths(t *testing.T) {
	startDate := time.Date(2024, 1, 15, 0, 0, 0, 0, time.UTC)
	items := make([]*pb.LoanScheduleItem, 360)
	for i := range items {
		isPaid := i < 12
		items[i] = &pb.LoanScheduleItem{
			MonthNumber:   int32(i + 1),
			Payment:       531300,
			PrincipalPart: 122500,
			InterestPart:  408800,
			IsPaid:        isPaid,
			DueDate:       timestamppb.New(startDate.AddDate(0, i+1, 0)),
		}
	}

	loan := &pb.Loan{
		Principal:          1000000_00,
		RemainingPrincipal: 970000_00,
		AnnualRate:         4.9,
		TotalMonths:        360,
		PaidMonths:         12,
		RepaymentMethod:    pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
		PaymentDay:         15,
		StartDate:          timestamppb.New(startDate),
		InterestCalcMethod: pb.InterestCalcMethod_INTEREST_CALC_MONTHLY,
	}

	calc := calcPrepaymentSchedule(prepaymentInput{
		loan:             loan,
		items:            items,
		prepaymentAmount: 200000_00,
		strategy:         pb.PrepaymentStrategy_PREPAYMENT_STRATEGY_REDUCE_MONTHS,
	})

	assert.Greater(t, calc.interestSaved, int64(0))
	assert.Greater(t, calc.monthsReduced, int32(0))
	assert.Equal(t, int64(770000_00), calc.newPrincipal)
	assert.NotEmpty(t, calc.newSchedule)
	assert.Less(t, int32(len(calc.newSchedule)), int32(348))
}

func TestCalcPrepaymentSchedule_ReducePayment(t *testing.T) {
	startDate := time.Date(2024, 1, 15, 0, 0, 0, 0, time.UTC)
	items := make([]*pb.LoanScheduleItem, 120)
	for i := range items {
		isPaid := i < 24
		items[i] = &pb.LoanScheduleItem{
			MonthNumber:   int32(i + 1),
			Payment:       500000,
			PrincipalPart: 300000,
			InterestPart:  200000,
			IsPaid:        isPaid,
			DueDate:       timestamppb.New(startDate.AddDate(0, i+1, 0)),
		}
	}

	loan := &pb.Loan{
		Principal:          500000_00,
		RemainingPrincipal: 430000_00,
		AnnualRate:         3.5,
		TotalMonths:        120,
		PaidMonths:         24,
		RepaymentMethod:    pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
		PaymentDay:         15,
		StartDate:          timestamppb.New(startDate),
		InterestCalcMethod: pb.InterestCalcMethod_INTEREST_CALC_MONTHLY,
	}

	calc := calcPrepaymentSchedule(prepaymentInput{
		loan:             loan,
		items:            items,
		prepaymentAmount: 100000_00,
		strategy:         pb.PrepaymentStrategy_PREPAYMENT_STRATEGY_REDUCE_PAYMENT,
	})

	assert.Equal(t, int64(330000_00), calc.newPrincipal)
	assert.Equal(t, int32(120), calc.newTotalMonths)
	assert.Equal(t, int32(0), calc.monthsReduced)
	assert.Len(t, calc.newSchedule, 96)
	assert.Greater(t, calc.interestSaved, int64(0))
}

func TestCalcPrepaymentSchedule_FullPrepayment(t *testing.T) {
	startDate := time.Date(2024, 1, 15, 0, 0, 0, 0, time.UTC)
	items := []*pb.LoanScheduleItem{
		{MonthNumber: 1, Payment: 10000, InterestPart: 2000, IsPaid: true, DueDate: timestamppb.New(startDate.AddDate(0, 1, 0))},
		{MonthNumber: 2, Payment: 10000, InterestPart: 1900, IsPaid: false, DueDate: timestamppb.New(startDate.AddDate(0, 2, 0))},
	}

	loan := &pb.Loan{
		Principal:          20000,
		RemainingPrincipal: 10000,
		AnnualRate:         5.0,
		TotalMonths:        2,
		PaidMonths:         1,
		RepaymentMethod:    pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
		PaymentDay:         15,
		StartDate:          timestamppb.New(startDate),
		InterestCalcMethod: pb.InterestCalcMethod_INTEREST_CALC_MONTHLY,
	}

	calc := calcPrepaymentSchedule(prepaymentInput{
		loan:             loan,
		items:            items,
		prepaymentAmount: 10000,
		strategy:         pb.PrepaymentStrategy_PREPAYMENT_STRATEGY_REDUCE_MONTHS,
	})

	assert.Equal(t, int64(0), calc.newPrincipal)
	assert.Empty(t, calc.newSchedule)
	assert.Equal(t, int32(1), calc.newTotalMonths)
}

func TestCalcPrepaymentSchedule_PanicsOnUnknownStrategy(t *testing.T) {
	startDate := time.Date(2024, 1, 15, 0, 0, 0, 0, time.UTC)
	loan := &pb.Loan{
		Principal:          100000,
		RemainingPrincipal: 80000,
		AnnualRate:         4.0,
		TotalMonths:        12,
		PaidMonths:         2,
		RepaymentMethod:    pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
		PaymentDay:         15,
		StartDate:          timestamppb.New(startDate),
		InterestCalcMethod: pb.InterestCalcMethod_INTEREST_CALC_MONTHLY,
	}
	items := []*pb.LoanScheduleItem{
		{MonthNumber: 1, InterestPart: 100, IsPaid: true, DueDate: timestamppb.New(startDate.AddDate(0, 1, 0))},
		{MonthNumber: 2, InterestPart: 90, IsPaid: true, DueDate: timestamppb.New(startDate.AddDate(0, 2, 0))},
		{MonthNumber: 3, InterestPart: 80, IsPaid: false, DueDate: timestamppb.New(startDate.AddDate(0, 3, 0))},
	}

	assert.Panics(t, func() {
		calcPrepaymentSchedule(prepaymentInput{
			loan:             loan,
			items:            items,
			prepaymentAmount: 10000,
			strategy:         pb.PrepaymentStrategy(999),
		})
	})
}

func TestFindNextUnpaidDueDate(t *testing.T) {
	fallback := time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC)
	due3 := time.Date(2024, 3, 15, 0, 0, 0, 0, time.UTC)

	items := []*pb.LoanScheduleItem{
		{MonthNumber: 1, IsPaid: true, DueDate: timestamppb.New(time.Date(2024, 1, 15, 0, 0, 0, 0, time.UTC))},
		{MonthNumber: 2, IsPaid: true, DueDate: timestamppb.New(time.Date(2024, 2, 15, 0, 0, 0, 0, time.UTC))},
		{MonthNumber: 3, IsPaid: false, DueDate: timestamppb.New(due3)},
	}

	result := findNextUnpaidDueDate(items, fallback)
	assert.Equal(t, due3, result)

	// All paid → fallback
	allPaid := []*pb.LoanScheduleItem{
		{MonthNumber: 1, IsPaid: true, DueDate: timestamppb.New(time.Date(2024, 1, 15, 0, 0, 0, 0, time.UTC))},
	}
	result = findNextUnpaidDueDate(allPaid, fallback)
	assert.Equal(t, fallback, result)
}

func TestBuildScheduleProto_RelativeNumbering(t *testing.T) {
	calc := prepaymentCalcResult{
		newSchedule: []scheduleItem{
			{payment: 1000, principalPart: 800, interestPart: 200, remainingPrincipal: 9200, dueDate: time.Date(2024, 2, 15, 0, 0, 0, 0, time.UTC)},
			{payment: 1000, principalPart: 810, interestPart: 190, remainingPrincipal: 8390, dueDate: time.Date(2024, 3, 15, 0, 0, 0, 0, time.UTC)},
		},
	}

	// Relative (1-based for Simulate)
	relative := buildScheduleProto(calc, func(i int) int32 { return int32(i + 1) })
	require.Len(t, relative, 2)
	assert.Equal(t, int32(1), relative[0].MonthNumber)
	assert.Equal(t, int32(2), relative[1].MonthNumber)

	// Absolute (for Execute, e.g. paidMonths=12)
	absolute := buildScheduleProto(calc, func(i int) int32 { return int32(12+1+i) })
	require.Len(t, absolute, 2)
	assert.Equal(t, int32(13), absolute[0].MonthNumber)
	assert.Equal(t, int32(14), absolute[1].MonthNumber)

	// Both should have same payment data
	assert.Equal(t, relative[0].Payment, absolute[0].Payment)
}

func TestCalcReduceMonths_PanicsOnUnknownMethod(t *testing.T) {
	loan := &pb.Loan{
		Principal:   100000,
		AnnualRate:  4.0,
		TotalMonths: 12,
		PaidMonths:  2,
	}

	assert.Panics(t, func() {
		calcReduceMonths(loan, 80000, "progressive", "monthly", 15, time.Now())
	})
}
