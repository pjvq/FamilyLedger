package loan

import (
	"context"
	"fmt"
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

const boost2UserID = "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"

var boost2UserUUID = uuid.MustParse(boost2UserID)

func boost2Ctx() context.Context {
	return context.WithValue(context.Background(), middleware.UserIDKey, boost2UserID)
}

// ════════════════════════════════════════════════════════════════════════════
// UpdateLoan — additional branches
// ════════════════════════════════════════════════════════════════════════════

func TestBoost2_UpdateLoan_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.UpdateLoan(context.Background(), &pb.UpdateLoanRequest{LoanId: uuid.New().String()})
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestBoost2_UpdateLoan_EmptyLoanID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.UpdateLoan(boost2Ctx(), &pb.UpdateLoanRequest{LoanId: ""})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoost2_UpdateLoan_LoanNotFound(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	loanID := uuid.New().String()

	mock.ExpectQuery("SELECT .+ FROM loans WHERE id").
		WithArgs(loanID).
		WillReturnError(pgx.ErrNoRows)

	_, err = svc.UpdateLoan(boost2Ctx(), &pb.UpdateLoanRequest{LoanId: loanID})
	assert.Equal(t, codes.NotFound, status.Code(err))
}

func TestBoost2_UpdateLoan_NameOnly(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	loanID := uuid.New()

	// loadLoan
	mock.ExpectQuery("SELECT .+ FROM loans WHERE id").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows(loanColumns()).AddRow(loanRow(loanID, boost2UserUUID)...))

	// Exec update
	mock.ExpectExec("UPDATE loans SET").
		WithArgs("新名字", int32(15), (*uuid.UUID)(nil), loanID.String(), boost2UserID, (*uuid.UUID)(nil)).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	// loadLoan again
	updatedRow := loanRow(loanID, boost2UserUUID)
	updatedRow[2] = "新名字"
	mock.ExpectQuery("SELECT .+ FROM loans WHERE id").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows(loanColumns()).AddRow(updatedRow...))

	resp, err := svc.UpdateLoan(boost2Ctx(), &pb.UpdateLoanRequest{
		LoanId: loanID.String(),
		Name:   "新名字",
	})
	require.NoError(t, err)
	assert.Equal(t, "新名字", resp.Name)
}

func TestBoost2_UpdateLoan_PaymentDayInvalid(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	loanID := uuid.New()

	mock.ExpectQuery("SELECT .+ FROM loans WHERE id").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows(loanColumns()).AddRow(loanRow(loanID, boost2UserUUID)...))

	_, err = svc.UpdateLoan(boost2Ctx(), &pb.UpdateLoanRequest{
		LoanId:     loanID.String(),
		PaymentDay: 30,
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoost2_UpdateLoan_PaymentDayOutOfRange(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	loanID := uuid.New()

	// PaymentDay > 28 triggers range check
	mock.ExpectQuery("SELECT .+ FROM loans WHERE id").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows(loanColumns()).AddRow(loanRow(loanID, boost2UserUUID)...))

	_, err = svc.UpdateLoan(boost2Ctx(), &pb.UpdateLoanRequest{
		LoanId:     loanID.String(),
		PaymentDay: 29,
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoost2_UpdateLoan_InvalidAccountID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	loanID := uuid.New()

	mock.ExpectQuery("SELECT .+ FROM loans WHERE id").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows(loanColumns()).AddRow(loanRow(loanID, boost2UserUUID)...))

	_, err = svc.UpdateLoan(boost2Ctx(), &pb.UpdateLoanRequest{
		LoanId:    loanID.String(),
		AccountId: "not-uuid",
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoost2_UpdateLoan_WithAccountID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	loanID := uuid.New()
	accountID := uuid.New()

	mock.ExpectQuery("SELECT .+ FROM loans WHERE id").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows(loanColumns()).AddRow(loanRow(loanID, boost2UserUUID)...))

	mock.ExpectExec("UPDATE loans SET").
		WithArgs("房贷", int32(15), &accountID, loanID.String(), boost2UserID, (*uuid.UUID)(nil)).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	updatedRow := loanRow(loanID, boost2UserUUID)
	updatedRow[14] = &accountID
	mock.ExpectQuery("SELECT .+ FROM loans WHERE id").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows(loanColumns()).AddRow(updatedRow...))

	resp, err := svc.UpdateLoan(boost2Ctx(), &pb.UpdateLoanRequest{
		LoanId:    loanID.String(),
		AccountId: accountID.String(),
	})
	require.NoError(t, err)
	assert.Equal(t, accountID.String(), resp.AccountId)
}

func TestBoost2_UpdateLoan_PaymentDayUpdate(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	loanID := uuid.New()

	mock.ExpectQuery("SELECT .+ FROM loans WHERE id").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows(loanColumns()).AddRow(loanRow(loanID, boost2UserUUID)...))

	mock.ExpectExec("UPDATE loans SET").
		WithArgs("房贷", int32(20), (*uuid.UUID)(nil), loanID.String(), boost2UserID, (*uuid.UUID)(nil)).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	updatedRow := loanRow(loanID, boost2UserUUID)
	updatedRow[10] = int32(20)
	mock.ExpectQuery("SELECT .+ FROM loans WHERE id").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows(loanColumns()).AddRow(updatedRow...))

	resp, err := svc.UpdateLoan(boost2Ctx(), &pb.UpdateLoanRequest{
		LoanId:     loanID.String(),
		PaymentDay: 20,
	})
	require.NoError(t, err)
	assert.Equal(t, int32(20), resp.PaymentDay)
}

