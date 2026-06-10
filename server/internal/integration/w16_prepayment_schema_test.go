//go:build integration

package integration

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/familyledger/server/internal/loan"
	pbLoan "github.com/familyledger/server/proto/loan"
)

// ═══════════════════════════════════════════════════════════════════════════════
// W16: ExecutePrepayment against the REAL PostgreSQL schema.
//
// Regression guard for the bug where ExecutePrepayment's UPDATE referenced a
// nonexistent `monthly_payment` column on the loans table, which PG rejected
// with "column does not exist" → gRPC INTERNAL "failed to update loan".
//
// The mock-based unit tests (pgxmock) could not catch this: they only
// prefix-match the SQL and never validate column names against the real
// schema. These tests run the actual migrations, so any SQL that references a
// column the loans table doesn't have will fail here in CI.
// ═══════════════════════════════════════════════════════════════════════════════

func w16CreateLoan(t *testing.T, svc *loan.Service, ctx context.Context) *pbLoan.Loan {
	t.Helper()
	l, err := svc.CreateLoan(ctx, &pbLoan.CreateLoanRequest{
		Name:            "W16 Mortgage",
		LoanType:        pbLoan.LoanType_LOAN_TYPE_MORTGAGE,
		Principal:       100000000, // 100万 (分)
		AnnualRate:      4.2,
		TotalMonths:     360,
		RepaymentMethod: pbLoan.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
		PaymentDay:      15,
		StartDate:       timestamppb.New(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.NoError(t, err)
	require.NotEmpty(t, l.Id)
	return l
}

// W16-001: REDUCE_MONTHS prepayment succeeds against the real schema.
// This is the direct regression for the monthly_payment column bug.
func TestW16_ExecutePrepayment_ReduceMonths_RealSchema(t *testing.T) {
	db := getDB(t)
	ctx, _ := w7Ctx(t, db)
	svc := loan.NewService(db.pool)

	l := w16CreateLoan(t, svc, ctx)

	resp, err := svc.ExecutePrepayment(ctx, &pbLoan.ExecutePrepaymentRequest{
		LoanId:           l.Id,
		PrepaymentAmount: 20000000, // 提前还 20万
		Strategy:         pbLoan.PrepaymentStrategy_PREPAYMENT_STRATEGY_REDUCE_MONTHS,
	})
	require.NoError(t, err, "ExecutePrepayment must not fail against the real loans schema")
	require.NotNil(t, resp)
	require.NotNil(t, resp.Loan)
	assert.Equal(t, int64(80000000), resp.Loan.RemainingPrincipal)
	assert.Greater(t, resp.Simulation.InterestSaved, int64(0))
	assert.Greater(t, resp.Simulation.MonthsReduced, int32(0))

	// Verify the loan row was actually updated and re-readable.
	got, err := svc.GetLoan(ctx, &pbLoan.GetLoanRequest{LoanId: l.Id})
	require.NoError(t, err)
	assert.Equal(t, int64(80000000), got.RemainingPrincipal)

	t.Logf("W16-001 PASS: remaining=%d saved=%d monthsReduced=%d",
		resp.Loan.RemainingPrincipal, resp.Simulation.InterestSaved, resp.Simulation.MonthsReduced)
}

// W16-002: REDUCE_PAYMENT prepayment succeeds against the real schema.
func TestW16_ExecutePrepayment_ReducePayment_RealSchema(t *testing.T) {
	db := getDB(t)
	ctx, _ := w7Ctx(t, db)
	svc := loan.NewService(db.pool)

	l := w16CreateLoan(t, svc, ctx)

	resp, err := svc.ExecutePrepayment(ctx, &pbLoan.ExecutePrepaymentRequest{
		LoanId:           l.Id,
		PrepaymentAmount: 30000000,
		Strategy:         pbLoan.PrepaymentStrategy_PREPAYMENT_STRATEGY_REDUCE_PAYMENT,
	})
	require.NoError(t, err)
	require.NotNil(t, resp)
	assert.Equal(t, int64(70000000), resp.Loan.RemainingPrincipal)
	// REDUCE_PAYMENT keeps total months; monthly payment shrinks.
	assert.Greater(t, resp.Simulation.NewMonthlyPayment, int64(0))

	t.Logf("W16-002 PASS: remaining=%d newMonthly=%d",
		resp.Loan.RemainingPrincipal, resp.Simulation.NewMonthlyPayment)
}

// W16-003: Full payoff (prepayment >= remaining principal) succeeds.
// This is the exact scenario from the original bug report (总利息→¥0, 缩短).
func TestW16_ExecutePrepayment_FullPayoff_RealSchema(t *testing.T) {
	db := getDB(t)
	ctx, _ := w7Ctx(t, db)
	svc := loan.NewService(db.pool)

	l := w16CreateLoan(t, svc, ctx)

	resp, err := svc.ExecutePrepayment(ctx, &pbLoan.ExecutePrepaymentRequest{
		LoanId:           l.Id,
		PrepaymentAmount: 100000000, // 全额结清
		Strategy:         pbLoan.PrepaymentStrategy_PREPAYMENT_STRATEGY_REDUCE_MONTHS,
	})
	require.NoError(t, err)
	require.NotNil(t, resp)
	assert.Equal(t, int64(0), resp.Loan.RemainingPrincipal)
	assert.Empty(t, resp.NewSchedule, "fully paid-off loan should have no remaining schedule")

	got, err := svc.GetLoan(ctx, &pbLoan.GetLoanRequest{LoanId: l.Id})
	require.NoError(t, err)
	assert.Equal(t, int64(0), got.RemainingPrincipal)

	t.Logf("W16-003 PASS: full payoff, remaining=%d saved=%d",
		resp.Loan.RemainingPrincipal, resp.Simulation.InterestSaved)
}
