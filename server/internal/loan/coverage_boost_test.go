package loan

import (
	"errors"
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

	pb "github.com/familyledger/server/proto/loan"
)

// ════════════════════════════════════════════════════════════════════════════
// Type conversion helpers
// ════════════════════════════════════════════════════════════════════════════

func TestBoost_LoanSubTypeToString(t *testing.T) {
	assert.Equal(t, "commercial", loanSubTypeToString(pb.LoanSubType_LOAN_SUB_TYPE_COMMERCIAL))
	assert.Equal(t, "provident", loanSubTypeToString(pb.LoanSubType_LOAN_SUB_TYPE_PROVIDENT))
	assert.Equal(t, "commercial", loanSubTypeToString(pb.LoanSubType_LOAN_SUB_TYPE_UNSPECIFIED))
}

func TestBoost_StringToLoanSubType(t *testing.T) {
	assert.Equal(t, pb.LoanSubType_LOAN_SUB_TYPE_COMMERCIAL, stringToLoanSubType("commercial"))
	assert.Equal(t, pb.LoanSubType_LOAN_SUB_TYPE_PROVIDENT, stringToLoanSubType("provident"))
	assert.Equal(t, pb.LoanSubType_LOAN_SUB_TYPE_UNSPECIFIED, stringToLoanSubType("unknown"))
	assert.Equal(t, pb.LoanSubType_LOAN_SUB_TYPE_UNSPECIFIED, stringToLoanSubType(""))
}

func TestBoost_RateTypeToString(t *testing.T) {
	assert.Equal(t, "fixed", rateTypeToString(pb.RateType_RATE_TYPE_FIXED))
	assert.Equal(t, "lpr_floating", rateTypeToString(pb.RateType_RATE_TYPE_LPR_FLOATING))
	assert.Equal(t, "fixed", rateTypeToString(pb.RateType_RATE_TYPE_UNSPECIFIED))
}

func TestBoost_StringToRateType(t *testing.T) {
	assert.Equal(t, pb.RateType_RATE_TYPE_FIXED, stringToRateType("fixed"))
	assert.Equal(t, pb.RateType_RATE_TYPE_LPR_FLOATING, stringToRateType("lpr_floating"))
	assert.Equal(t, pb.RateType_RATE_TYPE_UNSPECIFIED, stringToRateType("unknown"))
	assert.Equal(t, pb.RateType_RATE_TYPE_UNSPECIFIED, stringToRateType(""))
}

func TestBoost_CalculateLPRRate(t *testing.T) {
	assert.InDelta(t, 4.15, calculateLPRRate(3.85, 0.30), 0.001)
	assert.InDelta(t, 3.85, calculateLPRRate(3.85, 0.0), 0.001)
	assert.InDelta(t, 3.55, calculateLPRRate(3.85, -0.30), 0.001)
}

// ════════════════════════════════════════════════════════════════════════════
// Loan columns returned by all loan queries
// ════════════════════════════════════════════════════════════════════════════

// Reuse loanColumns() and loanRow() from service_test.go

// ════════════════════════════════════════════════════════════════════════════
// CreateLoanGroup
// ════════════════════════════════════════════════════════════════════════════

