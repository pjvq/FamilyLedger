package loan

import (
	"context"
	"fmt"
	"log/slog"
	"math"
	"time"

	"github.com/jackc/pgx/v5"
	"google.golang.org/protobuf/types/known/timestamppb"

	pb "github.com/familyledger/server/proto/loan"
)

// ── Prepayment Types ─────────────────────────────────────────────────────────

// prepaymentInput holds the validated inputs needed to compute a prepayment.
type prepaymentInput struct {
	loan             *pb.Loan
	items            []*pb.LoanScheduleItem
	prepaymentAmount int64
	strategy         pb.PrepaymentStrategy
}

// prepaymentCalcResult holds the pure-computation results of a prepayment
// schedule recalculation, shared by Simulate and Execute.
type prepaymentCalcResult struct {
	newSchedule         []scheduleItem
	newPrincipal        int64
	newTotalMonths      int32
	totalInterestBefore int64
	totalInterestAfter  int64
	interestSaved       int64
	monthsReduced       int32
	displayMonthlyPayment   int64
}

// ── Pure Computation ─────────────────────────────────────────────────────────

// calcPrepaymentSchedule computes the new schedule and savings for a
// prepayment. Pure computation with no side effects, shared by
// SimulatePrepayment and ExecutePrepayment.
// Caller must not mutate in.loan concurrently.
func calcPrepaymentSchedule(in prepaymentInput) prepaymentCalcResult {
	loan := in.loan
	items := in.items

	// Original total interest
	var totalInterestBefore int64
	for _, it := range items {
		totalInterestBefore += it.InterestPart
	}

	// Interest already paid (locked in, doesn't change)
	var paidInterest int64
	for _, it := range items {
		if it.IsPaid {
			paidInterest += it.InterestPart
		}
	}

	newPrincipal := loan.RemainingPrincipal - in.prepaymentAmount
	remainingMonths := int(loan.TotalMonths - loan.PaidMonths)
	method := repaymentMethodToString(loan.RepaymentMethod)
	calcMethod := interestCalcMethodToString(loan.InterestCalcMethod)

	// Next unpaid due date → normalize to 1st of month.
	// advanceMonths(startDate, 0, paymentDay) adds an extra month when
	// startDate.Day() >= paymentDay; using the 1st avoids that shift.
	nextDueDate := findNextUnpaidDueDate(items, loan.StartDate.AsTime())
	nextDueDate = time.Date(nextDueDate.Year(), nextDueDate.Month(), 1, 0, 0, 0, 0, nextDueDate.Location())

	var newSchedule []scheduleItem
	var newTotalMonths int32

	if newPrincipal <= 0 {
		// Full prepayment — loan is paid off
		newSchedule = nil
		newTotalMonths = loan.PaidMonths
		newPrincipal = 0
	} else {
		switch in.strategy {
		case pb.PrepaymentStrategy_PREPAYMENT_STRATEGY_REDUCE_MONTHS:
			newSchedule = calcReduceMonths(loan, newPrincipal, method, calcMethod, int(loan.PaymentDay), nextDueDate)
			newTotalMonths = loan.PaidMonths + int32(len(newSchedule))

		case pb.PrepaymentStrategy_PREPAYMENT_STRATEGY_REDUCE_PAYMENT:
			newSchedule = generateSchedule(newPrincipal, loan.AnnualRate, remainingMonths, method, int(loan.PaymentDay), nextDueDate, calcMethod)
			newTotalMonths = loan.TotalMonths

		default:
			panic(fmt.Sprintf("loan: unsupported prepayment strategy: %v", in.strategy))
		}
	}

	// Interest & savings
	var newInterest int64
	for _, si := range newSchedule {
		newInterest += si.interestPart
	}
	totalInterestAfter := paidInterest + newInterest
	interestSaved := totalInterestBefore - totalInterestAfter
	if interestSaved < 0 {
		interestSaved = 0
	}
	monthsReduced := int32(remainingMonths) - int32(len(newSchedule))
	if monthsReduced < 0 {
		monthsReduced = 0
	}
	var displayMonthlyPayment int64
	if len(newSchedule) > 0 {
		displayMonthlyPayment = newSchedule[0].payment
	}

	return prepaymentCalcResult{
		newSchedule:         newSchedule,
		newPrincipal:        newPrincipal,
		newTotalMonths:      newTotalMonths,
		totalInterestBefore: totalInterestBefore,
		totalInterestAfter:  totalInterestAfter,
		interestSaved:       interestSaved,
		monthsReduced:       monthsReduced,
		displayMonthlyPayment:   displayMonthlyPayment,
	}
}

