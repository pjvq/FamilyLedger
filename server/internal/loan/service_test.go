package loan

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/familyledger/server/pkg/middleware"
	pb "github.com/familyledger/server/proto/loan"
)

const testUserID = "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"

var testUserUUID = uuid.MustParse(testUserID)

func authedCtx() context.Context {
	return context.WithValue(context.Background(), middleware.UserIDKey, testUserID)
}

// ─── CreateLoan ─────────────────────────────────────────────────────────────

func TestCreateLoan_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	loanID := uuid.New()
	now := time.Now()

	mock.ExpectBegin()
	mock.ExpectQuery("INSERT INTO loans").
		WithArgs(
			testUserUUID, "\u623f\u8d37", "mortgage", int64(100000000), int64(100000000),
			float64(3.85), int32(360), "equal_installment", int32(15),
			pgxmock.AnyArg(), (*uuid.UUID)(nil), (*uuid.UUID)(nil),
		).
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at", "updated_at"}).
			AddRow(loanID, now, now))
	// Schedule inserts (360 months for a mortgage)
	for i := 0; i < 360; i++ {
		mock.ExpectExec("INSERT INTO loan_schedules").
			WithArgs(loanID, pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
			WillReturnResult(pgxmock.NewResult("INSERT", 1))
	}
	mock.ExpectCommit()

	resp, err := svc.CreateLoan(authedCtx(), &pb.CreateLoanRequest{
		Name:            "房贷",
		LoanType:        pb.LoanType_LOAN_TYPE_MORTGAGE,
		Principal:       100000000, // 100万
		AnnualRate:      3.85,
		TotalMonths:     360,
		RepaymentMethod: pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
		PaymentDay:      15,
		StartDate:       timestamppb.New(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)),
	})
	require.NoError(t, err)
	assert.Equal(t, "房贷", resp.Name)
	assert.Equal(t, int64(100000000), resp.Principal)
	assert.Equal(t, int64(100000000), resp.RemainingPrincipal)
	assert.Equal(t, int32(360), resp.TotalMonths)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestCreateLoan_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	_, err = svc.CreateLoan(context.Background(), &pb.CreateLoanRequest{})
	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestCreateLoan_MissingName(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	_, err = svc.CreateLoan(authedCtx(), &pb.CreateLoanRequest{
		LoanType:        pb.LoanType_LOAN_TYPE_MORTGAGE,
		Principal:       100000000,
		AnnualRate:      3.85,
		TotalMonths:     360,
		RepaymentMethod: pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
		PaymentDay:      15,
		StartDate:       timestamppb.New(time.Now()),
	})
	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestCreateLoan_InvalidPaymentDay(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	_, err = svc.CreateLoan(authedCtx(), &pb.CreateLoanRequest{
		Name:            "test",
		LoanType:        pb.LoanType_LOAN_TYPE_MORTGAGE,
		Principal:       100000000,
		AnnualRate:      3.85,
		TotalMonths:     360,
		RepaymentMethod: pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
		PaymentDay:      31, // > 28
		StartDate:       timestamppb.New(time.Now()),
	})
	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── GetLoan ────────────────────────────────────────────────────────────────

func loanColumns() []string {
	return []string{
		"id", "user_id", "name", "loan_type", "principal", "remaining_principal",
		"annual_rate", "total_months", "paid_months", "repayment_method", "payment_day",
		"start_date", "created_at", "updated_at", "account_id",
		"group_id", "sub_type", "rate_type", "lpr_base", "lpr_spread", "rate_adjust_month",
		"family_id", "repayment_category_id",
	}
}

func loanRow(id uuid.UUID, userID uuid.UUID) []interface{} {
	now := time.Now()
	return []interface{}{
		id, userID, "房贷", "mortgage", int64(100000000), int64(95000000),
		3.85, int32(360), int32(12), "equal_installment", int32(15),
		now, now, now, (*uuid.UUID)(nil),
		(*uuid.UUID)(nil), (*string)(nil), (*string)(nil), (*float64)(nil), (*float64)(nil), (*int32)(nil),
		(*uuid.UUID)(nil), (*uuid.UUID)(nil), // family_id, repayment_category_id
	}
}

// subLoanColumns returns the 22 columns used by loadSubLoans (no repayment_category_id).
func subLoanColumns() []string {
	return []string{
		"id", "user_id", "name", "loan_type", "principal", "remaining_principal",
		"annual_rate", "total_months", "paid_months", "repayment_method", "payment_day",
		"start_date", "created_at", "updated_at", "account_id",
		"group_id", "sub_type", "rate_type", "lpr_base", "lpr_spread", "rate_adjust_month",
		"family_id", "repayment_category_id",
	}
}

func TestGetLoan_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	loanID := uuid.New()

	mock.ExpectQuery("SELECT .+ FROM loans").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows(loanColumns()).AddRow(loanRow(loanID, testUserUUID)...))

	resp, err := svc.GetLoan(authedCtx(), &pb.GetLoanRequest{LoanId: loanID.String()})
	require.NoError(t, err)
	assert.Equal(t, "房贷", resp.Name)
	assert.Equal(t, int64(100000000), resp.Principal)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGetLoan_NotFound(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	loanID := uuid.New()

	mock.ExpectQuery("SELECT .+ FROM loans").
		WithArgs(loanID.String()).
		WillReturnError(pgx.ErrNoRows)

	_, err = svc.GetLoan(authedCtx(), &pb.GetLoanRequest{LoanId: loanID.String()})
	require.Error(t, err)
	assert.Equal(t, codes.NotFound, status.Code(err))
}

func TestGetLoan_PermissionDenied(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	loanID := uuid.New()
	otherUser := uuid.New()

	mock.ExpectQuery("SELECT .+ FROM loans").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows(loanColumns()).AddRow(loanRow(loanID, otherUser)...))

	_, err = svc.GetLoan(authedCtx(), &pb.GetLoanRequest{LoanId: loanID.String()})
	require.Error(t, err)
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

// ─── DeleteLoan ─────────────────────────────────────────────────────────────

func TestDeleteLoan_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	loanID := uuid.New()

	mock.ExpectExec("UPDATE loans SET deleted_at").
		WithArgs(loanID.String(), testUserID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	_, err = svc.DeleteLoan(authedCtx(), &pb.DeleteLoanRequest{LoanId: loanID.String()})
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestDeleteLoan_NotFound(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	loanID := uuid.New()

	mock.ExpectExec("UPDATE loans SET deleted_at").
		WithArgs(loanID.String(), testUserID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 0))

	_, err = svc.DeleteLoan(authedCtx(), &pb.DeleteLoanRequest{LoanId: loanID.String()})
	require.Error(t, err)
	assert.Equal(t, codes.NotFound, status.Code(err))
}

func TestDeleteLoan_EmptyID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.DeleteLoan(authedCtx(), &pb.DeleteLoanRequest{LoanId: ""})
	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── ListLoans ──────────────────────────────────────────────────────────────

func listLoanColumns() []string {
	return []string{
		"id", "user_id", "name", "loan_type", "principal", "remaining_principal",
		"annual_rate", "total_months", "paid_months", "repayment_method", "payment_day",
		"start_date", "created_at", "updated_at", "account_id",
		"group_id", "sub_type", "rate_type", "lpr_base", "lpr_spread", "rate_adjust_month",
		"family_id", "repayment_category_id",
	}
}

func listLoanRow(id uuid.UUID, userID uuid.UUID, name string) []interface{} {
	now := time.Now()
	return []interface{}{
		id, userID, name, "mortgage", int64(100000000), int64(95000000),
		3.85, int32(360), int32(12), "equal_installment", int32(15),
		now, now, now, (*uuid.UUID)(nil),
		(*uuid.UUID)(nil), (*string)(nil), (*string)(nil), (*float64)(nil), (*float64)(nil), (*int32)(nil),
		(*uuid.UUID)(nil), (*uuid.UUID)(nil),
	}
}

func TestListLoans_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	id1 := uuid.New()
	id2 := uuid.New()

	mock.ExpectQuery("SELECT .+ FROM loans WHERE user_id").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows(listLoanColumns()).
			AddRow(listLoanRow(id1, testUserUUID, "房贷1")...).
			AddRow(listLoanRow(id2, testUserUUID, "房贷2")...))

	resp, err := svc.ListLoans(authedCtx(), &pb.ListLoansRequest{})
	require.NoError(t, err)
	assert.Len(t, resp.Loans, 2)
}

