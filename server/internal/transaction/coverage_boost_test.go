package transaction

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	pgxmock "github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/familyledger/server/pkg/storage"
	pb "github.com/familyledger/server/proto/transaction"
)

// ── helpers ─────────────────────────────────────────────────────────────────

func svcWithMock(t *testing.T) (*Service, pgxmock.PgxPoolIface) {
	t.Helper()
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	t.Cleanup(func() { mock.Close() })
	svc := NewService(mock, WithFileStorage(storage.NewLocalFileStorage(t.TempDir(), "/uploads")))
	return svc, mock
}

var userUID = uuid.MustParse(testUserID)

// ── validateImageMagic ──────────────────────────────────────────────────────

func TestValidateImageMagic_JPEG(t *testing.T) {
	assert.True(t, validateImageMagic([]byte{0xFF, 0xD8, 0xFF, 0xE0}, "image/jpeg"))
}

func TestValidateImageMagic_PNG(t *testing.T) {
	assert.True(t, validateImageMagic([]byte{0x89, 0x50, 0x4E, 0x47, 0x0D}, "image/png"))
}

func TestValidateImageMagic_WebP(t *testing.T) {
	assert.True(t, validateImageMagic([]byte{0x52, 0x49, 0x46, 0x46, 0x00}, "image/webp"))
}

func TestValidateImageMagic_HEIC(t *testing.T) {
	assert.True(t, validateImageMagic([]byte{0x00, 0x00, 0x00, 0x20}, "image/heic"))
}

func TestValidateImageMagic_Unknown(t *testing.T) {
	assert.False(t, validateImageMagic([]byte{0xFF}, "image/gif"))
}

func TestValidateImageMagic_WrongMagic(t *testing.T) {
	assert.False(t, validateImageMagic([]byte{0x00, 0x00}, "image/jpeg"))
}

func TestValidateImageMagic_TooShort(t *testing.T) {
	assert.False(t, validateImageMagic([]byte{0xFF}, "image/jpeg"))
}

func TestValidateImageMagic_EmptyData(t *testing.T) {
	assert.False(t, validateImageMagic([]byte{}, "image/jpeg"))
}

// ── WithFileStorage ─────────────────────────────────────────────────────────

func TestWithFileStorage(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	fs := storage.NewLocalFileStorage(t.TempDir(), "/test")
	svc := NewService(mock, WithFileStorage(fs))
	assert.NotNil(t, svc.fileStorage)
}

// ── UploadTransactionImage ──────────────────────────────────────────────────

func TestUploadTransactionImage_NoAuth(t *testing.T) {
	svc, _ := svcWithMock(t)
	_, err := svc.UploadTransactionImage(noAuthCtx(), &pb.UploadTransactionImageRequest{Data: []byte{0xFF, 0xD8, 0xFF}})
	assert.Error(t, err)
	st, _ := status.FromError(err)
	assert.Equal(t, codes.Unauthenticated, st.Code())
}

func TestUploadTransactionImage_EmptyData(t *testing.T) {
	svc, _ := svcWithMock(t)
	_, err := svc.UploadTransactionImage(authedCtx(), &pb.UploadTransactionImageRequest{})
	assert.Error(t, err)
	st, _ := status.FromError(err)
	assert.Equal(t, codes.InvalidArgument, st.Code())
}

func TestUploadTransactionImage_TooLarge(t *testing.T) {
	svc, _ := svcWithMock(t)
	data := make([]byte, 6*1024*1024) // 6MB
	_, err := svc.UploadTransactionImage(authedCtx(), &pb.UploadTransactionImageRequest{Data: data})
	assert.Error(t, err)
	st, _ := status.FromError(err)
	assert.Equal(t, codes.InvalidArgument, st.Code())
}

func TestUploadTransactionImage_UnsupportedType(t *testing.T) {
	svc, _ := svcWithMock(t)
	_, err := svc.UploadTransactionImage(authedCtx(), &pb.UploadTransactionImageRequest{
		Data: []byte{0x47, 0x49, 0x46}, ContentType: "image/gif",
	})
	assert.Error(t, err)
	st, _ := status.FromError(err)
	assert.Equal(t, codes.InvalidArgument, st.Code())
}

func TestUploadTransactionImage_MagicMismatch(t *testing.T) {
	svc, _ := svcWithMock(t)
	_, err := svc.UploadTransactionImage(authedCtx(), &pb.UploadTransactionImageRequest{
		Data: []byte{0x00, 0x00, 0x00}, ContentType: "image/jpeg",
	})
	assert.Error(t, err)
	st, _ := status.FromError(err)
	assert.Equal(t, codes.InvalidArgument, st.Code())
}

func TestUploadTransactionImage_Success(t *testing.T) {
	svc, _ := svcWithMock(t)
	// Create the user dir so quota check works
	os.MkdirAll(svc.uploadDir+"/"+testUserID, 0o755)

	resp, err := svc.UploadTransactionImage(authedCtx(), &pb.UploadTransactionImageRequest{
		Data:        []byte{0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10},
		ContentType: "image/jpeg",
	})
	require.NoError(t, err)
	assert.NotEmpty(t, resp.ImageUrl)
}