func TestBoost_CreateLoanGroup_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	groupID := uuid.New()
	loanID := uuid.New()
	now := time.Now()
	startDate := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)

	mock.ExpectBegin()

	// Insert loan_group
	mock.ExpectQuery("INSERT INTO loan_groups").
		WithArgs(testUserUUID, "房贷组合", "combined", int64(150000000), int32(15), startDate, (*uuid.UUID)(nil), (*uuid.UUID)(nil)).
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at", "updated_at"}).AddRow(groupID, now, now))

	// Sub-loan insert
	mock.ExpectQuery("INSERT INTO loans").
		WithArgs(
			testUserUUID, "房贷组合-商贷", "mortgage", int64(100000000), int64(100000000),
			float64(3.85), int32(360), "equal_installment", int32(15),
			startDate, (*uuid.UUID)(nil), groupID, "commercial", "fixed",
			(*float64)(nil), (*float64)(nil), (*int32)(nil), (*uuid.UUID)(nil), "monthly",
		).
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at", "updated_at"}).AddRow(loanID, now, now))

	// Schedule inserts for sub-loan (360 months)
	for i := 0; i < 360; i++ {
		mock.ExpectExec("INSERT INTO loan_schedules").
			WithArgs(loanID, pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
			WillReturnResult(pgxmock.NewResult("INSERT", 1))
	}

	// Second sub-loan
	loanID2 := uuid.New()
	mock.ExpectQuery("INSERT INTO loans").
		WithArgs(
			testUserUUID, "房贷组合-公积金", "mortgage", int64(50000000), int64(50000000),
			float64(2.85), int32(360), "equal_installment", int32(15),
			startDate, (*uuid.UUID)(nil), groupID, "provident", "fixed",
			(*float64)(nil), (*float64)(nil), (*int32)(nil), (*uuid.UUID)(nil), "monthly",
		).
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at", "updated_at"}).AddRow(loanID2, now, now))

	for i := 0; i < 360; i++ {
		mock.ExpectExec("INSERT INTO loan_schedules").
			WithArgs(loanID2, pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
			WillReturnResult(pgxmock.NewResult("INSERT", 1))
	}

	mock.ExpectCommit()

	resp, err := svc.CreateLoanGroup(authedCtx(), &pb.CreateLoanGroupRequest{
		Name:       "房贷组合",
		GroupType:  "combined",
		PaymentDay: 15,
		StartDate:  timestamppb.New(startDate),
		LoanType:   pb.LoanType_LOAN_TYPE_MORTGAGE,
		SubLoans: []*pb.SubLoanSpec{
			{
				SubType:         pb.LoanSubType_LOAN_SUB_TYPE_COMMERCIAL,
				Principal:       100000000,
				AnnualRate:      3.85,
				TotalMonths:     360,
				RepaymentMethod: pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
				RateType:        pb.RateType_RATE_TYPE_FIXED,
			},
			{
				SubType:         pb.LoanSubType_LOAN_SUB_TYPE_PROVIDENT,
				Principal:       50000000,
				AnnualRate:      2.85,
				TotalMonths:     360,
				RepaymentMethod: pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
				RateType:        pb.RateType_RATE_TYPE_FIXED,
			},
		},
	})
	require.NoError(t, err)
	assert.Equal(t, "房贷组合", resp.Name)
	assert.Equal(t, int64(150000000), resp.TotalPrincipal)
	assert.Len(t, resp.SubLoans, 2)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoost_CreateLoanGroup_InvalidPaymentDay(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.CreateLoanGroup(authedCtx(), &pb.CreateLoanGroupRequest{
		Name:       "test",
		GroupType:  "combined",
		PaymentDay: 30, // invalid
		StartDate:  timestamppb.Now(),
		SubLoans: []*pb.SubLoanSpec{
			{Principal: 100, AnnualRate: 3.0, TotalMonths: 12, RepaymentMethod: pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT},
		},
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoost_CreateLoanGroup_NoSubLoans(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.CreateLoanGroup(authedCtx(), &pb.CreateLoanGroupRequest{
		Name:       "test",
		GroupType:  "combined",
		PaymentDay: 15,
		StartDate:  timestamppb.Now(),
		SubLoans:   nil,
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoost_CreateLoanGroup_TooManySubLoans(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.CreateLoanGroup(authedCtx(), &pb.CreateLoanGroupRequest{
		Name:       "test",
		GroupType:  "combined",
		PaymentDay: 15,
		StartDate:  timestamppb.Now(),
		SubLoans: []*pb.SubLoanSpec{
			{Principal: 100, AnnualRate: 3.0, TotalMonths: 12, RepaymentMethod: pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT},
			{Principal: 200, AnnualRate: 3.0, TotalMonths: 12, RepaymentMethod: pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT},
			{Principal: 300, AnnualRate: 3.0, TotalMonths: 12, RepaymentMethod: pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT},
		},
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoost_CreateLoanGroup_InvalidSubLoanPrincipal(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.CreateLoanGroup(authedCtx(), &pb.CreateLoanGroupRequest{
		Name:       "test",
		GroupType:  "combined",
		PaymentDay: 15,
		StartDate:  timestamppb.Now(),
		SubLoans: []*pb.SubLoanSpec{
			{Principal: -100, AnnualRate: 3.0, TotalMonths: 12, RepaymentMethod: pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT},
		},
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoost_CreateLoanGroup_MissingGroupType(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.CreateLoanGroup(authedCtx(), &pb.CreateLoanGroupRequest{
		Name:       "test",
		GroupType:  "",
		PaymentDay: 15,
		StartDate:  timestamppb.Now(),
		SubLoans: []*pb.SubLoanSpec{
			{Principal: 100, AnnualRate: 3.0, TotalMonths: 12, RepaymentMethod: pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT},
		},
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoost_CreateLoanGroup_MissingStartDate(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.CreateLoanGroup(authedCtx(), &pb.CreateLoanGroupRequest{
		Name:       "test",
		GroupType:  "combined",
		PaymentDay: 15,
		StartDate:  nil,
		SubLoans: []*pb.SubLoanSpec{
			{Principal: 100, AnnualRate: 3.0, TotalMonths: 12, RepaymentMethod: pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT},
		},
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoost_CreateLoanGroup_SubLoanMissingRepaymentMethod(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.CreateLoanGroup(authedCtx(), &pb.CreateLoanGroupRequest{
		Name:       "test",
		GroupType:  "combined",
		PaymentDay: 15,
		StartDate:  timestamppb.Now(),
		SubLoans: []*pb.SubLoanSpec{
			{Principal: 100, AnnualRate: 3.0, TotalMonths: 12, RepaymentMethod: pb.RepaymentMethod_REPAYMENT_METHOD_UNSPECIFIED},
		},
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ════════════════════════════════════════════════════════════════════════════
// ListLoanGroups
// ════════════════════════════════════════════════════════════════════════════

func TestBoost_ListLoanGroups_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	groupID := uuid.New()
	loanID := uuid.New()
	now := time.Now()

	// List groups query
	mock.ExpectQuery("SELECT .+ FROM loan_groups WHERE user_id").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "name", "group_type", "total_principal", "payment_day", "start_date", "account_id", "family_id", "created_at", "updated_at"}).
			AddRow(groupID, "房贷组合", "combined", int64(150000000), int32(15), now, (*uuid.UUID)(nil), (*uuid.UUID)(nil), now, now))

	// loadSubLoans for this group
	subType := "commercial"
	rateType := "fixed"
	mock.ExpectQuery("SELECT .+ FROM loans WHERE group_id").
		WithArgs(groupID.String(), testUserID).
		WillReturnRows(pgxmock.NewRows(subLoanColumns()).
			AddRow(loanID, testUserUUID, "房贷-商贷", "mortgage", int64(100000000), int64(90000000),
				float64(3.85), int32(360), int32(12), "equal_installment", int32(15),
				now, now, now, (*uuid.UUID)(nil),
				&groupID, &subType, &rateType, (*float64)(nil), (*float64)(nil), (*int32)(nil), (*uuid.UUID)(nil), (*uuid.UUID)(nil), "monthly"))

	// loadSchedule to find monthly payment
	mock.ExpectQuery("SELECT .+ FROM loan_schedules WHERE loan_id").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows([]string{"month_number", "payment", "principal_part", "interest_part", "remaining_principal", "is_paid", "due_date", "paid_date"}).
			AddRow(int32(13), int64(467000), int64(178000), int64(289000), int64(89000000), false, now, (*time.Time)(nil)))

	resp, err := svc.ListLoanGroups(authedCtx(), &pb.ListLoanGroupsRequest{})
	require.NoError(t, err)
	require.Len(t, resp.Groups, 1)
	assert.Equal(t, "房贷组合", resp.Groups[0].Name)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoost_ListLoanGroups_Empty(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectQuery("SELECT .+ FROM loan_groups WHERE user_id").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "name", "group_type", "total_principal", "payment_day", "start_date", "account_id", "family_id", "created_at", "updated_at"}))

	resp, err := svc.ListLoanGroups(authedCtx(), &pb.ListLoanGroupsRequest{})
	require.NoError(t, err)
	assert.Empty(t, resp.Groups)
}

func TestBoost_ListLoanGroups_DBError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectQuery("SELECT .+ FROM loan_groups WHERE user_id").
		WithArgs(testUserID).
		WillReturnError(errors.New("db error"))

	_, err = svc.ListLoanGroups(authedCtx(), &pb.ListLoanGroupsRequest{})
	assert.Equal(t, codes.Internal, status.Code(err))
}

// ════════════════════════════════════════════════════════════════════════════
// loadLoanGroup
// ════════════════════════════════════════════════════════════════════════════

func TestBoost_GetLoanGroup_NotFound(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectQuery("SELECT .+ FROM loan_groups WHERE id").
		WithArgs(pgxmock.AnyArg()).
		WillReturnError(pgx.ErrNoRows)

	_, err = svc.GetLoanGroup(authedCtx(), &pb.GetLoanGroupRequest{GroupId: uuid.New().String()})
	assert.Equal(t, codes.NotFound, status.Code(err))
}

func TestBoost_GetLoanGroup_NotOwner(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	groupID := uuid.New()
	otherUser := uuid.New()
	now := time.Now()

	mock.ExpectQuery("SELECT .+ FROM loan_groups WHERE id").
		WithArgs(groupID.String()).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "name", "group_type", "total_principal", "payment_day", "start_date", "account_id", "created_at", "updated_at"}).
			AddRow(groupID, otherUser, "Other", "combined", int64(100), int32(15), now, (*uuid.UUID)(nil), now, now))

	_, err = svc.GetLoanGroup(authedCtx(), &pb.GetLoanGroupRequest{GroupId: groupID.String()})
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

// ════════════════════════════════════════════════════════════════════════════
// loadSubLoans
// ════════════════════════════════════════════════════════════════════════════

func TestBoost_LoadSubLoans_DBError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	groupID := uuid.New()
	now := time.Now()

	// loadLoanGroup succeeds
	mock.ExpectQuery("SELECT .+ FROM loan_groups WHERE id").
		WithArgs(groupID.String()).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "name", "group_type", "total_principal", "payment_day", "start_date", "account_id", "created_at", "updated_at"}).
			AddRow(groupID, testUserUUID, "Group", "combined", int64(100), int32(15), now, (*uuid.UUID)(nil), now, now))

	// loadSubLoans fails
	mock.ExpectQuery("SELECT .+ FROM loans WHERE group_id").
		WithArgs(groupID.String(), testUserID).
		WillReturnError(errors.New("query error"))

	_, err = svc.GetLoanGroup(authedCtx(), &pb.GetLoanGroupRequest{GroupId: groupID.String()})
	assert.Equal(t, codes.Internal, status.Code(err))
}

// ════════════════════════════════════════════════════════════════════════════
// GetUpcomingPayments
// ════════════════════════════════════════════════════════════════════════════

func TestBoost_GetUpcomingPayments_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	loanID := uuid.New()
	userID := uuid.New()
	dueDate := time.Now().Add(3 * 24 * time.Hour)

	mock.ExpectQuery("SELECT .+ FROM loan_schedules .+ JOIN loans").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "name", "month_number", "payment", "due_date"}).
			AddRow(loanID, userID, "房贷", int32(5), int64(500000), dueDate))

	results, err := svc.GetUpcomingPayments(authedCtx(), 7)
	require.NoError(t, err)
	require.Len(t, results, 1)
	assert.Equal(t, loanID.String(), results[0].LoanID)
	assert.Equal(t, userID.String(), results[0].UserID)
	assert.Equal(t, "房贷", results[0].LoanName)
	assert.Equal(t, int32(5), results[0].MonthNumber)
	assert.Equal(t, int64(500000), results[0].Payment)
}

func TestBoost_GetUpcomingPayments_Empty(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectQuery("SELECT .+ FROM loan_schedules .+ JOIN loans").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "name", "month_number", "payment", "due_date"}))

	results, err := svc.GetUpcomingPayments(authedCtx(), 7)
	require.NoError(t, err)
	assert.Empty(t, results)
}

func TestBoost_GetUpcomingPayments_DBError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectQuery("SELECT .+ FROM loan_schedules .+ JOIN loans").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnError(errors.New("db error"))

	_, err = svc.GetUpcomingPayments(authedCtx(), 7)
	assert.Error(t, err)
}

// ════════════════════════════════════════════════════════════════════════════
// RecordRateChange
// ════════════════════════════════════════════════════════════════════════════

func TestBoost_RecordRateChange_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	loanID := uuid.New()
	now := time.Now()
	effDate := time.Date(2026, 6, 1, 0, 0, 0, 0, time.UTC)

	// loadLoan
	mock.ExpectQuery("SELECT .+ FROM loans WHERE id").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows(loanColumns()).AddRow(loanRow(loanID, testUserUUID)...))

	mock.ExpectBegin()

	// Insert rate change
	mock.ExpectExec("INSERT INTO loan_rate_changes").
		WithArgs(loanID.String(), float64(3.85), float64(3.5), effDate).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	// Update loan rate
	mock.ExpectExec("UPDATE loans SET annual_rate").
		WithArgs(float64(3.5), loanID.String()).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	// Find next unpaid month
	mock.ExpectQuery("SELECT COALESCE\\(MIN\\(month_number\\)").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows([]string{"min"}).AddRow(int32(13)))

	// Get remaining principal before unpaid month
	mock.ExpectQuery("SELECT remaining_principal FROM loan_schedules").
		WithArgs(loanID.String(), int32(12)).
		WillReturnRows(pgxmock.NewRows([]string{"remaining_principal"}).AddRow(int64(90000000)))

	// Get next due date
	mock.ExpectQuery("SELECT due_date FROM loan_schedules").
		WithArgs(loanID.String(), int32(13)).
		WillReturnRows(pgxmock.NewRows([]string{"due_date"}).AddRow(now))

	// Delete unpaid schedule items
	mock.ExpectExec("DELETE FROM loan_schedules WHERE loan_id.*AND is_paid=false").
		WithArgs(loanID.String()).
		WillReturnResult(pgxmock.NewResult("DELETE", 348))

	// Insert new schedule items (360 - 12 = 348)
	for i := 0; i < 348; i++ {
		mock.ExpectExec("INSERT INTO loan_schedules").
			WithArgs(loanID.String(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
			WillReturnResult(pgxmock.NewResult("INSERT", 1))
	}

	mock.ExpectCommit()

	// loadLoan again for return value
	mock.ExpectQuery("SELECT .+ FROM loans WHERE id").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows(loanColumns()).AddRow(loanRow(loanID, testUserUUID)...))

	resp, err := svc.RecordRateChange(authedCtx(), &pb.RecordRateChangeRequest{
		LoanId:        loanID.String(),
		NewRate:       3.5,
		EffectiveDate: timestamppb.New(effDate),
	})
	require.NoError(t, err)
	assert.NotNil(t, resp)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoost_RecordRateChange_AllPaid(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	loanID := uuid.New()
	effDate := time.Date(2026, 6, 1, 0, 0, 0, 0, time.UTC)

	// loadLoan
	mock.ExpectQuery("SELECT .+ FROM loans WHERE id").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows(loanColumns()).AddRow(loanRow(loanID, testUserUUID)...))

	mock.ExpectBegin()

	mock.ExpectExec("INSERT INTO loan_rate_changes").
		WithArgs(loanID.String(), float64(3.85), float64(3.5), effDate).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	mock.ExpectExec("UPDATE loans SET annual_rate").
		WithArgs(float64(3.5), loanID.String()).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	// No unpaid months
	mock.ExpectQuery("SELECT COALESCE\\(MIN\\(month_number\\)").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows([]string{"min"}).AddRow(int32(0)))

	mock.ExpectCommit()

	// loadLoan for return
	mock.ExpectQuery("SELECT .+ FROM loans WHERE id").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows(loanColumns()).AddRow(loanRow(loanID, testUserUUID)...))

	resp, err := svc.RecordRateChange(authedCtx(), &pb.RecordRateChangeRequest{
		LoanId:        loanID.String(),
		NewRate:       3.5,
		EffectiveDate: timestamppb.New(effDate),
	})
	require.NoError(t, err)
	assert.NotNil(t, resp)
}

