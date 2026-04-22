package loan

import (
	"context"
	"fmt"
	"log"
	"math"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/familyledger/server/pkg/middleware"
	pb "github.com/familyledger/server/proto/loan"
)

type Service struct {
	pb.UnimplementedLoanServiceServer
	pool *pgxpool.Pool
}

func NewService(pool *pgxpool.Pool) *Service {
	return &Service{pool: pool}
}

// ── CreateLoan ──────────────────────────────────────────────────────────────

func (s *Service) CreateLoan(ctx context.Context, req *pb.CreateLoanRequest) (*pb.Loan, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}
	if err := validateCreateLoanRequest(req); err != nil {
		return nil, err
	}

	uid, err := uuid.Parse(userID)
	if err != nil {
		return nil, status.Error(codes.Internal, "invalid user id")
	}

	loanType := loanTypeToString(req.LoanType)
	method := repaymentMethodToString(req.RepaymentMethod)
	startDate := req.StartDate.AsTime()

	var accountID *uuid.UUID
	if req.AccountId != "" {
		aid, err := uuid.Parse(req.AccountId)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid account_id")
		}
		accountID = &aid
	}

	schedule := generateSchedule(req.Principal, req.AnnualRate, int(req.TotalMonths), method, int(req.PaymentDay), startDate)

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to begin transaction")
	}
	defer tx.Rollback(ctx)

	var loanID uuid.UUID
	var createdAt, updatedAt time.Time
	err = tx.QueryRow(ctx,
		`INSERT INTO loans (user_id, name, loan_type, principal, remaining_principal,
		 annual_rate, total_months, paid_months, repayment_method, payment_day,
		 start_date, account_id)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, 0, $8, $9, $10, $11)
		 RETURNING id, created_at, updated_at`,
		uid, req.Name, loanType, req.Principal, req.Principal,
		req.AnnualRate, req.TotalMonths, method, req.PaymentDay,
		startDate, accountID,
	).Scan(&loanID, &createdAt, &updatedAt)
	if err != nil {
		log.Printf("loan: create error: %v", err)
		return nil, status.Error(codes.Internal, "failed to create loan")
	}

	if err := batchInsertSchedule(ctx, tx, loanID, schedule); err != nil {
		return nil, err
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Error(codes.Internal, "failed to commit")
	}

	log.Printf("loan: created %s (%s) for user %s, %d items", loanID, req.Name, userID, len(schedule))
	return buildLoanProto(loanID.String(), userID, req.Name, req.LoanType,
		req.Principal, req.Principal, req.AnnualRate, req.TotalMonths, 0,
		req.RepaymentMethod, req.PaymentDay, startDate, createdAt, updatedAt, req.AccountId), nil
}

// ── GetLoan ─────────────────────────────────────────────────────────────────

func (s *Service) GetLoan(ctx context.Context, req *pb.GetLoanRequest) (*pb.Loan, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}
	return s.loadLoan(ctx, req.LoanId, userID)
}

// ── ListLoans ───────────────────────────────────────────────────────────────

func (s *Service) ListLoans(ctx context.Context, req *pb.ListLoansRequest) (*pb.ListLoansResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	rows, err := s.pool.Query(ctx,
		`SELECT id, user_id, name, loan_type, principal, remaining_principal,
		        annual_rate, total_months, paid_months, repayment_method, payment_day,
		        start_date, created_at, updated_at, account_id
		 FROM loans WHERE user_id = $1 AND deleted_at IS NULL
		 ORDER BY created_at DESC`,
		userID,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to query loans")
	}
	defer rows.Close()

	var loans []*pb.Loan
	for rows.Next() {
		loan, err := scanLoan(rows)
		if err != nil {
			return nil, err
		}
		loans = append(loans, loan)
	}
	if loans == nil {
		loans = []*pb.Loan{}
	}
	return &pb.ListLoansResponse{Loans: loans}, nil
}

// ── UpdateLoan ──────────────────────────────────────────────────────────────