func TestUploadTransactionImage_WithTransactionID(t *testing.T) {
	svc, mock := svcWithMock(t)
	os.MkdirAll(svc.uploadDir+"/"+testUserID, 0o755)
	txnID := uuid.New()

	mock.ExpectQuery("SELECT user_id FROM transactions WHERE").
		WithArgs(txnID.String()).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}).AddRow(testUserID))
	mock.ExpectExec("UPDATE transactions").
		WithArgs(pgxmock.AnyArg(), txnID.String()).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	resp, err := svc.UploadTransactionImage(authedCtx(), &pb.UploadTransactionImageRequest{
		Data:          []byte{0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10},
		ContentType:   "image/jpeg",
		TransactionId: txnID.String(),
	})
	require.NoError(t, err)
	assert.NotEmpty(t, resp.ImageUrl)
}

func TestUploadTransactionImage_DefaultContentType(t *testing.T) {
	svc, _ := svcWithMock(t)
	os.MkdirAll(svc.uploadDir+"/"+testUserID, 0o755)

	resp, err := svc.UploadTransactionImage(authedCtx(), &pb.UploadTransactionImageRequest{
		Data: []byte{0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10}, // no ContentType → default jpeg
	})
	require.NoError(t, err)
	assert.NotEmpty(t, resp.ImageUrl)
}

// ── UpdateCategory ──────────────────────────────────────────────────────────

func TestUpdateCategory_NoAuth(t *testing.T) {
	svc, _ := svcWithMock(t)
	_, err := svc.UpdateCategory(noAuthCtx(), &pb.UpdateCategoryRequest{CategoryId: uuid.New().String()})
	assert.Error(t, err)
}

func TestUpdateCategory_InvalidID(t *testing.T) {
	svc, _ := svcWithMock(t)
	_, err := svc.UpdateCategory(authedCtx(), &pb.UpdateCategoryRequest{CategoryId: "bad"})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.InvalidArgument, st.Code())
}

func TestUpdateCategory_NothingToUpdate(t *testing.T) {
	svc, _ := svcWithMock(t)
	_, err := svc.UpdateCategory(authedCtx(), &pb.UpdateCategoryRequest{CategoryId: uuid.New().String()})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.InvalidArgument, st.Code())
	assert.Contains(t, st.Message(), "nothing to update")
}

func TestUpdateCategory_NameOnly(t *testing.T) {
	svc, mock := svcWithMock(t)
	catID := uuid.New()
	name := "新名字"
	mock.ExpectQuery("UPDATE categories SET").
		WithArgs(name, catID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "name", "icon", "icon_key", "type", "is_preset", "sort_order", "parent_id"}).
			AddRow(catID, name, "🍔", "food", "expense", false, int32(1), ""))

	resp, err := svc.UpdateCategory(authedCtx(), &pb.UpdateCategoryRequest{
		CategoryId: catID.String(), Name: &name,
	})
	require.NoError(t, err)
	assert.Equal(t, name, resp.Category.Name)
}

func TestUpdateCategory_IconKeyOnly(t *testing.T) {
	svc, mock := svcWithMock(t)
	catID := uuid.New()
	iconKey := "new_icon"
	mock.ExpectQuery("UPDATE categories SET").
		WithArgs(iconKey, catID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "name", "icon", "icon_key", "type", "is_preset", "sort_order", "parent_id"}).
			AddRow(catID, "test", "", iconKey, "income", false, int32(2), ""))

	resp, err := svc.UpdateCategory(authedCtx(), &pb.UpdateCategoryRequest{
		CategoryId: catID.String(), IconKey: &iconKey,
	})
	require.NoError(t, err)
	assert.Equal(t, pb.TransactionType_TRANSACTION_TYPE_INCOME, resp.Category.Type)
}

func TestUpdateCategory_BothFields(t *testing.T) {
	svc, mock := svcWithMock(t)
	catID := uuid.New()
	name := "n"
	iconKey := "ik"
	mock.ExpectQuery("UPDATE categories SET").
		WithArgs(name, iconKey, catID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "name", "icon", "icon_key", "type", "is_preset", "sort_order", "parent_id"}).
			AddRow(catID, name, "", iconKey, "expense", false, int32(1), ""))

	resp, err := svc.UpdateCategory(authedCtx(), &pb.UpdateCategoryRequest{
		CategoryId: catID.String(), Name: &name, IconKey: &iconKey,
	})
	require.NoError(t, err)
	assert.Equal(t, name, resp.Category.Name)
}

func TestUpdateCategory_NotFound(t *testing.T) {
	svc, mock := svcWithMock(t)
	catID := uuid.New()
	name := "x"
	mock.ExpectQuery("UPDATE categories SET").
		WithArgs(name, catID).
		WillReturnError(pgx.ErrNoRows)

	_, err := svc.UpdateCategory(authedCtx(), &pb.UpdateCategoryRequest{
		CategoryId: catID.String(), Name: &name,
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.NotFound, st.Code())
}

// ── CreateCategory ──────────────────────────────────────────────────────────

func TestCreateCategory_EmptyIconKey(t *testing.T) {
	svc, _ := svcWithMock(t)
	_, err := svc.CreateCategory(authedCtx(), &pb.CreateCategoryRequest{Name: "x", Type: pb.TransactionType_TRANSACTION_TYPE_EXPENSE})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.InvalidArgument, st.Code())
}