func TestBoost_RecordRateChange_FirstMonthUnpaid(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	loanID := uuid.New()
	now := time.Now()
	effDate := time.Date(2026, 6, 1, 0, 0, 0, 0, time.UTC)

	// loadLoan
	mock.ExpectQuery("SELECT .+ FROM loans WHERE id").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows(loanColumns()).AddRow(loanRow(loanID, testUserUUID)...))

	mock.ExpectBegin()

	mock.ExpectExec("INSERT INTO loan_rate_changes").
		WithArgs(loanID.String(), float64(3.85), float64(3.5), effDate).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	mock.ExpectExec("UPDATE loans SET annual_rate").
		WithArgs(float64(3.5), loanID.String()).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	// First month unpaid (month_number = 1)
	mock.ExpectQuery("SELECT COALESCE\\(MIN\\(month_number\\)").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows([]string{"min"}).AddRow(int32(1)))

	// rpBefore = loan.Principal (nextUnpaidMonth == 1)

	// Get due date
	mock.ExpectQuery("SELECT due_date FROM loan_schedules").
		WithArgs(loanID.String(), int32(1)).
		WillReturnRows(pgxmock.NewRows([]string{"due_date"}).AddRow(now))

	// Delete unpaid
	mock.ExpectExec("DELETE FROM loan_schedules WHERE loan_id.*AND is_paid=false").
		WithArgs(loanID.String()).
		WillReturnResult(pgxmock.NewResult("DELETE", 360))

	// Insert new 360 items
	for i := 0; i < 360; i++ {
		mock.ExpectExec("INSERT INTO loan_schedules").
			WithArgs(loanID.String(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
			WillReturnResult(pgxmock.NewResult("INSERT", 1))
	}

	mock.ExpectCommit()

	mock.ExpectQuery("SELECT .+ FROM loans WHERE id").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows(loanColumns()).AddRow(loanRow(loanID, testUserUUID)...))

	resp, err := svc.RecordRateChange(authedCtx(), &pb.RecordRateChangeRequest{
		LoanId:        loanID.String(),
		NewRate:       3.5,
		EffectiveDate: timestamppb.New(effDate),
	})
	require.NoError(t, err)
	assert.NotNil(t, resp)
}