func (s *Service) UpdateLoan(ctx context.Context, req *pb.UpdateLoanRequest) (*pb.Loan, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}
	if req.LoanId == "" {
		return nil, status.Error(codes.InvalidArgument, "loan_id is required")
	}

	existing, err := s.loadLoan(ctx, req.LoanId, userID)
	if err != nil {
		return nil, err
	}

	name := existing.Name
	if req.Name != "" {
		name = req.Name
	}
	paymentDay := existing.PaymentDay
	if req.PaymentDay > 0 {
		if req.PaymentDay < 1 || req.PaymentDay > 28 {
			return nil, status.Error(codes.InvalidArgument, "payment_day must be 1-28")
		}
		paymentDay = req.PaymentDay
	}
	accountID := existing.AccountId
	if req.AccountId != "" {
		if _, err := uuid.Parse(req.AccountId); err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid account_id")
		}
		accountID = req.AccountId
	}

	var accountUUID *uuid.UUID
	if accountID != "" {
		aid, _ := uuid.Parse(accountID)
		accountUUID = &aid
	}

	_, err = s.pool.Exec(ctx,
		`UPDATE loans SET name=$1, payment_day=$2, account_id=$3, updated_at=NOW()
		 WHERE id=$4 AND user_id=$5 AND deleted_at IS NULL`,
		name, paymentDay, accountUUID, req.LoanId, userID,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to update loan")
	}
	return s.loadLoan(ctx, req.LoanId, userID)
}

// ── DeleteLoan ──────────────────────────────────────────────────────────────

func (s *Service) DeleteLoan(ctx context.Context, req *pb.DeleteLoanRequest) (*emptypb.Empty, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}
	if req.LoanId == "" {
		return nil, status.Error(codes.InvalidArgument, "loan_id is required")
	}

	tag, err := s.pool.Exec(ctx,
		`UPDATE loans SET deleted_at=NOW(), updated_at=NOW()
		 WHERE id=$1 AND user_id=$2 AND deleted_at IS NULL`,
		req.LoanId, userID,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to delete loan")
	}
	if tag.RowsAffected() == 0 {
		return nil, status.Error(codes.NotFound, "loan not found")
	}
	log.Printf("loan: soft-deleted %s by user %s", req.LoanId, userID)
	return &emptypb.Empty{}, nil
}

// ── GetLoanSchedule ─────────────────────────────────────────────────────────

func (s *Service) GetLoanSchedule(ctx context.Context, req *pb.GetLoanScheduleRequest) (*pb.LoanScheduleResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}
	if _, err := s.loadLoan(ctx, req.LoanId, userID); err != nil {
		return nil, err
	}
	items, err := s.loadSchedule(ctx, req.LoanId)
	if err != nil {
		return nil, err
	}
	return &pb.LoanScheduleResponse{Items: items}, nil
}

// ── SimulatePrepayment ──────────────────────────────────────────────────────