func TestListLoans_Empty(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	mock.ExpectQuery("SELECT .+ FROM loans WHERE user_id").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows(listLoanColumns()))

	resp, err := svc.ListLoans(authedCtx(), &pb.ListLoansRequest{})
	require.NoError(t, err)
	assert.Empty(t, resp.Loans)
}

// ─── GetLoanSchedule ────────────────────────────────────────────────────────

func TestGetLoanSchedule_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	loanID := uuid.New()
	now := time.Now()

	// loadLoan
	mock.ExpectQuery("SELECT .+ FROM loans").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows(loanColumns()).AddRow(loanRow(loanID, testUserUUID)...))

	// loadSchedule
	mock.ExpectQuery("SELECT .+ FROM loan_schedules").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows([]string{
			"month_number", "payment", "principal_part", "interest_part",
			"remaining_principal", "is_paid", "due_date", "paid_date",
		}).
			AddRow(int32(1), int64(468215), int64(146882), int64(321333), int64(99853118), false, now, (*time.Time)(nil)).
			AddRow(int32(2), int64(468215), int64(147353), int64(320862), int64(99705765), false, now, (*time.Time)(nil)))

	resp, err := svc.GetLoanSchedule(authedCtx(), &pb.GetLoanScheduleRequest{LoanId: loanID.String()})
	require.NoError(t, err)
	assert.Len(t, resp.Items, 2)
	assert.Equal(t, int32(1), resp.Items[0].MonthNumber)
}