// ════════════════════════════════════════════════════════════════════════════
// RecordPayment
// ════════════════════════════════════════════════════════════════════════════

func TestBoost_RecordPayment_Success_NoAccount(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	loanID := uuid.New()
	now := time.Now()
	dueDate := time.Date(2026, 2, 15, 0, 0, 0, 0, time.UTC)

	// loadLoan — no account_id
	mock.ExpectQuery("SELECT .+ FROM loans WHERE id").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows(loanColumns()).AddRow(loanRow(loanID, testUserUUID)...))

	// Check next unpaid month
	mock.ExpectQuery("SELECT COALESCE\\(MIN\\(month_number\\)").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows([]string{"min"}).AddRow(int32(13)))

	mock.ExpectBegin()

	// Update schedule item
	mock.ExpectQuery("UPDATE loan_schedules SET is_paid=true").
		WithArgs(pgxmock.AnyArg(), loanID.String(), int32(13)).
		WillReturnRows(pgxmock.NewRows([]string{"month_number", "payment", "principal_part", "interest_part", "remaining_principal", "due_date"}).
			AddRow(int32(13), int64(467000), int64(178000), int64(289000), int64(89000000), dueDate))

	// Update loan counters
	mock.ExpectExec("UPDATE loans SET").
		WithArgs(loanID.String(), int64(89000000)).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	mock.ExpectCommit()

	resp, err := svc.RecordPayment(authedCtx(), &pb.RecordPaymentRequest{
		LoanId:      loanID.String(),
		MonthNumber: 13,
	})
	require.NoError(t, err)
	assert.True(t, resp.IsPaid)
	assert.Equal(t, int32(13), resp.MonthNumber)
	_ = now
}