func (s *Service) SimulatePrepayment(ctx context.Context, req *pb.SimulatePrepaymentRequest) (*pb.PrepaymentSimulation, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}
	if req.PrepaymentAmount <= 0 {
		return nil, status.Error(codes.InvalidArgument, "prepayment_amount must be positive")
	}
	if req.Strategy == pb.PrepaymentStrategy_PREPAYMENT_STRATEGY_UNSPECIFIED {
		return nil, status.Error(codes.InvalidArgument, "strategy is required")
	}

	loan, err := s.loadLoan(ctx, req.LoanId, userID)
	if err != nil {
		return nil, err
	}
	if req.PrepaymentAmount >= loan.RemainingPrincipal {
		return nil, status.Error(codes.InvalidArgument, "prepayment_amount exceeds remaining principal")
	}

	items, err := s.loadSchedule(ctx, req.LoanId)
	if err != nil {
		return nil, err
	}

	// Original total interest
	var totalInterestBefore int64
	for _, it := range items {
		totalInterestBefore += it.InterestPart
	}

	// Interest already paid (these don't change)
	var paidInterest int64
	for _, it := range items {
		if it.IsPaid {
			paidInterest += it.InterestPart
		}
	}

	newPrincipal := loan.RemainingPrincipal - req.PrepaymentAmount
	remainingMonths := int(loan.TotalMonths - loan.PaidMonths)
	method := repaymentMethodToString(loan.RepaymentMethod)

	// Start date for new schedule = next unpaid due date
	var nextDueDate time.Time
	for _, it := range items {
		if !it.IsPaid {
			nextDueDate = it.DueDate.AsTime()
			break
		}
	}
	if nextDueDate.IsZero() {
		nextDueDate = loan.StartDate.AsTime()
	}

	var newSchedule []scheduleItem

	switch req.Strategy {
	case pb.PrepaymentStrategy_PREPAYMENT_STRATEGY_REDUCE_MONTHS:
		// Keep same monthly payment, reduce months.
		// For equal_installment: compute original monthly payment, then figure out
		// how many months needed to pay off newPrincipal with that payment.
		// For equal_principal: same monthly principal portion, fewer months.

		r := loan.AnnualRate / 100.0 / 12.0

		if method == "equal_installment" {
			// Original monthly payment
			var originalMonthly float64
			if r == 0 {
				originalMonthly = float64(loan.Principal) / float64(loan.TotalMonths)
			} else {
				rn := math.Pow(1+r, float64(loan.TotalMonths))
				originalMonthly = float64(loan.Principal) * r * rn / (rn - 1)
			}
			M := roundCent(originalMonthly)

			// Generate month-by-month with fixed M until paid off
			newSchedule = generateWithFixedPayment(newPrincipal, loan.AnnualRate, M, int(loan.PaymentDay), nextDueDate)
		} else {
			// equal_principal: original monthly principal = loan.Principal / totalMonths
			origMonthlyPrincipal := roundCent(float64(loan.Principal) / float64(loan.TotalMonths))
			// New months = ceil(newPrincipal / origMonthlyPrincipal)
			newMonths := int(math.Ceil(float64(newPrincipal) / float64(origMonthlyPrincipal)))
			if newMonths < 1 {
				newMonths = 1
			}
			newSchedule = generateSchedule(newPrincipal, loan.AnnualRate, newMonths, method, int(loan.PaymentDay), nextDueDate)
		}

	case pb.PrepaymentStrategy_PREPAYMENT_STRATEGY_REDUCE_PAYMENT:
		// Keep same months, reduce payment
		newSchedule = generateSchedule(newPrincipal, loan.AnnualRate, remainingMonths, method, int(loan.PaymentDay), nextDueDate)
	}

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
	var newMonthlyPayment int64
	if len(newSchedule) > 0 {
		newMonthlyPayment = newSchedule[0].payment
	}

	protoItems := make([]*pb.LoanScheduleItem, len(newSchedule))
	for i, si := range newSchedule {
		protoItems[i] = &pb.LoanScheduleItem{
			MonthNumber:        int32(i + 1),
			Payment:            si.payment,
			PrincipalPart:      si.principalPart,
			InterestPart:       si.interestPart,
			RemainingPrincipal: si.remainingPrincipal,
			IsPaid:             false,
			DueDate:            timestamppb.New(si.dueDate),
		}
	}

	return &pb.PrepaymentSimulation{
		PrepaymentAmount:    req.PrepaymentAmount,
		TotalInterestBefore: totalInterestBefore,
		TotalInterestAfter:  totalInterestAfter,
		InterestSaved:       interestSaved,
		MonthsReduced:       monthsReduced,
		NewMonthlyPayment:   newMonthlyPayment,
		NewSchedule:         protoItems,
	}, nil
}

// ── RecordRateChange ────────────────────────────────────────────────────────