// ─── RecordPayment ──────────────────────────────────────────────────────────

func TestRecordPayment_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	loanID := uuid.New()
	now := time.Now()

	// loadLoan
	mock.ExpectQuery("SELECT .+ FROM loans").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows(loanColumns()).AddRow(loanRow(loanID, testUserUUID)...))

	// Sequential payment check
	mock.ExpectQuery("SELECT COALESCE").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows([]string{"min"}).AddRow(int32(13)))

	// Begin
	mock.ExpectBegin()
	// UPDATE loan_schedules ... RETURNING (QueryRow inside tx)
	mock.ExpectQuery("UPDATE loan_schedules SET is_paid").
		WithArgs(pgxmock.AnyArg(), loanID.String(), int32(13)).
		WillReturnRows(pgxmock.NewRows([]string{
			"month_number", "payment", "principal_part", "interest_part",
			"remaining_principal", "due_date",
		}).AddRow(int32(13), int64(468215), int64(148000), int64(320215), int64(94852000), now))
	// UPDATE loans
	mock.ExpectExec("UPDATE loans SET").
		WithArgs(loanID.String(), int64(94852000)).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectCommit()

	resp, err := svc.RecordPayment(authedCtx(), &pb.RecordPaymentRequest{
		LoanId:      loanID.String(),
		MonthNumber: 13,
	})
	require.NoError(t, err)
	assert.Equal(t, int32(13), resp.MonthNumber)
	assert.True(t, resp.IsPaid)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRecordPayment_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	_, err = svc.RecordPayment(context.Background(), &pb.RecordPaymentRequest{})
	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestRecordPayment_MissingParams(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	_, err = svc.RecordPayment(authedCtx(), &pb.RecordPaymentRequest{LoanId: "", MonthNumber: 0})
	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── SimulatePrepayment ─────────────────────────────────────────────────────

func TestSimulatePrepayment_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	_, err = svc.SimulatePrepayment(context.Background(), &pb.SimulatePrepaymentRequest{})
	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestSimulatePrepayment_InvalidAmount(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	_, err = svc.SimulatePrepayment(authedCtx(), &pb.SimulatePrepaymentRequest{
		PrepaymentAmount: 0,
	})
	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── Schedule generation (pure logic, no DB) ────────────────────────────────

func TestGenerateSchedule_EqualInstallment(t *testing.T) {
	// 100万, 4.9%, 360月, 等额本息
	items := generateSchedule(100000000, 4.9, 360, "equal_installment", 15,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC))

	require.Len(t, items, 360)
	// Last item should have 0 remaining
	assert.Equal(t, int64(0), items[359].remainingPrincipal)
	// First month interest ≈ 1000000 * 4.9% / 12 ≈ 408333
	assert.InDelta(t, 408333, items[0].interestPart, 2000)
	// Total principal should sum to 100000000
	var totalPrincipal int64
	for _, it := range items {
		totalPrincipal += it.principalPart
	}
	assert.Equal(t, int64(100000000), totalPrincipal)
}

func TestGenerateSchedule_EqualPrincipal(t *testing.T) {
	// 100万, 4.9%, 360月, 等额本金
	items := generateSchedule(100000000, 4.9, 360, "equal_principal", 15,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC))

	require.Len(t, items, 360)
	assert.Equal(t, int64(0), items[359].remainingPrincipal)
	// Equal principal: each month's principal portion should be ~277778
	assert.InDelta(t, 277778, items[0].principalPart, 1)
	// First month payment should be highest (most interest)
	assert.Greater(t, items[0].payment, items[359].payment)
}

func TestGenerateSchedule_ZeroRate(t *testing.T) {
	items := generateSchedule(1200000, 0, 12, "equal_installment", 1,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC))

	require.Len(t, items, 12)
	for _, it := range items {
		assert.Equal(t, int64(0), it.interestPart)
		assert.Equal(t, int64(100000), it.payment)
	}
}