func TestBoost2_UpdateLoan_DBExecError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	loanID := uuid.New()

	mock.ExpectQuery("SELECT .+ FROM loans WHERE id").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows(loanColumns()).AddRow(loanRow(loanID, boost2UserUUID)...))

	mock.ExpectExec("UPDATE loans SET").
		WithArgs("房贷", int32(15), (*uuid.UUID)(nil), loanID.String(), boost2UserID, (*uuid.UUID)(nil)).
		WillReturnError(fmt.Errorf("db error"))

	_, err = svc.UpdateLoan(boost2Ctx(), &pb.UpdateLoanRequest{
		LoanId: loanID.String(),
		Name:   "", // no change, uses existing
	})
	assert.Equal(t, codes.Internal, status.Code(err))
}

// ════════════════════════════════════════════════════════════════════════════
// GetLoanSchedule — additional branches
// ════════════════════════════════════════════════════════════════════════════

func TestBoost2_GetLoanSchedule_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.GetLoanSchedule(context.Background(), &pb.GetLoanScheduleRequest{LoanId: uuid.New().String()})
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestBoost2_GetLoanSchedule_LoanNotFound(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	loanID := uuid.New().String()

	mock.ExpectQuery("SELECT .+ FROM loans WHERE id").
		WithArgs(loanID).
		WillReturnError(pgx.ErrNoRows)

	_, err = svc.GetLoanSchedule(boost2Ctx(), &pb.GetLoanScheduleRequest{LoanId: loanID})
	assert.Equal(t, codes.NotFound, status.Code(err))
}

func TestBoost2_GetLoanSchedule_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	loanID := uuid.New()
	dueDate := time.Date(2026, 2, 15, 0, 0, 0, 0, time.UTC)
	paidDate := time.Date(2026, 2, 14, 0, 0, 0, 0, time.UTC)

	// loadLoan
	mock.ExpectQuery("SELECT .+ FROM loans WHERE id").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows(loanColumns()).AddRow(loanRow(loanID, boost2UserUUID)...))

	// loadSchedule
	mock.ExpectQuery("SELECT .+ FROM loan_schedules WHERE loan_id").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows([]string{"month_number", "payment", "principal_part", "interest_part", "remaining_principal", "is_paid", "due_date", "paid_date"}).
			AddRow(int32(1), int64(467000), int64(178000), int64(289000), int64(99822000), true, dueDate, &paidDate).
			AddRow(int32(2), int64(467000), int64(178500), int64(288500), int64(99643500), false, dueDate.AddDate(0, 1, 0), (*time.Time)(nil)))

	resp, err := svc.GetLoanSchedule(boost2Ctx(), &pb.GetLoanScheduleRequest{LoanId: loanID.String()})
	require.NoError(t, err)
	require.Len(t, resp.Items, 2)
	assert.True(t, resp.Items[0].IsPaid)
	assert.NotNil(t, resp.Items[0].PaidDate)
	assert.False(t, resp.Items[1].IsPaid)
	assert.Nil(t, resp.Items[1].PaidDate)
}