func TestBoost_RecordPayment_WrongSequence(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	loanID := uuid.New()

	mock.ExpectQuery("SELECT .+ FROM loans WHERE id").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows(loanColumns()).AddRow(loanRow(loanID, testUserUUID)...))

	// Next unpaid is 13, but requesting 15
	mock.ExpectQuery("SELECT COALESCE\\(MIN\\(month_number\\)").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows([]string{"min"}).AddRow(int32(13)))

	// Idempotency check: month 15 not already paid
	mock.ExpectQuery("SELECT .+ FROM loan_schedules WHERE loan_id").
		WithArgs(loanID.String(), int32(15)).
		WillReturnError(pgx.ErrNoRows)

	_, err = svc.RecordPayment(authedCtx(), &pb.RecordPaymentRequest{
		LoanId:      loanID.String(),
		MonthNumber: 15,
	})
	assert.Equal(t, codes.FailedPrecondition, status.Code(err))
}

func TestBoost_RecordPayment_AllPaid(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	loanID := uuid.New()

	mock.ExpectQuery("SELECT .+ FROM loans WHERE id").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows(loanColumns()).AddRow(loanRow(loanID, testUserUUID)...))

	mock.ExpectQuery("SELECT COALESCE\\(MIN\\(month_number\\)").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows([]string{"min"}).AddRow(int32(0)))

	// Idempotency check: month 1 not already paid
	mock.ExpectQuery("SELECT .+ FROM loan_schedules WHERE loan_id").
		WithArgs(loanID.String(), int32(1)).
		WillReturnError(pgx.ErrNoRows)

	_, err = svc.RecordPayment(authedCtx(), &pb.RecordPaymentRequest{
		LoanId:      loanID.String(),
		MonthNumber: 1,
	})
	assert.Equal(t, codes.FailedPrecondition, status.Code(err))
}

func TestBoost_RecordPayment_WithAccountDeduction(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	loanID := uuid.New()
	accountID := uuid.New()
	now := time.Now()
	dueDate := time.Date(2026, 2, 15, 0, 0, 0, 0, time.UTC)

	// Loan with account_id
	rowData := loanRow(loanID, testUserUUID)
	rowData[14] = &accountID // account_id
	mock.ExpectQuery("SELECT .+ FROM loans WHERE id").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows(loanColumns()).AddRow(rowData...))

	mock.ExpectQuery("SELECT COALESCE\\(MIN\\(month_number\\)").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows([]string{"min"}).AddRow(int32(13)))

	mock.ExpectBegin()

	mock.ExpectQuery("UPDATE loan_schedules SET is_paid=true").
		WithArgs(pgxmock.AnyArg(), loanID.String(), int32(13)).
		WillReturnRows(pgxmock.NewRows([]string{"month_number", "payment", "principal_part", "interest_part", "remaining_principal", "due_date"}).
			AddRow(int32(13), int64(467000), int64(178000), int64(289000), int64(89000000), dueDate))

	mock.ExpectExec("UPDATE loans SET").
		WithArgs(loanID.String(), int64(89000000)).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	// Deduct payment from account (no balance check, direct deduction)
	mock.ExpectExec("UPDATE accounts SET balance").
		WithArgs(int64(467000), accountID.String()).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	// SELECT repayment_category_id
	mock.ExpectQuery("SELECT repayment_category_id FROM loans").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows([]string{"repayment_category_id"}).AddRow((*uuid.UUID)(nil)))

	// Fallback category lookup: "还款"
	catID := uuid.New()
	mock.ExpectQuery("SELECT id FROM categories WHERE name").
		WillReturnRows(pgxmock.NewRows([]string{"id"}).AddRow(catID.String()))

	// INSERT transaction record
	mock.ExpectExec("INSERT INTO transactions").
		WithArgs(testUserID, accountID.String(), catID.String(), int64(467000), pgxmock.AnyArg(), pgxmock.AnyArg(), nil).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	mock.ExpectCommit()

	resp, err := svc.RecordPayment(authedCtx(), &pb.RecordPaymentRequest{
		LoanId:      loanID.String(),
		MonthNumber: 13,
	})
	require.NoError(t, err)
	assert.True(t, resp.IsPaid)
	_ = now
}

// TestBoost_RecordPayment_InsufficientBalance removed:
// Balance check was removed in commit 26044a7. Account balance can go negative.
// The code now directly deducts without checking.

// ════════════════════════════════════════════════════════════════════════════
// CreateLoanGroup with LPR floating rate
// ════════════════════════════════════════════════════════════════════════════