func TestGenerateSchedule_EdgeCases(t *testing.T) {
	// Zero principal
	items := generateSchedule(0, 4.9, 360, "equal_installment", 15, time.Now())
	assert.Nil(t, items)

	// Zero months
	items = generateSchedule(100000000, 4.9, 0, "equal_installment", 15, time.Now())
	assert.Nil(t, items)
}

func TestGenerateSchedule_InterestOnly(t *testing.T) {
	// 50万, 5.0%, 12个月, 先息后本
	principal := int64(50000000) // 50万 (分)
	items := generateSchedule(principal, 5.0, 12, "interest_only", 15,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC))

	require.Len(t, items, 12)

	// 前 11 个月只付利息，不还本
	expectedMonthlyInterest := roundCent(float64(principal) * 5.0 / 100.0 / 12.0)
	for i := 0; i < 11; i++ {
		assert.Equal(t, int64(0), items[i].principalPart, "month %d principal should be 0", i+1)
		assert.Equal(t, expectedMonthlyInterest, items[i].interestPart)
		assert.Equal(t, expectedMonthlyInterest, items[i].payment)
		assert.Equal(t, principal, items[i].remainingPrincipal)
	}

	// 最后一个月还本+利息
	assert.Equal(t, principal, items[11].principalPart)
	assert.Equal(t, expectedMonthlyInterest, items[11].interestPart)
	assert.Equal(t, principal+expectedMonthlyInterest, items[11].payment)
	assert.Equal(t, int64(0), items[11].remainingPrincipal)
}

func TestGenerateSchedule_Bullet(t *testing.T) {
	// 10万, 6.0%, 6个月, 一次性还本付息
	principal := int64(10000000) // 10万 (分)
	items := generateSchedule(principal, 6.0, 6, "bullet", 1,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC))

	require.Len(t, items, 6)

	// 前 5 个月无任何还款
	for i := 0; i < 5; i++ {
		assert.Equal(t, int64(0), items[i].payment, "month %d payment should be 0", i+1)
		assert.Equal(t, int64(0), items[i].principalPart)
		assert.Equal(t, int64(0), items[i].interestPart)
		assert.Equal(t, principal, items[i].remainingPrincipal)
	}

	// 最后一期还本+累计利息
	totalInterest := roundCent(float64(principal) * 6.0 / 100.0 / 12.0 * 6)
	assert.Equal(t, principal, items[5].principalPart)
	assert.Equal(t, totalInterest, items[5].interestPart)
	assert.Equal(t, principal+totalInterest, items[5].payment)
	assert.Equal(t, int64(0), items[5].remainingPrincipal)
}

func TestGenerateSchedule_EqualInterest(t *testing.T) {
	// 12万, 12.0%, 12个月, 等本等息
	principal := int64(12000000) // 12万 (分)
	items := generateSchedule(principal, 12.0, 12, "equal_interest", 1,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC))

	require.Len(t, items, 12)

	// 每月本金 = 12万/12 = 1万
	// 每月利息 = 12万 * 12% / 12 = 1200 (按初始本金计算，每月固定)
	expectedPrincipal := roundCent(float64(principal) / 12.0)
	expectedInterest := roundCent(float64(principal) * 12.0 / 100.0 / 12.0)

	for i := 0; i < 11; i++ {
		assert.Equal(t, expectedPrincipal, items[i].principalPart, "month %d", i+1)
		assert.Equal(t, expectedInterest, items[i].interestPart, "month %d", i+1)
		assert.Equal(t, expectedPrincipal+expectedInterest, items[i].payment, "month %d", i+1)
	}

	// 最后一期本金清除尾差
	var totalPrincipal int64
	for _, it := range items {
		totalPrincipal += it.principalPart
	}
	assert.Equal(t, principal, totalPrincipal)
	assert.Equal(t, int64(0), items[11].remainingPrincipal)
}

func TestGenerateWithFixedPayment(t *testing.T) {
	// 50万 remaining, 4.9%, fixed payment 5308 (original equal installment for 100万/360)
	items := generateWithFixedPayment(50000000, 4.9, 530850, 15,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC))

	require.NotEmpty(t, items)
	// Should have fewer months than 360
	assert.Less(t, len(items), 360)
	// Last item should have 0 remaining
	assert.Equal(t, int64(0), items[len(items)-1].remainingPrincipal)
}

// ─── UpdateLoan ─────────────────────────────────────────────────────────────