func TestBoost2_GetLoanSchedule_DBError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	loanID := uuid.New()

	mock.ExpectQuery("SELECT .+ FROM loans WHERE id").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows(loanColumns()).AddRow(loanRow(loanID, boost2UserUUID)...))

	mock.ExpectQuery("SELECT .+ FROM loan_schedules WHERE loan_id").
		WithArgs(loanID.String()).
		WillReturnError(fmt.Errorf("db error"))

	_, err = svc.GetLoanSchedule(boost2Ctx(), &pb.GetLoanScheduleRequest{LoanId: loanID.String()})
	assert.Equal(t, codes.Internal, status.Code(err))
}

// ════════════════════════════════════════════════════════════════════════════
// stringToRepaymentMethod — additional branches
// ════════════════════════════════════════════════════════════════════════════

func TestBoost2_StringToRepaymentMethod(t *testing.T) {
	assert.Equal(t, pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT, stringToRepaymentMethod("equal_installment"))
	assert.Equal(t, pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_PRINCIPAL, stringToRepaymentMethod("equal_principal"))
	assert.Equal(t, pb.RepaymentMethod_REPAYMENT_METHOD_UNSPECIFIED, stringToRepaymentMethod("other"))
	assert.Equal(t, pb.RepaymentMethod_REPAYMENT_METHOD_UNSPECIFIED, stringToRepaymentMethod(""))
}

// ════════════════════════════════════════════════════════════════════════════
// GetLoan — additional branches
// ════════════════════════════════════════════════════════════════════════════

func TestBoost2_GetLoan_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.GetLoan(context.Background(), &pb.GetLoanRequest{LoanId: uuid.New().String()})
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestBoost2_GetLoan_EmptyLoanID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.GetLoan(boost2Ctx(), &pb.GetLoanRequest{LoanId: ""})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoost2_GetLoan_NotOwnerPersonalLoan(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	loanID := uuid.New()
	otherUser := uuid.New()

	mock.ExpectQuery("SELECT .+ FROM loans WHERE id").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows(loanColumns()).AddRow(loanRow(loanID, otherUser)...))

	_, err = svc.GetLoan(boost2Ctx(), &pb.GetLoanRequest{LoanId: loanID.String()})
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

func TestBoost2_GetLoan_FamilyLoanPermissionDenied(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	loanID := uuid.New()
	otherUser := uuid.New()
	famID := uuid.New()

	row := loanRow(loanID, otherUser)
	row[21] = &famID // family_id
	mock.ExpectQuery("SELECT .+ FROM loans WHERE id").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows(loanColumns()).AddRow(row...))

	// permission.Check: not a member
	mock.ExpectQuery("SELECT role, permissions FROM family_members WHERE").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnError(pgx.ErrNoRows)

	_, err = svc.GetLoan(boost2Ctx(), &pb.GetLoanRequest{LoanId: loanID.String()})
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

func TestBoost2_GetLoan_FamilyLoanAccessOK(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	loanID := uuid.New()
	otherUser := uuid.New()
	famID := uuid.New()

	row := loanRow(loanID, otherUser)
	row[21] = &famID
	mock.ExpectQuery("SELECT .+ FROM loans WHERE id").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows(loanColumns()).AddRow(row...))

	// permission.Check: member with CanView
	mock.ExpectQuery("SELECT role, permissions FROM family_members WHERE").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).
			AddRow("member", []byte(`{"can_view":true}`)))

	resp, err := svc.GetLoan(boost2Ctx(), &pb.GetLoanRequest{LoanId: loanID.String()})
	require.NoError(t, err)
	assert.NotNil(t, resp)
}