func TestBoost_CreateLoanGroup_LPRFloating(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	groupID := uuid.New()
	loanID := uuid.New()
	now := time.Now()
	startDate := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)

	lprBase := 3.85
	lprSpread := 0.30
	rateAdjustMonth := int32(1)

	mock.ExpectBegin()

	mock.ExpectQuery("INSERT INTO loan_groups").
		WithArgs(testUserUUID, "LPR贷", "commercial_only", int64(100000000), int32(15), startDate, (*uuid.UUID)(nil), (*uuid.UUID)(nil)).
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at", "updated_at"}).AddRow(groupID, now, now))

	// Sub-loan with LPR type: effective rate = 3.85 + 0.30 = 4.15
	mock.ExpectQuery("INSERT INTO loans").
		WithArgs(
			testUserUUID, "LPR贷-商贷", "mortgage", int64(100000000), int64(100000000),
			float64(4.15), int32(12), "equal_installment", int32(15),
			startDate, (*uuid.UUID)(nil), groupID, "commercial", "lpr_floating",
			&lprBase, &lprSpread, &rateAdjustMonth, (*uuid.UUID)(nil), "monthly",
		).
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at", "updated_at"}).AddRow(loanID, now, now))

	for i := 0; i < 12; i++ {
		mock.ExpectExec("INSERT INTO loan_schedules").
			WithArgs(loanID, pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
			WillReturnResult(pgxmock.NewResult("INSERT", 1))
	}

	mock.ExpectCommit()

	resp, err := svc.CreateLoanGroup(authedCtx(), &pb.CreateLoanGroupRequest{
		Name:       "LPR贷",
		GroupType:  "commercial_only",
		PaymentDay: 15,
		StartDate:  timestamppb.New(startDate),
		LoanType:   pb.LoanType_LOAN_TYPE_MORTGAGE,
		SubLoans: []*pb.SubLoanSpec{
			{
				SubType:         pb.LoanSubType_LOAN_SUB_TYPE_COMMERCIAL,
				Principal:       100000000,
				AnnualRate:      3.85, // ignored when LPR
				TotalMonths:     12,
				RepaymentMethod: pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
				RateType:        pb.RateType_RATE_TYPE_LPR_FLOATING,
				LprBase:         3.85,
				LprSpread:       0.30,
				RateAdjustMonth: 1,
			},
		},
	})
	require.NoError(t, err)
	assert.Equal(t, "LPR贷", resp.Name)
	assert.Len(t, resp.SubLoans, 1)
}

// ════════════════════════════════════════════════════════════════════════════
// ListLoanGroups with FamilyId
// ════════════════════════════════════════════════════════════════════════════

func TestBoost_ListLoanGroups_WithFamilyID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	familyID := uuid.New().String()

	mock.ExpectQuery("SELECT .+ FROM loan_groups WHERE family_id").
		WithArgs(familyID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "name", "group_type", "total_principal", "payment_day", "start_date", "account_id", "created_at", "updated_at"}))

	resp, err := svc.ListLoanGroups(authedCtx(), &pb.ListLoanGroupsRequest{FamilyId: familyID})
	require.NoError(t, err)
	assert.Empty(t, resp.Groups)
}

// ════════════════════════════════════════════════════════════════════════════
// SimulateGroupPrepayment
// ════════════════════════════════════════════════════════════════════════════

func TestBoost_SimulateGroupPrepayment_InvalidArgs(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	// Missing group_id
	_, err = svc.SimulateGroupPrepayment(authedCtx(), &pb.SimulateGroupPrepaymentRequest{
		GroupId:          "",
		PrepaymentAmount: 100,
		Strategy:         pb.PrepaymentStrategy_PREPAYMENT_STRATEGY_REDUCE_MONTHS,
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))

	// Negative amount
	_, err = svc.SimulateGroupPrepayment(authedCtx(), &pb.SimulateGroupPrepaymentRequest{
		GroupId:          uuid.New().String(),
		PrepaymentAmount: -100,
		Strategy:         pb.PrepaymentStrategy_PREPAYMENT_STRATEGY_REDUCE_MONTHS,
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))

	// Missing strategy
	_, err = svc.SimulateGroupPrepayment(authedCtx(), &pb.SimulateGroupPrepaymentRequest{
		GroupId:          uuid.New().String(),
		PrepaymentAmount: 100,
		Strategy:         pb.PrepaymentStrategy_PREPAYMENT_STRATEGY_UNSPECIFIED,
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoost_SimulateGroupPrepayment_GroupNotFound(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	groupID := uuid.New().String()

	mock.ExpectQuery("SELECT .+ FROM loan_groups WHERE id").
		WithArgs(groupID).
		WillReturnError(pgx.ErrNoRows)

	_, err = svc.SimulateGroupPrepayment(authedCtx(), &pb.SimulateGroupPrepaymentRequest{
		GroupId:          groupID,
		PrepaymentAmount: 100000,
		Strategy:         pb.PrepaymentStrategy_PREPAYMENT_STRATEGY_REDUCE_MONTHS,
	})
	assert.Equal(t, codes.NotFound, status.Code(err))
}

func TestBoost_SimulateGroupPrepayment_AutoSelectTargetLoan(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	groupID := uuid.New()
	loanID := uuid.New()
	now := time.Now()

	// loadLoanGroup
	mock.ExpectQuery("SELECT .+ FROM loan_groups WHERE id").
		WithArgs(groupID.String()).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "name", "group_type", "total_principal", "payment_day", "start_date", "account_id", "created_at", "updated_at"}).
			AddRow(groupID, testUserUUID, "Group", "combined", int64(100000000), int32(15), now, (*uuid.UUID)(nil), now, now))

	// loadSubLoans
	subType := "commercial"
	rateType := "fixed"
	mock.ExpectQuery("SELECT .+ FROM loans WHERE group_id").
		WithArgs(groupID.String(), testUserID).
		WillReturnRows(pgxmock.NewRows(loanColumns()).
			AddRow(loanID, testUserUUID, "商贷", "mortgage", int64(100000000), int64(95000000),
				float64(3.85), int32(360), int32(12), "equal_installment", int32(15),
				now, now, now, (*uuid.UUID)(nil),
				&groupID, &subType, &rateType, (*float64)(nil), (*float64)(nil), (*int32)(nil), (*uuid.UUID)(nil), (*uuid.UUID)(nil), "monthly"))

	// loadSchedule for monthly payment
	mock.ExpectQuery("SELECT .+ FROM loan_schedules WHERE loan_id").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows([]string{"month_number", "payment", "principal_part", "interest_part", "remaining_principal", "is_paid", "due_date", "paid_date"}).
			AddRow(int32(13), int64(467000), int64(178000), int64(289000), int64(94000000), false, now, (*time.Time)(nil)))

	// SimulatePrepayment calls loadLoan + loadSchedule on the target loan
	mock.ExpectQuery("SELECT .+ FROM loans WHERE id").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows(loanColumns()).
			AddRow(loanID, testUserUUID, "商贷", "mortgage", int64(100000000), int64(95000000),
				float64(3.85), int32(360), int32(12), "equal_installment", int32(15),
				now, now, now, (*uuid.UUID)(nil),
				&groupID, &subType, &rateType, (*float64)(nil), (*float64)(nil), (*int32)(nil), (*uuid.UUID)(nil), (*uuid.UUID)(nil), "monthly"))

	// loadSchedule for simulate
	schedRows := pgxmock.NewRows([]string{"month_number", "payment", "principal_part", "interest_part", "remaining_principal", "is_paid", "due_date", "paid_date"})
	dueDate := now
	paidDate := now
	// 12 paid months + a few unpaid
	for i := 1; i <= 12; i++ {
		schedRows.AddRow(int32(i), int64(467000), int64(178000), int64(289000), int64(95000000-int64(i)*178000), true, dueDate, &paidDate)
		dueDate = dueDate.AddDate(0, 1, 0)
	}
	for i := 13; i <= 360; i++ {
		rem := int64(95000000) - int64(i-12)*178000
		if rem < 0 {
			rem = 0
		}
		schedRows.AddRow(int32(i), int64(467000), int64(178000), int64(289000), rem, false, dueDate, (*time.Time)(nil))
		dueDate = dueDate.AddDate(0, 1, 0)
	}
	mock.ExpectQuery("SELECT .+ FROM loan_schedules WHERE loan_id").
		WithArgs(loanID.String()).
		WillReturnRows(schedRows)

	resp, err := svc.SimulateGroupPrepayment(authedCtx(), &pb.SimulateGroupPrepaymentRequest{
		GroupId:          groupID.String(),
		PrepaymentAmount: 5000000,
		Strategy:         pb.PrepaymentStrategy_PREPAYMENT_STRATEGY_REDUCE_MONTHS,
	})
	require.NoError(t, err)
	assert.Equal(t, loanID.String(), resp.TargetLoanId)
	assert.NotNil(t, resp.TargetSim)
}