func TestCreateCategory_UnspecifiedType(t *testing.T) {
	svc, _ := svcWithMock(t)
	_, err := svc.CreateCategory(authedCtx(), &pb.CreateCategoryRequest{Name: "x", IconKey: "y"})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.InvalidArgument, st.Code())
}

func TestCreateCategory_InvalidParentID(t *testing.T) {
	svc, _ := svcWithMock(t)
	_, err := svc.CreateCategory(authedCtx(), &pb.CreateCategoryRequest{
		Name: "x", IconKey: "y", Type: pb.TransactionType_TRANSACTION_TYPE_EXPENSE, ParentId: "bad",
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.InvalidArgument, st.Code())
}

func TestCreateCategory_ParentNotFound(t *testing.T) {
	svc, mock := svcWithMock(t)
	parentID := uuid.New()
	mock.ExpectQuery("SELECT parent_id FROM categories WHERE").
		WithArgs(parentID).
		WillReturnError(pgx.ErrNoRows)

	_, err := svc.CreateCategory(authedCtx(), &pb.CreateCategoryRequest{
		Name: "x", IconKey: "y", Type: pb.TransactionType_TRANSACTION_TYPE_EXPENSE, ParentId: parentID.String(),
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.NotFound, st.Code())
}

func TestCreateCategory_SubSubcategoryBlocked(t *testing.T) {
	svc, mock := svcWithMock(t)
	parentID := uuid.New()
	grandParent := uuid.New()
	mock.ExpectQuery("SELECT parent_id FROM categories WHERE").
		WithArgs(parentID).
		WillReturnRows(pgxmock.NewRows([]string{"parent_id"}).AddRow(&grandParent))

	_, err := svc.CreateCategory(authedCtx(), &pb.CreateCategoryRequest{
		Name: "x", IconKey: "y", Type: pb.TransactionType_TRANSACTION_TYPE_EXPENSE, ParentId: parentID.String(),
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.InvalidArgument, st.Code())
	assert.Contains(t, st.Message(), "sub-subcategory")
}

func TestCreateCategory_RootSuccess(t *testing.T) {
	svc, mock := svcWithMock(t)
	mock.ExpectQuery("SELECT COALESCE.*MAX.*sort_order").
		WithArgs("expense").
		WillReturnRows(pgxmock.NewRows([]string{"max"}).AddRow(int32(5)))
	mock.ExpectExec("INSERT INTO categories").
		WithArgs(pgxmock.AnyArg(), "餐饮", "food", "expense", int32(6), pgxmock.AnyArg(), testUserID).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	resp, err := svc.CreateCategory(authedCtx(), &pb.CreateCategoryRequest{
		Name: "餐饮", IconKey: "food", Type: pb.TransactionType_TRANSACTION_TYPE_EXPENSE,
	})
	require.NoError(t, err)
	assert.Equal(t, "餐饮", resp.Category.Name)
	assert.Equal(t, int32(6), resp.Category.SortOrder)
}

func TestCreateCategory_IncomeType(t *testing.T) {
	svc, mock := svcWithMock(t)
	mock.ExpectQuery("SELECT COALESCE.*MAX.*sort_order").
		WithArgs("income").
		WillReturnRows(pgxmock.NewRows([]string{"max"}).AddRow(int32(0)))
	mock.ExpectExec("INSERT INTO categories").
		WithArgs(pgxmock.AnyArg(), "salary", "money", "income", int32(1), pgxmock.AnyArg(), testUserID).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	resp, err := svc.CreateCategory(authedCtx(), &pb.CreateCategoryRequest{
		Name: "salary", IconKey: "money", Type: pb.TransactionType_TRANSACTION_TYPE_INCOME,
	})
	require.NoError(t, err)
	assert.Equal(t, pb.TransactionType_TRANSACTION_TYPE_INCOME, resp.Category.Type)
}

func TestCreateCategory_WithParent(t *testing.T) {
	svc, mock := svcWithMock(t)
	parentID := uuid.New()
	mock.ExpectQuery("SELECT parent_id FROM categories WHERE").
		WithArgs(parentID).
		WillReturnRows(pgxmock.NewRows([]string{"parent_id"}).AddRow((*uuid.UUID)(nil)))
	mock.ExpectQuery("SELECT COALESCE.*MAX.*sort_order").
		WithArgs(parentID).
		WillReturnRows(pgxmock.NewRows([]string{"max"}).AddRow(int32(3)))
	mock.ExpectExec("INSERT INTO categories").
		WithArgs(pgxmock.AnyArg(), "sub", "sub_icon", "expense", int32(4), pgxmock.AnyArg(), testUserID).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	resp, err := svc.CreateCategory(authedCtx(), &pb.CreateCategoryRequest{
		Name: "sub", IconKey: "sub_icon", Type: pb.TransactionType_TRANSACTION_TYPE_EXPENSE, ParentId: parentID.String(),
	})
	require.NoError(t, err)
	assert.Equal(t, parentID.String(), resp.Category.ParentId)
}

func TestCreateCategory_DBError(t *testing.T) {
	svc, mock := svcWithMock(t)
	mock.ExpectQuery("SELECT COALESCE.*MAX.*sort_order").
		WithArgs("expense").
		WillReturnRows(pgxmock.NewRows([]string{"max"}).AddRow(int32(0)))
	mock.ExpectExec("INSERT INTO categories").
		WithArgs(pgxmock.AnyArg(), "x", "y", "expense", int32(1), pgxmock.AnyArg(), testUserID).
		WillReturnError(fmt.Errorf("dup"))

	_, err := svc.CreateCategory(authedCtx(), &pb.CreateCategoryRequest{
		Name: "x", IconKey: "y", Type: pb.TransactionType_TRANSACTION_TYPE_EXPENSE,
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.Internal, st.Code())
}

// ── DeleteCategory ──────────────────────────────────────────────────────────

func TestDeleteCategory_NotFoundBoost(t *testing.T) {
	svc, mock := svcWithMock(t)
	catID := uuid.New()
	mock.ExpectQuery("SELECT is_preset FROM categories WHERE").
		WithArgs(catID).
		WillReturnError(pgx.ErrNoRows)

	_, err := svc.DeleteCategory(authedCtx(), &pb.DeleteCategoryRequest{CategoryId: catID.String()})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.NotFound, st.Code())
}

func TestDeleteCategory_PresetBlocked(t *testing.T) {
	svc, mock := svcWithMock(t)
	catID := uuid.New()
	mock.ExpectQuery("SELECT is_preset FROM categories WHERE").
		WithArgs(catID).
		WillReturnRows(pgxmock.NewRows([]string{"is_preset"}).AddRow(true))

	_, err := svc.DeleteCategory(authedCtx(), &pb.DeleteCategoryRequest{CategoryId: catID.String()})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.PermissionDenied, st.Code())
}

func TestDeleteCategory_Success(t *testing.T) {
	svc, mock := svcWithMock(t)
	catID := uuid.New()
	mock.ExpectQuery("SELECT is_preset FROM categories WHERE").
		WithArgs(catID).
		WillReturnRows(pgxmock.NewRows([]string{"is_preset"}).AddRow(false))
	mock.ExpectExec("UPDATE categories SET deleted_at").
		WithArgs(catID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 2)) // parent + 1 child

	resp, err := svc.DeleteCategory(authedCtx(), &pb.DeleteCategoryRequest{CategoryId: catID.String()})
	require.NoError(t, err)
	assert.NotNil(t, resp)
}

func TestDeleteCategory_DBError(t *testing.T) {
	svc, mock := svcWithMock(t)
	catID := uuid.New()
	mock.ExpectQuery("SELECT is_preset FROM categories WHERE").
		WithArgs(catID).
		WillReturnRows(pgxmock.NewRows([]string{"is_preset"}).AddRow(false))
	mock.ExpectExec("UPDATE categories SET deleted_at").
		WithArgs(catID).
		WillReturnError(fmt.Errorf("err"))

	_, err := svc.DeleteCategory(authedCtx(), &pb.DeleteCategoryRequest{CategoryId: catID.String()})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.Internal, st.Code())
}