func (s *Service) RecordRateChange(ctx context.Context, req *pb.RecordRateChangeRequest) (*pb.Loan, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}
	if req.NewRate <= 0 {
		return nil, status.Error(codes.InvalidArgument, "new_rate must be positive")
	}
	if req.EffectiveDate == nil {
		return nil, status.Error(codes.InvalidArgument, "effective_date is required")
	}

	loan, err := s.loadLoan(ctx, req.LoanId, userID)
	if err != nil {
		return nil, err
	}

	oldRate := loan.AnnualRate

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to begin transaction")
	}
	defer tx.Rollback(ctx)

	// Record the change
	_, err = tx.Exec(ctx,
		`INSERT INTO loan_rate_changes (loan_id, old_rate, new_rate, effective_date) VALUES ($1,$2,$3,$4)`,
		req.LoanId, oldRate, req.NewRate, req.EffectiveDate.AsTime(),
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to record rate change")
	}

	// Update loan rate
	_, err = tx.Exec(ctx,
		`UPDATE loans SET annual_rate=$1, updated_at=NOW() WHERE id=$2`,
		req.NewRate, req.LoanId,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to update loan rate")
	}

	// Find the boundary: next unpaid month and its remaining principal
	var nextUnpaidMonth int32
	err = tx.QueryRow(ctx,
		`SELECT COALESCE(MIN(month_number), 0) FROM loan_schedules WHERE loan_id=$1 AND is_paid=false`,
		req.LoanId,
	).Scan(&nextUnpaidMonth)
	if err != nil || nextUnpaidMonth == 0 {
		if err := tx.Commit(ctx); err != nil {
			return nil, status.Error(codes.Internal, "failed to commit")
		}
		return s.loadLoan(ctx, req.LoanId, userID)
	}

	// Get the remaining principal before the first unpaid month
	var rpBefore int64
	if nextUnpaidMonth == 1 {
		rpBefore = loan.Principal
	} else {
		err = tx.QueryRow(ctx,
			`SELECT remaining_principal FROM loan_schedules WHERE loan_id=$1 AND month_number=$2`,
			req.LoanId, nextUnpaidMonth-1,
		).Scan(&rpBefore)
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to get remaining principal")
		}
	}

	// Get due date of first unpaid month
	var nextDueDate time.Time
	err = tx.QueryRow(ctx,
		`SELECT due_date FROM loan_schedules WHERE loan_id=$1 AND month_number=$2`,
		req.LoanId, nextUnpaidMonth,
	).Scan(&nextDueDate)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to get next due date")
	}

	newMonthCount := int(loan.TotalMonths) - int(nextUnpaidMonth) + 1
	method := repaymentMethodToString(loan.RepaymentMethod)
	newItems := generateSchedule(rpBefore, req.NewRate, newMonthCount, method, int(loan.PaymentDay), nextDueDate)

	// Delete unpaid items, insert new
	_, err = tx.Exec(ctx, `DELETE FROM loan_schedules WHERE loan_id=$1 AND is_paid=false`, req.LoanId)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to delete old schedule")
	}

	for i, item := range newItems {
		monthNum := int(nextUnpaidMonth) + i
		_, err = tx.Exec(ctx,
			`INSERT INTO loan_schedules (loan_id, month_number, payment, principal_part,
			 interest_part, remaining_principal, due_date) VALUES ($1,$2,$3,$4,$5,$6,$7)`,
			req.LoanId, monthNum, item.payment, item.principalPart,
			item.interestPart, item.remainingPrincipal, item.dueDate,
		)
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to insert new schedule item")
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Error(codes.Internal, "failed to commit")
	}
	log.Printf("loan: rate change %s: %.4f%% -> %.4f%%", req.LoanId, oldRate, req.NewRate)
	return s.loadLoan(ctx, req.LoanId, userID)
}

// ── RecordPayment ───────────────────────────────────────────────────────────

func (s *Service) RecordPayment(ctx context.Context, req *pb.RecordPaymentRequest) (*pb.LoanScheduleItem, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}
	if req.LoanId == "" || req.MonthNumber <= 0 {
		return nil, status.Error(codes.InvalidArgument, "loan_id and month_number required")
	}
	if _, err := s.loadLoan(ctx, req.LoanId, userID); err != nil {
		return nil, err
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to begin transaction")
	}
	defer tx.Rollback(ctx)

	var item pb.LoanScheduleItem
	var dueDate time.Time
	now := time.Now()
	err = tx.QueryRow(ctx,
		`UPDATE loan_schedules SET is_paid=true, paid_date=$1
		 WHERE loan_id=$2 AND month_number=$3 AND is_paid=false
		 RETURNING month_number, payment, principal_part, interest_part, remaining_principal, due_date`,
		now, req.LoanId, req.MonthNumber,
	).Scan(&item.MonthNumber, &item.Payment, &item.PrincipalPart, &item.InterestPart,
		&item.RemainingPrincipal, &dueDate)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, status.Error(codes.NotFound, "schedule item not found or already paid")
		}
		return nil, status.Error(codes.Internal, "failed to mark payment")
	}
	item.IsPaid = true
	item.DueDate = timestamppb.New(dueDate)
	item.PaidDate = timestamppb.New(now)

	_, err = tx.Exec(ctx,
		`UPDATE loans SET
		   paid_months = (SELECT COUNT(*) FROM loan_schedules WHERE loan_id=$1 AND is_paid=true),
		   remaining_principal = $2, updated_at=NOW()
		 WHERE id = $1`,
		req.LoanId, item.RemainingPrincipal,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to update loan counters")
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Error(codes.Internal, "failed to commit")
	}
	log.Printf("loan: payment recorded %s month %d", req.LoanId, req.MonthNumber)
	return &item, nil
}