func TestBoost2_GetLoan_DBError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	loanID := uuid.New().String()

	mock.ExpectQuery("SELECT .+ FROM loans WHERE id").
		WithArgs(loanID).
		WillReturnError(fmt.Errorf("db error"))

	_, err = svc.GetLoan(boost2Ctx(), &pb.GetLoanRequest{LoanId: loanID})
	assert.Equal(t, codes.Internal, status.Code(err))
}

// ════════════════════════════════════════════════════════════════════════════
// CreateLoan — additional branches
// ════════════════════════════════════════════════════════════════════════════

func TestBoost2_CreateLoan_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.CreateLoan(context.Background(), &pb.CreateLoanRequest{
		Name:            "test",
		LoanType:        pb.LoanType_LOAN_TYPE_MORTGAGE,
		Principal:       100,
		AnnualRate:      3.0,
		TotalMonths:     12,
		RepaymentMethod: pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
		PaymentDay:      15,
		StartDate:       timestamppb.Now(),
	})
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestBoost2_CreateLoan_ValidationFails(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.CreateLoan(boost2Ctx(), &pb.CreateLoanRequest{
		Name: "", // missing name
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoost2_CreateLoan_FamilyPermissionDenied(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()

	// permission.Check: not a member
	mock.ExpectQuery("SELECT role, permissions FROM family_members WHERE").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnError(pgx.ErrNoRows)

	_, err = svc.CreateLoan(boost2Ctx(), &pb.CreateLoanRequest{
		Name:            "test",
		LoanType:        pb.LoanType_LOAN_TYPE_MORTGAGE,
		Principal:       100,
		AnnualRate:      3.0,
		TotalMonths:     12,
		RepaymentMethod: pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
		PaymentDay:      15,
		StartDate:       timestamppb.Now(),
		FamilyId:        famID.String(),
	})
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

func TestBoost2_CreateLoan_FamilySuccess(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()
	loanID := uuid.New()
	now := time.Now()
	startDate := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)

	// permission.Check: owner
	mock.ExpectQuery("SELECT role, permissions FROM family_members WHERE").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).AddRow("owner", []byte(`{}`)))

	mock.ExpectBegin()
	mock.ExpectQuery("INSERT INTO loans").
		WithArgs(boost2UserUUID, "家庭贷款", "mortgage", int64(10000), int64(10000),
			float64(3.0), int32(12), "equal_installment", int32(15),
			startDate, (*uuid.UUID)(nil), &famID, "monthly").
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at", "updated_at"}).AddRow(loanID, now, now))

	// Schedule inserts (12 months)
	for i := 0; i < 12; i++ {
		mock.ExpectExec("INSERT INTO loan_schedules").
			WithArgs(loanID, pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
			WillReturnResult(pgxmock.NewResult("INSERT", 1))
	}
	mock.ExpectCommit()

	resp, err := svc.CreateLoan(boost2Ctx(), &pb.CreateLoanRequest{
		Name:            "家庭贷款",
		LoanType:        pb.LoanType_LOAN_TYPE_MORTGAGE,
		Principal:       10000,
		AnnualRate:      3.0,
		TotalMonths:     12,
		RepaymentMethod: pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
		PaymentDay:      15,
		StartDate:       timestamppb.New(startDate),
		FamilyId:        famID.String(),
	})
	require.NoError(t, err)
	assert.Equal(t, famID.String(), resp.FamilyId)
}

func TestBoost2_CreateLoan_WithAccountID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	loanID := uuid.New()
	accountID := uuid.New()
	now := time.Now()
	startDate := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)

	mock.ExpectBegin()
	mock.ExpectQuery("INSERT INTO loans").
		WithArgs(boost2UserUUID, "test", "mortgage", int64(10000), int64(10000),
			float64(3.0), int32(12), "equal_installment", int32(15),
			startDate, &accountID, (*uuid.UUID)(nil), "monthly").
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at", "updated_at"}).AddRow(loanID, now, now))

	for i := 0; i < 12; i++ {
		mock.ExpectExec("INSERT INTO loan_schedules").
			WithArgs(loanID, pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
			WillReturnResult(pgxmock.NewResult("INSERT", 1))
	}
	mock.ExpectCommit()

	resp, err := svc.CreateLoan(boost2Ctx(), &pb.CreateLoanRequest{
		Name:            "test",
		LoanType:        pb.LoanType_LOAN_TYPE_MORTGAGE,
		Principal:       10000,
		AnnualRate:      3.0,
		TotalMonths:     12,
		RepaymentMethod: pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
		PaymentDay:      15,
		StartDate:       timestamppb.New(startDate),
		AccountId:       accountID.String(),
	})
	require.NoError(t, err)
	assert.Equal(t, accountID.String(), resp.AccountId)
}

func TestBoost2_CreateLoan_BeginTxError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectBegin().WillReturnError(fmt.Errorf("pool exhausted"))

	_, err = svc.CreateLoan(boost2Ctx(), &pb.CreateLoanRequest{
		Name:            "test",
		LoanType:        pb.LoanType_LOAN_TYPE_MORTGAGE,
		Principal:       10000,
		AnnualRate:      3.0,
		TotalMonths:     12,
		RepaymentMethod: pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
		PaymentDay:      15,
		StartDate:       timestamppb.Now(),
	})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestBoost2_CreateLoan_EqualPrincipalMethod(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	loanID := uuid.New()
	now := time.Now()
	startDate := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)

	mock.ExpectBegin()
	mock.ExpectQuery("INSERT INTO loans").
		WithArgs(boost2UserUUID, "等额本金", "consumer", int64(12000), int64(12000),
			float64(5.0), int32(12), "equal_principal", int32(10),
			startDate, (*uuid.UUID)(nil), (*uuid.UUID)(nil), "monthly").
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at", "updated_at"}).AddRow(loanID, now, now))

	for i := 0; i < 12; i++ {
		mock.ExpectExec("INSERT INTO loan_schedules").
			WithArgs(loanID, pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
			WillReturnResult(pgxmock.NewResult("INSERT", 1))
	}
	mock.ExpectCommit()

	resp, err := svc.CreateLoan(boost2Ctx(), &pb.CreateLoanRequest{
		Name:            "等额本金",
		LoanType:        pb.LoanType_LOAN_TYPE_CONSUMER,
		Principal:       12000,
		AnnualRate:      5.0,
		TotalMonths:     12,
		RepaymentMethod: pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_PRINCIPAL,
		PaymentDay:      10,
		StartDate:       timestamppb.New(startDate),
	})
	require.NoError(t, err)
	assert.Equal(t, pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_PRINCIPAL, resp.RepaymentMethod)
}

// ════════════════════════════════════════════════════════════════════════════
// Type conversion helpers — all cases
// ════════════════════════════════════════════════════════════════════════════

func TestBoost2_LoanTypeToString(t *testing.T) {
	assert.Equal(t, "mortgage", loanTypeToString(pb.LoanType_LOAN_TYPE_MORTGAGE))
	assert.Equal(t, "car_loan", loanTypeToString(pb.LoanType_LOAN_TYPE_CAR_LOAN))
	assert.Equal(t, "credit_card", loanTypeToString(pb.LoanType_LOAN_TYPE_CREDIT_CARD))
	assert.Equal(t, "consumer", loanTypeToString(pb.LoanType_LOAN_TYPE_CONSUMER))
	assert.Equal(t, "business", loanTypeToString(pb.LoanType_LOAN_TYPE_BUSINESS))
	assert.Equal(t, "other", loanTypeToString(pb.LoanType_LOAN_TYPE_OTHER))
	assert.Equal(t, "other", loanTypeToString(pb.LoanType_LOAN_TYPE_UNSPECIFIED))
}

func TestBoost2_StringToLoanType(t *testing.T) {
	assert.Equal(t, pb.LoanType_LOAN_TYPE_MORTGAGE, stringToLoanType("mortgage"))
	assert.Equal(t, pb.LoanType_LOAN_TYPE_CAR_LOAN, stringToLoanType("car_loan"))
	assert.Equal(t, pb.LoanType_LOAN_TYPE_CREDIT_CARD, stringToLoanType("credit_card"))
	assert.Equal(t, pb.LoanType_LOAN_TYPE_CONSUMER, stringToLoanType("consumer"))
	assert.Equal(t, pb.LoanType_LOAN_TYPE_BUSINESS, stringToLoanType("business"))
	assert.Equal(t, pb.LoanType_LOAN_TYPE_OTHER, stringToLoanType("other"))
	assert.Equal(t, pb.LoanType_LOAN_TYPE_UNSPECIFIED, stringToLoanType("xyz"))
	assert.Equal(t, pb.LoanType_LOAN_TYPE_UNSPECIFIED, stringToLoanType(""))
}

func TestBoost2_RepaymentMethodToString(t *testing.T) {
	assert.Equal(t, "equal_installment", repaymentMethodToString(pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT))
	assert.Equal(t, "equal_principal", repaymentMethodToString(pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_PRINCIPAL))
	assert.Equal(t, "equal_installment", repaymentMethodToString(pb.RepaymentMethod_REPAYMENT_METHOD_UNSPECIFIED))
}

// ════════════════════════════════════════════════════════════════════════════
// generateSchedule — edge cases
// ════════════════════════════════════════════════════════════════════════════

func TestBoost2_GenerateSchedule_ZeroMonths(t *testing.T) {
	items := generateSchedule(100000, 3.0, 0, "equal_installment", 15, time.Now(), "monthly")
	assert.Nil(t, items)
}

func TestBoost2_GenerateSchedule_ZeroPrincipal(t *testing.T) {
	items := generateSchedule(0, 3.0, 12, "equal_installment", 15, time.Now(), "monthly")
	assert.Nil(t, items)
}

func TestBoost2_GenerateSchedule_ZeroRate(t *testing.T) {
	items := generateSchedule(12000, 0.0, 12, "equal_installment", 15, time.Now(), "monthly")
	require.Len(t, items, 12)
	// With zero rate, all interest parts should be 0
	for _, item := range items {
		assert.Equal(t, int64(0), item.interestPart)
	}
	assert.Equal(t, int64(0), items[11].remainingPrincipal)
}

func TestBoost2_GenerateSchedule_EqualPrincipal(t *testing.T) {
	items := generateSchedule(12000, 12.0, 12, "equal_principal", 15, time.Now(), "monthly")
	require.Len(t, items, 12)
	// Each month principal should be 1000
	assert.Equal(t, int64(1000), items[0].principalPart)
	// Last item remaining should be 0
	assert.Equal(t, int64(0), items[11].remainingPrincipal)
}

// ════════════════════════════════════════════════════════════════════════════
// SimulatePrepayment — equal_principal reduce_months branch
// ════════════════════════════════════════════════════════════════════════════

func TestBoost2_SimulatePrepayment_EqualPrincipalReduceMonths(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	loanID := uuid.New()
	now := time.Now()

	// loadLoan with equal_principal
	row := loanRow(loanID, boost2UserUUID)
	row[9] = "equal_principal"
	mock.ExpectQuery("SELECT .+ FROM loans WHERE id").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows(loanColumns()).AddRow(row...))

	// loadSchedule: 12 paid + 348 unpaid
	schedRows := pgxmock.NewRows([]string{"month_number", "payment", "principal_part", "interest_part", "remaining_principal", "is_paid", "due_date", "paid_date"})
	dueDate := now
	paidDate := now
	for i := 1; i <= 12; i++ {
		schedRows.AddRow(int32(i), int64(500000), int64(278000), int64(222000), int64(95000000-int64(i)*278000), true, dueDate, &paidDate)
		dueDate = dueDate.AddDate(0, 1, 0)
	}
	for i := 13; i <= 360; i++ {
		rem := int64(95000000) - int64(i-12)*278000
		if rem < 0 {
			rem = 0
		}
		schedRows.AddRow(int32(i), int64(500000), int64(278000), int64(222000), rem, false, dueDate, (*time.Time)(nil))
		dueDate = dueDate.AddDate(0, 1, 0)
	}
	mock.ExpectQuery("SELECT .+ FROM loan_schedules WHERE loan_id").
		WithArgs(loanID.String()).
		WillReturnRows(schedRows)

	resp, err := svc.SimulatePrepayment(boost2Ctx(), &pb.SimulatePrepaymentRequest{
		LoanId:           loanID.String(),
		PrepaymentAmount: 5000000,
		Strategy:         pb.PrepaymentStrategy_PREPAYMENT_STRATEGY_REDUCE_MONTHS,
	})
	require.NoError(t, err)
	assert.NotNil(t, resp)
	assert.True(t, resp.MonthsReduced > 0)
}