// ── ReorderCategories ───────────────────────────────────────────────────────

func TestReorderCategories_NoAuth(t *testing.T) {
	svc, _ := svcWithMock(t)
	_, err := svc.ReorderCategories(noAuthCtx(), &pb.ReorderCategoriesRequest{})
	assert.Error(t, err)
}

func TestReorderCategories_Empty(t *testing.T) {
	svc, _ := svcWithMock(t)
	resp, err := svc.ReorderCategories(authedCtx(), &pb.ReorderCategoriesRequest{})
	require.NoError(t, err)
	assert.NotNil(t, resp)
}

func TestReorderCategories_Success(t *testing.T) {
	svc, mock := svcWithMock(t)
	cat1 := uuid.New()
	cat2 := uuid.New()

	mock.ExpectBegin()
	mock.ExpectExec("UPDATE categories SET sort_order").
		WithArgs(int32(1), cat1).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectExec("UPDATE categories SET sort_order").
		WithArgs(int32(2), cat2).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectCommit()

	resp, err := svc.ReorderCategories(authedCtx(), &pb.ReorderCategoriesRequest{
		Orders: []*pb.CategoryOrder{
			{CategoryId: cat1.String(), SortOrder: 1},
			{CategoryId: cat2.String(), SortOrder: 2},
		},
	})
	require.NoError(t, err)
	assert.NotNil(t, resp)
}

func TestReorderCategories_InvalidID(t *testing.T) {
	svc, mock := svcWithMock(t)
	cat1 := uuid.New()

	mock.ExpectBegin()
	// bad id → skipped (continue)
	mock.ExpectExec("UPDATE categories SET sort_order").
		WithArgs(int32(2), cat1).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectCommit()

	resp, err := svc.ReorderCategories(authedCtx(), &pb.ReorderCategoriesRequest{
		Orders: []*pb.CategoryOrder{
			{CategoryId: "bad-uuid", SortOrder: 1},
			{CategoryId: cat1.String(), SortOrder: 2},
		},
	})
	require.NoError(t, err)
	assert.NotNil(t, resp)
}