// calcReduceMonths computes the new schedule for REDUCE_MONTHS strategy.
func calcReduceMonths(loan *pb.Loan, newPrincipal int64, method, calcMethod string, paymentDay int, startDate time.Time) []scheduleItem {
	r := loan.AnnualRate / 100.0 / 12.0

	switch method {
	case "equal_installment":
		var originalMonthly float64
		if r == 0 {
			originalMonthly = float64(loan.Principal) / float64(loan.TotalMonths)
		} else {
			rn := math.Pow(1+r, float64(loan.TotalMonths))
			originalMonthly = float64(loan.Principal) * r * rn / (rn - 1)
		}
		M := roundCent(originalMonthly)
		return generateWithFixedPayment(newPrincipal, loan.AnnualRate, M, paymentDay, startDate)

	case "interest_only", "bullet":
		// These methods can't meaningfully reduce months; fall back to reduce payment
		remainingMonths := int(loan.TotalMonths - loan.PaidMonths)
		return generateSchedule(newPrincipal, loan.AnnualRate, remainingMonths, method, paymentDay, startDate, calcMethod)

	default:
		if method != "equal_principal" {
			panic("loan: unsupported repayment method in calcReduceMonths: " + method)
		}
		origMonthlyPrincipal := roundCent(float64(loan.Principal) / float64(loan.TotalMonths))
		newMonths := int(math.Ceil(float64(newPrincipal) / float64(origMonthlyPrincipal)))
		if newMonths < 1 {
			newMonths = 1
		}
		return generateSchedule(newPrincipal, loan.AnnualRate, newMonths, method, paymentDay, startDate, calcMethod)
	}
}

// findNextUnpaidDueDate returns the due date of the first unpaid schedule item,
// or fallback if all are paid / empty.
// Unreachable fallback when called from calcPrepaymentSchedule (caller handles full-prepay separately).
func findNextUnpaidDueDate(items []*pb.LoanScheduleItem, fallback time.Time) time.Time {
	for _, it := range items {
		if !it.IsPaid {
			return it.DueDate.AsTime()
		}
	}
	return fallback
}

// ── Persistence ──────────────────────────────────────────────────────────────