// ════════════════════════════════════════════════════════════════════════════
// DeleteLoan — additional branches
// ════════════════════════════════════════════════════════════════════════════

func TestBoost2_DeleteLoan_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.DeleteLoan(context.Background(), &pb.DeleteLoanRequest{LoanId: uuid.New().String()})
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestBoost2_DeleteLoan_EmptyID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.DeleteLoan(boost2Ctx(), &pb.DeleteLoanRequest{LoanId: ""})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoost2_DeleteLoan_DBError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	loanID := uuid.New().String()

	mock.ExpectExec("UPDATE loans SET deleted_at").
		WithArgs(loanID, boost2UserID).
		WillReturnError(fmt.Errorf("db error"))

	_, err = svc.DeleteLoan(boost2Ctx(), &pb.DeleteLoanRequest{LoanId: loanID})
	assert.Equal(t, codes.Internal, status.Code(err))
}

// ════════════════════════════════════════════════════════════════════════════
// loadLoan — with all nullable fields populated
// ════════════════════════════════════════════════════════════════════════════

func TestBoost2_LoadLoan_AllNullableFields(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	loanID := uuid.New()
	accountID := uuid.New()
	groupID := uuid.New()
	famID := uuid.New()
	subType := "provident"
	rateType := "lpr_floating"
	lprBase := 3.85
	lprSpread := 0.30
	rateAdjustMonth := int32(1)
	now := time.Now()

	row := []interface{}{
		loanID, boost2UserUUID, "全字段贷款", "mortgage", int64(100000000), int64(95000000),
		float64(4.15), int32(360), int32(12), "equal_installment", int32(15),
		now, now, now, &accountID,
		&groupID, &subType, &rateType, &lprBase, &lprSpread, &rateAdjustMonth,
		&famID, (*uuid.UUID)(nil), "monthly",
	}
	mock.ExpectQuery("SELECT .+ FROM loans WHERE id").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows(loanColumns()).AddRow(row...))

	resp, err := svc.GetLoan(boost2Ctx(), &pb.GetLoanRequest{LoanId: loanID.String()})
	require.NoError(t, err)
	assert.Equal(t, accountID.String(), resp.AccountId)
	assert.Equal(t, groupID.String(), resp.GroupId)
	assert.Equal(t, pb.LoanSubType_LOAN_SUB_TYPE_PROVIDENT, resp.SubType)
	assert.Equal(t, pb.RateType_RATE_TYPE_LPR_FLOATING, resp.RateType)
	assert.InDelta(t, 3.85, resp.LprBase, 0.001)
	assert.InDelta(t, 0.30, resp.LprSpread, 0.001)
	assert.Equal(t, int32(1), resp.RateAdjustMonth)
	assert.Equal(t, famID.String(), resp.FamilyId)
}

// ════════════════════════════════════════════════════════════════════════════
// RecordRateChange — additional error branches
// ════════════════════════════════════════════════════════════════════════════

func TestBoost2_RecordRateChange_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.RecordRateChange(context.Background(), &pb.RecordRateChangeRequest{
		LoanId:        uuid.New().String(),
		NewRate:       3.5,
		EffectiveDate: timestamppb.Now(),
	})
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestBoost2_RecordRateChange_InvalidRate(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.RecordRateChange(boost2Ctx(), &pb.RecordRateChangeRequest{
		LoanId:        uuid.New().String(),
		NewRate:       0,
		EffectiveDate: timestamppb.Now(),
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoost2_RecordRateChange_MissingEffectiveDate(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.RecordRateChange(boost2Ctx(), &pb.RecordRateChangeRequest{
		LoanId:        uuid.New().String(),
		NewRate:       3.5,
		EffectiveDate: nil,
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}