// ════════════════════════════════════════════════════════════════════════════
// ListLoans with FamilyId
// ════════════════════════════════════════════════════════════════════════════

func TestBoost_ListLoans_WithFamilyID_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	familyID := uuid.New().String()
	loanID := uuid.New()

	// Family membership check
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(familyID, testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))

	// Query loans by family_id
	mock.ExpectQuery("SELECT .+ FROM loans WHERE family_id").
		WithArgs(familyID).
		WillReturnRows(pgxmock.NewRows(loanColumns()).AddRow(loanRow(loanID, testUserUUID)...))

	resp, err := svc.ListLoans(authedCtx(), &pb.ListLoansRequest{FamilyId: familyID})
	require.NoError(t, err)
	assert.Len(t, resp.Loans, 1)
}

func TestBoost_ListLoans_WithFamilyID_NotMember(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	familyID := uuid.New().String()

	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(familyID, testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(false))

	_, err = svc.ListLoans(authedCtx(), &pb.ListLoansRequest{FamilyId: familyID})
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

func TestBoost_ListLoans_WithFamilyID_DBError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	familyID := uuid.New().String()

	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(familyID, testUserID).
		WillReturnError(errors.New("db error"))

	_, err = svc.ListLoans(authedCtx(), &pb.ListLoansRequest{FamilyId: familyID})
	assert.Equal(t, codes.Internal, status.Code(err))
}

// ════════════════════════════════════════════════════════════════════════════
// loadLoanGroup with account_id present
// ════════════════════════════════════════════════════════════════════════════

func TestBoost_GetLoanGroup_WithAccountID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	groupID := uuid.New()
	accountID := uuid.New()
	now := time.Now()

	mock.ExpectQuery("SELECT .+ FROM loan_groups WHERE id").
		WithArgs(groupID.String()).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "name", "group_type", "total_principal", "payment_day", "start_date", "account_id", "created_at", "updated_at"}).
			AddRow(groupID, testUserUUID, "Group", "combined", int64(100000000), int32(15), now, &accountID, now, now))

	// loadSubLoans
	mock.ExpectQuery("SELECT .+ FROM loans WHERE group_id").
		WithArgs(groupID.String(), testUserID).
		WillReturnRows(pgxmock.NewRows(loanColumns())) // no sub-loans

	resp, err := svc.GetLoanGroup(authedCtx(), &pb.GetLoanGroupRequest{GroupId: groupID.String()})
	require.NoError(t, err)
	assert.Equal(t, accountID.String(), resp.AccountId)
}

func TestBoost_GetLoanGroup_InvalidGroupID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.GetLoanGroup(authedCtx(), &pb.GetLoanGroupRequest{GroupId: ""})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ════════════════════════════════════════════════════════════════════════════
// RecordPayment — additional edge cases
// ════════════════════════════════════════════════════════════════════════════

func TestBoost_RecordPayment_InvalidArgs(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.RecordPayment(authedCtx(), &pb.RecordPaymentRequest{LoanId: "", MonthNumber: 1})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))

	_, err = svc.RecordPayment(authedCtx(), &pb.RecordPaymentRequest{LoanId: uuid.New().String(), MonthNumber: 0})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoost_RecordPayment_LoanNotFound(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	loanID := uuid.New().String()

	mock.ExpectQuery("SELECT .+ FROM loans WHERE id").
		WithArgs(loanID).
		WillReturnError(pgx.ErrNoRows)

	_, err = svc.RecordPayment(authedCtx(), &pb.RecordPaymentRequest{LoanId: loanID, MonthNumber: 1})
	assert.Equal(t, codes.NotFound, status.Code(err))
}