func TestReorderCategories_DBError(t *testing.T) {
	svc, mock := svcWithMock(t)
	cat1 := uuid.New()

	mock.ExpectBegin()
	mock.ExpectExec("UPDATE categories SET sort_order").
		WithArgs(int32(1), cat1).
		WillReturnError(fmt.Errorf("err"))

	_, err := svc.ReorderCategories(authedCtx(), &pb.ReorderCategoriesRequest{
		Orders: []*pb.CategoryOrder{
			{CategoryId: cat1.String(), SortOrder: 1},
		},
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.Internal, st.Code())
}

// ── BatchDeleteTransactions ─────────────────────────────────────────────────

func TestBatchDelete_NoneFound(t *testing.T) {
	svc, mock := svcWithMock(t)
	txnID := uuid.New()

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT id, user_id, account_id, amount_cny, type").
		WithArgs(pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "account_id", "amount_cny", "type"}))
	mock.ExpectRollback()

	resp, err := svc.BatchDeleteTransactions(authedCtx(), &pb.BatchDeleteTransactionsRequest{TransactionIds: []string{txnID.String()}})
	require.NoError(t, err)
	assert.Equal(t, int32(0), resp.DeletedCount)
}

func TestBatchDelete_Success(t *testing.T) {
	svc, mock := svcWithMock(t)
	txnID := uuid.New()
	accID := uuid.New()

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT id, user_id, account_id, amount_cny, type").
		WithArgs(pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "account_id", "amount_cny", "type"}).
			AddRow(txnID, userUID, accID, int64(5000), "expense"))
	mock.ExpectExec("UPDATE transactions SET deleted_at").
		WithArgs(pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectExec("UPDATE accounts SET balance").
		WithArgs(int64(5000), accID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectCommit()

	resp, err := svc.BatchDeleteTransactions(authedCtx(), &pb.BatchDeleteTransactionsRequest{TransactionIds: []string{txnID.String()}})
	require.NoError(t, err)
	assert.Equal(t, int32(1), resp.DeletedCount)
}

// ── listTransactionsIncremental ─────────────────────────────────────────────

func TestListTransactions_Incremental(t *testing.T) {
	svc, mock := svcWithMock(t)
	now := time.Now()
	txnID := uuid.New()
	accID := uuid.New()
	catID := uuid.New()

	// Personal mode, no family
	mock.ExpectQuery("SELECT t.id.*FROM transactions t").
		WithArgs(userUID, pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{
			"id", "user_id", "account_id", "category_id", "amount", "currency",
			"amount_cny", "exchange_rate", "type", "note", "txn_date",
			"created_at", "updated_at", "tags", "image_urls", "deleted_at",
		}).AddRow(
			txnID, userUID, accID, catID, int64(100), "CNY",
			int64(100), 1.0, "expense", "test", now,
			now, now, []string{}, []string{}, (*time.Time)(nil),
		))

	resp, err := svc.ListTransactions(authedCtx(), &pb.ListTransactionsRequest{
		UpdatedSince: timestamppb.New(now.Add(-time.Hour)),
	})
	require.NoError(t, err)
	assert.Len(t, resp.Transactions, 1)
}

func TestListTransactions_IncrementalWithFamily(t *testing.T) {
	svc, mock := svcWithMock(t)
	now := time.Now()
	famID := uuid.New()

	// Verify family membership
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(famID, userUID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))
	// Family incremental query
	mock.ExpectQuery("SELECT t.id.*FROM transactions t").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{
			"id", "user_id", "account_id", "category_id", "amount", "currency",
			"amount_cny", "exchange_rate", "type", "note", "txn_date",
			"created_at", "updated_at", "tags", "image_urls", "deleted_at",
		})) // empty result

	resp, err := svc.ListTransactions(authedCtx(), &pb.ListTransactionsRequest{
		UpdatedSince: timestamppb.New(now.Add(-time.Hour)),
		FamilyId:     famID.String(),
	})
	require.NoError(t, err)
	assert.Len(t, resp.Transactions, 0)
}

func TestListTransactions_IncrementalIncludeDeleted(t *testing.T) {
	svc, mock := svcWithMock(t)
	now := time.Now()
	txnID := uuid.New()
	accID := uuid.New()
	catID := uuid.New()
	deletedAt := now.Add(-time.Minute)

	mock.ExpectQuery("SELECT t.id.*FROM transactions t").
		WithArgs(userUID, pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{
			"id", "user_id", "account_id", "category_id", "amount", "currency",
			"amount_cny", "exchange_rate", "type", "note", "txn_date",
			"created_at", "updated_at", "tags", "image_urls", "deleted_at",
		}).AddRow(
			txnID, userUID, accID, catID, int64(200), "CNY",
			int64(200), 1.0, "income", "", now,
			now, now, []string{"tag1"}, []string{}, &deletedAt,
		))

	resp, err := svc.ListTransactions(authedCtx(), &pb.ListTransactionsRequest{
		UpdatedSince:   timestamppb.New(now.Add(-time.Hour)),
		IncludeDeleted: true,
	})
	require.NoError(t, err)
	assert.Len(t, resp.Transactions, 1)
	assert.NotNil(t, resp.Transactions[0].DeletedAt)
	assert.Equal(t, pb.TransactionType_TRANSACTION_TYPE_INCOME, resp.Transactions[0].Type)
}

// ── newFileStorageFromEnv ───────────────────────────────────────────────────

func TestNewFileStorageFromEnv_Default(t *testing.T) {
	os.Unsetenv("FILE_STORAGE")
	fs := newFileStorageFromEnv("/tmp/test", "/uploads")
	assert.NotNil(t, fs)
}