func TestUpdateLoan_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	loanID := uuid.New()
	now := time.Now()

	// loadLoan (existing)
	mock.ExpectQuery("SELECT .+ FROM loans").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows(loanColumns()).AddRow(loanRow(loanID, testUserUUID)...))

	// UPDATE
	mock.ExpectExec("UPDATE loans SET").
		WithArgs("\u65b0\u540d\u5b57", int32(15), (*uuid.UUID)(nil), loanID.String(), testUserID, (*uuid.UUID)(nil)).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	// loadLoan (reload after update)
	updatedRow := loanRow(loanID, testUserUUID)
	updatedRow[2] = "新名字" // name
	_ = now
	mock.ExpectQuery("SELECT .+ FROM loans").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows(loanColumns()).AddRow(updatedRow...))

	resp, err := svc.UpdateLoan(authedCtx(), &pb.UpdateLoanRequest{
		LoanId: loanID.String(),
		Name:   "新名字",
	})
	require.NoError(t, err)
	assert.Equal(t, "新名字", resp.Name)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestUpdateLoan_EmptyID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	_, err = svc.UpdateLoan(authedCtx(), &pb.UpdateLoanRequest{LoanId: ""})
	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── Validation ─────────────────────────────────────────────────────────────

func TestValidateCreateLoanRequest(t *testing.T) {
	tests := []struct {
		name    string
		req     *pb.CreateLoanRequest
		wantErr bool
	}{
		{
			name: "valid",
			req: &pb.CreateLoanRequest{
				Name: "test", LoanType: pb.LoanType_LOAN_TYPE_MORTGAGE,
				Principal: 100000000, AnnualRate: 3.85, TotalMonths: 360,
				RepaymentMethod: pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
				PaymentDay: 15, StartDate: timestamppb.New(time.Now()),
			},
			wantErr: false,
		},
		{name: "empty name", req: &pb.CreateLoanRequest{Name: ""}, wantErr: true},
		{
			name: "negative principal",
			req: &pb.CreateLoanRequest{
				Name: "test", LoanType: pb.LoanType_LOAN_TYPE_MORTGAGE, Principal: -1,
			},
			wantErr: true,
		},
		{
			name: "payment_day too high",
			req: &pb.CreateLoanRequest{
				Name: "test", LoanType: pb.LoanType_LOAN_TYPE_MORTGAGE,
				Principal: 100, AnnualRate: 3, TotalMonths: 12,
				RepaymentMethod: pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
				PaymentDay: 29,
			},
			wantErr: true,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validateCreateLoanRequest(tt.req)
			if tt.wantErr {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
			}
		})
	}
}

// ─── Type conversions ───────────────────────────────────────────────────────

func TestLoanTypeConversions(t *testing.T) {
	types := []struct {
		str string
		val pb.LoanType
	}{
		{"mortgage", pb.LoanType_LOAN_TYPE_MORTGAGE},
		{"car_loan", pb.LoanType_LOAN_TYPE_CAR_LOAN},
		{"credit_card", pb.LoanType_LOAN_TYPE_CREDIT_CARD},
		{"consumer", pb.LoanType_LOAN_TYPE_CONSUMER},
		{"business", pb.LoanType_LOAN_TYPE_BUSINESS},
		{"other", pb.LoanType_LOAN_TYPE_OTHER},
	}
	for _, tt := range types {
		assert.Equal(t, tt.str, loanTypeToString(tt.val))
		assert.Equal(t, tt.val, stringToLoanType(tt.str))
	}
}

func TestRepaymentMethodConversions(t *testing.T) {
	assert.Equal(t, "equal_installment", repaymentMethodToString(pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT))
	assert.Equal(t, "equal_principal", repaymentMethodToString(pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_PRINCIPAL))
	assert.Equal(t, pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT, stringToRepaymentMethod("equal_installment"))
}

// ─── advanceMonths ──────────────────────────────────────────────────────────

func TestAdvanceMonths(t *testing.T) {
	start := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	// First payment on or after start, payment day 15
	d := advanceMonths(start, 0, 15)
	assert.Equal(t, 15, d.Day())
	assert.Equal(t, time.January, d.Month())

	// If start day >= payment day, first payment is next month
	start2 := time.Date(2026, 1, 20, 0, 0, 0, 0, time.UTC)
	d2 := advanceMonths(start2, 0, 15)
	assert.Equal(t, time.February, d2.Month())
	assert.Equal(t, 15, d2.Day())

	// Feb 30 should clamp
	d3 := advanceMonths(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC), 1, 30)
	assert.Equal(t, 28, d3.Day()) // Feb 2026 has 28 days
}