func TestBoost_RecordPayment_AccountLockError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	loanID := uuid.New()
	accountID := uuid.New()
	dueDate := time.Date(2026, 2, 15, 0, 0, 0, 0, time.UTC)

	rowData := loanRow(loanID, testUserUUID)
	rowData[14] = &accountID
	mock.ExpectQuery("SELECT .+ FROM loans WHERE id").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows(loanColumns()).AddRow(rowData...))

	mock.ExpectQuery("SELECT COALESCE\\(MIN\\(month_number\\)").
		WithArgs(loanID.String()).
		WillReturnRows(pgxmock.NewRows([]string{"min"}).AddRow(int32(13)))

	mock.ExpectBegin()

	mock.ExpectQuery("UPDATE loan_schedules SET is_paid=true").
		WithArgs(pgxmock.AnyArg(), loanID.String(), int32(13)).
		WillReturnRows(pgxmock.NewRows([]string{"month_number", "payment", "principal_part", "interest_part", "remaining_principal", "due_date"}).
			AddRow(int32(13), int64(467000), int64(178000), int64(289000), int64(89000000), dueDate))

	mock.ExpectExec("UPDATE loans SET").
		WithArgs(loanID.String(), int64(89000000)).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	mock.ExpectQuery("SELECT balance FROM accounts WHERE id").
		WithArgs(accountID.String()).
		WillReturnError(errors.New("lock failed"))

	mock.ExpectRollback()

	_, err = svc.RecordPayment(authedCtx(), &pb.RecordPaymentRequest{LoanId: loanID.String(), MonthNumber: 13})
	assert.Equal(t, codes.Internal, status.Code(err))
}

// ════════════════════════════════════════════════════════════════════════════
// CreateLoan with FamilyId path
// ════════════════════════════════════════════════════════════════════════════

func TestBoost_CreateLoan_InvalidFamilyID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.CreateLoan(authedCtx(), &pb.CreateLoanRequest{
		Name:            "test",
		LoanType:        pb.LoanType_LOAN_TYPE_MORTGAGE,
		Principal:       100,
		AnnualRate:      3.0,
		TotalMonths:     12,
		RepaymentMethod: pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
		PaymentDay:      15,
		StartDate:       timestamppb.Now(),
		FamilyId:        "not-a-uuid",
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoost_CreateLoan_InvalidAccountID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.CreateLoan(authedCtx(), &pb.CreateLoanRequest{
		Name:            "test",
		LoanType:        pb.LoanType_LOAN_TYPE_MORTGAGE,
		Principal:       100,
		AnnualRate:      3.0,
		TotalMonths:     12,
		RepaymentMethod: pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT,
		PaymentDay:      15,
		StartDate:       timestamppb.Now(),
		AccountId:       "not-a-uuid",
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ════════════════════════════════════════════════════════════════════════════
// validateCreateLoanRequest edge cases
// ════════════════════════════════════════════════════════════════════════════

func TestBoost_ValidateCreateLoanRequest_AllErrors(t *testing.T) {
	tests := []struct {
		name string
		req  *pb.CreateLoanRequest
	}{
		{"empty name", &pb.CreateLoanRequest{Name: "", LoanType: pb.LoanType_LOAN_TYPE_MORTGAGE, Principal: 100, AnnualRate: 3.0, TotalMonths: 12, RepaymentMethod: pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT, PaymentDay: 15, StartDate: timestamppb.Now()}},
		{"unspecified loan type", &pb.CreateLoanRequest{Name: "test", LoanType: pb.LoanType_LOAN_TYPE_UNSPECIFIED, Principal: 100, AnnualRate: 3.0, TotalMonths: 12, RepaymentMethod: pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT, PaymentDay: 15, StartDate: timestamppb.Now()}},
		{"zero principal", &pb.CreateLoanRequest{Name: "test", LoanType: pb.LoanType_LOAN_TYPE_MORTGAGE, Principal: 0, AnnualRate: 3.0, TotalMonths: 12, RepaymentMethod: pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT, PaymentDay: 15, StartDate: timestamppb.Now()}},
		{"negative rate", &pb.CreateLoanRequest{Name: "test", LoanType: pb.LoanType_LOAN_TYPE_MORTGAGE, Principal: 100, AnnualRate: -1, TotalMonths: 12, RepaymentMethod: pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT, PaymentDay: 15, StartDate: timestamppb.Now()}},
		{"zero months", &pb.CreateLoanRequest{Name: "test", LoanType: pb.LoanType_LOAN_TYPE_MORTGAGE, Principal: 100, AnnualRate: 3.0, TotalMonths: 0, RepaymentMethod: pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT, PaymentDay: 15, StartDate: timestamppb.Now()}},
		{"unspecified method", &pb.CreateLoanRequest{Name: "test", LoanType: pb.LoanType_LOAN_TYPE_MORTGAGE, Principal: 100, AnnualRate: 3.0, TotalMonths: 12, RepaymentMethod: pb.RepaymentMethod_REPAYMENT_METHOD_UNSPECIFIED, PaymentDay: 15, StartDate: timestamppb.Now()}},
		{"payment day 0", &pb.CreateLoanRequest{Name: "test", LoanType: pb.LoanType_LOAN_TYPE_MORTGAGE, Principal: 100, AnnualRate: 3.0, TotalMonths: 12, RepaymentMethod: pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT, PaymentDay: 0, StartDate: timestamppb.Now()}},
		{"payment day 29", &pb.CreateLoanRequest{Name: "test", LoanType: pb.LoanType_LOAN_TYPE_MORTGAGE, Principal: 100, AnnualRate: 3.0, TotalMonths: 12, RepaymentMethod: pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT, PaymentDay: 29, StartDate: timestamppb.Now()}},
		{"nil start date", &pb.CreateLoanRequest{Name: "test", LoanType: pb.LoanType_LOAN_TYPE_MORTGAGE, Principal: 100, AnnualRate: 3.0, TotalMonths: 12, RepaymentMethod: pb.RepaymentMethod_REPAYMENT_METHOD_EQUAL_INSTALLMENT, PaymentDay: 15, StartDate: nil}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validateCreateLoanRequest(tt.req)
			assert.Error(t, err)
			assert.Equal(t, codes.InvalidArgument, status.Code(err))
		})
	}
}
