//go:build integration

package integration

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
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

// presetHousingExpenseCategoryID mirrors the seeded "居住" preset category
// (migration 032: UUIDv5(ns, "expense:居住")). Kept here independently so the
// test fails if production code drifts from the seed.
const w16PresetHousingCategoryID = "f925409c-19b9-5461-8a3d-5dc88e50efeb"

// W16-004: Prepayment on a loan WITH an account actually executes step 5
// (account deduction + resolveLoanRepaymentCategoryID + INSERT transaction).
//
// This is the path the previous W16 cases never hit (their loans had no
// AccountId, so the entire step 5 was gated out by `if loan.AccountId != ""`).
// It asserts a real expense transaction lands with the global preset "居住"
// category_id — catching any UUID-formula drift in resolveLoanRepaymentCategoryID.
func TestW16_ExecutePrepayment_WithAccount_RecordsTransaction_RealSchema(t *testing.T) {
	db := getDB(t)
	ctx, userIDStr := w7Ctx(t, db)
	svc := loan.NewService(db.pool)

	userID, err := uuid.Parse(userIDStr)
	require.NoError(t, err)
	acctID := createTestAccount(t, db, userID, "W16 Account", nil)

	// Sanity: the global preset "居住" category must be present (seeded by migration).
	var presetExists bool
	require.NoError(t, db.pool.QueryRow(context.Background(),
		`SELECT EXISTS(SELECT 1 FROM categories WHERE id = $1)`,
		w16PresetHousingCategoryID,
	).Scan(&presetExists))
	require.True(t, presetExists, "seeded 居住 preset category must exist")

	l, err := svc.CreateLoan(ctx, &pbLoan.CreateLoanRequest{
		Name:            "W16 Mortgage w/ account",
		LoanType:        pbLoan.LoanType_LOAN_TYPE_MORTGAGE,
		Principal:       100000000,
		AnnualRate:      4.2,
		TotalMonths:     360,
		RepaymentMethod: pbLoan.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
		PaymentDay:      15,
		StartDate:       timestamppb.New(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)),
		AccountId:       acctID.String(),
	})
	require.NoError(t, err)
	require.Equal(t, acctID.String(), l.AccountId)

	const prepay = int64(20000000)
	_, err = svc.ExecutePrepayment(ctx, &pbLoan.ExecutePrepaymentRequest{
		LoanId:           l.Id,
		PrepaymentAmount: prepay,
		Strategy:         pbLoan.PrepaymentStrategy_PREPAYMENT_STRATEGY_REDUCE_MONTHS,
	})
	require.NoError(t, err)

	// 1) A real expense transaction must have been inserted with the preset category.
	var txnCount int
	var gotCategoryID, gotType string
	var gotAmount int64
	err = db.pool.QueryRow(context.Background(),
		`SELECT count(*), max(category_id::text), max(type::text), max(amount)
		   FROM transactions WHERE account_id = $1`,
		acctID,
	).Scan(&txnCount, &gotCategoryID, &gotType, &gotAmount)
	require.NoError(t, err)
	require.Equal(t, 1, txnCount, "prepayment must create exactly one transaction record")
	assert.Equal(t, w16PresetHousingCategoryID, gotCategoryID,
		"transaction must use the global preset 居住 category (UUID-formula drift guard)")
	assert.Equal(t, "expense", gotType)
	assert.Equal(t, prepay, gotAmount)

	// 2) The account balance must have been deducted by the prepayment amount.
	var balance int64
	err = db.pool.QueryRow(context.Background(),
		`SELECT balance FROM accounts WHERE id = $1`, acctID,
	).Scan(&balance)
	require.NoError(t, err)
	assert.Equal(t, -prepay, balance, "account balance should be reduced by the prepayment")

	t.Logf("W16-004 PASS: txn count=%d category=%s amount=%d balance=%d",
		txnCount, gotCategoryID, gotAmount, balance)
}