func TestNewFileStorageFromEnv_S3NoBucket(t *testing.T) {
	os.Setenv("FILE_STORAGE", "s3")
	os.Unsetenv("S3_BUCKET")
	t.Cleanup(func() { os.Unsetenv("FILE_STORAGE") })
	fs := newFileStorageFromEnv("/tmp/test", "/uploads")
	assert.NotNil(t, fs) // falls back to local
}

// ── GetCategories edge cases ────────────────────────────────────────────────

func TestGetCategories_WithTypeFilter(t *testing.T) {
	svc, mock := svcWithMock(t)

	mock.ExpectQuery("SELECT id, name, icon, type").
		WithArgs("income").
		WillReturnRows(pgxmock.NewRows([]string{"id", "name", "icon", "type", "is_preset", "sort_order", "parent_id", "icon_key"}).
			AddRow(uuid.New(), "salary", "💰", "income", true, int32(1), "", "money"))

	resp, err := svc.GetCategories(context.Background(), &pb.GetCategoriesRequest{
		Type: pb.TransactionType_TRANSACTION_TYPE_INCOME,
	})
	require.NoError(t, err)
	assert.Len(t, resp.Categories, 1)
	assert.Equal(t, "salary", resp.Categories[0].Name)
}

func TestGetCategories_WithChildren(t *testing.T) {
	svc, mock := svcWithMock(t)
	parentID := uuid.New()
	childID := uuid.New()

	mock.ExpectQuery("SELECT id, name, icon, type").
		WillReturnRows(pgxmock.NewRows([]string{"id", "name", "icon", "type", "is_preset", "sort_order", "parent_id", "icon_key"}).
			AddRow(parentID, "food", "🍔", "expense", true, int32(1), "", "food").
			AddRow(childID, "lunch", "🍱", "expense", false, int32(1), parentID.String(), "lunch"))

	resp, err := svc.GetCategories(context.Background(), &pb.GetCategoriesRequest{})
	require.NoError(t, err)
	assert.Len(t, resp.Categories, 1) // parent is root
	assert.Len(t, resp.Categories[0].Children, 1)
	assert.Equal(t, "lunch", resp.Categories[0].Children[0].Name)
}

func TestGetCategories_OrphanChild(t *testing.T) {
	svc, mock := svcWithMock(t)
	orphanID := uuid.New()

	mock.ExpectQuery("SELECT id, name, icon, type").
		WillReturnRows(pgxmock.NewRows([]string{"id", "name", "icon", "type", "is_preset", "sort_order", "parent_id", "icon_key"}).
			AddRow(orphanID, "orphan", "", "expense", false, int32(1), uuid.New().String(), ""))

	resp, err := svc.GetCategories(context.Background(), &pb.GetCategoriesRequest{})
	require.NoError(t, err)
	assert.Len(t, resp.Categories, 1) // orphan treated as root
}

func TestGetCategories_DBError(t *testing.T) {
	svc, mock := svcWithMock(t)
	mock.ExpectQuery("SELECT id, name, icon, type").
		WillReturnError(fmt.Errorf("err"))

	_, err := svc.GetCategories(context.Background(), &pb.GetCategoriesRequest{})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.Internal, st.Code())
}

func TestGetCategories_Empty(t *testing.T) {
	svc, mock := svcWithMock(t)
	mock.ExpectQuery("SELECT id, name, icon, type").
		WillReturnRows(pgxmock.NewRows([]string{"id", "name", "icon", "type", "is_preset", "sort_order", "parent_id", "icon_key"}))

	resp, err := svc.GetCategories(context.Background(), &pb.GetCategoriesRequest{})
	require.NoError(t, err)
	assert.Len(t, resp.Categories, 0)
}

// ── UpdateTransaction edge cases ────────────────────────────────────────────

func TestUpdateTransaction_NoAuth(t *testing.T) {
	svc, _ := svcWithMock(t)
	_, err := svc.UpdateTransaction(noAuthCtx(), &pb.UpdateTransactionRequest{TransactionId: uuid.New().String()})
	assert.Error(t, err)
}

func TestUpdateTransaction_InvalidTxnID(t *testing.T) {
	svc, _ := svcWithMock(t)
	_, err := svc.UpdateTransaction(authedCtx(), &pb.UpdateTransactionRequest{TransactionId: "bad"})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.InvalidArgument, st.Code())
}

func TestUpdateTransaction_ZeroAmount(t *testing.T) {
	svc, mock := svcWithMock(t)
	txnID := uuid.New()
	accID := uuid.New()
	catID := uuid.New()

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT user_id, account_id, category_id").
		WithArgs(txnID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "account_id", "category_id", "amount", "type", "currency", "note", "tags", "exchange_rate", "amount_cny"}).
			AddRow(userUID, accID, catID, int64(100), "expense", "CNY", "", []string{}, 1.0, int64(100)))
	// personal account - no family
	mock.ExpectQuery("SELECT family_id.*FROM accounts").
		WithArgs(accID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(nil, userUID))

	amt := int64(0)
	_, err := svc.UpdateTransaction(authedCtx(), &pb.UpdateTransactionRequest{
		TransactionId: txnID.String(), Amount: &amt,
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.InvalidArgument, st.Code())
}