// ════════════════════════════════════════════════════════════════════════════
// Internal helpers
// ════════════════════════════════════════════════════════════════════════════

type scheduleItem struct {
	payment            int64
	principalPart      int64
	interestPart       int64
	remainingPrincipal int64
	dueDate            time.Time
}

func roundCent(v float64) int64 {
	return int64(math.Round(v))
}

// generateSchedule creates the full amortization schedule from scratch.
func generateSchedule(principal int64, annualRate float64, totalMonths int, method string, paymentDay int, startDate time.Time) []scheduleItem {
	if totalMonths <= 0 || principal <= 0 {
		return nil
	}
	r := annualRate / 100.0 / 12.0
	P := float64(principal)
	n := totalMonths
	items := make([]scheduleItem, n)

	switch method {
	case "equal_installment":
		var M float64
		if r == 0 {
			M = P / float64(n)
		} else {
			rn := math.Pow(1+r, float64(n))
			M = P * r * rn / (rn - 1)
		}
		monthlyPayment := roundCent(M)

		remaining := P
		var totalPrincipalPaid int64

		for i := 0; i < n; i++ {
			dueDate := advanceMonths(startDate, i, paymentDay)
			interest := roundCent(remaining * r)

			var pprt int64
			if i == n-1 {
				// Last period: clear remaining to eliminate rounding error
				pprt = principal - totalPrincipalPaid
				interest = roundCent(float64(pprt+roundCent(remaining)-pprt) * r)
				// Simpler: interest on actual remaining
				interest = roundCent(float64(principal-totalPrincipalPaid) * r)
			} else {
				pprt = monthlyPayment - interest
			}

			payment := pprt + interest
			if i < n-1 {
				payment = monthlyPayment
			}

			remaining -= float64(pprt)
			if remaining < 0.5 {
				remaining = 0
			}
			totalPrincipalPaid += pprt

			items[i] = scheduleItem{
				payment:            payment,
				principalPart:      pprt,
				interestPart:       interest,
				remainingPrincipal: roundCent(remaining),
				dueDate:            dueDate,
			}
		}
		// Ensure last item remaining is exactly 0
		items[n-1].remainingPrincipal = 0

	case "equal_principal":
		monthlyPrincipal := roundCent(P / float64(n))
		remaining := principal

		for i := 0; i < n; i++ {
			dueDate := advanceMonths(startDate, i, paymentDay)
			interest := roundCent(float64(remaining) * r)
			pprt := monthlyPrincipal
			if i == n-1 {
				pprt = remaining // clear remainder exactly
			}
			remaining -= pprt

			items[i] = scheduleItem{
				payment:            pprt + interest,
				principalPart:      pprt,
				interestPart:       interest,
				remainingPrincipal: remaining,
				dueDate:            dueDate,
			}
		}
	}
	return items
}

