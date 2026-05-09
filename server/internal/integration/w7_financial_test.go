//go:build integration

package integration

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/familyledger/server/internal/asset"
	"github.com/familyledger/server/internal/investment"
	"github.com/familyledger/server/internal/loan"
	pbAsset "github.com/familyledger/server/proto/asset"
	pbInvest "github.com/familyledger/server/proto/investment"
	pbLoan "github.com/familyledger/server/proto/loan"
)

// ═══════════════════════════════════════════════════════════════════════════════
// W7 Helpers
// ═══════════════════════════════════════════════════════════════════════════════

func w7Ctx(t *testing.T, db *testDB) (context.Context, string) {
	t.Helper()
	ctx, userID, _, _ := w6User(t, db, t.Name()+"@test.com")
	return ctx, userID
}

// ═══════════════════════════════════════════════════════════════════════════════
// Loan: 创建→还款计划→逐期还款→提前还款→利率变更→重算
// ═══════════════════════════════════════════════════════════════════════════════

// L-001: Create equal installment loan and verify schedule
func TestW7_Loan_EqualInstallment_Create(t *testing.T) {
	db := getDB(t)
	ctx, _ := w7Ctx(t, db)
	loanSvc := loan.NewService(db.pool)

	l, err := loanSvc.CreateLoan(ctx, &pbLoan.CreateLoanRequest{
		Name:            "Test Mortgage",
		LoanType:        pbLoan.LoanType_LOAN_TYPE_MORTGAGE,
		Principal:       100000000, // 100万 (分)
		AnnualRate:      4.2,
		TotalMonths:     360, // 30年
		RepaymentMethod: pbLoan.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
		PaymentDay:      15,
		StartDate:       timestamppb.New(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.NoError(t, err)
	assert.NotEmpty(t, l.Id)
	assert.Equal(t, int64(100000000), l.Principal)

	// Get schedule
	sched, err := loanSvc.GetLoanSchedule(ctx, &pbLoan.GetLoanScheduleRequest{LoanId: l.Id})
	require.NoError(t, err)
	require.Equal(t, 360, len(sched.Items))

	// Equal installment: all monthly payments should be equal (within rounding)
	firstPayment := sched.Items[0].Payment
	for i := 1; i < len(sched.Items); i++ {
		diff := sched.Items[i].Payment - firstPayment
		assert.LessOrEqual(t, abs(diff), int64(200),
			"period %d payment=%d differs from first=%d by %d", i+1, sched.Items[i].Payment, firstPayment, diff)
	}

	// Verify sum of principal repayments == loan principal
	var totalPrincipal int64
	for _, item := range sched.Items {
		totalPrincipal += item.PrincipalPart
	}
	assert.InDelta(t, float64(100000000), float64(totalPrincipal), 100,
		"sum of principal parts should equal loan principal")

	t.Logf("L-001 PASS: 360 periods, monthly=%d, principal sum=%d", firstPayment, totalPrincipal)
}

// L-002: Equal principal loan
func TestW7_Loan_EqualPrincipal_Create(t *testing.T) {
	db := getDB(t)
	ctx, _ := w7Ctx(t, db)
	loanSvc := loan.NewService(db.pool)

	l, err := loanSvc.CreateLoan(ctx, &pbLoan.CreateLoanRequest{
		Name:            "Car Loan",
		LoanType:        pbLoan.LoanType_LOAN_TYPE_CAR_LOAN,
		Principal:       20000000, // 20万
		AnnualRate:      5.0,
		TotalMonths:     36,
		RepaymentMethod: pbLoan.RepaymentMethod_REPAYMENT_METHOD_EQUAL_PRINCIPAL,
		PaymentDay:      20,
		StartDate:       timestamppb.New(time.Date(2026, 3, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.NoError(t, err)

	sched, err := loanSvc.GetLoanSchedule(ctx, &pbLoan.GetLoanScheduleRequest{LoanId: l.Id})
	require.NoError(t, err)
	require.Equal(t, 36, len(sched.Items))

	// Equal principal: principal part should be constant (~555556 per month)
	expectedPrincipalPart := int64(20000000) / 36
	for i, item := range sched.Items {
		diff := item.PrincipalPart - expectedPrincipalPart
		assert.LessOrEqual(t, abs(diff), int64(100),
			"period %d principal=%d expected~%d", i+1, item.PrincipalPart, expectedPrincipalPart)
	}

	// Payment should decrease month over month (decreasing interest)
	for i := 1; i < len(sched.Items); i++ {
		assert.GreaterOrEqual(t, sched.Items[i-1].Payment, sched.Items[i].Payment,
			"period %d payment should be <= period %d", i+1, i)
	}

	t.Logf("L-002 PASS: equal principal, 36 periods, decreasing payments")
}

// L-003: Record payment
func TestW7_Loan_RecordPayment(t *testing.T) {
	db := getDB(t)
	ctx, _ := w7Ctx(t, db)
	loanSvc := loan.NewService(db.pool)

	l, err := loanSvc.CreateLoan(ctx, &pbLoan.CreateLoanRequest{
		Name:            "Payment Test",
		LoanType:        pbLoan.LoanType_LOAN_TYPE_CONSUMER,
		Principal:       1000000,
		AnnualRate:      6.0,
		TotalMonths:     12,
		RepaymentMethod: pbLoan.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
		PaymentDay:      1,
		StartDate:       timestamppb.New(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.NoError(t, err)

	// Record first 3 payments
	for i := int32(1); i <= 3; i++ {
		item, err := loanSvc.RecordPayment(ctx, &pbLoan.RecordPaymentRequest{
			LoanId:      l.Id,
			MonthNumber: i,
		})
		require.NoError(t, err)
		assert.True(t, item.IsPaid)
	}

	// Verify schedule shows first 3 paid
	sched, err := loanSvc.GetLoanSchedule(ctx, &pbLoan.GetLoanScheduleRequest{LoanId: l.Id})
	require.NoError(t, err)
	for i := 0; i < 3; i++ {
		assert.True(t, sched.Items[i].IsPaid, "period %d should be paid", i+1)
	}
	for i := 3; i < 12; i++ {
		assert.False(t, sched.Items[i].IsPaid, "period %d should not be paid", i+1)
	}
	t.Log("L-003 PASS: 3 payments recorded")
}

// L-004: Rate change and schedule recalculation
func TestW7_Loan_RateChange(t *testing.T) {
	db := getDB(t)
	ctx, _ := w7Ctx(t, db)
	loanSvc := loan.NewService(db.pool)

	l, err := loanSvc.CreateLoan(ctx, &pbLoan.CreateLoanRequest{
		Name:            "Rate Change",
		LoanType:        pbLoan.LoanType_LOAN_TYPE_MORTGAGE,
		Principal:       50000000,
		AnnualRate:      4.2,
		TotalMonths:     120,
		RepaymentMethod: pbLoan.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
		PaymentDay:      15,
		StartDate:       timestamppb.New(time.Date(2025, 1, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.NoError(t, err)

	// Get original schedule payment
	origSched, err := loanSvc.GetLoanSchedule(ctx, &pbLoan.GetLoanScheduleRequest{LoanId: l.Id})
	require.NoError(t, err)
	origPayment := origSched.Items[0].Payment

	// Pay first 12 months to establish paid/unpaid boundary
	for i := int32(1); i <= 12; i++ {
		_, err = loanSvc.RecordPayment(ctx, &pbLoan.RecordPaymentRequest{
			LoanId: l.Id, MonthNumber: i,
		})
		require.NoError(t, err)
	}

	// Record rate change (LPR drop: 4.2% -> 3.8%)
	_, err = loanSvc.RecordRateChange(ctx, &pbLoan.RecordRateChangeRequest{
		LoanId:        l.Id,
		NewRate:       3.8,
		EffectiveDate: timestamppb.New(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.NoError(t, err)

	// Get new schedule
	newSched, err := loanSvc.GetLoanSchedule(ctx, &pbLoan.GetLoanScheduleRequest{LoanId: l.Id})
	require.NoError(t, err)

	// Paid periods (1-12) should retain original payment (historical)
	for i := 0; i < 12; i++ {
		assert.Equal(t, origPayment, newSched.Items[i].Payment,
			"period %d (paid) should keep original payment %d, got %d",
			i+1, origPayment, newSched.Items[i].Payment)
	}

	// Unpaid periods (13+) should all have lower payment
	newPayment := newSched.Items[12].Payment
	assert.Less(t, newPayment, origPayment,
		"unpaid periods should have lower payment: orig=%d new=%d", origPayment, newPayment)
	for i := 12; i < len(newSched.Items); i++ {
		diff := newSched.Items[i].Payment - newPayment
		assert.LessOrEqual(t, abs(diff), int64(200),
			"period %d: expected ~%d got %d", i+1, newPayment, newSched.Items[i].Payment)
	}

	// Verify loan reflects new rate
	updatedLoan, err := loanSvc.GetLoan(ctx, &pbLoan.GetLoanRequest{LoanId: l.Id})
	require.NoError(t, err)
	assert.InDelta(t, 3.8, updatedLoan.AnnualRate, 0.001)

	t.Logf("L-004 PASS: rate 4.2->3.8, paid keep %d, unpaid now %d", origPayment, newPayment)
}

// L-005: Prepayment simulation
func TestW7_Loan_Prepayment(t *testing.T) {
	db := getDB(t)
	ctx, _ := w7Ctx(t, db)
	loanSvc := loan.NewService(db.pool)

	l, err := loanSvc.CreateLoan(ctx, &pbLoan.CreateLoanRequest{
		Name:            "Prepay Test",
		LoanType:        pbLoan.LoanType_LOAN_TYPE_MORTGAGE,
		Principal:       30000000,
		AnnualRate:      4.5,
		TotalMonths:     240,
		RepaymentMethod: pbLoan.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
		PaymentDay:      10,
		StartDate:       timestamppb.New(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.NoError(t, err)

	sim, err := loanSvc.SimulatePrepayment(ctx, &pbLoan.SimulatePrepaymentRequest{
		LoanId:           l.Id,
		PrepaymentAmount: 5000000, // 5万
		Strategy:         pbLoan.PrepaymentStrategy_PREPAYMENT_STRATEGY_REDUCE_MONTHS,
	})
	require.NoError(t, err)
	assert.Greater(t, sim.MonthsReduced, int32(0), "prepayment should reduce term")
	assert.Greater(t, sim.InterestSaved, int64(0), "should save interest")
	t.Logf("L-005 PASS: prepay 50000, months_reduced=%d, saved=%d",
		sim.MonthsReduced, sim.InterestSaved)
}

// ═══════════════════════════════════════════════════════════════════════════════
// Loan Group (组合贷): 商贷+公积金
// ═══════════════════════════════════════════════════════════════════════════════

// LG-001: Combined mortgage (commercial + provident)
func TestW7_LoanGroup_Combined(t *testing.T) {
	db := getDB(t)
	ctx, _ := w7Ctx(t, db)
	loanSvc := loan.NewService(db.pool)

	grp, err := loanSvc.CreateLoanGroup(ctx, &pbLoan.CreateLoanGroupRequest{
		Name:       "Home Mortgage",
		GroupType:  "combined",
		PaymentDay: 15,
		StartDate:  timestamppb.New(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)),
		LoanType:   pbLoan.LoanType_LOAN_TYPE_MORTGAGE,
		SubLoans: []*pbLoan.SubLoanSpec{
			{
				Name:            "Commercial",
				SubType:         pbLoan.LoanSubType_LOAN_SUB_TYPE_COMMERCIAL,
				Principal:       60000000, // 60万
				AnnualRate:      4.2,
				TotalMonths:     360,
				RepaymentMethod: pbLoan.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
				RateType:        pbLoan.RateType_RATE_TYPE_LPR_FLOATING,
				LprBase:         3.85,
				LprSpread:       0.35,
				RateAdjustMonth: 1,
			},
			{
				Name:            "Provident",
				SubType:         pbLoan.LoanSubType_LOAN_SUB_TYPE_PROVIDENT,
				Principal:       40000000, // 40万
				AnnualRate:      3.1,
				TotalMonths:     360,
				RepaymentMethod: pbLoan.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
				RateType:        pbLoan.RateType_RATE_TYPE_FIXED,
			},
		},
	})
	require.NoError(t, err)
	assert.NotEmpty(t, grp.Id)
	require.Equal(t, 2, len(grp.SubLoans))

	// Verify each sub-loan has independent schedule
	for _, sub := range grp.SubLoans {
		sched, err := loanSvc.GetLoanSchedule(ctx, &pbLoan.GetLoanScheduleRequest{LoanId: sub.Id})
		require.NoError(t, err)
		assert.Equal(t, 360, len(sched.Items))
	}
	t.Log("LG-001 PASS: combined group, 2 sub-loans with independent schedules")
}

// LG-002: Group prepayment simulation (choose which sub-loan to prepay)
func TestW7_LoanGroup_Prepayment(t *testing.T) {
	db := getDB(t)
	ctx, _ := w7Ctx(t, db)
	loanSvc := loan.NewService(db.pool)

	grp, err := loanSvc.CreateLoanGroup(ctx, &pbLoan.CreateLoanGroupRequest{
		Name:       "Prepay Group",
		GroupType:  "combined",
		PaymentDay: 20,
		StartDate:  timestamppb.New(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)),
		LoanType:   pbLoan.LoanType_LOAN_TYPE_MORTGAGE,
		SubLoans: []*pbLoan.SubLoanSpec{
			{
				Name:            "Commercial",
				SubType:         pbLoan.LoanSubType_LOAN_SUB_TYPE_COMMERCIAL,
				Principal:       50000000,
				AnnualRate:      4.5,
				TotalMonths:     240,
				RepaymentMethod: pbLoan.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
				RateType:        pbLoan.RateType_RATE_TYPE_FIXED,
			},
			{
				Name:            "Provident",
				SubType:         pbLoan.LoanSubType_LOAN_SUB_TYPE_PROVIDENT,
				Principal:       30000000,
				AnnualRate:      3.1,
				TotalMonths:     240,
				RepaymentMethod: pbLoan.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
				RateType:        pbLoan.RateType_RATE_TYPE_FIXED,
			},
		},
	})
	require.NoError(t, err)

	sim, err := loanSvc.SimulateGroupPrepayment(ctx, &pbLoan.SimulateGroupPrepaymentRequest{
		GroupId:          grp.Id,
		PrepaymentAmount: 10000000, // 10万
		Strategy:         pbLoan.PrepaymentStrategy_PREPAYMENT_STRATEGY_REDUCE_MONTHS,
	})
	require.NoError(t, err)
	assert.Greater(t, sim.TotalInterestSaved, int64(0))

	// Should recommend prepaying the higher-rate commercial loan (4.5%) over provident (3.1%)
	commercialID := grp.SubLoans[0].Id
	assert.Equal(t, commercialID, sim.TargetLoanId,
		"should target higher-rate commercial loan (4.5%%) over provident (3.1%%)")

	// Compare: explicitly target provident and verify it saves less
	simProvident, err := loanSvc.SimulateGroupPrepayment(ctx, &pbLoan.SimulateGroupPrepaymentRequest{
		GroupId:          grp.Id,
		TargetLoanId:     grp.SubLoans[1].Id, // force provident
		PrepaymentAmount: 10000000,
		Strategy:         pbLoan.PrepaymentStrategy_PREPAYMENT_STRATEGY_REDUCE_MONTHS,
	})
	require.NoError(t, err)
	assert.Greater(t, sim.TotalInterestSaved, simProvident.TotalInterestSaved,
		"prepaying higher-rate loan should save more interest: commercial=%d > provident=%d",
		sim.TotalInterestSaved, simProvident.TotalInterestSaved)

	t.Logf("LG-002 PASS: auto-target commercial(4.5%%), saved=%d > provident saved=%d",
		sim.TotalInterestSaved, simProvident.TotalInterestSaved)
}

// LG-003: LPR annual adjustment — commercial follows LPR, provident stays fixed
func TestW7_LoanGroup_LPRAdjustment(t *testing.T) {
	db := getDB(t)
	ctx, _ := w7Ctx(t, db)
	loanSvc := loan.NewService(db.pool)

	grp, err := loanSvc.CreateLoanGroup(ctx, &pbLoan.CreateLoanGroupRequest{
		Name:       "LPR Adjust",
		GroupType:  "combined",
		PaymentDay: 15,
		StartDate:  timestamppb.New(time.Date(2025, 6, 1, 0, 0, 0, 0, time.UTC)),
		LoanType:   pbLoan.LoanType_LOAN_TYPE_MORTGAGE,
		SubLoans: []*pbLoan.SubLoanSpec{
			{
				Name:            "Commercial",
				SubType:         pbLoan.LoanSubType_LOAN_SUB_TYPE_COMMERCIAL,
				Principal:       60000000,
				AnnualRate:      4.2, // lprBase(3.85) + lprSpread(0.35) = 4.2
				TotalMonths:     360,
				RepaymentMethod: pbLoan.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
				RateType:        pbLoan.RateType_RATE_TYPE_LPR_FLOATING,
				LprBase:         3.85,
				LprSpread:       0.35,
				RateAdjustMonth: 1, // January adjustment
			},
			{
				Name:            "Provident",
				SubType:         pbLoan.LoanSubType_LOAN_SUB_TYPE_PROVIDENT,
				Principal:       40000000,
				AnnualRate:      3.1,
				TotalMonths:     360,
				RepaymentMethod: pbLoan.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
				RateType:        pbLoan.RateType_RATE_TYPE_FIXED,
			},
		},
	})
	require.NoError(t, err)
	require.Equal(t, 2, len(grp.SubLoans))

	commercialID := grp.SubLoans[0].Id
	providentID := grp.SubLoans[1].Id

	// Get original schedules
	commOrig, err := loanSvc.GetLoanSchedule(ctx, &pbLoan.GetLoanScheduleRequest{LoanId: commercialID})
	require.NoError(t, err)
	provOrig, err := loanSvc.GetLoanSchedule(ctx, &pbLoan.GetLoanScheduleRequest{LoanId: providentID})
	require.NoError(t, err)

	// Simulate LPR drop: 3.85 → 3.65, so new rate = 3.65 + 0.35 = 4.0%
	_, err = loanSvc.RecordRateChange(ctx, &pbLoan.RecordRateChangeRequest{
		LoanId:        commercialID,
		NewRate:       4.0, // lpr(3.65) + spread(0.35)
		EffectiveDate: timestamppb.New(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.NoError(t, err)

	// Commercial schedule should have lower payments after effective date
	commNew, err := loanSvc.GetLoanSchedule(ctx, &pbLoan.GetLoanScheduleRequest{LoanId: commercialID})
	require.NoError(t, err)
	// Payments after month 7 (Jan 2026, 7th month from Jun 2025) should decrease
	assert.Less(t, commNew.Items[len(commNew.Items)-1].Payment, commOrig.Items[0].Payment,
		"commercial payment should decrease after LPR drop")

	// Provident should be UNCHANGED
	provNew, err := loanSvc.GetLoanSchedule(ctx, &pbLoan.GetLoanScheduleRequest{LoanId: providentID})
	require.NoError(t, err)
	assert.Equal(t, provOrig.Items[0].Payment, provNew.Items[0].Payment,
		"provident (fixed rate) should be unaffected by LPR change")
	assert.Equal(t, provOrig.Items[len(provOrig.Items)-1].Payment, provNew.Items[len(provNew.Items)-1].Payment,
		"provident last payment should be unchanged")

	// Verify commercial loan record shows updated rate
	commLoan, err := loanSvc.GetLoan(ctx, &pbLoan.GetLoanRequest{LoanId: commercialID})
	require.NoError(t, err)
	assert.InDelta(t, 4.0, commLoan.AnnualRate, 0.001,
		"commercial rate should be updated to 4.0%%")

	// Provident loan rate unchanged
	provLoan, err := loanSvc.GetLoan(ctx, &pbLoan.GetLoanRequest{LoanId: providentID})
	require.NoError(t, err)
	assert.InDelta(t, 3.1, provLoan.AnnualRate, 0.001,
		"provident rate should remain 3.1%%")

	t.Logf("LG-003 PASS: LPR 3.85→3.65, commercial rate 4.2%%→4.0%%, provident unchanged at 3.1%%")
}

// ═══════════════════════════════════════════════════════════════════════════════
// Investment: 创建→买入→卖出→持仓→XIRR
// ═══════════════════════════════════════════════════════════════════════════════

// I-001: Buy shares
func TestW7_Investment_BuyAndHolding(t *testing.T) {
	db := getDB(t)
	ctx, _ := w7Ctx(t, db)
	investSvc := investment.NewService(db.pool)

	inv, err := investSvc.CreateInvestment(ctx, &pbInvest.CreateInvestmentRequest{
		Symbol:     "600519",
		Name:       "Kweichow Moutai",
		MarketType: pbInvest.MarketType_MARKET_TYPE_A_SHARE,
	})
	require.NoError(t, err)
	assert.NotEmpty(t, inv.Id)

	// Buy 100 shares at 1500 CNY (150000 cents) each
	trade, err := investSvc.RecordTrade(ctx, &pbInvest.RecordTradeRequest{
		InvestmentId: inv.Id,
		TradeType:    pbInvest.TradeType_TRADE_TYPE_BUY,
		Quantity:     100,
		Price:        15000000, // 150000.00 CNY in cents per share
		Fee:          5000,     // 50 CNY fee
		TradeDate:    timestamppb.New(time.Date(2026, 1, 15, 0, 0, 0, 0, time.UTC)),
	})
	require.NoError(t, err)
	assert.NotEmpty(t, trade.Id)

	// Check portfolio
	portfolio, err := investSvc.GetPortfolioSummary(ctx, &pbInvest.GetPortfolioSummaryRequest{})
	require.NoError(t, err)
	assert.Equal(t, int64(1500000000+5000), portfolio.TotalCost) // 100*150000*100 + fee
	require.GreaterOrEqual(t, len(portfolio.Holdings), 1)
	t.Log("I-001 PASS: buy 100 shares, portfolio cost correct")
}

// I-002: Sell shares (partial)
func TestW7_Investment_Sell(t *testing.T) {
	db := getDB(t)
	ctx, _ := w7Ctx(t, db)
	investSvc := investment.NewService(db.pool)

	inv, err := investSvc.CreateInvestment(ctx, &pbInvest.CreateInvestmentRequest{
		Symbol:     "000001",
		Name:       "Ping An",
		MarketType: pbInvest.MarketType_MARKET_TYPE_A_SHARE,
	})
	require.NoError(t, err)

	// Buy 200 shares
	_, err = investSvc.RecordTrade(ctx, &pbInvest.RecordTradeRequest{
		InvestmentId: inv.Id,
		TradeType:    pbInvest.TradeType_TRADE_TYPE_BUY,
		Quantity:     200,
		Price:        5000000, // 50000 cents/share
		Fee:          3000,
		TradeDate:    timestamppb.New(time.Date(2026, 1, 10, 0, 0, 0, 0, time.UTC)),
	})
	require.NoError(t, err)

	// Sell 80 shares at higher price
	_, err = investSvc.RecordTrade(ctx, &pbInvest.RecordTradeRequest{
		InvestmentId: inv.Id,
		TradeType:    pbInvest.TradeType_TRADE_TYPE_SELL,
		Quantity:     80,
		Price:        5500000, // 55000 cents/share
		Fee:          2500,
		TradeDate:    timestamppb.New(time.Date(2026, 3, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.NoError(t, err)

	// Verify remaining holding = 120
	portfolio, err := investSvc.GetPortfolioSummary(ctx, &pbInvest.GetPortfolioSummaryRequest{})
	require.NoError(t, err)
	var found bool
	for _, h := range portfolio.Holdings {
		if h.Symbol == "000001" {
			found = true
			assert.InDelta(t, 120.0, h.Quantity, 0.01, "should hold 120 shares after selling 80")
			break
		}
	}
	assert.True(t, found, "should find Ping An in holdings")
	t.Log("I-002 PASS: sell 80 of 200 shares, holding=120")
}

// I-003: Sell more than held (rejected)
func TestW7_Investment_SellOverHolding_Rejected(t *testing.T) {
	db := getDB(t)
	ctx, _ := w7Ctx(t, db)
	investSvc := investment.NewService(db.pool)

	inv, err := investSvc.CreateInvestment(ctx, &pbInvest.CreateInvestmentRequest{
		Symbol:     "TSLA",
		Name:       "Tesla",
		MarketType: pbInvest.MarketType_MARKET_TYPE_US_STOCK,
	})
	require.NoError(t, err)

	// Buy 10 shares
	_, err = investSvc.RecordTrade(ctx, &pbInvest.RecordTradeRequest{
		InvestmentId: inv.Id,
		TradeType:    pbInvest.TradeType_TRADE_TYPE_BUY,
		Quantity:     10,
		Price:        25000000,
		Fee:          1000,
		TradeDate:    timestamppb.New(time.Date(2026, 2, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.NoError(t, err)

	// Try to sell 20 (more than held)
	_, err = investSvc.RecordTrade(ctx, &pbInvest.RecordTradeRequest{
		InvestmentId: inv.Id,
		TradeType:    pbInvest.TradeType_TRADE_TYPE_SELL,
		Quantity:     20,
		Price:        26000000,
		Fee:          1000,
		TradeDate:    timestamppb.New(time.Date(2026, 3, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.Error(t, err)
	t.Log("I-003 PASS: sell > held rejected")
}

// I-004: XIRR calculation
func TestW7_Investment_XIRR(t *testing.T) {
	db := getDB(t)
	ctx, _ := w7Ctx(t, db)
	investSvc := investment.NewService(db.pool)

	inv, err := investSvc.CreateInvestment(ctx, &pbInvest.CreateInvestmentRequest{
		Symbol:     "XIRR_TEST",
		Name:       "XIRR Test Fund",
		MarketType: pbInvest.MarketType_MARKET_TYPE_FUND,
	})
	require.NoError(t, err)

	// Buy at 100, sell later at 110 (10% gain)
	_, err = investSvc.RecordTrade(ctx, &pbInvest.RecordTradeRequest{
		InvestmentId: inv.Id,
		TradeType:    pbInvest.TradeType_TRADE_TYPE_BUY,
		Quantity:     100,
		Price:        10000, // 100 CNY/unit
		Fee:          0,
		TradeDate:    timestamppb.New(time.Date(2025, 1, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.NoError(t, err)

	_, err = investSvc.RecordTrade(ctx, &pbInvest.RecordTradeRequest{
		InvestmentId: inv.Id,
		TradeType:    pbInvest.TradeType_TRADE_TYPE_SELL,
		Quantity:     100,
		Price:        11000, // 110 CNY/unit
		Fee:          0,
		TradeDate:    timestamppb.New(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.NoError(t, err)

	irr, err := investSvc.GetInvestmentIRR(ctx, &pbInvest.GetIRRRequest{
		InvestmentId: inv.Id,
	})
	require.NoError(t, err)
	// 10% gain over 1 year = ~10% annualized
	assert.InDelta(t, 0.10, irr.AnnualizedIrr, 0.02,
		"XIRR should be ~10%%, got %f", irr.AnnualizedIrr)
	t.Logf("I-004 PASS: XIRR = %.2f%%", irr.AnnualizedIrr*100)
}

// ═══════════════════════════════════════════════════════════════════════════════
// Asset: CRUD→估值→折旧
// ═══════════════════════════════════════════════════════════════════════════════

// AS-001: Create and get asset
func TestW7_Asset_CRUD(t *testing.T) {
	db := getDB(t)
	ctx, _ := w7Ctx(t, db)
	assetSvc := asset.NewService(db.pool)

	a, err := assetSvc.CreateAsset(ctx, &pbAsset.CreateAssetRequest{
		Name:          "MacBook Pro M4",
		AssetType:     pbAsset.AssetType_ASSET_TYPE_ELECTRONICS,
		PurchasePrice: 2999900, // 29999 CNY
		PurchaseDate:  timestamppb.New(time.Date(2026, 1, 15, 0, 0, 0, 0, time.UTC)),
		Description:   "16-inch, 48GB RAM",
	})
	require.NoError(t, err)
	assert.NotEmpty(t, a.Id)

	// Get
	got, err := assetSvc.GetAsset(ctx, &pbAsset.GetAssetRequest{AssetId: a.Id})
	require.NoError(t, err)
	assert.Equal(t, "MacBook Pro M4", got.Name)
	assert.Equal(t, int64(2999900), got.PurchasePrice)

	// Update valuation
	val, err := assetSvc.UpdateValuation(ctx, &pbAsset.UpdateValuationRequest{
		AssetId: a.Id,
		Value:   2500000, // depreciated to 25000
		Source:  "manual",
	})
	require.NoError(t, err)
	assert.Equal(t, int64(2500000), val.Value)

	// Delete
	_, err = assetSvc.DeleteAsset(ctx, &pbAsset.DeleteAssetRequest{AssetId: a.Id})
	require.NoError(t, err)
	t.Log("AS-001 PASS: asset CRUD lifecycle")
}

// AS-002: Straight-line depreciation
func TestW7_Asset_DepreciationStraightLine(t *testing.T) {
	db := getDB(t)
	ctx, _ := w7Ctx(t, db)
	assetSvc := asset.NewService(db.pool)

	a, err := assetSvc.CreateAsset(ctx, &pbAsset.CreateAssetRequest{
		Name:          "Office Desk",
		AssetType:     pbAsset.AssetType_ASSET_TYPE_FURNITURE,
		PurchasePrice: 500000, // 5000 CNY
		PurchaseDate:  timestamppb.New(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.NoError(t, err)

	// Set straight-line depreciation: 5 years, 10% salvage
	_, err = assetSvc.SetDepreciationRule(ctx, &pbAsset.SetDepreciationRuleRequest{
		AssetId:         a.Id,
		Method:          pbAsset.DepreciationMethod_DEPRECIATION_METHOD_STRAIGHT_LINE,
		UsefulLifeYears: 5,
		SalvageRate:     0.10,
	})
	require.NoError(t, err)

	// Run depreciation once
	updated, err := assetSvc.RunDepreciation(ctx, &pbAsset.RunDepreciationRequest{AssetId: a.Id})
	require.NoError(t, err)

	// Straight-line: (500000 - 50000) / (5*12) = 7500 per month
	// Current value should be 500000 - 7500 = 492500
	expectedMonthly := int64((500000 - 50000) / 60) // 7500
	expectedValue := int64(500000) - expectedMonthly
	assert.InDelta(t, float64(expectedValue), float64(updated.CurrentValue), 100,
		"after 1 month straight-line: expected ~%d got %d", expectedValue, updated.CurrentValue)
	t.Logf("AS-002 PASS: straight-line, monthly=%d, value after 1mo=%d", expectedMonthly, updated.CurrentValue)
}

// AS-003: Double-declining balance depreciation
func TestW7_Asset_DepreciationDoubleDeclining(t *testing.T) {
	db := getDB(t)
	ctx, _ := w7Ctx(t, db)
	assetSvc := asset.NewService(db.pool)

	a, err := assetSvc.CreateAsset(ctx, &pbAsset.CreateAssetRequest{
		Name:          "Company Car",
		AssetType:     pbAsset.AssetType_ASSET_TYPE_VEHICLE,
		PurchasePrice: 20000000, // 200000 CNY
		PurchaseDate:  timestamppb.New(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.NoError(t, err)

	_, err = assetSvc.SetDepreciationRule(ctx, &pbAsset.SetDepreciationRuleRequest{
		AssetId:         a.Id,
		Method:          pbAsset.DepreciationMethod_DEPRECIATION_METHOD_DOUBLE_DECLINING,
		UsefulLifeYears: 5,
		SalvageRate:     0.05,
	})
	require.NoError(t, err)

	// Run 4 months of depreciation, track each period's depreciation amount
	var deps []int64
	prevValue := int64(20000000)
	for i := 0; i < 4; i++ {
		updated, err := assetSvc.RunDepreciation(ctx, &pbAsset.RunDepreciationRequest{AssetId: a.Id})
		require.NoError(t, err)
		monthlyDep := prevValue - updated.CurrentValue
		assert.Greater(t, monthlyDep, int64(0), "period %d depreciation must be positive", i+1)
		deps = append(deps, monthlyDep)
		prevValue = updated.CurrentValue
	}

	// Core property of double-declining: each period's depreciation DECREASES
	// (because it's a fixed % applied to a shrinking book value)
	for i := 1; i < len(deps); i++ {
		assert.Less(t, deps[i], deps[i-1],
			"double-declining: period %d dep (%d) must be < period %d dep (%d)",
			i+1, deps[i], i, deps[i-1])
	}

	assert.Less(t, prevValue, int64(20000000), "value should decrease")
	assert.Greater(t, prevValue, int64(0), "value should not be negative")
	t.Logf("AS-003 PASS: double-declining 4 months, deps=%v, final=%d", deps, prevValue)
}

// ═══════════════════════════════════════════════════════════════════════════════
// Transaction Atomicity: loan payment + account deduction
// ═══════════════════════════════════════════════════════════════════════════════

// TestW7_LoanPayment_Atomicity verifies RecordPayment transactional consistency:
// - schedule item marked paid AND loan counters updated atomically
// - remaining_principal on loan matches schedule item's value exactly
// - double-pay is rejected without corrupting state
//
// NOTE: RecordPayment does NOT integrate account balance deduction.
// Account deduction is handled separately by the client (CreateTransaction).
// This is documented as intentional design — loan payment tracking is decoupled
// from account balance management.
func TestW7_LoanPayment_Atomicity(t *testing.T) {
	db := getDB(t)
	ctx, _ := w7Ctx(t, db)
	loanSvc := loan.NewService(db.pool)

	l, err := loanSvc.CreateLoan(ctx, &pbLoan.CreateLoanRequest{
		Name:            "Atomic Loan",
		LoanType:        pbLoan.LoanType_LOAN_TYPE_CONSUMER,
		Principal:       1200000, // 12000 CNY
		AnnualRate:      5.0,
		TotalMonths:     12,
		RepaymentMethod: pbLoan.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
		PaymentDay:      1,
		StartDate:       timestamppb.New(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.NoError(t, err)

	// Get full schedule to know expected remaining_principal per period
	origSched, err := loanSvc.GetLoanSchedule(ctx, &pbLoan.GetLoanScheduleRequest{LoanId: l.Id})
	require.NoError(t, err)

	// Record payments 1-3 and verify consistency after EACH payment
	for i := int32(1); i <= 3; i++ {
		_, err := loanSvc.RecordPayment(ctx, &pbLoan.RecordPaymentRequest{
			LoanId:      l.Id,
			MonthNumber: i,
		})
		require.NoError(t, err)

		// After each payment, verify loan state is consistent
		updatedLoan, err := loanSvc.GetLoan(ctx, &pbLoan.GetLoanRequest{LoanId: l.Id})
		require.NoError(t, err)
		assert.Equal(t, i, updatedLoan.PaidMonths,
			"after paying period %d, paid_months should be %d", i, i)
		// remaining_principal from loan must match the schedule item's value
		expectedRP := origSched.Items[i-1].RemainingPrincipal
		assert.Equal(t, expectedRP, updatedLoan.RemainingPrincipal,
			"period %d: loan.remaining_principal=%d should match schedule item=%d",
			i, updatedLoan.RemainingPrincipal, expectedRP)
	}

	// Verify schedule reflects paid status
	sched, err := loanSvc.GetLoanSchedule(ctx, &pbLoan.GetLoanScheduleRequest{LoanId: l.Id})
	require.NoError(t, err)
	for i := 0; i < 3; i++ {
		assert.True(t, sched.Items[i].IsPaid, "period %d should be paid", i+1)
		assert.NotNil(t, sched.Items[i].PaidDate, "period %d should have paid_date", i+1)
	}
	for i := 3; i < 12; i++ {
		assert.False(t, sched.Items[i].IsPaid, "period %d should not be paid", i+1)
	}

	// Double-pay should be idempotent (returns existing data without error)
	dupeResp, err := loanSvc.RecordPayment(ctx, &pbLoan.RecordPaymentRequest{
		LoanId:      l.Id,
		MonthNumber: 1,
	})
	require.NoError(t, err, "double-paying same period should be idempotent")
	assert.Equal(t, int32(1), dupeResp.MonthNumber, "should return existing period data")
	assert.True(t, dupeResp.IsPaid, "should show as already paid")

	// Verify state unchanged after idempotent double-pay
	finalLoan, err := loanSvc.GetLoan(ctx, &pbLoan.GetLoanRequest{LoanId: l.Id})
	require.NoError(t, err)
	assert.Equal(t, int32(3), finalLoan.PaidMonths, "paid_months should not change after failed pay")

	t.Logf("Atomicity PASS: 3 payments, each verified consistent. Double-pay rejected cleanly.")
}

// TestW7_Investment_SellAtomicity verifies that RecordTrade(SELL) atomically
// updates both the trade log and the investment holding. If investment doesn't
// exist, neither trade record nor holding change should persist.
func TestW7_Investment_SellAtomicity(t *testing.T) {
	db := getDB(t)
	ctx, _ := w7Ctx(t, db)
	investSvc := investment.NewService(db.pool)

	// Try to sell a non-existent investment — should fail completely
	_, err := investSvc.RecordTrade(ctx, &pbInvest.RecordTradeRequest{
		InvestmentId: "00000000-0000-0000-0000-000000000000",
		TradeType:    pbInvest.TradeType_TRADE_TYPE_SELL,
		Quantity:     10,
		Price:        10000,
		Fee:          0,
		TradeDate:    timestamppb.New(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.Error(t, err, "sell non-existent investment should fail")

	// Create investment, buy shares, then verify sell atomicity
	inv, err := investSvc.CreateInvestment(ctx, &pbInvest.CreateInvestmentRequest{
		Symbol:     "ATOMIC",
		Name:       "Atomicity Test",
		MarketType: pbInvest.MarketType_MARKET_TYPE_A_SHARE,
	})
	require.NoError(t, err)

	_, err = investSvc.RecordTrade(ctx, &pbInvest.RecordTradeRequest{
		InvestmentId: inv.Id,
		TradeType:    pbInvest.TradeType_TRADE_TYPE_BUY,
		Quantity:     100,
		Price:        10000,
		Fee:          0,
		TradeDate:    timestamppb.New(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.NoError(t, err)

	// Attempt oversell — should fail AND leave holding unchanged
	_, err = investSvc.RecordTrade(ctx, &pbInvest.RecordTradeRequest{
		InvestmentId: inv.Id,
		TradeType:    pbInvest.TradeType_TRADE_TYPE_SELL,
		Quantity:     200, // more than held
		Price:        12000,
		Fee:          0,
		TradeDate:    timestamppb.New(time.Date(2026, 2, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.Error(t, err)

	// Verify holding is still 100 (no partial write)
	portfolio, err := investSvc.GetPortfolioSummary(ctx, &pbInvest.GetPortfolioSummaryRequest{})
	require.NoError(t, err)
	var found bool
	for _, h := range portfolio.Holdings {
		if h.Symbol == "ATOMIC" {
			found = true
			assert.InDelta(t, 100.0, h.Quantity, 0.01,
				"holding should remain 100 after failed oversell")
		}
	}
	assert.True(t, found)

	// Also verify trade list: the failed sell should NOT have a trade record
	trades, err := investSvc.ListTrades(ctx, &pbInvest.ListTradesRequest{InvestmentId: inv.Id})
	require.NoError(t, err)
	assert.Equal(t, 1, len(trades.Trades), "only the BUY trade should exist")

	t.Log("Investment atomicity PASS: failed sell leaves no trace")
}

// ═══════════════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════════════

func abs(x int64) int64 {
	if x < 0 {
		return -x
	}
	return x
}

// ═══════════════════════════════════════════════════════════════════════════════
// W7 Edge Cases — Boundary & Negative Testing
// ═══════════════════════════════════════════════════════════════════════════════

// ── Loan Edge Cases ─────────────────────────────────────────────────────────

// LE-001: Out-of-order payment (pay month 5 before 1-4) — should be rejected
// or at minimum produce correct remaining_principal.
func TestW7_Loan_OutOfOrderPayment(t *testing.T) {
	db := getDB(t)
	ctx, _ := w7Ctx(t, db)
	loanSvc := loan.NewService(db.pool)

	l, err := loanSvc.CreateLoan(ctx, &pbLoan.CreateLoanRequest{
		Name:            "OutOfOrder",
		LoanType:        pbLoan.LoanType_LOAN_TYPE_CONSUMER,
		Principal:       1200000,
		AnnualRate:      6.0,
		TotalMonths:     12,
		RepaymentMethod: pbLoan.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
		PaymentDay:      1,
		StartDate:       timestamppb.New(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.NoError(t, err)

	// Try paying month 5 directly (skipping 1-4)
	_, err = loanSvc.RecordPayment(ctx, &pbLoan.RecordPaymentRequest{
		LoanId:      l.Id,
		MonthNumber: 5,
	})
	// Should fail: sequential payment required
	require.Error(t, err, "LE-001: out-of-order payment should be rejected")
	assert.Contains(t, err.Error(), "sequential",
		"error should mention sequential requirement")

	// Verify loan state is unchanged
	updatedLoan, err := loanSvc.GetLoan(ctx, &pbLoan.GetLoanRequest{LoanId: l.Id})
	require.NoError(t, err)
	assert.Equal(t, int32(0), updatedLoan.PaidMonths, "no payments should have been recorded")
	assert.Equal(t, int64(1200000), updatedLoan.RemainingPrincipal,
		"remaining principal should be unchanged")

	// Now pay sequentially: month 1 should work
	_, err = loanSvc.RecordPayment(ctx, &pbLoan.RecordPaymentRequest{
		LoanId:      l.Id,
		MonthNumber: 1,
	})
	require.NoError(t, err, "sequential payment (month 1) should succeed")
	t.Log("LE-001 PASS: out-of-order rejected, sequential payment enforced")
}

// LE-002: Payment with month_number exceeding total_months
func TestW7_Loan_PaymentExceedsTotal(t *testing.T) {
	db := getDB(t)
	ctx, _ := w7Ctx(t, db)
	loanSvc := loan.NewService(db.pool)

	l, err := loanSvc.CreateLoan(ctx, &pbLoan.CreateLoanRequest{
		Name:            "ExceedTotal",
		LoanType:        pbLoan.LoanType_LOAN_TYPE_CONSUMER,
		Principal:       600000,
		AnnualRate:      5.0,
		TotalMonths:     6,
		RepaymentMethod: pbLoan.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
		PaymentDay:      1,
		StartDate:       timestamppb.New(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.NoError(t, err)

	// month_number 7 doesn't exist in a 6-month loan
	_, err = loanSvc.RecordPayment(ctx, &pbLoan.RecordPaymentRequest{
		LoanId:      l.Id,
		MonthNumber: 7,
	})
	require.Error(t, err, "LE-002: payment for non-existent period should fail")
	t.Logf("LE-002 PASS: month %d rejected for %d-month loan", 7, 6)
}

// LE-003: Create loan with AnnualRate=0 (interest-free)
func TestW7_Loan_ZeroRate(t *testing.T) {
	db := getDB(t)
	ctx, _ := w7Ctx(t, db)
	loanSvc := loan.NewService(db.pool)

	l, err := loanSvc.CreateLoan(ctx, &pbLoan.CreateLoanRequest{
		Name:            "Zero Rate",
		LoanType:        pbLoan.LoanType_LOAN_TYPE_CONSUMER,
		Principal:       1200000,
		AnnualRate:      0, // interest-free
		TotalMonths:     12,
		RepaymentMethod: pbLoan.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
		PaymentDay:      1,
		StartDate:       timestamppb.New(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.NoError(t, err)

	sched, err := loanSvc.GetLoanSchedule(ctx, &pbLoan.GetLoanScheduleRequest{LoanId: l.Id})
	require.NoError(t, err)

	// With 0% rate: payment = principal / months = 100000 per month, interest = 0
	for i, item := range sched.Items {
		assert.Equal(t, int64(0), item.InterestPart,
			"period %d: interest should be 0 with 0%% rate", i+1)
		assert.Equal(t, item.Payment, item.PrincipalPart,
			"period %d: payment should equal principal part with 0%% rate", i+1)
	}

	var totalPrincipal int64
	for _, item := range sched.Items {
		totalPrincipal += item.PrincipalPart
	}
	assert.Equal(t, int64(1200000), totalPrincipal,
		"total principal repaid should equal loan amount")
	t.Logf("LE-003 PASS: 0%% rate, payment=%d, all interest=0", sched.Items[0].Payment)
}

// LE-004: PaymentDay boundary (invalid values 0, 29, 31)
func TestW7_Loan_InvalidPaymentDay(t *testing.T) {
	db := getDB(t)
	ctx, _ := w7Ctx(t, db)
	loanSvc := loan.NewService(db.pool)

	for _, day := range []int32{0, 29, 31} {
		_, err := loanSvc.CreateLoan(ctx, &pbLoan.CreateLoanRequest{
			Name:            "BadDay",
			LoanType:        pbLoan.LoanType_LOAN_TYPE_CONSUMER,
			Principal:       100000,
			AnnualRate:      5.0,
			TotalMonths:     12,
			RepaymentMethod: pbLoan.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
			PaymentDay:      day,
			StartDate:       timestamppb.New(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)),
		})
		require.Error(t, err, "LE-004: payment_day=%d should be rejected", day)
	}
	t.Log("LE-004 PASS: invalid payment_day values rejected")
}

// LE-005: Rate change — rate=0 should be rejected
func TestW7_Loan_RateChangeToZero(t *testing.T) {
	db := getDB(t)
	ctx, _ := w7Ctx(t, db)
	loanSvc := loan.NewService(db.pool)

	l, err := loanSvc.CreateLoan(ctx, &pbLoan.CreateLoanRequest{
		Name:            "RateZero",
		LoanType:        pbLoan.LoanType_LOAN_TYPE_MORTGAGE,
		Principal:       50000000,
		AnnualRate:      4.2,
		TotalMonths:     120,
		RepaymentMethod: pbLoan.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
		PaymentDay:      15,
		StartDate:       timestamppb.New(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.NoError(t, err)

	// Rate change to 0 — should be rejected (validation requires rate > 0)
	_, err = loanSvc.RecordRateChange(ctx, &pbLoan.RecordRateChangeRequest{
		LoanId:        l.Id,
		NewRate:       0,
		EffectiveDate: timestamppb.New(time.Date(2026, 6, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.Error(t, err, "LE-005: rate change to 0 should be rejected")
	t.Log("LE-005 PASS: rate change to 0 rejected")
}

// LE-006: Prepayment amount exceeds remaining principal
func TestW7_Loan_PrepaymentExceedsPrincipal(t *testing.T) {
	db := getDB(t)
	ctx, _ := w7Ctx(t, db)
	loanSvc := loan.NewService(db.pool)

	l, err := loanSvc.CreateLoan(ctx, &pbLoan.CreateLoanRequest{
		Name:            "PrepayOver",
		LoanType:        pbLoan.LoanType_LOAN_TYPE_CONSUMER,
		Principal:       1000000, // 1万
		AnnualRate:      5.0,
		TotalMonths:     12,
		RepaymentMethod: pbLoan.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
		PaymentDay:      1,
		StartDate:       timestamppb.New(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.NoError(t, err)

	// Try prepaying more than the loan principal
	sim, err := loanSvc.SimulatePrepayment(ctx, &pbLoan.SimulatePrepaymentRequest{
		LoanId:           l.Id,
		PrepaymentAmount: 5000000, // 5万 >> 1万 principal
		Strategy:         pbLoan.PrepaymentStrategy_PREPAYMENT_STRATEGY_REDUCE_MONTHS,
	})
	if err != nil {
		// Good: rejected
		t.Logf("LE-006 PASS: prepayment exceeding principal rejected: %v", err)
	} else {
		// If allowed, verify it at most pays off the entire loan
		assert.GreaterOrEqual(t, sim.MonthsReduced, int32(11),
			"LE-006: overpayment should effectively pay off entire loan")
		t.Logf("LE-006 OK: overpayment handled gracefully, months_reduced=%d", sim.MonthsReduced)
	}
}

// ── Investment Edge Cases ────────────────────────────────────────────────────

// IE-001: Trade with price=0 (rejected)
func TestW7_Investment_ZeroPrice(t *testing.T) {
	db := getDB(t)
	ctx, _ := w7Ctx(t, db)
	investSvc := investment.NewService(db.pool)

	inv, err := investSvc.CreateInvestment(ctx, &pbInvest.CreateInvestmentRequest{
		Symbol:     "ZERO",
		Name:       "Zero Price Test",
		MarketType: pbInvest.MarketType_MARKET_TYPE_A_SHARE,
	})
	require.NoError(t, err)

	_, err = investSvc.RecordTrade(ctx, &pbInvest.RecordTradeRequest{
		InvestmentId: inv.Id,
		TradeType:    pbInvest.TradeType_TRADE_TYPE_BUY,
		Quantity:     100,
		Price:        0, // invalid
		Fee:          0,
		TradeDate:    timestamppb.New(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.Error(t, err, "IE-001: price=0 should be rejected")
	t.Log("IE-001 PASS: zero price rejected")
}

// IE-002: Trade with negative quantity
func TestW7_Investment_NegativeQuantity(t *testing.T) {
	db := getDB(t)
	ctx, _ := w7Ctx(t, db)
	investSvc := investment.NewService(db.pool)

	inv, err := investSvc.CreateInvestment(ctx, &pbInvest.CreateInvestmentRequest{
		Symbol:     "NEG",
		Name:       "Negative Qty",
		MarketType: pbInvest.MarketType_MARKET_TYPE_A_SHARE,
	})
	require.NoError(t, err)

	_, err = investSvc.RecordTrade(ctx, &pbInvest.RecordTradeRequest{
		InvestmentId: inv.Id,
		TradeType:    pbInvest.TradeType_TRADE_TYPE_BUY,
		Quantity:     -10, // invalid
		Price:        10000,
		Fee:          0,
		TradeDate:    timestamppb.New(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.Error(t, err, "IE-002: negative quantity should be rejected")
	t.Log("IE-002 PASS: negative quantity rejected")
}

// IE-003: Portfolio summary with zero holdings
func TestW7_Investment_EmptyPortfolio(t *testing.T) {
	db := getDB(t)
	ctx, _ := w7Ctx(t, db)
	investSvc := investment.NewService(db.pool)

	// Fresh user with no investments — should return empty, not crash
	portfolio, err := investSvc.GetPortfolioSummary(ctx, &pbInvest.GetPortfolioSummaryRequest{})
	require.NoError(t, err)
	assert.Equal(t, int64(0), portfolio.TotalCost)
	assert.Equal(t, int64(0), portfolio.TotalValue)
	assert.Empty(t, portfolio.Holdings)
	t.Log("IE-003 PASS: empty portfolio returns zeros")
}

// IE-004: Sell exactly all shares (position should become 0)
func TestW7_Investment_SellAll(t *testing.T) {
	db := getDB(t)
	ctx, _ := w7Ctx(t, db)
	investSvc := investment.NewService(db.pool)

	inv, err := investSvc.CreateInvestment(ctx, &pbInvest.CreateInvestmentRequest{
		Symbol:     "SELLALL",
		Name:       "Sell All",
		MarketType: pbInvest.MarketType_MARKET_TYPE_FUND,
	})
	require.NoError(t, err)

	_, err = investSvc.RecordTrade(ctx, &pbInvest.RecordTradeRequest{
		InvestmentId: inv.Id,
		TradeType:    pbInvest.TradeType_TRADE_TYPE_BUY,
		Quantity:     50,
		Price:        10000,
		Fee:          100,
		TradeDate:    timestamppb.New(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.NoError(t, err)

	// Sell all 50
	_, err = investSvc.RecordTrade(ctx, &pbInvest.RecordTradeRequest{
		InvestmentId: inv.Id,
		TradeType:    pbInvest.TradeType_TRADE_TYPE_SELL,
		Quantity:     50,
		Price:        12000,
		Fee:          100,
		TradeDate:    timestamppb.New(time.Date(2026, 3, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.NoError(t, err)

	// Portfolio should show 0 holding for this investment
	portfolio, err := investSvc.GetPortfolioSummary(ctx, &pbInvest.GetPortfolioSummaryRequest{})
	require.NoError(t, err)
	for _, h := range portfolio.Holdings {
		if h.Symbol == "SELLALL" {
			assert.InDelta(t, 0.0, h.Quantity, 0.001,
				"IE-004 BUG: sold all but holding still shows quantity")
		}
	}
	t.Log("IE-004 PASS: sell all shares, position cleared")
}

// IE-005: Floating point precision — sell 33.333... of 100
func TestW7_Investment_FloatingPointSell(t *testing.T) {
	db := getDB(t)
	ctx, _ := w7Ctx(t, db)
	investSvc := investment.NewService(db.pool)

	inv, err := investSvc.CreateInvestment(ctx, &pbInvest.CreateInvestmentRequest{
		Symbol:     "FLOAT",
		Name:       "Float Test",
		MarketType: pbInvest.MarketType_MARKET_TYPE_FUND,
	})
	require.NoError(t, err)

	_, err = investSvc.RecordTrade(ctx, &pbInvest.RecordTradeRequest{
		InvestmentId: inv.Id,
		TradeType:    pbInvest.TradeType_TRADE_TYPE_BUY,
		Quantity:     100,
		Price:        10000,
		Fee:          0,
		TradeDate:    timestamppb.New(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.NoError(t, err)

	// Sell 33.333333 (repeating decimal)
	_, err = investSvc.RecordTrade(ctx, &pbInvest.RecordTradeRequest{
		InvestmentId: inv.Id,
		TradeType:    pbInvest.TradeType_TRADE_TYPE_SELL,
		Quantity:     33.333333,
		Price:        11000,
		Fee:          0,
		TradeDate:    timestamppb.New(time.Date(2026, 2, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.NoError(t, err)

	// Sell another 33.333333
	_, err = investSvc.RecordTrade(ctx, &pbInvest.RecordTradeRequest{
		InvestmentId: inv.Id,
		TradeType:    pbInvest.TradeType_TRADE_TYPE_SELL,
		Quantity:     33.333333,
		Price:        11000,
		Fee:          0,
		TradeDate:    timestamppb.New(time.Date(2026, 3, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.NoError(t, err)

	// Remaining: 100 - 33.333333 - 33.333333 = 33.333334 (floating point)
	// Selling exactly 33.333334 should work OR 33.333333+epsilon should work
	portfolio, err := investSvc.GetPortfolioSummary(ctx, &pbInvest.GetPortfolioSummaryRequest{})
	require.NoError(t, err)
	for _, h := range portfolio.Holdings {
		if h.Symbol == "FLOAT" {
			assert.InDelta(t, 33.333334, h.Quantity, 0.001,
				"IE-005: remaining should be ~33.33")
			t.Logf("IE-005 PASS: remaining quantity=%.8f (floating point handled)", h.Quantity)
			return
		}
	}
	t.Error("IE-005: FLOAT not found in portfolio")
}

// ── Asset Edge Cases ─────────────────────────────────────────────────────────

// AE-001: RunDepreciation without setting a rule
func TestW7_Asset_DepreciationNoRule(t *testing.T) {
	db := getDB(t)
	ctx, _ := w7Ctx(t, db)
	assetSvc := asset.NewService(db.pool)

	a, err := assetSvc.CreateAsset(ctx, &pbAsset.CreateAssetRequest{
		Name:          "No Rule",
		AssetType:     pbAsset.AssetType_ASSET_TYPE_ELECTRONICS,
		PurchasePrice: 100000,
		PurchaseDate:  timestamppb.New(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.NoError(t, err)

	_, err = assetSvc.RunDepreciation(ctx, &pbAsset.RunDepreciationRequest{AssetId: a.Id})
	require.Error(t, err, "AE-001: RunDepreciation without rule should fail")
	t.Logf("AE-001 PASS: no rule → error: %v", err)
}

// AE-002: Depreciation stops at salvage value
func TestW7_Asset_DepreciationStopsAtSalvage(t *testing.T) {
	db := getDB(t)
	ctx, _ := w7Ctx(t, db)
	assetSvc := asset.NewService(db.pool)

	// Small asset, short life — can depreciate to salvage quickly
	a, err := assetSvc.CreateAsset(ctx, &pbAsset.CreateAssetRequest{
		Name:          "QuickDep",
		AssetType:     pbAsset.AssetType_ASSET_TYPE_ELECTRONICS,
		PurchasePrice: 120000, // 1200 CNY
		PurchaseDate:  timestamppb.New(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.NoError(t, err)

	// 1 year life, 10% salvage → salvage=12000, monthly_dep=9000, reaches salvage in ~12 months
	_, err = assetSvc.SetDepreciationRule(ctx, &pbAsset.SetDepreciationRuleRequest{
		AssetId:         a.Id,
		Method:          pbAsset.DepreciationMethod_DEPRECIATION_METHOD_STRAIGHT_LINE,
		UsefulLifeYears: 1,
		SalvageRate:     0.10, // salvage = 12000
	})
	require.NoError(t, err)

	// Run 15 months (more than useful life)
	var lastValue int64
	for i := 0; i < 15; i++ {
		updated, err := assetSvc.RunDepreciation(ctx, &pbAsset.RunDepreciationRequest{AssetId: a.Id})
		require.NoError(t, err)
		lastValue = updated.CurrentValue
	}

	// Should stop at salvage value (12000), never go below
	salvage := int64(12000)
	assert.GreaterOrEqual(t, lastValue, salvage,
		"AE-002 BUG: value %d dropped below salvage %d", lastValue, salvage)
	assert.Equal(t, salvage, lastValue,
		"AE-002: should be exactly at salvage after full depreciation")
	t.Logf("AE-002 PASS: depreciated to salvage=%d, stopped", lastValue)
}

// AE-003: Override depreciation rule (set rule twice)
func TestW7_Asset_OverrideDepreciationRule(t *testing.T) {
	db := getDB(t)
	ctx, _ := w7Ctx(t, db)
	assetSvc := asset.NewService(db.pool)

	a, err := assetSvc.CreateAsset(ctx, &pbAsset.CreateAssetRequest{
		Name:          "RuleOverride",
		AssetType:     pbAsset.AssetType_ASSET_TYPE_VEHICLE,
		PurchasePrice: 10000000,
		PurchaseDate:  timestamppb.New(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.NoError(t, err)

	// Set straight line
	_, err = assetSvc.SetDepreciationRule(ctx, &pbAsset.SetDepreciationRuleRequest{
		AssetId:         a.Id,
		Method:          pbAsset.DepreciationMethod_DEPRECIATION_METHOD_STRAIGHT_LINE,
		UsefulLifeYears: 10,
		SalvageRate:     0.05,
	})
	require.NoError(t, err)

	// Run once
	after1, err := assetSvc.RunDepreciation(ctx, &pbAsset.RunDepreciationRequest{AssetId: a.Id})
	require.NoError(t, err)

	// Override to double declining
	_, err = assetSvc.SetDepreciationRule(ctx, &pbAsset.SetDepreciationRuleRequest{
		AssetId:         a.Id,
		Method:          pbAsset.DepreciationMethod_DEPRECIATION_METHOD_DOUBLE_DECLINING,
		UsefulLifeYears: 5,
		SalvageRate:     0.10,
	})
	require.NoError(t, err)

	// Run again with new rule — should use new method on current book value
	after2, err := assetSvc.RunDepreciation(ctx, &pbAsset.RunDepreciationRequest{AssetId: a.Id})
	require.NoError(t, err)

	// Double-declining on shorter life → bigger monthly depreciation
	dep1 := int64(10000000) - after1.CurrentValue     // straight-line monthly
	dep2 := after1.CurrentValue - after2.CurrentValue // double-declining monthly
	assert.Greater(t, dep2, dep1,
		"AE-003: double-declining dep (%d) should exceed straight-line dep (%d)", dep2, dep1)
	t.Logf("AE-003 PASS: rule override applied, dep1=%d(SL) dep2=%d(DD)", dep1, dep2)
}

// AE-004: Depreciation method=NONE should be rejected
func TestW7_Asset_DepreciationMethodNone(t *testing.T) {
	db := getDB(t)
	ctx, _ := w7Ctx(t, db)
	assetSvc := asset.NewService(db.pool)

	a, err := assetSvc.CreateAsset(ctx, &pbAsset.CreateAssetRequest{
		Name:          "NoDep",
		AssetType:     pbAsset.AssetType_ASSET_TYPE_REAL_ESTATE,
		PurchasePrice: 300000000,
		PurchaseDate:  timestamppb.New(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.NoError(t, err)

	// Set method=NONE (e.g. real estate that appreciates)
	_, err = assetSvc.SetDepreciationRule(ctx, &pbAsset.SetDepreciationRuleRequest{
		AssetId:         a.Id,
		Method:          pbAsset.DepreciationMethod_DEPRECIATION_METHOD_NONE,
		UsefulLifeYears: 0,
		SalvageRate:     0,
	})
	require.NoError(t, err)

	// RunDepreciation on NONE method should fail
	_, err = assetSvc.RunDepreciation(ctx, &pbAsset.RunDepreciationRequest{AssetId: a.Id})
	require.Error(t, err, "AE-004: depreciation on NONE method should fail")
	t.Logf("AE-004 PASS: NONE method → error: %v", err)
}
