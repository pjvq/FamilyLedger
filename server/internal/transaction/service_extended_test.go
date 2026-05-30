package transaction

import (
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	pgxmock "github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	pb "github.com/familyledger/server/proto/transaction"
)

// ─── CreateTransaction: validation edge cases ────────────────────────────────

func TestCreateTransaction_ZeroAmount(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	accountID := uuid.New()
	categoryID := uuid.New()

	mock.ExpectQuery(`SELECT family_id::text, user_id FROM accounts WHERE id = \$1 AND deleted_at IS NULL`).
		WithArgs(accountID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(nil, uuid.MustParse(testUserID)))

	_, err = svc.CreateTransaction(authedCtx(), &pb.CreateTransactionRequest{
		AccountId:  accountID.String(),
		CategoryId: categoryID.String(),
		Amount:     0, // invalid
		Currency:   "CNY",
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
	assert.Contains(t, status.Convert(err).Message(), "amount must be positive")
}

func TestCreateTransaction_NegativeAmount(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	accountID := uuid.New()
	categoryID := uuid.New()

	mock.ExpectQuery(`SELECT family_id::text, user_id FROM accounts WHERE id = \$1 AND deleted_at IS NULL`).
		WithArgs(accountID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(nil, uuid.MustParse(testUserID)))

	_, err = svc.CreateTransaction(authedCtx(), &pb.CreateTransactionRequest{
		AccountId:  accountID.String(),
		CategoryId: categoryID.String(),
		Amount:     -100,
		Currency:   "CNY",
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestCreateTransaction_ForeignCurrency_MissingAmountCny(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	accountID := uuid.New()
	categoryID := uuid.New()

	mock.ExpectQuery(`SELECT family_id::text, user_id FROM accounts WHERE id = \$1 AND deleted_at IS NULL`).
		WithArgs(accountID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(nil, uuid.MustParse(testUserID)))

	_, err = svc.CreateTransaction(authedCtx(), &pb.CreateTransactionRequest{
		AccountId:  accountID.String(),
		CategoryId: categoryID.String(),
		Amount:     100,
		Currency:   "USD",
		AmountCny:  0, // required for non-CNY
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
	assert.Contains(t, status.Convert(err).Message(), "amount_cny")
}

func TestCreateTransaction_InvalidAccountId(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.CreateTransaction(authedCtx(), &pb.CreateTransactionRequest{
		AccountId:  "not-a-uuid",
		CategoryId: uuid.New().String(),
		Amount:     100,
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestCreateTransaction_InvalidCategoryId(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.CreateTransaction(authedCtx(), &pb.CreateTransactionRequest{
		AccountId:  uuid.New().String(),
		CategoryId: "bad-uuid",
		Amount:     100,
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestCreateTransaction_DBBeginFailure(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	accountID := uuid.New()
	categoryID := uuid.New()

	mock.ExpectQuery(`SELECT family_id::text, user_id FROM accounts WHERE id = \$1 AND deleted_at IS NULL`).
		WithArgs(accountID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(nil, uuid.MustParse(testUserID)))

	mock.ExpectBegin().WillReturnError(assert.AnError)

	_, err = svc.CreateTransaction(authedCtx(), &pb.CreateTransactionRequest{
		AccountId:  accountID.String(),
		CategoryId: categoryID.String(),
		Amount:     100,
		Currency:   "CNY",
		TxnDate:    timestamppb.Now(),
	})

	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

// ─── BatchDeleteTransactions ─────────────────────────────────────────────────

func TestBatchDeleteTransactions_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.BatchDeleteTransactions(noAuthCtx(), &pb.BatchDeleteTransactionsRequest{
		TransactionIds: []string{uuid.New().String()},
	})

	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestBatchDeleteTransactions_EmptyList(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.BatchDeleteTransactions(authedCtx(), &pb.BatchDeleteTransactionsRequest{
		TransactionIds: []string{},
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBatchDeleteTransactions_TooMany(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	ids := make([]string, 101)
	for i := range ids {
		ids[i] = uuid.New().String()
	}

	_, err = svc.BatchDeleteTransactions(authedCtx(), &pb.BatchDeleteTransactionsRequest{
		TransactionIds: ids,
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
	assert.Contains(t, status.Convert(err).Message(), "max 100")
}

func TestBatchDeleteTransactions_InvalidId(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.BatchDeleteTransactions(authedCtx(), &pb.BatchDeleteTransactionsRequest{
		TransactionIds: []string{"valid-" + uuid.New().String(), "not-a-uuid"},
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── GetCategories ───────────────────────────────────────────────────────────

func TestGetCategories_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	catID := uuid.New()

	mock.ExpectQuery(`SELECT id, name, icon, type, is_preset, sort_order`).
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{
			"id", "name", "icon", "type", "is_preset", "sort_order", "parent_id", "icon_key",
		}).AddRow(catID, "餐饮", "food", "expense", true, 1, "", "food"))

	resp, err := svc.GetCategories(authedCtx(), &pb.GetCategoriesRequest{})

	require.NoError(t, err)
	assert.Len(t, resp.Categories, 1)
	assert.Equal(t, "餐饮", resp.Categories[0].Name)
}

func TestGetCategories_DBFailure(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	mock.ExpectQuery(`SELECT id, name, icon, type, is_preset, sort_order`).
		WithArgs(testUserID).
		WillReturnError(assert.AnError)

	_, err = svc.GetCategories(authedCtx(), &pb.GetCategoriesRequest{})

	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

// ─── CreateCategory ──────────────────────────────────────────────────────────

func TestCreateCategory_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.CreateCategory(noAuthCtx(), &pb.CreateCategoryRequest{
		Name: "Test",
		Type: pb.TransactionType_TRANSACTION_TYPE_EXPENSE,
	})

	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestCreateCategory_EmptyName(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.CreateCategory(authedCtx(), &pb.CreateCategoryRequest{
		Name: "",
		Type: pb.TransactionType_TRANSACTION_TYPE_EXPENSE,
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── DeleteCategory ──────────────────────────────────────────────────────────

func TestDeleteCategory_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.DeleteCategory(noAuthCtx(), &pb.DeleteCategoryRequest{
		CategoryId: uuid.New().String(),
	})

	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestDeleteCategory_InvalidId(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.DeleteCategory(authedCtx(), &pb.DeleteCategoryRequest{
		CategoryId: "not-uuid",
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── ListTransactions: edge cases ────────────────────────────────────────────

func TestListTransactions_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.ListTransactions(noAuthCtx(), &pb.ListTransactionsRequest{
		AccountId: uuid.New().String(),
	})

	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestListTransactions_InvalidAccountId(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.ListTransactions(authedCtx(), &pb.ListTransactionsRequest{
		AccountId: "bad-uuid",
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── MergeCategories ─────────────────────────────────────────────────────────

func TestMergeCategories_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.MergeCategories(noAuthCtx(), &pb.MergeCategoriesRequest{
		SourceCategoryId: "11111111-1111-1111-1111-111111111111",
		TargetCategoryId: "22222222-2222-2222-2222-222222222222",
	})

	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestMergeCategories_InvalidSourceId(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.MergeCategories(authedCtx(), &pb.MergeCategoriesRequest{
		SourceCategoryId: "not-a-uuid",
		TargetCategoryId: "22222222-2222-2222-2222-222222222222",
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestMergeCategories_InvalidTargetId(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.MergeCategories(authedCtx(), &pb.MergeCategoriesRequest{
		SourceCategoryId: "11111111-1111-1111-1111-111111111111",
		TargetCategoryId: "bad-uuid",
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestMergeCategories_SameId(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.MergeCategories(authedCtx(), &pb.MergeCategoriesRequest{
		SourceCategoryId: "11111111-1111-1111-1111-111111111111",
		TargetCategoryId: "11111111-1111-1111-1111-111111111111",
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestMergeCategories_SourceNotFound(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT user_id, type FROM categories").
		WithArgs(pgxmock.AnyArg()).
		WillReturnError(pgx.ErrNoRows)
	mock.ExpectRollback()

	_, err = svc.MergeCategories(authedCtx(), &pb.MergeCategoriesRequest{
		SourceCategoryId: "11111111-1111-1111-1111-111111111111",
		TargetCategoryId: "22222222-2222-2222-2222-222222222222",
	})

	require.Error(t, err)
	assert.Equal(t, codes.NotFound, status.Code(err))
}

func TestMergeCategories_TypeMismatch(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	sourceID := "11111111-1111-1111-1111-111111111111"
	targetID := "22222222-2222-2222-2222-222222222222"

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT user_id, type FROM categories").
		WithArgs(pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "type"}).
			AddRow(testUserID, "expense"))
	mock.ExpectQuery("SELECT user_id, type FROM categories").
		WithArgs(pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "type"}).
			AddRow(testUserID, "income"))
	mock.ExpectRollback()

	_, err = svc.MergeCategories(authedCtx(), &pb.MergeCategoriesRequest{
		SourceCategoryId: sourceID,
		TargetCategoryId: targetID,
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestMergeCategories_PermissionDenied(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	sourceID := "11111111-1111-1111-1111-111111111111"
	targetID := "22222222-2222-2222-2222-222222222222"

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT user_id, type FROM categories").
		WithArgs(pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "type"}).
			AddRow("other-user-id", "expense"))
	mock.ExpectQuery("SELECT user_id, type FROM categories").
		WithArgs(pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "type"}).
			AddRow(testUserID, "expense"))
	mock.ExpectRollback()

	_, err = svc.MergeCategories(authedCtx(), &pb.MergeCategoriesRequest{
		SourceCategoryId: sourceID,
		TargetCategoryId: targetID,
	})

	require.Error(t, err)
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

func TestMergeCategories_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	sourceID := "11111111-1111-1111-1111-111111111111"
	targetID := "22222222-2222-2222-2222-222222222222"

	mock.ExpectBegin()
	// Verify source
	mock.ExpectQuery("SELECT user_id, type FROM categories").
		WithArgs(pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "type"}).
			AddRow(testUserID, "expense"))
	// Verify target
	mock.ExpectQuery("SELECT user_id, type FROM categories").
		WithArgs(pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "type"}).
			AddRow(testUserID, "expense"))
	// Remap transactions
	mock.ExpectExec("UPDATE transactions SET category_id").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("UPDATE", 5))
	// Reparent children
	mock.ExpectExec("UPDATE categories SET parent_id").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("UPDATE", 0))
	// Remap budgets
	mock.ExpectExec("UPDATE category_budgets SET category_id").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("UPDATE", 0))
	// Delete orphan budgets
	mock.ExpectExec("DELETE FROM category_budgets").
		WithArgs(pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))
	// Soft delete source
	mock.ExpectExec("UPDATE categories SET deleted_at").
		WithArgs(pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectCommit()

	resp, err := svc.MergeCategories(authedCtx(), &pb.MergeCategoriesRequest{
		SourceCategoryId: sourceID,
		TargetCategoryId: targetID,
	})

	require.NoError(t, err)
	assert.Equal(t, int32(5), resp.AffectedTransactions)
	assert.NoError(t, mock.ExpectationsWereMet())
}