// generateWithFixedPayment builds a schedule month-by-month with a fixed payment
// amount until the principal is fully repaid. Used for "reduce months" prepayment.
func generateWithFixedPayment(principal int64, annualRate float64, fixedPayment int64, paymentDay int, startDate time.Time) []scheduleItem {
	if principal <= 0 {
		return nil
	}
	r := annualRate / 100.0 / 12.0
	remaining := float64(principal)
	var items []scheduleItem
	var totalPrincipalPaid int64
	maxMonths := 360 * 2 // safety cap

	for i := 0; remaining > 0.5 && i < maxMonths; i++ {
		dueDate := advanceMonths(startDate, i, paymentDay)
		interest := roundCent(remaining * r)

		pprt := fixedPayment - interest
		if pprt <= 0 {
			// Payment doesn't even cover interest — shouldn't happen in practice
			pprt = 1
		}

		// If this is the last payment (would overpay), adjust
		remainingInt := principal - totalPrincipalPaid
		if pprt >= remainingInt {
			pprt = remainingInt
			interest = roundCent(float64(remainingInt) * r)
			items = append(items, scheduleItem{
				payment:            pprt + interest,
				principalPart:      pprt,
				interestPart:       interest,
				remainingPrincipal: 0,
				dueDate:            dueDate,
			})
			break
		}

		remaining -= float64(pprt)
		totalPrincipalPaid += pprt

		items = append(items, scheduleItem{
			payment:            fixedPayment,
			principalPart:      pprt,
			interestPart:       interest,
			remainingPrincipal: roundCent(remaining),
			dueDate:            dueDate,
		})
	}
	return items
}

func advanceMonths(startDate time.Time, monthOffset int, paymentDay int) time.Time {
	// First payment (monthOffset=0): next payment day on or after startDate
	// Subsequent payments: one more month each
	y := startDate.Year()
	m := int(startDate.Month()) + monthOffset

	// If start day >= paymentDay, the first available payment day is next month
	if startDate.Day() >= paymentDay {
		m++
	}

	// Normalize year/month
	for m > 12 {
		y++
		m -= 12
	}
	for m < 1 {
		y--
		m += 12
	}

	day := paymentDay
	maxDay := daysInMonth(y, time.Month(m))
	if day > maxDay {
		day = maxDay
	}
	return time.Date(y, time.Month(m), day, 0, 0, 0, 0, time.UTC)
}

func daysInMonth(year int, month time.Month) int {
	return time.Date(year, month+1, 0, 0, 0, 0, 0, time.UTC).Day()
}

func batchInsertSchedule(ctx context.Context, tx pgx.Tx, loanID uuid.UUID, items []scheduleItem) error {
	for i, item := range items {
		_, err := tx.Exec(ctx,
			`INSERT INTO loan_schedules (loan_id, month_number, payment, principal_part,
			 interest_part, remaining_principal, due_date) VALUES ($1,$2,$3,$4,$5,$6,$7)`,
			loanID, i+1, item.payment, item.principalPart,
			item.interestPart, item.remainingPrincipal, item.dueDate,
		)
		if err != nil {
			return status.Errorf(codes.Internal, "failed to insert schedule item %d: %v", i+1, err)
		}
	}
	return nil
}

// ── DB loading ──────────────────────────────────────────────────────────────

func (s *Service) loadLoan(ctx context.Context, loanID, userID string) (*pb.Loan, error) {
	if loanID == "" {
		return nil, status.Error(codes.InvalidArgument, "loan_id is required")
	}

	var id, uid uuid.UUID
	var name, loanType, method string
	var principal, remainingPrincipal int64
	var annualRate float64
	var totalMonths, paidMonths, paymentDay int32
	var startDate, createdAt, updatedAt time.Time
	var accountID *uuid.UUID

	err := s.pool.QueryRow(ctx,
		`SELECT id, user_id, name, loan_type, principal, remaining_principal,
		        annual_rate, total_months, paid_months, repayment_method, payment_day,
		        start_date, created_at, updated_at, account_id
		 FROM loans WHERE id=$1 AND deleted_at IS NULL`,
		loanID,
	).Scan(&id, &uid, &name, &loanType, &principal, &remainingPrincipal,
		&annualRate, &totalMonths, &paidMonths, &method, &paymentDay,
		&startDate, &createdAt, &updatedAt, &accountID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, status.Error(codes.NotFound, "loan not found")
		}
		return nil, status.Error(codes.Internal, "failed to query loan")
	}
	if uid.String() != userID {
		return nil, status.Error(codes.PermissionDenied, "not your loan")
	}

	acctStr := ""
	if accountID != nil {
		acctStr = accountID.String()
	}
	return buildLoanProto(id.String(), uid.String(), name,
		stringToLoanType(loanType), principal, remainingPrincipal,
		annualRate, totalMonths, paidMonths,
		stringToRepaymentMethod(method), paymentDay,
		startDate, createdAt, updatedAt, acctStr), nil
}

