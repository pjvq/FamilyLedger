package loan

import (
	"context"
	"fmt"
	"log"
	"math"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/familyledger/server/pkg/db"
	"github.com/familyledger/server/pkg/permission"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/familyledger/server/pkg/middleware"
	pb "github.com/familyledger/server/proto/loan"
)

type Service struct {
	pb.UnimplementedLoanServiceServer
	pool db.Pool
}

func NewService(pool db.Pool) *Service {
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
	calcMethod := interestCalcMethodToString(req.InterestCalcMethod)
	startDate := req.StartDate.AsTime()

	var accountID *uuid.UUID
	if req.AccountId != "" {
		aid, err := uuid.Parse(req.AccountId)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid account_id")
		}
		accountID = &aid
	}

	var familyID *uuid.UUID
	if req.FamilyId != "" {
		fid, err := uuid.Parse(req.FamilyId)
		if err != nil {
			log.Printf("loan: create: invalid family_id %q: %v", req.FamilyId, err)
			return nil, status.Error(codes.InvalidArgument, "invalid family_id")
		}
		familyID = &fid
		if err := permission.Check(ctx, s.pool, userID, req.FamilyId, permission.CanEdit); err != nil {
			log.Printf("loan: create: permission denied for user %s on family %s: %v", userID, req.FamilyId, err)
			return nil, err
		}
	}

	schedule := generateSchedule(req.Principal, req.AnnualRate, int(req.TotalMonths), method, int(req.PaymentDay), startDate, calcMethod)

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
		 start_date, account_id, family_id, interest_calc_method)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, 0, $8, $9, $10, $11, $12, $13)
		 RETURNING id, created_at, updated_at`,
		uid, req.Name, loanType, req.Principal, req.Principal,
		req.AnnualRate, req.TotalMonths, method, req.PaymentDay,
		startDate, accountID, familyID, calcMethod,
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

	log.Printf("loan: created %s (%s) for user %s, %d items, familyId=%q", loanID, req.Name, userID, len(schedule), req.FamilyId)
	return buildLoanProto(loanID.String(), userID, req.Name, req.LoanType,
		req.Principal, req.Principal, req.AnnualRate, req.TotalMonths, 0,
		req.RepaymentMethod, req.PaymentDay, startDate, createdAt, updatedAt, req.AccountId, req.FamilyId), nil
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

	var rows pgx.Rows
	if req.FamilyId != "" {
		// Verify user is a member of this family
		var isMember bool
		err = s.pool.QueryRow(ctx,
			`SELECT EXISTS(SELECT 1 FROM family_members WHERE family_id = $1 AND user_id = $2)`,
			req.FamilyId, userID,
		).Scan(&isMember)
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to verify family membership")
		}
		if !isMember {
			return nil, status.Error(codes.PermissionDenied, "not a member of this family")
		}
		rows, err = s.pool.Query(ctx,
			`SELECT id, user_id, name, loan_type, principal, remaining_principal,
			        annual_rate, total_months, paid_months, repayment_method, payment_day,
			        start_date, created_at, updated_at, account_id,
			        group_id, sub_type, rate_type, lpr_base, lpr_spread, rate_adjust_month,
			        family_id, repayment_category_id, interest_calc_method
			 FROM loans WHERE family_id = $1 AND deleted_at IS NULL
			 ORDER BY created_at DESC`,
			req.FamilyId,
		)
	} else {
		rows, err = s.pool.Query(ctx,
			`SELECT id, user_id, name, loan_type, principal, remaining_principal,
			        annual_rate, total_months, paid_months, repayment_method, payment_day,
			        start_date, created_at, updated_at, account_id,
			        group_id, sub_type, rate_type, lpr_base, lpr_spread, rate_adjust_month,
			        family_id, repayment_category_id, interest_calc_method
			 FROM loans WHERE user_id = $1 AND deleted_at IS NULL
			 AND (family_id IS NULL OR family_id::text = '')
			 ORDER BY created_at DESC`,
			userID,
		)
	}
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
	for _, l := range loans {
		log.Printf("loan: ListLoans returning id=%s name=%s familyId=%s", l.Id, l.Name, l.FamilyId)
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

	var repCatUUID *uuid.UUID
	if req.RepaymentCategoryId != "" {
		rcid, err := uuid.Parse(req.RepaymentCategoryId)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid repayment_category_id")
		}
		repCatUUID = &rcid
	}

	_, err = s.pool.Exec(ctx,
		`UPDATE loans SET name=$1, payment_day=$2, account_id=$3, repayment_category_id=$6, updated_at=NOW()
		 WHERE id=$4 AND user_id=$5 AND deleted_at IS NULL`,
		name, paymentDay, accountUUID, req.LoanId, userID, repCatUUID,
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
	calcMethodPrepay := interestCalcMethodToString(loan.InterestCalcMethod)

	// Start date for new schedule = next unpaid due date.
	// Normalize to 1st of month — see ExecutePrepayment comment for why.
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
	nextDueDate = time.Date(nextDueDate.Year(), nextDueDate.Month(), 1, 0, 0, 0, 0, nextDueDate.Location())

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
			newSchedule = generateSchedule(newPrincipal, loan.AnnualRate, newMonths, method, int(loan.PaymentDay), nextDueDate, calcMethodPrepay)
		}

	case pb.PrepaymentStrategy_PREPAYMENT_STRATEGY_REDUCE_PAYMENT:
		// Keep same months, reduce payment
		newSchedule = generateSchedule(newPrincipal, loan.AnnualRate, remainingMonths, method, int(loan.PaymentDay), nextDueDate, calcMethodPrepay)
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



// ── ExecutePrepayment ────────────────────────────────────────────────────────

func (s *Service) ExecutePrepayment(ctx context.Context, req *pb.ExecutePrepaymentRequest) (*pb.ExecutePrepaymentResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}
	if req.LoanId == "" {
		return nil, status.Error(codes.InvalidArgument, "loan_id is required")
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
	if req.PrepaymentAmount > loan.RemainingPrincipal {
		return nil, status.Error(codes.InvalidArgument, "prepayment_amount exceeds remaining principal")
	}

	// Check family permission if applicable
	if loan.FamilyId != "" {
		if err := permission.Check(ctx, s.pool, userID, loan.FamilyId, permission.CanEdit); err != nil {
			return nil, err
		}
	}

	// Load current schedule for interest calculation
	items, err := s.loadSchedule(ctx, req.LoanId)
	if err != nil {
		return nil, err
	}

	// Original total interest
	var totalInterestBefore int64
	for _, it := range items {
		totalInterestBefore += it.InterestPart
	}

	// Interest already paid
	var paidInterest int64
	for _, it := range items {
		if it.IsPaid {
			paidInterest += it.InterestPart
		}
	}

	newPrincipal := loan.RemainingPrincipal - req.PrepaymentAmount
	remainingMonths := int(loan.TotalMonths - loan.PaidMonths)
	method := repaymentMethodToString(loan.RepaymentMethod)
	calcMethod := interestCalcMethodToString(loan.InterestCalcMethod)

	// Find next unpaid due date as start for new schedule.
	// We use the 1st of that month as the startDate for generateSchedule,
	// because advanceMonths(startDate, 0, paymentDay) adds an extra month
	// when startDate.Day() >= paymentDay. Since nextDueDate.Day() == paymentDay,
	// passing it directly would shift the first period forward by one month.
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
	// Normalize to 1st of the month so advanceMonths won't skip forward
	nextDueDate = time.Date(nextDueDate.Year(), nextDueDate.Month(), 1, 0, 0, 0, 0, nextDueDate.Location())

	// Calculate new schedule based on strategy
	var newSchedule []scheduleItem
	var newTotalMonths int32

	if newPrincipal <= 0 {
		// Full prepayment — loan is paid off
		newSchedule = nil
		newTotalMonths = loan.PaidMonths
		newPrincipal = 0
	} else {
		switch req.Strategy {
		case pb.PrepaymentStrategy_PREPAYMENT_STRATEGY_REDUCE_MONTHS:
			r := loan.AnnualRate / 100.0 / 12.0
			if method == "equal_installment" {
				var originalMonthly float64
				if r == 0 {
					originalMonthly = float64(loan.Principal) / float64(loan.TotalMonths)
				} else {
					rn := math.Pow(1+r, float64(loan.TotalMonths))
					originalMonthly = float64(loan.Principal) * r * rn / (rn - 1)
				}
				M := roundCent(originalMonthly)
				newSchedule = generateWithFixedPayment(newPrincipal, loan.AnnualRate, M, int(loan.PaymentDay), nextDueDate)
			} else if method == "interest_only" || method == "bullet" {
				// These methods can't meaningfully reduce months; fall back to reduce payment
				newSchedule = generateSchedule(newPrincipal, loan.AnnualRate, remainingMonths, method, int(loan.PaymentDay), nextDueDate, calcMethod)
			} else {
				origMonthlyPrincipal := roundCent(float64(loan.Principal) / float64(loan.TotalMonths))
				newMonths := int(math.Ceil(float64(newPrincipal) / float64(origMonthlyPrincipal)))
				if newMonths < 1 {
					newMonths = 1
				}
				newSchedule = generateSchedule(newPrincipal, loan.AnnualRate, newMonths, method, int(loan.PaymentDay), nextDueDate, calcMethod)
			}
			newTotalMonths = loan.PaidMonths + int32(len(newSchedule))

		case pb.PrepaymentStrategy_PREPAYMENT_STRATEGY_REDUCE_PAYMENT:
			newSchedule = generateSchedule(newPrincipal, loan.AnnualRate, remainingMonths, method, int(loan.PaymentDay), nextDueDate, calcMethod)
			newTotalMonths = loan.TotalMonths
		}
	}

	// Calculate interest savings
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

	// ===== Execute in transaction =====
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to begin transaction")
	}
	defer tx.Rollback(ctx)

	// 1. Update loan: remaining_principal, total_months, monthly_payment
	_, err = tx.Exec(ctx,
		`UPDATE loans SET remaining_principal = $1, total_months = $2, monthly_payment = $3, updated_at = NOW()
		 WHERE id = $4 AND deleted_at IS NULL`,
		newPrincipal, newTotalMonths, newMonthlyPayment, req.LoanId,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to update loan")
	}

	// 2. Delete all unpaid schedule items
	_, err = tx.Exec(ctx,
		`DELETE FROM loan_schedules WHERE loan_id = $1 AND is_paid = false`,
		req.LoanId,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to delete unpaid schedule")
	}

	// 3. Insert new schedule (month_number continues from paid_months+1)
	for i, item := range newSchedule {
		monthNum := int(loan.PaidMonths) + 1 + i
		_, err = tx.Exec(ctx,
			`INSERT INTO loan_schedules (loan_id, month_number, payment, principal_part,
			 interest_part, remaining_principal, due_date) VALUES ($1,$2,$3,$4,$5,$6,$7)`,
			req.LoanId, monthNum, item.payment, item.principalPart,
			item.interestPart, item.remainingPrincipal, item.dueDate,
		)
		if err != nil {
			return nil, status.Errorf(codes.Internal, "failed to insert schedule item %d: %v", monthNum, err)
		}
	}

	// 4. Deduct prepayment amount from associated account
	if loan.AccountId != "" {
		_, err = tx.Exec(ctx,
			`UPDATE accounts SET balance = balance - $1, updated_at = NOW() WHERE id = $2`,
			req.PrepaymentAmount, loan.AccountId,
		)
		if err != nil {
			log.Printf("loan: execute prepayment: failed to deduct from account %s: %v", loan.AccountId, err)
			return nil, status.Error(codes.Internal, "failed to deduct from account")
		}
	}

	// 5. Create transaction record for the prepayment
	{
		var categoryID string
		var repCatID *uuid.UUID
		err = tx.QueryRow(ctx,
			`SELECT repayment_category_id FROM loans WHERE id = $1`,
			req.LoanId,
		).Scan(&repCatID)
		if err == nil && repCatID != nil {
			categoryID = repCatID.String()
		} else {
			_ = tx.QueryRow(ctx,
				`SELECT id FROM categories WHERE name = '还款' LIMIT 1`,
			).Scan(&categoryID)
			if categoryID == "" {
				_ = tx.QueryRow(ctx,
					`SELECT id FROM categories WHERE name = '房贷' LIMIT 1`,
				).Scan(&categoryID)
			}
		}

		accountID := loan.AccountId

		if categoryID != "" && accountID != "" {
			note := fmt.Sprintf("%s 提前还款", loan.Name)
			var familyIDVal interface{}
			if loan.FamilyId != "" {
				familyIDVal = loan.FamilyId
			}
			_, txErr := tx.Exec(ctx,
				`INSERT INTO transactions (user_id, account_id, category_id, amount, amount_cny, type, note, txn_date, family_id)
				 VALUES ($1, $2, $3, $4, $4, 'expense', $5, $6, $7)`,
				userID, accountID, categoryID, req.PrepaymentAmount, note, time.Now(), familyIDVal,
			)
			if txErr != nil {
				log.Printf("loan: execute prepayment: failed to create transaction record: %v", txErr)
				// Non-fatal — payment still processed
			}
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Error(codes.Internal, "failed to commit")
	}

	log.Printf("loan: prepayment executed %s: amount=%d strategy=%s newPrincipal=%d newMonths=%d",
		req.LoanId, req.PrepaymentAmount, req.Strategy, newPrincipal, newTotalMonths)

	// Build response — update the loan proto we already have
	loan.RemainingPrincipal = newPrincipal
	loan.TotalMonths = newTotalMonths

	protoNewItems := make([]*pb.LoanScheduleItem, len(newSchedule))
	for i, si := range newSchedule {
		protoNewItems[i] = &pb.LoanScheduleItem{
			MonthNumber:        int32(int(loan.PaidMonths) + 1 + i),
			Payment:            si.payment,
			PrincipalPart:      si.principalPart,
			InterestPart:       si.interestPart,
			RemainingPrincipal: si.remainingPrincipal,
			IsPaid:             false,
			DueDate:            timestamppb.New(si.dueDate),
		}
	}

	return &pb.ExecutePrepaymentResponse{
		Loan: loan,
		Simulation: &pb.PrepaymentSimulation{
			PrepaymentAmount:    req.PrepaymentAmount,
			TotalInterestBefore: totalInterestBefore,
			TotalInterestAfter:  totalInterestAfter,
			InterestSaved:       interestSaved,
			MonthsReduced:       monthsReduced,
			NewMonthlyPayment:   newMonthlyPayment,
		},
		NewSchedule: protoNewItems,
	}, nil
}

// ── ExecuteGroupPrepayment ───────────────────────────────────────────────────

func (s *Service) ExecuteGroupPrepayment(ctx context.Context, req *pb.ExecuteGroupPrepaymentRequest) (*pb.ExecuteGroupPrepaymentResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}
	if req.GroupId == "" {
		return nil, status.Error(codes.InvalidArgument, "group_id is required")
	}
	if req.PrepaymentAmount <= 0 {
		return nil, status.Error(codes.InvalidArgument, "prepayment_amount must be positive")
	}
	if req.Strategy == pb.PrepaymentStrategy_PREPAYMENT_STRATEGY_UNSPECIFIED {
		return nil, status.Error(codes.InvalidArgument, "strategy is required")
	}

	group, err := s.loadLoanGroup(ctx, req.GroupId, userID)
	if err != nil {
		return nil, err
	}

	targetLoanID := req.TargetLoanId
	if targetLoanID == "" {
		var maxRate float64
		for _, sl := range group.SubLoans {
			if sl.AnnualRate > maxRate {
				maxRate = sl.AnnualRate
				targetLoanID = sl.Id
			}
		}
	}
	if targetLoanID == "" {
		return nil, status.Error(codes.InvalidArgument, "no sub-loans found in group")
	}

	resp, err := s.ExecutePrepayment(ctx, &pb.ExecutePrepaymentRequest{
		LoanId:           targetLoanID,
		PrepaymentAmount: req.PrepaymentAmount,
		Strategy:         req.Strategy,
	})
	if err != nil {
		return nil, err
	}

	return &pb.ExecuteGroupPrepaymentResponse{
		TargetLoanId: targetLoanID,
		Loan:         resp.Loan,
		Simulation:   resp.Simulation,
		NewSchedule:  resp.NewSchedule,
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

	// Get due date of first unpaid month.
	// Normalize to 1st of month — see ExecutePrepayment comment for why.
	var nextDueDate time.Time
	err = tx.QueryRow(ctx,
		`SELECT due_date FROM loan_schedules WHERE loan_id=$1 AND month_number=$2`,
		req.LoanId, nextUnpaidMonth,
	).Scan(&nextDueDate)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to get next due date")
	}
	nextDueDate = time.Date(nextDueDate.Year(), nextDueDate.Month(), 1, 0, 0, 0, 0, nextDueDate.Location())

	newMonthCount := int(loan.TotalMonths) - int(nextUnpaidMonth) + 1
	method := repaymentMethodToString(loan.RepaymentMethod)
	calcMethodRate := interestCalcMethodToString(loan.InterestCalcMethod)
	newItems := generateSchedule(rpBefore, req.NewRate, newMonthCount, method, int(loan.PaymentDay), nextDueDate, calcMethodRate)

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
	loan, err := s.loadLoan(ctx, req.LoanId, userID)
	if err != nil {
		return nil, err
	}

	// Enforce sequential payment: only allow paying the next unpaid period
	var nextUnpaid int32
	err = s.pool.QueryRow(ctx,
		`SELECT COALESCE(MIN(month_number), 0) FROM loan_schedules WHERE loan_id=$1 AND is_paid=false`,
		req.LoanId,
	).Scan(&nextUnpaid)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to check payment sequence")
	}
	if nextUnpaid == 0 || req.MonthNumber != nextUnpaid {
		// Idempotent: if the requested month is already paid, return its data
		var existingItem pb.LoanScheduleItem
		var existingDueDate time.Time
		var existingPaidDate time.Time
		err = s.pool.QueryRow(ctx,
			`SELECT month_number, payment, principal_part, interest_part, remaining_principal, due_date, paid_date
			 FROM loan_schedules WHERE loan_id=$1 AND month_number=$2 AND is_paid=true`,
			req.LoanId, req.MonthNumber,
		).Scan(&existingItem.MonthNumber, &existingItem.Payment, &existingItem.PrincipalPart,
			&existingItem.InterestPart, &existingItem.RemainingPrincipal, &existingDueDate, &existingPaidDate)
		if err == nil {
			// Already paid — return idempotent success
			existingItem.IsPaid = true
			existingItem.DueDate = timestamppb.New(existingDueDate)
			existingItem.PaidDate = timestamppb.New(existingPaidDate)
			return &existingItem, nil
		}
		if err != pgx.ErrNoRows {
			return nil, status.Error(codes.Internal, "failed to check existing payment")
		}
		// Not already paid — return the original error
		if nextUnpaid == 0 {
			return nil, status.Error(codes.FailedPrecondition, "all payments already completed")
		}
		return nil, status.Errorf(codes.FailedPrecondition,
			"must pay period %d before period %d (sequential payment required)", nextUnpaid, req.MonthNumber)
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

	// Deduct payment amount from the associated account balance.
	if loan.AccountId != "" {
		_, err = tx.Exec(ctx,
			`UPDATE accounts SET balance = balance - $1, updated_at = NOW()
			 WHERE id = $2`,
			item.Payment, loan.AccountId,
		)
		if err != nil {
			log.Printf("loan: failed to deduct payment from account %s: %v", loan.AccountId, err)
			return nil, status.Error(codes.Internal, "failed to deduct payment from account")
		}
		log.Printf("loan: deducted %d from account %s for loan %s month %d", item.Payment, loan.AccountId, req.LoanId, req.MonthNumber)
	}

	// Create a transaction record for the loan payment
	{
		// First check if the loan has a custom repayment category
		var categoryID string
		var repCatID *uuid.UUID
		err = tx.QueryRow(ctx,
			`SELECT repayment_category_id FROM loans WHERE id = $1`,
			req.LoanId,
		).Scan(&repCatID)
		if err == nil && repCatID != nil {
			categoryID = repCatID.String()
		} else {
			// Fallback: find the "还款" category
			err = tx.QueryRow(ctx,
				`SELECT id FROM categories WHERE name = '还款' LIMIT 1`,
			).Scan(&categoryID)
			if err != nil {
				// Fallback: try "房贷"
				err = tx.QueryRow(ctx,
					`SELECT id FROM categories WHERE name = '房贷' LIMIT 1`,
				).Scan(&categoryID)
				if err != nil {
					log.Printf("loan: no repayment category found, skipping transaction record")
					goto skipTransaction
				}
			}
		}

		accountID := loan.AccountId
		if accountID == "" {
			log.Printf("loan: no account linked to loan, skipping transaction record")
			goto skipTransaction
		}

		note := fmt.Sprintf("%s 第%d期还款", loan.Name, req.MonthNumber)
		var familyIDVal interface{}
		if loan.FamilyId != "" {
			familyIDVal = loan.FamilyId
		}
		_, err = tx.Exec(ctx,
			`INSERT INTO transactions (user_id, account_id, category_id, amount, amount_cny, type, note, txn_date, family_id)
			 VALUES ($1, $2, $3, $4, $4, 'expense', $5, $6, $7)`,
			userID, accountID, categoryID, item.Payment, note, now, familyIDVal,
		)
		if err != nil {
			log.Printf("loan: failed to create transaction record: %v", err)
			// Non-fatal: payment is still recorded, just no transaction entry
		}
	}
skipTransaction:

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

// daysInPeriod returns the actual number of days between two consecutive due dates.
func daysInPeriod(from, to time.Time) int {
	return int(to.Sub(from).Hours() / 24)
}

// dailyRate returns the daily interest rate based on the calc method.
func dailyRate(annualRate float64, calcMethod string) float64 {
	switch calcMethod {
	case "daily_act_360":
		return annualRate / 100.0 / 360.0
	default: // daily_act_365
		return annualRate / 100.0 / 365.0
	}
}

// generateSchedule creates the full amortization schedule from scratch.
func generateSchedule(principal int64, annualRate float64, totalMonths int, method string, paymentDay int, startDate time.Time, calcMethod string) []scheduleItem {
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

	case "interest_only":
		// 先息后本: 每月只付利息，最后一期还本+利息
		for i := 0; i < n; i++ {
			dueDate := advanceMonths(startDate, i, paymentDay)
			var interest int64
			if calcMethod == "daily_act_365" || calcMethod == "daily_act_360" {
				// 按日计息：利息 = 本金 × 日利率 × 当期实际天数
				dr := dailyRate(annualRate, calcMethod)
				var periodStart time.Time
				if i == 0 {
					periodStart = startDate
				} else {
					periodStart = advanceMonths(startDate, i-1, paymentDay)
				}
				days := daysInPeriod(periodStart, dueDate)
				if days <= 0 {
					log.Printf("loan: unexpected zero-day period at month %d, periodStart=%v dueDate=%v, using 30-day fallback", i+1, periodStart, dueDate)
					days = 30 // fallback
				}
				interest = roundCent(P * dr * float64(days))
			} else {
				// 按月计息
				interest = roundCent(P * r)
			}
			var pprt int64
			if i == n-1 {
				// 最后一期还本
				pprt = principal
			}
			items[i] = scheduleItem{
				payment:            pprt + interest,
				principalPart:      pprt,
				interestPart:       interest,
				remainingPrincipal: principal - pprt,
				dueDate:            dueDate,
			}
		}

	case "bullet":
		// 一次性还本付息: 期间无任何还款，到期还本+累计利息
		var totalInterest int64
		if calcMethod == "daily_act_365" || calcMethod == "daily_act_360" {
			// 按日计息：累加每期实际天数
			dr := dailyRate(annualRate, calcMethod)
			prevDate := startDate
			for i := 0; i < n; i++ {
				dueDate := advanceMonths(startDate, i, paymentDay)
				days := daysInPeriod(prevDate, dueDate)
				if days <= 0 {
					log.Printf("loan: unexpected zero-day period at month %d, prevDate=%v dueDate=%v, using 30-day fallback", i, prevDate, dueDate)
					days = 30
				}
				totalInterest += roundCent(P * dr * float64(days))
				prevDate = dueDate
			}
		} else {
			totalInterest = roundCent(P * r * float64(n))
		}
		for i := 0; i < n; i++ {
			dueDate := advanceMonths(startDate, i, paymentDay)
			if i == n-1 {
				items[i] = scheduleItem{
					payment:            principal + totalInterest,
					principalPart:      principal,
					interestPart:       totalInterest,
					remainingPrincipal: 0,
					dueDate:            dueDate,
				}
			} else {
				items[i] = scheduleItem{
					payment:            0,
					principalPart:      0,
					interestPart:       0,
					remainingPrincipal: principal,
					dueDate:            dueDate,
				}
			}
		}

	case "equal_interest":
		// 等本等息: 每月固定本金 + 固定利息（利息按初始本金计算）
		monthlyPrincipal := roundCent(P / float64(n))
		monthlyInterest := roundCent(P * r)
		remaining := principal

		for i := 0; i < n; i++ {
			dueDate := advanceMonths(startDate, i, paymentDay)
			pprt := monthlyPrincipal
			if i == n-1 {
				pprt = remaining // 清除尾差
			}
			remaining -= pprt

			items[i] = scheduleItem{
				payment:            pprt + monthlyInterest,
				principalPart:      pprt,
				interestPart:       monthlyInterest,
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
	var groupID *uuid.UUID
	var subType, rateType *string
	var lprBase, lprSpread *float64
	var rateAdjustMonth *int32
	var familyID *uuid.UUID
	var repCatID *uuid.UUID
	var loadCalcMethod string

	err := s.pool.QueryRow(ctx,
		`SELECT id, user_id, name, loan_type, principal, remaining_principal,
		        annual_rate, total_months, paid_months, repayment_method, payment_day,
		        start_date, created_at, updated_at, account_id,
		        group_id, sub_type, rate_type, lpr_base, lpr_spread, rate_adjust_month,
		        family_id, repayment_category_id, interest_calc_method
		 FROM loans WHERE id=$1 AND deleted_at IS NULL`,
		loanID,
	).Scan(&id, &uid, &name, &loanType, &principal, &remainingPrincipal,
		&annualRate, &totalMonths, &paidMonths, &method, &paymentDay,
		&startDate, &createdAt, &updatedAt, &accountID,
		&groupID, &subType, &rateType, &lprBase, &lprSpread, &rateAdjustMonth,
		&familyID, &repCatID, &loadCalcMethod)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, status.Error(codes.NotFound, "loan not found")
		}
		return nil, status.Error(codes.Internal, "failed to query loan")
	}
	if uid.String() != userID {
		// If this is a family loan, check family membership
		if familyID != nil {
			if err := permission.Check(ctx, s.pool, userID, familyID.String(), permission.CanView); err != nil {
				return nil, status.Error(codes.PermissionDenied, "not your loan")
			}
		} else {
			return nil, status.Error(codes.PermissionDenied, "not your loan")
		}
	}

	f := loanFields{
		id: id.String(), userID: uid.String(), name: name,
		loanType: stringToLoanType(loanType), principal: principal,
		remainingPrinc: remainingPrincipal, annualRate: annualRate,
		totalMonths: totalMonths, paidMonths: paidMonths,
		method: stringToRepaymentMethod(method), paymentDay: paymentDay,
		startDate: startDate, createdAt: createdAt, updatedAt: updatedAt,
	}
	if accountID != nil {
		f.accountID = accountID.String()
	}
	if groupID != nil {
		f.groupID = groupID.String()
	}
	if subType != nil {
		f.subType = stringToLoanSubType(*subType)
	}
	if rateType != nil {
		f.rateType = stringToRateType(*rateType)
	}
	if lprBase != nil {
		f.lprBase = *lprBase
	}
	if lprSpread != nil {
		f.lprSpread = *lprSpread
	}
	if rateAdjustMonth != nil {
		f.rateAdjustMonth = *rateAdjustMonth
	}
	if familyID != nil {
		f.familyID = familyID.String()
	}
	if repCatID != nil {
		f.repaymentCategoryID = repCatID.String()
	}
	f.interestCalcMethod = stringToInterestCalcMethod(loadCalcMethod)
	return buildLoanProtoFull(f), nil
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
	var groupID *uuid.UUID
	var subType, rateType *string
	var lprBase, lprSpread *float64
	var rateAdjustMonth *int32
	var familyID *uuid.UUID
	var repCatID *uuid.UUID
	var interestCalcMethodStr string

	if err := rows.Scan(&id, &uid, &name, &loanType, &principal, &remainingPrincipal,
		&annualRate, &totalMonths, &paidMonths, &method, &paymentDay,
		&startDate, &createdAt, &updatedAt, &accountID,
		&groupID, &subType, &rateType, &lprBase, &lprSpread, &rateAdjustMonth, &familyID, &repCatID, &interestCalcMethodStr); err != nil {
		return nil, status.Error(codes.Internal, "failed to scan loan")
	}

	f := loanFields{
		id: id.String(), userID: uid.String(), name: name,
		loanType: stringToLoanType(loanType), principal: principal,
		remainingPrinc: remainingPrincipal, annualRate: annualRate,
		totalMonths: totalMonths, paidMonths: paidMonths,
		method: stringToRepaymentMethod(method), paymentDay: paymentDay,
		startDate: startDate, createdAt: createdAt, updatedAt: updatedAt,
	}
	if accountID != nil {
		f.accountID = accountID.String()
	}
	if groupID != nil {
		f.groupID = groupID.String()
	}
	if subType != nil {
		f.subType = stringToLoanSubType(*subType)
	}
	if rateType != nil {
		f.rateType = stringToRateType(*rateType)
	}
	if lprBase != nil {
		f.lprBase = *lprBase
	}
	if lprSpread != nil {
		f.lprSpread = *lprSpread
	}
	if rateAdjustMonth != nil {
		f.rateAdjustMonth = *rateAdjustMonth
	}
	if familyID != nil {
		f.familyID = familyID.String()
	}
	f.interestCalcMethod = stringToInterestCalcMethod(interestCalcMethodStr)
	return buildLoanProtoFull(f), nil
}

type loanFields struct {
	id, userID, name string
	loanType         pb.LoanType
	principal        int64
	remainingPrinc   int64
	annualRate       float64
	totalMonths      int32
	paidMonths       int32
	method           pb.RepaymentMethod
	paymentDay       int32
	startDate        time.Time
	createdAt        time.Time
	updatedAt        time.Time
	accountID        string
	groupID          string
	subType          pb.LoanSubType
	rateType         pb.RateType
	lprBase          float64
	lprSpread        float64
	rateAdjustMonth  int32
	familyID         string
	repaymentCategoryID string
	interestCalcMethod  pb.InterestCalcMethod
}

func buildLoanProto(id, userID, name string, loanType pb.LoanType,
	principal, remainingPrincipal int64, annualRate float64,
	totalMonths, paidMonths int32, method pb.RepaymentMethod, paymentDay int32,
	startDate, createdAt, updatedAt time.Time, accountID, familyID string) *pb.Loan {
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
		FamilyId:           familyID,
	}
}

func buildLoanProtoFull(f loanFields) *pb.Loan {
		loan := buildLoanProto(f.id, f.userID, f.name, f.loanType,
		f.principal, f.remainingPrinc, f.annualRate,
		f.totalMonths, f.paidMonths, f.method, f.paymentDay,
		f.startDate, f.createdAt, f.updatedAt, f.accountID, f.familyID)
	loan.GroupId = f.groupID
	loan.SubType = f.subType
	loan.RateType = f.rateType
	loan.LprBase = f.lprBase
	loan.LprSpread = f.lprSpread
	loan.RateAdjustMonth = f.rateAdjustMonth
	loan.FamilyId = f.familyID
	loan.RepaymentCategoryId = f.repaymentCategoryID
	loan.InterestCalcMethod = f.interestCalcMethod
	return loan
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
	case pb.RepaymentMethod_REPAYMENT_METHOD_INTEREST_ONLY:
		return "interest_only"
	case pb.RepaymentMethod_REPAYMENT_METHOD_BULLET:
		return "bullet"
	case pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INTEREST:
		return "equal_interest"
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
	case "interest_only":
		return pb.RepaymentMethod_REPAYMENT_METHOD_INTEREST_ONLY
	case "bullet":
		return pb.RepaymentMethod_REPAYMENT_METHOD_BULLET
	case "equal_interest":
		return pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INTEREST
	default:
		return pb.RepaymentMethod_REPAYMENT_METHOD_UNSPECIFIED
	}
}

func loanSubTypeToString(st pb.LoanSubType) string {
	switch st {
	case pb.LoanSubType_LOAN_SUB_TYPE_COMMERCIAL:
		return "commercial"
	case pb.LoanSubType_LOAN_SUB_TYPE_PROVIDENT:
		return "provident"
	default:
		return "commercial"
	}
}

func stringToLoanSubType(s string) pb.LoanSubType {
	switch s {
	case "commercial":
		return pb.LoanSubType_LOAN_SUB_TYPE_COMMERCIAL
	case "provident":
		return pb.LoanSubType_LOAN_SUB_TYPE_PROVIDENT
	default:
		return pb.LoanSubType_LOAN_SUB_TYPE_UNSPECIFIED
	}
}

func rateTypeToString(rt pb.RateType) string {
	switch rt {
	case pb.RateType_RATE_TYPE_FIXED:
		return "fixed"
	case pb.RateType_RATE_TYPE_LPR_FLOATING:
		return "lpr_floating"
	default:
		return "fixed"
	}
}

func interestCalcMethodToString(m pb.InterestCalcMethod) string {
	switch m {
	case pb.InterestCalcMethod_INTEREST_CALC_DAILY_ACT_365:
		return "daily_act_365"
	case pb.InterestCalcMethod_INTEREST_CALC_DAILY_ACT_360:
		return "daily_act_360"
	default:
		return "monthly"
	}
}

func stringToInterestCalcMethod(s string) pb.InterestCalcMethod {
	switch s {
	case "daily_act_365":
		return pb.InterestCalcMethod_INTEREST_CALC_DAILY_ACT_365
	case "daily_act_360":
		return pb.InterestCalcMethod_INTEREST_CALC_DAILY_ACT_360
	default:
		return pb.InterestCalcMethod_INTEREST_CALC_MONTHLY
	}
}

func stringToRateType(s string) pb.RateType {
	switch s {
	case "fixed":
		return pb.RateType_RATE_TYPE_FIXED
	case "lpr_floating":
		return pb.RateType_RATE_TYPE_LPR_FLOATING
	default:
		return pb.RateType_RATE_TYPE_UNSPECIFIED
	}
}

// calculateLPRRate returns the effective rate from LPR base + spread.
func calculateLPRRate(base, spread float64) float64 {
	return base + spread
}

// ── Loan Group RPCs ─────────────────────────────────────────────────────────

func (s *Service) CreateLoanGroup(ctx context.Context, req *pb.CreateLoanGroupRequest) (*pb.LoanGroup, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	// Validate
	if req.Name == "" {
		return nil, status.Error(codes.InvalidArgument, "name is required")
	}
	if req.GroupType == "" {
		return nil, status.Error(codes.InvalidArgument, "group_type is required")
	}
	if req.PaymentDay < 1 || req.PaymentDay > 28 {
		return nil, status.Error(codes.InvalidArgument, "payment_day must be 1-28")
	}
	if req.StartDate == nil {
		return nil, status.Error(codes.InvalidArgument, "start_date is required")
	}
	if len(req.SubLoans) == 0 || len(req.SubLoans) > 2 {
		return nil, status.Error(codes.InvalidArgument, "sub_loans must have 1-2 items")
	}
	for i, sl := range req.SubLoans {
		if sl.Principal <= 0 {
			return nil, status.Errorf(codes.InvalidArgument, "sub_loan[%d].principal must be positive", i)
		}
		if sl.AnnualRate < 0 {
			return nil, status.Errorf(codes.InvalidArgument, "sub_loan[%d].annual_rate must be non-negative", i)
		}
		if sl.TotalMonths <= 0 {
			return nil, status.Errorf(codes.InvalidArgument, "sub_loan[%d].total_months must be positive", i)
		}
		if sl.RepaymentMethod == pb.RepaymentMethod_REPAYMENT_METHOD_UNSPECIFIED {
			return nil, status.Errorf(codes.InvalidArgument, "sub_loan[%d].repayment_method is required", i)
		}
	}

	uid, err := uuid.Parse(userID)
	if err != nil {
		return nil, status.Error(codes.Internal, "invalid user id")
	}

	startDate := req.StartDate.AsTime()

	var accountID *uuid.UUID
	if req.AccountId != "" {
		aid, err := uuid.Parse(req.AccountId)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid account_id")
		}
		accountID = &aid
	}

	// Compute total principal
	var totalPrincipal int64
	for _, sl := range req.SubLoans {
		totalPrincipal += sl.Principal
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to begin transaction")
	}
	defer tx.Rollback(ctx)

	// Create loan_group
	var groupID uuid.UUID
	var createdAt, updatedAt time.Time

	var familyIDPtr *uuid.UUID
	if req.FamilyId != "" {
		fid, err := uuid.Parse(req.FamilyId)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid family_id")
		}
		if err := permission.Check(ctx, s.pool, userID, req.FamilyId, permission.CanEdit); err != nil {
			return nil, err
		}
		familyIDPtr = &fid
	}

	err = tx.QueryRow(ctx,
		`INSERT INTO loan_groups (user_id, name, group_type, total_principal, payment_day, start_date, account_id, family_id)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		 RETURNING id, created_at, updated_at`,
		uid, req.Name, req.GroupType, totalPrincipal, req.PaymentDay, startDate, accountID, familyIDPtr,
	).Scan(&groupID, &createdAt, &updatedAt)
	if err != nil {
		log.Printf("loan: create group error: %v", err)
		return nil, status.Error(codes.Internal, "failed to create loan group")
	}

	// Create sub-loans
	var subLoanProtos []*pb.Loan
	var totalMonthlyPayment int64
	loanTypeStr := loanTypeToString(req.LoanType)

	for _, sl := range req.SubLoans {
		subTypeStr := loanSubTypeToString(sl.SubType)
		rateTypeStr := rateTypeToString(sl.RateType)
		methodStr := repaymentMethodToString(sl.RepaymentMethod)
		slCalcMethod := interestCalcMethodToString(sl.InterestCalcMethod)

		// Determine effective annual rate
		annualRate := sl.AnnualRate
		if sl.RateType == pb.RateType_RATE_TYPE_LPR_FLOATING {
			annualRate = calculateLPRRate(sl.LprBase, sl.LprSpread)
		}

		// Use sub-loan name or derive from group name
		subName := sl.Name
		if subName == "" {
			if sl.SubType == pb.LoanSubType_LOAN_SUB_TYPE_PROVIDENT {
				subName = req.Name + "-公积金"
			} else {
				subName = req.Name + "-商贷"
			}
		}

		schedule := generateSchedule(sl.Principal, annualRate, int(sl.TotalMonths), methodStr, int(req.PaymentDay), startDate, slCalcMethod)

		var loanID uuid.UUID
		var lCreatedAt, lUpdatedAt time.Time
		var lprBasePtr, lprSpreadPtr *float64
		var rateAdjustMonthPtr *int32
		if sl.RateType == pb.RateType_RATE_TYPE_LPR_FLOATING {
			lprBasePtr = &sl.LprBase
			lprSpreadPtr = &sl.LprSpread
			ram := sl.RateAdjustMonth
			rateAdjustMonthPtr = &ram
		}

		err = tx.QueryRow(ctx,
			`INSERT INTO loans (user_id, name, loan_type, principal, remaining_principal,
			 annual_rate, total_months, paid_months, repayment_method, payment_day,
			 start_date, account_id, group_id, sub_type, rate_type, lpr_base, lpr_spread, rate_adjust_month, family_id, interest_calc_method)
			 VALUES ($1,$2,$3,$4,$5,$6,$7,0,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19)
			 RETURNING id, created_at, updated_at`,
			uid, subName, loanTypeStr, sl.Principal, sl.Principal,
			annualRate, sl.TotalMonths, methodStr, req.PaymentDay,
			startDate, accountID, groupID, subTypeStr, rateTypeStr,
			lprBasePtr, lprSpreadPtr, rateAdjustMonthPtr, familyIDPtr, slCalcMethod,
		).Scan(&loanID, &lCreatedAt, &lUpdatedAt)
		if err != nil {
			log.Printf("loan: create sub-loan error: %v", err)
			return nil, status.Error(codes.Internal, "failed to create sub-loan")
		}

		if err := batchInsertSchedule(ctx, tx, loanID, schedule); err != nil {
			return nil, err
		}

		// Calculate first month payment for total
		if len(schedule) > 0 {
			totalMonthlyPayment += schedule[0].payment
		}

		acctStr := ""
		if accountID != nil {
			acctStr = accountID.String()
		}

		f := loanFields{
			id: loanID.String(), userID: userID, name: subName,
			loanType: req.LoanType, principal: sl.Principal,
			remainingPrinc: sl.Principal, annualRate: annualRate,
			totalMonths: sl.TotalMonths, paidMonths: 0,
			method: sl.RepaymentMethod, paymentDay: req.PaymentDay,
			startDate: startDate, createdAt: lCreatedAt, updatedAt: lUpdatedAt,
			accountID: acctStr, groupID: groupID.String(),
			subType: sl.SubType, rateType: sl.RateType,
			lprBase: sl.LprBase, lprSpread: sl.LprSpread,
			rateAdjustMonth: sl.RateAdjustMonth,
			familyID: req.FamilyId,
		}
		subLoanProtos = append(subLoanProtos, buildLoanProtoFull(f))
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Error(codes.Internal, "failed to commit")
	}

	acctStr := ""
	if accountID != nil {
		acctStr = accountID.String()
	}

	log.Printf("loan: created group %s (%s) with %d sub-loans for user %s familyId=%q", groupID, req.Name, len(subLoanProtos), userID, req.FamilyId)
	return &pb.LoanGroup{
		Id:                 groupID.String(),
		UserId:             userID,
		Name:               req.Name,
		GroupType:          req.GroupType,
		TotalPrincipal:     totalPrincipal,
		PaymentDay:         req.PaymentDay,
		LoanType:           req.LoanType,
		FamilyId:           req.FamilyId,
		StartDate:          timestamppb.New(startDate),
		AccountId:          acctStr,
		SubLoans:           subLoanProtos,
		TotalMonthlyPayment: totalMonthlyPayment,
		CreatedAt:          timestamppb.New(createdAt),
		UpdatedAt:          timestamppb.New(updatedAt),
	}, nil
}

func (s *Service) GetLoanGroup(ctx context.Context, req *pb.GetLoanGroupRequest) (*pb.LoanGroup, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}
	if req.GroupId == "" {
		return nil, status.Error(codes.InvalidArgument, "group_id is required")
	}
	return s.loadLoanGroup(ctx, req.GroupId, userID)
}

func (s *Service) ListLoanGroups(ctx context.Context, req *pb.ListLoanGroupsRequest) (*pb.ListLoanGroupsResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	var rows pgx.Rows
	if req.FamilyId != "" {
		rows, err = s.pool.Query(ctx,
			`SELECT id, name, group_type, total_principal, payment_day, start_date,
			        account_id, family_id, created_at, updated_at
			 FROM loan_groups WHERE family_id = $1 AND deleted_at IS NULL
			 ORDER BY created_at DESC`,
			req.FamilyId,
		)
	} else {
		rows, err = s.pool.Query(ctx,
			`SELECT id, name, group_type, total_principal, payment_day, start_date,
			        account_id, family_id, created_at, updated_at
			 FROM loan_groups WHERE user_id = $1 AND deleted_at IS NULL
			 AND (family_id IS NULL OR family_id::text = '')
			 ORDER BY created_at DESC`,
			userID,
		)
	}
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to query loan groups")
	}
	defer rows.Close()

	var groups []*pb.LoanGroup
	for rows.Next() {
		var gID uuid.UUID
		var name, groupType string
		var totalPrincipal int64
		var paymentDay int32
		var startDate, createdAt, updatedAt time.Time
		var accountID *uuid.UUID
		var familyID *uuid.UUID

		if err := rows.Scan(&gID, &name, &groupType, &totalPrincipal, &paymentDay,
			&startDate, &accountID, &familyID, &createdAt, &updatedAt); err != nil {
			return nil, status.Error(codes.Internal, "failed to scan loan group")
		}

		// Load sub-loans
		subLoans, err := s.loadSubLoans(ctx, gID.String(), userID)
		if err != nil {
			return nil, err
		}

		var totalMonthly int64
		for _, sl := range subLoans {
			// Use first unpaid schedule item or compute from params
			items, schedErr := s.loadSchedule(ctx, sl.Id)
			if schedErr == nil {
				for _, it := range items {
					if !it.IsPaid {
						totalMonthly += it.Payment
						break
					}
				}
			}
		}

		acctStr := ""
		if accountID != nil {
			acctStr = accountID.String()
		}
		famStr := ""
		if familyID != nil {
			famStr = familyID.String()
		}

		groups = append(groups, &pb.LoanGroup{
			Id:                 gID.String(),
			UserId:             userID,
			FamilyId:           famStr,
			Name:               name,
			GroupType:          groupType,
			TotalPrincipal:     totalPrincipal,
			PaymentDay:         paymentDay,
			StartDate:          timestamppb.New(startDate),
			AccountId:          acctStr,
			SubLoans:           subLoans,
			TotalMonthlyPayment: totalMonthly,
			CreatedAt:          timestamppb.New(createdAt),
			UpdatedAt:          timestamppb.New(updatedAt),
		})
	}
	if groups == nil {
		groups = []*pb.LoanGroup{}
	}
	return &pb.ListLoanGroupsResponse{Groups: groups}, nil
}

func (s *Service) SimulateGroupPrepayment(ctx context.Context, req *pb.SimulateGroupPrepaymentRequest) (*pb.GroupPrepaymentSimulation, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}
	if req.GroupId == "" {
		return nil, status.Error(codes.InvalidArgument, "group_id is required")
	}
	if req.PrepaymentAmount <= 0 {
		return nil, status.Error(codes.InvalidArgument, "prepayment_amount must be positive")
	}
	if req.Strategy == pb.PrepaymentStrategy_PREPAYMENT_STRATEGY_UNSPECIFIED {
		return nil, status.Error(codes.InvalidArgument, "strategy is required")
	}

	group, err := s.loadLoanGroup(ctx, req.GroupId, userID)
	if err != nil {
		return nil, err
	}

	// Determine target loan
	targetLoanID := req.TargetLoanId
	if targetLoanID == "" {
		// Auto-select: pick the sub-loan with the highest annual_rate
		var maxRate float64
		for _, sl := range group.SubLoans {
			if sl.AnnualRate > maxRate {
				maxRate = sl.AnnualRate
				targetLoanID = sl.Id
			}
		}
	}

	if targetLoanID == "" {
		return nil, status.Error(codes.InvalidArgument, "no sub-loans found in group")
	}

	// Use existing SimulatePrepayment on the target loan
	sim, err := s.SimulatePrepayment(ctx, &pb.SimulatePrepaymentRequest{
		LoanId:           targetLoanID,
		PrepaymentAmount: req.PrepaymentAmount,
		Strategy:         req.Strategy,
	})
	if err != nil {
		return nil, err
	}

	return &pb.GroupPrepaymentSimulation{
		TargetLoanId:       targetLoanID,
		TargetSim:          sim,
		TotalInterestSaved: sim.InterestSaved,
	}, nil
}

// loadLoanGroup loads a loan group with its sub-loans.
func (s *Service) loadLoanGroup(ctx context.Context, groupID, userID string) (*pb.LoanGroup, error) {
	var gID uuid.UUID
	var uid uuid.UUID
	var name, groupType string
	var totalPrincipal int64
	var paymentDay int32
	var startDate, createdAt, updatedAt time.Time
	var accountID *uuid.UUID

	err := s.pool.QueryRow(ctx,
		`SELECT id, user_id, name, group_type, total_principal, payment_day,
		        start_date, account_id, created_at, updated_at
		 FROM loan_groups WHERE id=$1 AND deleted_at IS NULL`,
		groupID,
	).Scan(&gID, &uid, &name, &groupType, &totalPrincipal, &paymentDay,
		&startDate, &accountID, &createdAt, &updatedAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, status.Error(codes.NotFound, "loan group not found")
		}
		return nil, status.Error(codes.Internal, "failed to query loan group")
	}
	if uid.String() != userID {
		return nil, status.Error(codes.PermissionDenied, "not your loan group")
	}

	subLoans, err := s.loadSubLoans(ctx, gID.String(), userID)
	if err != nil {
		return nil, err
	}

	var totalMonthly int64
	for _, sl := range subLoans {
		items, schedErr := s.loadSchedule(ctx, sl.Id)
		if schedErr == nil {
			for _, it := range items {
				if !it.IsPaid {
					totalMonthly += it.Payment
					break
				}
			}
		}
	}

	acctStr := ""
	if accountID != nil {
		acctStr = accountID.String()
	}

	return &pb.LoanGroup{
		Id:                 gID.String(),
		UserId:             userID,
		Name:               name,
		GroupType:          groupType,
		TotalPrincipal:     totalPrincipal,
		PaymentDay:         paymentDay,
		StartDate:          timestamppb.New(startDate),
		AccountId:          acctStr,
		SubLoans:           subLoans,
		TotalMonthlyPayment: totalMonthly,
		CreatedAt:          timestamppb.New(createdAt),
		UpdatedAt:          timestamppb.New(updatedAt),
	}, nil
}

// loadSubLoans loads all sub-loans belonging to a group.
func (s *Service) loadSubLoans(ctx context.Context, groupID, userID string) ([]*pb.Loan, error) {
	rows, err := s.pool.Query(ctx,
		`SELECT id, user_id, name, loan_type, principal, remaining_principal,
		        annual_rate, total_months, paid_months, repayment_method, payment_day,
		        start_date, created_at, updated_at, account_id,
		        group_id, sub_type, rate_type, lpr_base, lpr_spread, rate_adjust_month,
		        family_id, repayment_category_id, interest_calc_method
		 FROM loans WHERE group_id = $1 AND user_id = $2 AND deleted_at IS NULL
		 ORDER BY sub_type`,
		groupID, userID,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to query sub-loans")
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
	return loans, nil
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