func TestUpdateTransaction_Tags_JSON(t *testing.T) {
	svc, mock := svcWithMock(t)
	txnID := uuid.New()
	accID := uuid.New()
	catID := uuid.New()

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT user_id, account_id, category_id").
		WithArgs(txnID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "account_id", "category_id", "amount", "type", "currency", "note", "tags", "exchange_rate", "amount_cny"}).
			AddRow(userUID, accID, catID, int64(100), "expense", "CNY", "", []string{}, 1.0, int64(100)))
	mock.ExpectQuery("SELECT family_id.*FROM accounts").
		WithArgs(accID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(nil, userUID))
	mock.ExpectExec("UPDATE transactions SET").
		WithArgs(pgxmock.AnyArg(), txnID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectCommit()
	// Fetch updated
	mock.ExpectQuery("SELECT id, user_id, account_id").
		WithArgs(txnID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "account_id", "category_id", "amount", "currency", "amount_cny", "exchange_rate", "type", "note", "txn_date", "created_at", "updated_at", "tags", "image_urls"}).
			AddRow(txnID, userUID, accID, catID, int64(100), "CNY", int64(100), 1.0, "expense", "", time.Now(), time.Now(), time.Now(), []string{"a", "b"}, []string{}))

	tags := `["a","b"]`
	resp, err := svc.UpdateTransaction(authedCtx(), &pb.UpdateTransactionRequest{
		TransactionId: txnID.String(), Tags: &tags,
	})
	require.NoError(t, err)
	assert.Equal(t, []string{"a", "b"}, resp.Transaction.Tags)
}

func TestUpdateTransaction_Tags_CommaSeparated(t *testing.T) {
	svc, mock := svcWithMock(t)
	txnID := uuid.New()
	accID := uuid.New()
	catID := uuid.New()

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT user_id, account_id, category_id").
		WithArgs(txnID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "account_id", "category_id", "amount", "type", "currency", "note", "tags", "exchange_rate", "amount_cny"}).
			AddRow(userUID, accID, catID, int64(100), "expense", "CNY", "", []string{}, 1.0, int64(100)))
	mock.ExpectQuery("SELECT family_id.*FROM accounts").
		WithArgs(accID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(nil, userUID))
	mock.ExpectExec("UPDATE transactions SET").
		WithArgs(pgxmock.AnyArg(), txnID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectCommit()
	mock.ExpectQuery("SELECT id, user_id, account_id").
		WithArgs(txnID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "account_id", "category_id", "amount", "currency", "amount_cny", "exchange_rate", "type", "note", "txn_date", "created_at", "updated_at", "tags", "image_urls"}).
			AddRow(txnID, userUID, accID, catID, int64(100), "CNY", int64(100), 1.0, "expense", "", time.Now(), time.Now(), time.Now(), []string{"x", "y"}, []string{}))

	tags := "x, y"
	resp, err := svc.UpdateTransaction(authedCtx(), &pb.UpdateTransactionRequest{
		TransactionId: txnID.String(), Tags: &tags,
	})
	require.NoError(t, err)
	assert.Equal(t, []string{"x", "y"}, resp.Transaction.Tags)
}

func TestUpdateTransaction_Tags_Empty(t *testing.T) {
	svc, mock := svcWithMock(t)
	txnID := uuid.New()
	accID := uuid.New()
	catID := uuid.New()

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT user_id, account_id, category_id").
		WithArgs(txnID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "account_id", "category_id", "amount", "type", "currency", "note", "tags", "exchange_rate", "amount_cny"}).
			AddRow(userUID, accID, catID, int64(100), "expense", "CNY", "", []string{}, 1.0, int64(100)))
	mock.ExpectQuery("SELECT family_id.*FROM accounts").
		WithArgs(accID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(nil, userUID))
	mock.ExpectExec("UPDATE transactions SET").
		WithArgs(pgxmock.AnyArg(), txnID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectCommit()
	mock.ExpectQuery("SELECT id, user_id, account_id").
		WithArgs(txnID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "account_id", "category_id", "amount", "currency", "amount_cny", "exchange_rate", "type", "note", "txn_date", "created_at", "updated_at", "tags", "image_urls"}).
			AddRow(txnID, userUID, accID, catID, int64(100), "CNY", int64(100), 1.0, "expense", "", time.Now(), time.Now(), time.Now(), []string{}, []string{}))

	tags := "[]"
	resp, err := svc.UpdateTransaction(authedCtx(), &pb.UpdateTransactionRequest{
		TransactionId: txnID.String(), Tags: &tags,
	})
	require.NoError(t, err)
	assert.Empty(t, resp.Transaction.Tags)
}

