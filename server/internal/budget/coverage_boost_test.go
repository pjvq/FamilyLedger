package budget

import (
	"context"
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

	pb "github.com/familyledger/server/proto/budget"
)

// ═══════════════════════════════════════════════════════════════════════════
// CreateBudget — additional branches
// ═══════════════════════════════════════════════════════════════════════════

func TestCB_CreateBudget_InvalidYear(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	_, err := svc.CreateBudget(authedCtx(), &pb.CreateBudgetRequest{
		Month: 1, Year: 1999, TotalAmount: 1000,
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestCB_CreateBudget_InvalidFamilyID(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	_, err := svc.CreateBudget(authedCtx(), &pb.CreateBudgetRequest{
		Month: 1, Year: 2025, TotalAmount: 1000, FamilyId: "not-uuid",
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestCB_CreateBudget_PermDenied(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	fid := uuid.New()
	// permission.Check fails
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnError(pgx.ErrNoRows)
	_, err := svc.CreateBudget(authedCtx(), &pb.CreateBudgetRequest{
		Month: 1, Year: 2025, TotalAmount: 1000, FamilyId: fid.String(),
	})
	assert.Error(t, err)
}

func TestCB_CreateBudget_BeginFail(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	// personal mode: permission.Check with empty familyId should be a no-op or succeed
	// Actually need to mock the permission check
	mock.ExpectBegin().WillReturnError(errors.New("conn fail"))
	_, err := svc.CreateBudget(authedCtx(), &pb.CreateBudgetRequest{
		Month: 1, Year: 2025, TotalAmount: 1000,
	})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_CreateBudget_InsertError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectBegin()
	mock.ExpectQuery("INSERT INTO budgets").
		WithArgs(testUserUUID, (*uuid.UUID)(nil), int32(2025), int32(1), int64(1000)).
		WillReturnError(errors.New("db error"))
	mock.ExpectRollback()
	_, err := svc.CreateBudget(authedCtx(), &pb.CreateBudgetRequest{
		Month: 1, Year: 2025, TotalAmount: 1000,
	})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_CreateBudget_CategoryInvalidID(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	budgetID := uuid.New()
	now := time.Now()
	mock.ExpectBegin()
	mock.ExpectQuery("INSERT INTO budgets").
		WithArgs(testUserUUID, (*uuid.UUID)(nil), int32(2025), int32(1), int64(1000)).
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at"}).AddRow(budgetID, now))
	mock.ExpectExec("DELETE FROM category_budgets").
		WithArgs(budgetID).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))
	// Invalid category ID
	_, err := svc.CreateBudget(authedCtx(), &pb.CreateBudgetRequest{
		Month: 1, Year: 2025, TotalAmount: 1000,
		CategoryBudgets: []*pb.CategoryBudget{{CategoryId: "not-uuid", Amount: 500}},
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestCB_CreateBudget_CategoryInsertError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	budgetID := uuid.New()
	catID := uuid.New()
	now := time.Now()
	mock.ExpectBegin()
	mock.ExpectQuery("INSERT INTO budgets").
		WithArgs(testUserUUID, (*uuid.UUID)(nil), int32(2025), int32(1), int64(1000)).
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at"}).AddRow(budgetID, now))
	mock.ExpectExec("DELETE FROM category_budgets").
		WithArgs(budgetID).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))
	mock.ExpectExec("INSERT INTO category_budgets").
		WithArgs(budgetID, catID, int64(500)).
		WillReturnError(errors.New("insert fail"))
	mock.ExpectRollback()
	_, err := svc.CreateBudget(authedCtx(), &pb.CreateBudgetRequest{
		Month: 1, Year: 2025, TotalAmount: 1000,
		CategoryBudgets: []*pb.CategoryBudget{{CategoryId: catID.String(), Amount: 500}},
	})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_CreateBudget_CommitFail(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	budgetID := uuid.New()
	now := time.Now()
	mock.ExpectBegin()
	mock.ExpectQuery("INSERT INTO budgets").
		WithArgs(testUserUUID, (*uuid.UUID)(nil), int32(2025), int32(1), int64(1000)).
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at"}).AddRow(budgetID, now))
	mock.ExpectExec("DELETE FROM category_budgets").
		WithArgs(budgetID).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))
	mock.ExpectCommit().WillReturnError(errors.New("commit fail"))
	mock.ExpectRollback()
	_, err := svc.CreateBudget(authedCtx(), &pb.CreateBudgetRequest{
		Month: 1, Year: 2025, TotalAmount: 1000,
	})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_CreateBudget_NoAuth(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	_, err := svc.CreateBudget(context.Background(), &pb.CreateBudgetRequest{})
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

// ═══════════════════════════════════════════════════════════════════════════
// GetBudget — additional branches
// ═══════════════════════════════════════════════════════════════════════════

func TestCB_GetBudget_NoAuth(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	_, err := svc.GetBudget(context.Background(), &pb.GetBudgetRequest{BudgetId: uuid.New().String()})
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestCB_GetBudget_InvalidID(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	_, err := svc.GetBudget(authedCtx(), &pb.GetBudgetRequest{BudgetId: "not-uuid"})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestCB_GetBudget_QueryError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	bid := uuid.New()
	mock.ExpectQuery("SELECT user_id, family_id, year, month").
		WithArgs(bid).WillReturnError(errors.New("db err"))
	_, err := svc.GetBudget(authedCtx(), &pb.GetBudgetRequest{BudgetId: bid.String()})
	assert.Equal(t, codes.Internal, status.Code(err))
}

// ═══════════════════════════════════════════════════════════════════════════
// ListBudgets — additional branches
// ═══════════════════════════════════════════════════════════════════════════

func TestCB_ListBudgets_NoAuth(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	_, err := svc.ListBudgets(context.Background(), &pb.ListBudgetsRequest{})
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestCB_ListBudgets_InvalidFamilyID(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	_, err := svc.ListBudgets(authedCtx(), &pb.ListBudgetsRequest{FamilyId: "not-uuid"})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestCB_ListBudgets_FamilyNotMember(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	fid := uuid.New()
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(fid, testUserUUID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(false))
	_, err := svc.ListBudgets(authedCtx(), &pb.ListBudgetsRequest{FamilyId: fid.String()})
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

func TestCB_ListBudgets_FamilyMemberQueryErr(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	fid := uuid.New()
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(fid, testUserUUID).
		WillReturnError(errors.New("db fail"))
	_, err := svc.ListBudgets(authedCtx(), &pb.ListBudgetsRequest{FamilyId: fid.String()})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_ListBudgets_FamilyMode_Success(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	fid := uuid.New()
	bid := uuid.New()
	now := time.Now()

	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(fid, testUserUUID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))
	budgetCols := []string{"id", "user_id", "family_id", "year", "month", "total_amount", "created_at"}
	mock.ExpectQuery("SELECT b.id").
		WithArgs(fid, int32(0)).
		WillReturnRows(pgxmock.NewRows(budgetCols).AddRow(
			bid, testUserUUID, &fid, int32(2025), int32(1), int64(5000), now,
		))
	// loadCategoryBudgets
	mock.ExpectQuery("SELECT category_id, amount FROM category_budgets").
		WithArgs(bid).
		WillReturnRows(pgxmock.NewRows([]string{"category_id", "amount"}))

	resp, err := svc.ListBudgets(authedCtx(), &pb.ListBudgetsRequest{FamilyId: fid.String()})
	require.NoError(t, err)
	assert.Len(t, resp.Budgets, 1)
	assert.Equal(t, fid.String(), resp.Budgets[0].FamilyId)
}

func TestCB_ListBudgets_QueryError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectQuery("SELECT b.id").
		WithArgs(testUserUUID, int32(0)).
		WillReturnError(errors.New("query fail"))
	_, err := svc.ListBudgets(authedCtx(), &pb.ListBudgetsRequest{})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_ListBudgets_ScanError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	budgetCols := []string{"id", "user_id", "family_id", "year", "month", "total_amount", "created_at"}
	mock.ExpectQuery("SELECT b.id").
		WithArgs(testUserUUID, int32(0)).
		WillReturnRows(pgxmock.NewRows(budgetCols).AddRow(
			"not-uuid", testUserUUID, (*uuid.UUID)(nil), int32(2025), int32(1), int64(5000), time.Now(),
		))
	_, err := svc.ListBudgets(authedCtx(), &pb.ListBudgetsRequest{})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_ListBudgets_CategoryLoadError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	bid := uuid.New()
	now := time.Now()
	budgetCols := []string{"id", "user_id", "family_id", "year", "month", "total_amount", "created_at"}
	mock.ExpectQuery("SELECT b.id").
		WithArgs(testUserUUID, int32(0)).
		WillReturnRows(pgxmock.NewRows(budgetCols).AddRow(
			bid, testUserUUID, (*uuid.UUID)(nil), int32(2025), int32(1), int64(5000), now,
		))
	mock.ExpectQuery("SELECT category_id, amount FROM category_budgets").
		WithArgs(bid).
		WillReturnError(errors.New("cat query fail"))
	_, err := svc.ListBudgets(authedCtx(), &pb.ListBudgetsRequest{})
	assert.Equal(t, codes.Internal, status.Code(err))
}

// ═══════════════════════════════════════════════════════════════════════════
// UpdateBudget — additional branches
// ═══════════════════════════════════════════════════════════════════════════

func TestCB_UpdateBudget_InvalidID(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	_, err := svc.UpdateBudget(authedCtx(), &pb.UpdateBudgetRequest{BudgetId: "not-uuid"})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestCB_UpdateBudget_QueryError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	bid := uuid.New()
	mock.ExpectQuery("SELECT user_id, family_id FROM budgets").
		WithArgs(bid).WillReturnError(errors.New("db err"))
	_, err := svc.UpdateBudget(authedCtx(), &pb.UpdateBudgetRequest{BudgetId: bid.String()})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_UpdateBudget_NotOwner_NoFamily(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	bid := uuid.New()
	mock.ExpectQuery("SELECT user_id, family_id FROM budgets").
		WithArgs(bid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow("other", (*string)(nil)))
	_, err := svc.UpdateBudget(authedCtx(), &pb.UpdateBudgetRequest{BudgetId: bid.String()})
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

func TestCB_UpdateBudget_NotOwner_FamilyPerm(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	bid := uuid.New()
	fid := uuid.New().String()
	mock.ExpectQuery("SELECT user_id, family_id FROM budgets").
		WithArgs(bid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow("other", &fid))
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).AddRow("owner", []byte(`{}`)))
	// begin
	mock.ExpectBegin()
	mock.ExpectExec("UPDATE budgets SET total_amount").
		WithArgs(int64(2000), bid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectCommit()
	// loadBudget
	now := time.Now()
	famUID := uuid.MustParse(fid)
	mock.ExpectQuery("SELECT user_id, family_id, year, month").
		WithArgs(bid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id", "year", "month", "total_amount", "created_at"}).
			AddRow(uuid.MustParse("b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22"), &famUID, int32(2025), int32(1), int64(2000), now))
	// perm check in loadBudget
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).AddRow("owner", []byte(`{}`)))
	// loadCategoryBudgets
	mock.ExpectQuery("SELECT category_id, amount FROM category_budgets").
		WithArgs(bid).
		WillReturnRows(pgxmock.NewRows([]string{"category_id", "amount"}))

	resp, err := svc.UpdateBudget(authedCtx(), &pb.UpdateBudgetRequest{
		BudgetId: bid.String(), TotalAmount: 2000,
	})
	require.NoError(t, err)
	assert.Equal(t, int64(2000), resp.Budget.TotalAmount)
}

func TestCB_UpdateBudget_BeginFail(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	bid := uuid.New()
	mock.ExpectQuery("SELECT user_id, family_id FROM budgets").
		WithArgs(bid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(testUserID, (*string)(nil)))
	mock.ExpectBegin().WillReturnError(errors.New("conn fail"))
	_, err := svc.UpdateBudget(authedCtx(), &pb.UpdateBudgetRequest{BudgetId: bid.String()})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_UpdateBudget_UpdateExecError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	bid := uuid.New()
	mock.ExpectQuery("SELECT user_id, family_id FROM budgets").
		WithArgs(bid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(testUserID, (*string)(nil)))
	mock.ExpectBegin()
	mock.ExpectExec("UPDATE budgets SET total_amount").
		WithArgs(int64(2000), bid).
		WillReturnError(errors.New("exec fail"))
	mock.ExpectRollback()
	_, err := svc.UpdateBudget(authedCtx(), &pb.UpdateBudgetRequest{
		BudgetId: bid.String(), TotalAmount: 2000,
	})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_UpdateBudget_CategoryDeleteError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	bid := uuid.New()
	catID := uuid.New()
	mock.ExpectQuery("SELECT user_id, family_id FROM budgets").
		WithArgs(bid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(testUserID, (*string)(nil)))
	mock.ExpectBegin()
	mock.ExpectExec("DELETE FROM category_budgets").
		WithArgs(bid).
		WillReturnError(errors.New("delete fail"))
	mock.ExpectRollback()
	_, err := svc.UpdateBudget(authedCtx(), &pb.UpdateBudgetRequest{
		BudgetId: bid.String(),
		CategoryBudgets: []*pb.CategoryBudget{{CategoryId: catID.String(), Amount: 500}},
	})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_UpdateBudget_CategoryInvalidID(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	bid := uuid.New()
	mock.ExpectQuery("SELECT user_id, family_id FROM budgets").
		WithArgs(bid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(testUserID, (*string)(nil)))
	mock.ExpectBegin()
	mock.ExpectExec("DELETE FROM category_budgets").
		WithArgs(bid).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))
	_, err := svc.UpdateBudget(authedCtx(), &pb.UpdateBudgetRequest{
		BudgetId: bid.String(),
		CategoryBudgets: []*pb.CategoryBudget{{CategoryId: "not-uuid", Amount: 500}},
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestCB_UpdateBudget_CategoryInsertError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	bid := uuid.New()
	catID := uuid.New()
	mock.ExpectQuery("SELECT user_id, family_id FROM budgets").
		WithArgs(bid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(testUserID, (*string)(nil)))
	mock.ExpectBegin()
	mock.ExpectExec("DELETE FROM category_budgets").
		WithArgs(bid).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))
	mock.ExpectExec("INSERT INTO category_budgets").
		WithArgs(bid, catID, int64(500)).
		WillReturnError(errors.New("insert fail"))
	mock.ExpectRollback()
	_, err := svc.UpdateBudget(authedCtx(), &pb.UpdateBudgetRequest{
		BudgetId: bid.String(),
		CategoryBudgets: []*pb.CategoryBudget{{CategoryId: catID.String(), Amount: 500}},
	})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_UpdateBudget_CommitFail(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	bid := uuid.New()
	mock.ExpectQuery("SELECT user_id, family_id FROM budgets").
		WithArgs(bid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(testUserID, (*string)(nil)))
	mock.ExpectBegin()
	mock.ExpectExec("UPDATE budgets SET total_amount").
		WithArgs(int64(2000), bid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectCommit().WillReturnError(errors.New("commit fail"))
	mock.ExpectRollback()
	_, err := svc.UpdateBudget(authedCtx(), &pb.UpdateBudgetRequest{
		BudgetId: bid.String(), TotalAmount: 2000,
	})
	assert.Equal(t, codes.Internal, status.Code(err))
}

// ═══════════════════════════════════════════════════════════════════════════
// DeleteBudget — additional branches
// ═══════════════════════════════════════════════════════════════════════════

func TestCB_DeleteBudget_QueryError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	bid := uuid.New()
	mock.ExpectQuery("SELECT user_id, family_id FROM budgets").
		WithArgs(bid).WillReturnError(errors.New("db err"))
	_, err := svc.DeleteBudget(authedCtx(), &pb.DeleteBudgetRequest{BudgetId: bid.String()})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_DeleteBudget_NotOwner_NoFamily(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	bid := uuid.New()
	mock.ExpectQuery("SELECT user_id, family_id FROM budgets").
		WithArgs(bid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow("other", (*string)(nil)))
	_, err := svc.DeleteBudget(authedCtx(), &pb.DeleteBudgetRequest{BudgetId: bid.String()})
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

func TestCB_DeleteBudget_NotOwner_FamilyPerm(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	bid := uuid.New()
	fid := uuid.New().String()
	mock.ExpectQuery("SELECT user_id, family_id FROM budgets").
		WithArgs(bid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow("other", &fid))
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).AddRow("owner", []byte(`{}`)))
	mock.ExpectExec("DELETE FROM budgets").
		WithArgs(bid).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))
	resp, err := svc.DeleteBudget(authedCtx(), &pb.DeleteBudgetRequest{BudgetId: bid.String()})
	require.NoError(t, err)
	assert.NotNil(t, resp)
}

func TestCB_DeleteBudget_ExecError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	bid := uuid.New()
	mock.ExpectQuery("SELECT user_id, family_id FROM budgets").
		WithArgs(bid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(testUserID, (*string)(nil)))
	mock.ExpectExec("DELETE FROM budgets").
		WithArgs(bid).
		WillReturnError(errors.New("exec fail"))
	_, err := svc.DeleteBudget(authedCtx(), &pb.DeleteBudgetRequest{BudgetId: bid.String()})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_DeleteBudget_ZeroRows(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	bid := uuid.New()
	mock.ExpectQuery("SELECT user_id, family_id FROM budgets").
		WithArgs(bid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(testUserID, (*string)(nil)))
	mock.ExpectExec("DELETE FROM budgets").
		WithArgs(bid).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))
	_, err := svc.DeleteBudget(authedCtx(), &pb.DeleteBudgetRequest{BudgetId: bid.String()})
	assert.Equal(t, codes.NotFound, status.Code(err))
}

// ═══════════════════════════════════════════════════════════════════════════
// loadBudget — additional branches
// ═══════════════════════════════════════════════════════════════════════════

func TestCB_LoadBudget_NotOwner_NoFamily(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	bid := uuid.New()
	now := time.Now()
	mock.ExpectQuery("SELECT user_id, family_id, year, month").
		WithArgs(bid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id", "year", "month", "total_amount", "created_at"}).
			AddRow(uuid.MustParse("b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22"), (*uuid.UUID)(nil), int32(2025), int32(1), int64(1000), now))
	_, err := svc.loadBudget(authedCtx(), bid, testUserID)
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

func TestCB_LoadBudget_NotOwner_FamilyPerm(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	bid := uuid.New()
	fid := uuid.New()
	now := time.Now()
	mock.ExpectQuery("SELECT user_id, family_id, year, month").
		WithArgs(bid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id", "year", "month", "total_amount", "created_at"}).
			AddRow(uuid.MustParse("b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22"), &fid, int32(2025), int32(1), int64(1000), now))
	// permission.Check
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).AddRow("owner", []byte(`{}`)))
	// loadCategoryBudgets
	mock.ExpectQuery("SELECT category_id, amount FROM category_budgets").
		WithArgs(bid).
		WillReturnRows(pgxmock.NewRows([]string{"category_id", "amount"}))

	budget, err := svc.loadBudget(authedCtx(), bid, testUserID)
	require.NoError(t, err)
	assert.Equal(t, fid.String(), budget.FamilyId)
}

func TestCB_LoadBudget_CategoryQueryError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	bid := uuid.New()
	now := time.Now()
	mock.ExpectQuery("SELECT user_id, family_id, year, month").
		WithArgs(bid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id", "year", "month", "total_amount", "created_at"}).
			AddRow(testUserUUID, (*uuid.UUID)(nil), int32(2025), int32(1), int64(1000), now))
	mock.ExpectQuery("SELECT category_id, amount FROM category_budgets").
		WithArgs(bid).
		WillReturnError(errors.New("cat query fail"))
	_, err := svc.loadBudget(authedCtx(), bid, testUserID)
	assert.Equal(t, codes.Internal, status.Code(err))
}

// ═══════════════════════════════════════════════════════════════════════════
// GetBudgetExecution — additional branches
// ═══════════════════════════════════════════════════════════════════════════

func TestCB_GetBudgetExecution_NoAuth(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	_, err := svc.GetBudgetExecution(context.Background(), &pb.GetBudgetExecutionRequest{BudgetId: uuid.New().String()})
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestCB_ListBudgets_WithYear(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	bid := uuid.New()
	now := time.Now()

	budgetCols := []string{"id", "user_id", "family_id", "year", "month", "total_amount", "created_at"}
	mock.ExpectQuery("SELECT b.id").
		WithArgs(testUserUUID, int32(2025)).
		WillReturnRows(pgxmock.NewRows(budgetCols).AddRow(
			bid, testUserUUID, (*uuid.UUID)(nil), int32(2025), int32(3), int64(5000), now,
		))
	mock.ExpectQuery("SELECT category_id, amount FROM category_budgets").
		WithArgs(bid).
		WillReturnRows(pgxmock.NewRows([]string{"category_id", "amount"}))

	resp, err := svc.ListBudgets(authedCtx(), &pb.ListBudgetsRequest{Year: 2025})
	require.NoError(t, err)
	assert.Len(t, resp.Budgets, 1)
}