func (s *Service) loadSchedule(ctx context.Context, loanID string) ([]*pb.LoanScheduleItem, error) {
	rows, err := s.pool.Query(ctx,
		`SELECT month_number, payment, principal_part, interest_part,
		        remaining_principal, is_paid, due_date, paid_date
		 FROM loan_schedules WHERE loan_id=$1 ORDER BY month_number`,
		loanID,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to query schedule")
	}
	defer rows.Close()

	var items []*pb.LoanScheduleItem
	for rows.Next() {
		var monthNum int32
		var payment, pprt, interest, remaining int64
		var isPaid bool
		var dueDate time.Time
		var paidDate *time.Time

		if err := rows.Scan(&monthNum, &payment, &pprt, &interest, &remaining, &isPaid, &dueDate, &paidDate); err != nil {
			return nil, status.Error(codes.Internal, "failed to scan schedule item")
		}
		item := &pb.LoanScheduleItem{
			MonthNumber:        monthNum,
			Payment:            payment,
			PrincipalPart:      pprt,
			InterestPart:       interest,
			RemainingPrincipal: remaining,
			IsPaid:             isPaid,
			DueDate:            timestamppb.New(dueDate),
		}
		if paidDate != nil {
			item.PaidDate = timestamppb.New(*paidDate)
		}
		items = append(items, item)
	}
	return items, nil
}

func scanLoan(rows pgx.Rows) (*pb.Loan, error) {
	var id, uid uuid.UUID
	var name, loanType, method string
	var principal, remainingPrincipal int64
	var annualRate float64
	var totalMonths, paidMonths, paymentDay int32
	var startDate, createdAt, updatedAt time.Time
	var accountID *uuid.UUID

	if err := rows.Scan(&id, &uid, &name, &loanType, &principal, &remainingPrincipal,
		&annualRate, &totalMonths, &paidMonths, &method, &paymentDay,
		&startDate, &createdAt, &updatedAt, &accountID); err != nil {
		return nil, status.Error(codes.Internal, "failed to scan loan")
	}

	acctStr := ""
	if accountID != nil {
		acctStr = accountID.String()
	}
	return buildLoanProto(id.String(), uid.String(), name,
		stringToLoanType(loanType), principal, remainingPrincipal,
		annualRate, totalMonths, paidMonths,
		stringToRepaymentMethod(method), paymentDay,
		startDate, createdAt, updatedAt, acctStr), nil
}

func buildLoanProto(id, userID, name string, loanType pb.LoanType,
	principal, remainingPrincipal int64, annualRate float64,
	totalMonths, paidMonths int32, method pb.RepaymentMethod, paymentDay int32,
	startDate, createdAt, updatedAt time.Time, accountID string) *pb.Loan {
	return &pb.Loan{
		Id:                 id,
		UserId:             userID,
		Name:               name,
		LoanType:           loanType,
		Principal:          principal,
		RemainingPrincipal: remainingPrincipal,
		AnnualRate:         annualRate,
		TotalMonths:        totalMonths,
		PaidMonths:         paidMonths,
		RepaymentMethod:    method,
		PaymentDay:         paymentDay,
		StartDate:          timestamppb.New(startDate),
		CreatedAt:          timestamppb.New(createdAt),
		UpdatedAt:          timestamppb.New(updatedAt),
		AccountId:          accountID,
	}
}

// ── Type conversions ────────────────────────────────────────────────────────

func loanTypeToString(lt pb.LoanType) string {
	switch lt {
	case pb.LoanType_LOAN_TYPE_MORTGAGE:
		return "mortgage"
	case pb.LoanType_LOAN_TYPE_CAR_LOAN:
		return "car_loan"
	case pb.LoanType_LOAN_TYPE_CREDIT_CARD:
		return "credit_card"
	case pb.LoanType_LOAN_TYPE_CONSUMER:
		return "consumer"
	case pb.LoanType_LOAN_TYPE_BUSINESS:
		return "business"
	default:
		return "other"
	}
}