func TestUpdateTransaction_Currency(t *testing.T) {
	svc, mock := svcWithMock(t)
	txnID := uuid.New()
	accID := uuid.New()
	catID := uuid.New()

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT user_id, account_id, category_id").
		WithArgs(txnID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "account_id", "category_id", "amount", "type", "currency", "note", "tags", "exchange_rate", "amount_cny"}).
			AddRow(userUID, accID, catID, int64(100), "expense", "CNY", "", []string{}, 1.0, int64(100)))
	mock.ExpectQuery("SELECT family_id.*FROM accounts").
		WithArgs(accID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(nil, userUID))
	mock.ExpectExec("UPDATE transactions SET").
		WithArgs("USD", txnID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectCommit()
	mock.ExpectQuery("SELECT id, user_id, account_id").
		WithArgs(txnID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "account_id", "category_id", "amount", "currency", "amount_cny", "exchange_rate", "type", "note", "txn_date", "created_at", "updated_at", "tags", "image_urls"}).
			AddRow(txnID, userUID, accID, catID, int64(100), "USD", int64(100), 1.0, "expense", "", time.Now(), time.Now(), time.Now(), []string{}, []string{}))

	currency := "USD"
	resp, err := svc.UpdateTransaction(authedCtx(), &pb.UpdateTransactionRequest{
		TransactionId: txnID.String(), Currency: &currency,
	})
	require.NoError(t, err)
	assert.Equal(t, "USD", resp.Transaction.Currency)
}

func TestUpdateTransaction_InvalidCategoryID(t *testing.T) {
	svc, mock := svcWithMock(t)
	txnID := uuid.New()
	accID := uuid.New()
	catID := uuid.New()

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT user_id, account_id, category_id").
		WithArgs(txnID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "account_id", "category_id", "amount", "type", "currency", "note", "tags", "exchange_rate", "amount_cny"}).
			AddRow(userUID, accID, catID, int64(100), "expense", "CNY", "", []string{}, 1.0, int64(100)))
	mock.ExpectQuery("SELECT family_id.*FROM accounts").
		WithArgs(accID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(nil, userUID))

	badCat := "not-uuid"
	_, err := svc.UpdateTransaction(authedCtx(), &pb.UpdateTransactionRequest{
		TransactionId: txnID.String(), CategoryId: &badCat,
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.InvalidArgument, st.Code())
}

func TestUpdateTransaction_CategoryNotFound(t *testing.T) {
	svc, mock := svcWithMock(t)
	txnID := uuid.New()
	accID := uuid.New()
	catID := uuid.New()
	newCat := uuid.New()

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT user_id, account_id, category_id").
		WithArgs(txnID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "account_id", "category_id", "amount", "type", "currency", "note", "tags", "exchange_rate", "amount_cny"}).
			AddRow(userUID, accID, catID, int64(100), "expense", "CNY", "", []string{}, 1.0, int64(100)))
	mock.ExpectQuery("SELECT family_id.*FROM accounts").
		WithArgs(accID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(nil, userUID))
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(newCat).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(false))

	newCatStr := newCat.String()
	_, err := svc.UpdateTransaction(authedCtx(), &pb.UpdateTransactionRequest{
		TransactionId: txnID.String(), CategoryId: &newCatStr,
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.InvalidArgument, st.Code())
}

func TestUpdateTransaction_TypeChange(t *testing.T) {
	svc, mock := svcWithMock(t)
	txnID := uuid.New()
	accID := uuid.New()
	catID := uuid.New()

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT user_id, account_id, category_id").
		WithArgs(txnID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "account_id", "category_id", "amount", "type", "currency", "note", "tags", "exchange_rate", "amount_cny"}).
			AddRow(userUID, accID, catID, int64(1000), "expense", "CNY", "", []string{}, 1.0, int64(1000)))
	mock.ExpectQuery("SELECT family_id.*FROM accounts").
		WithArgs(accID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(nil, userUID))
	mock.ExpectExec("UPDATE transactions SET").
		WithArgs("income", txnID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	// balance adjust: old=-1000, new=+1000, adjust=+2000
	mock.ExpectExec("UPDATE accounts SET balance").
		WithArgs(int64(2000), accID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectCommit()
	mock.ExpectQuery("SELECT id, user_id, account_id").
		WithArgs(txnID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "account_id", "category_id", "amount", "currency", "amount_cny", "exchange_rate", "type", "note", "txn_date", "created_at", "updated_at", "tags", "image_urls"}).
			AddRow(txnID, userUID, accID, catID, int64(1000), "CNY", int64(1000), 1.0, "income", "", time.Now(), time.Now(), time.Now(), []string{}, []string{}))

	incomeType := pb.TransactionType_TRANSACTION_TYPE_INCOME
	resp, err := svc.UpdateTransaction(authedCtx(), &pb.UpdateTransactionRequest{
		TransactionId: txnID.String(), Type: &incomeType,
	})
	require.NoError(t, err)
	assert.Equal(t, pb.TransactionType_TRANSACTION_TYPE_INCOME, resp.Transaction.Type)
}

func TestUpdateTransaction_InvalidType(t *testing.T) {
	svc, mock := svcWithMock(t)
	txnID := uuid.New()
	accID := uuid.New()
	catID := uuid.New()

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT user_id, account_id, category_id").
		WithArgs(txnID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "account_id", "category_id", "amount", "type", "currency", "note", "tags", "exchange_rate", "amount_cny"}).
			AddRow(userUID, accID, catID, int64(100), "expense", "CNY", "", []string{}, 1.0, int64(100)))
	mock.ExpectQuery("SELECT family_id.*FROM accounts").
		WithArgs(accID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(nil, userUID))

	unspecified := pb.TransactionType_TRANSACTION_TYPE_UNSPECIFIED
	_, err := svc.UpdateTransaction(authedCtx(), &pb.UpdateTransactionRequest{
		TransactionId: txnID.String(), Type: &unspecified,
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.InvalidArgument, st.Code())
}