// persistPrepayment executes the transactional writes for a prepayment:
//  1. Update loan remaining_principal + total_months
//  2. Delete all unpaid schedule items
//  3. Insert new schedule items
//  4. Deduct amount from associated account
func persistPrepayment(ctx context.Context, tx pgx.Tx, loanID string, paidMonths int32, accountID string, calc prepaymentCalcResult, prepaymentAmount int64) error {
	// 1. Update loan
	_, err := tx.Exec(ctx,
		`UPDATE loans SET remaining_principal = $1, total_months = $2, updated_at = NOW()
		 WHERE id = $3 AND deleted_at IS NULL`,
		calc.newPrincipal, calc.newTotalMonths, loanID,
	)
	if err != nil {
		slog.Error("loan: execute prepayment: update loan failed", "loan_id", loanID, "error", err)
		return fmt.Errorf("failed to update loan")
	}

	// 2. Delete unpaid schedule items
	_, err = tx.Exec(ctx,
		`DELETE FROM loan_schedules WHERE loan_id = $1 AND is_paid = false`,
		loanID,
	)
	if err != nil {
		slog.Error("loan: execute prepayment: delete schedule failed", "loan_id", loanID, "error", err)
		return fmt.Errorf("failed to delete unpaid schedule")
	}

	// 3. Insert new schedule (month_number continues from paid_months+1)
	for i, item := range calc.newSchedule {
		monthNum := int(paidMonths) + 1 + i
		_, err = tx.Exec(ctx,
			`INSERT INTO loan_schedules (loan_id, month_number, payment, principal_part,
			 interest_part, remaining_principal, due_date) VALUES ($1,$2,$3,$4,$5,$6,$7)`,
			loanID, monthNum, item.payment, item.principalPart,
			item.interestPart, item.remainingPrincipal, item.dueDate,
		)
		if err != nil {
			slog.Error("loan: execute prepayment: insert schedule item failed", "month", monthNum, "loan_id", loanID, "error", err)
			return fmt.Errorf("failed to insert schedule item %d", monthNum)
		}
	}

	// 4. Deduct from associated account
	if accountID != "" {
		_, err = tx.Exec(ctx,
			`UPDATE accounts SET balance = balance - $1, updated_at = NOW() WHERE id = $2`,
			prepaymentAmount, accountID,
		)
		if err != nil {
			slog.Error("loan: execute prepayment: failed to deduct from account", "account_id", accountID, "error", err)
			return fmt.Errorf("failed to deduct from account")
		}
	}

	return nil
}

// recordPrepaymentTxn creates the expense transaction record for the prepayment.
// Fatal: prefer consistency (no orphan balance deduction without matching
// transaction record) over availability.
func recordPrepaymentTxn(ctx context.Context, tx pgx.Tx, userID, loanID string, loan *pb.Loan, prepaymentAmount int64) error {
	categoryID := resolveLoanRepaymentCategoryID(ctx, tx, loanID)
	accountID := loan.AccountId

	if categoryID == "" || accountID == "" {
		return nil
	}

	note := fmt.Sprintf("%s 提前还款", loan.Name)
	var familyIDVal interface{}
	if loan.FamilyId != "" {
		familyIDVal = loan.FamilyId
	}

	_, err := tx.Exec(ctx,
		`INSERT INTO transactions (user_id, account_id, category_id, amount, amount_cny, type, note, txn_date, family_id)
		 VALUES ($1, $2, $3, $4, $4, 'expense', $5, $6, $7)`,
		userID, accountID, categoryID, prepaymentAmount, note, time.Now(), familyIDVal,
	)
	if err != nil {
		slog.Error("loan: execute prepayment: failed to create transaction record", "error", err)
		return fmt.Errorf("failed to record prepayment transaction")
	}
	return nil
}

// ── Response Assembly ────────────────────────────────────────────────────────

// buildPrepaymentSimulationProto builds the PrepaymentSimulation protobuf
// from the calculation result.
func buildPrepaymentSimulationProto(calc prepaymentCalcResult, prepaymentAmount int64) *pb.PrepaymentSimulation {
	return &pb.PrepaymentSimulation{
		PrepaymentAmount:    prepaymentAmount,
		TotalInterestBefore: calc.totalInterestBefore,
		TotalInterestAfter:  calc.totalInterestAfter,
		InterestSaved:       calc.interestSaved,
		MonthsReduced:       calc.monthsReduced,
		NewMonthlyPayment:   calc.displayMonthlyPayment,
	}
}

// buildScheduleProto converts internal scheduleItems to proto with caller-defined numbering.
func buildScheduleProto(calc prepaymentCalcResult, monthNumFn func(i int) int32) []*pb.LoanScheduleItem {
	protoItems := make([]*pb.LoanScheduleItem, len(calc.newSchedule))
	for i, si := range calc.newSchedule {
		protoItems[i] = &pb.LoanScheduleItem{
			MonthNumber:        monthNumFn(i),
			Payment:            si.payment,
			PrincipalPart:      si.principalPart,
			InterestPart:       si.interestPart,
			RemainingPrincipal: si.remainingPrincipal,
			IsPaid:             false,
			DueDate:            timestamppb.New(si.dueDate),
		}
	}
	return protoItems
}