func stringToLoanType(s string) pb.LoanType {
	switch s {
	case "mortgage":
		return pb.LoanType_LOAN_TYPE_MORTGAGE
	case "car_loan":
		return pb.LoanType_LOAN_TYPE_CAR_LOAN
	case "credit_card":
		return pb.LoanType_LOAN_TYPE_CREDIT_CARD
	case "consumer":
		return pb.LoanType_LOAN_TYPE_CONSUMER
	case "business":
		return pb.LoanType_LOAN_TYPE_BUSINESS
	case "other":
		return pb.LoanType_LOAN_TYPE_OTHER
	default:
		return pb.LoanType_LOAN_TYPE_UNSPECIFIED
	}
}

func repaymentMethodToString(m pb.RepaymentMethod) string {
	switch m {
	case pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT:
		return "equal_installment"
	case pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_PRINCIPAL:
		return "equal_principal"
	default:
		return "equal_installment"
	}
}

func stringToRepaymentMethod(s string) pb.RepaymentMethod {
	switch s {
	case "equal_installment":
		return pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT
	case "equal_principal":
		return pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_PRINCIPAL
	default:
		return pb.RepaymentMethod_REPAYMENT_METHOD_UNSPECIFIED
	}
}

// ── Validation ──────────────────────────────────────────────────────────────

func validateCreateLoanRequest(req *pb.CreateLoanRequest) error {
	if req.Name == "" {
		return status.Error(codes.InvalidArgument, "name is required")
	}
	if req.LoanType == pb.LoanType_LOAN_TYPE_UNSPECIFIED {
		return status.Error(codes.InvalidArgument, "loan_type is required")
	}
	if req.Principal <= 0 {
		return status.Error(codes.InvalidArgument, "principal must be positive")
	}
	if req.AnnualRate < 0 {
		return status.Error(codes.InvalidArgument, "annual_rate must be non-negative")
	}
	if req.TotalMonths <= 0 {
		return status.Error(codes.InvalidArgument, "total_months must be positive")
	}
	if req.RepaymentMethod == pb.RepaymentMethod_REPAYMENT_METHOD_UNSPECIFIED {
		return status.Error(codes.InvalidArgument, "repayment_method is required")
	}
	if req.PaymentDay < 1 || req.PaymentDay > 28 {
		return status.Error(codes.InvalidArgument, "payment_day must be 1-28")
	}
	if req.StartDate == nil {
		return status.Error(codes.InvalidArgument, "start_date is required")
	}
	return nil
}

// ── Exported for NotifyService ──────────────────────────────────────────────

// UpcomingPayment represents a loan payment due soon.
type UpcomingPayment struct {
	LoanID      string
	UserID      string
	LoanName    string
	MonthNumber int32
	Payment     int64
	DueDate     time.Time
}

// GetUpcomingPayments returns loans with payments due within reminderDays.
func (s *Service) GetUpcomingPayments(ctx context.Context, reminderDays int) ([]UpcomingPayment, error) {
	now := time.Now()
	cutoff := now.AddDate(0, 0, reminderDays)

	rows, err := s.pool.Query(ctx,
		`SELECT l.id, l.user_id, l.name, ls.month_number, ls.payment, ls.due_date
		 FROM loan_schedules ls
		 JOIN loans l ON l.id = ls.loan_id AND l.deleted_at IS NULL
		 WHERE ls.is_paid = false
		   AND ls.due_date >= $1::date AND ls.due_date <= $2::date
		 ORDER BY ls.due_date`,
		now.Format("2006-01-02"), cutoff.Format("2006-01-02"),
	)
	if err != nil {
		return nil, fmt.Errorf("query upcoming payments: %w", err)
	}
	defer rows.Close()

	var results []UpcomingPayment
	for rows.Next() {
		var p UpcomingPayment
		var loanID, userID uuid.UUID
		if err := rows.Scan(&loanID, &userID, &p.LoanName, &p.MonthNumber, &p.Payment, &p.DueDate); err != nil {
			return nil, fmt.Errorf("scan upcoming payment: %w", err)
		}
		p.LoanID = loanID.String()
		p.UserID = userID.String()
		results = append(results, p)
	}
	return results, nil
}
