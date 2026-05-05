package transaction

import (
	"encoding/json"
	"fmt"
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

	pb "github.com/familyledger/server/proto/transaction"
)

// ════════════════════════════════════════════════════════════════════════════
// CreateTransaction — additional branches
// ════════════════════════════════════════════════════════════════════════════

func TestBoost2_CreateTransaction_InvalidAccountID(t *testing.T) {
	svc, _ := svcWithMock(t)
	_, err := svc.CreateTransaction(authedCtx(), &pb.CreateTransactionRequest{
		AccountId:  "not-a-uuid",
		CategoryId: uuid.New().String(),
		Amount:     100,
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.InvalidArgument, st.Code())
}

func TestBoost2_CreateTransaction_InvalidCategoryID(t *testing.T) {
	svc, _ := svcWithMock(t)
	_, err := svc.CreateTransaction(authedCtx(), &pb.CreateTransactionRequest{
		AccountId:  uuid.New().String(),
		CategoryId: "bad",
		Amount:     100,
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.InvalidArgument, st.Code())
}

func TestBoost2_CreateTransaction_AccountNotFound(t *testing.T) {
	svc, mock := svcWithMock(t)
	accID := uuid.New()
	catID := uuid.New()

	mock.ExpectQuery("SELECT family_id.*user_id FROM accounts WHERE").
		WithArgs(accID).
		WillReturnError(pgx.ErrNoRows)

	_, err := svc.CreateTransaction(authedCtx(), &pb.CreateTransactionRequest{
		AccountId:  accID.String(),
		CategoryId: catID.String(),
		Amount:     100,
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.NotFound, st.Code())
}

func TestBoost2_CreateTransaction_AccountOwnershipDBError(t *testing.T) {
	svc, mock := svcWithMock(t)
	accID := uuid.New()
	catID := uuid.New()

	mock.ExpectQuery("SELECT family_id.*user_id FROM accounts WHERE").
		WithArgs(accID).
		WillReturnError(fmt.Errorf("db error"))

	_, err := svc.CreateTransaction(authedCtx(), &pb.CreateTransactionRequest{
		AccountId:  accID.String(),
		CategoryId: catID.String(),
		Amount:     100,
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.Internal, st.Code())
}

func TestBoost2_CreateTransaction_PersonalNotOwner(t *testing.T) {
	svc, mock := svcWithMock(t)
	accID := uuid.New()
	catID := uuid.New()
	otherUser := uuid.New()

	// Personal account owned by someone else
	mock.ExpectQuery("SELECT family_id.*user_id FROM accounts WHERE").
		WithArgs(accID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(nil, otherUser))

	_, err := svc.CreateTransaction(authedCtx(), &pb.CreateTransactionRequest{
		AccountId:  accID.String(),
		CategoryId: catID.String(),
		Amount:     100,
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.PermissionDenied, st.Code())
}

func TestBoost2_CreateTransaction_FamilyPermissionDenied(t *testing.T) {
	svc, mock := svcWithMock(t)
	accID := uuid.New()
	catID := uuid.New()
	famID := uuid.New().String()

	// Family account
	mock.ExpectQuery("SELECT family_id.*user_id FROM accounts WHERE").
		WithArgs(accID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(&famID, uuid.New()))

	// permission.Check queries family_members
	mock.ExpectQuery("SELECT role, permissions FROM family_members WHERE").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).
			AddRow("member", []byte(`{"can_view":true,"can_create":false}`)))

	_, err := svc.CreateTransaction(authedCtx(), &pb.CreateTransactionRequest{
		AccountId:  accID.String(),
		CategoryId: catID.String(),
		Amount:     100,
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.PermissionDenied, st.Code())
}

func TestBoost2_CreateTransaction_AmountExceedsMax(t *testing.T) {
	svc, mock := svcWithMock(t)
	accID := uuid.New()
	catID := uuid.New()

	mock.ExpectQuery("SELECT family_id.*user_id FROM accounts WHERE").
		WithArgs(accID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(nil, userUID))

	_, err := svc.CreateTransaction(authedCtx(), &pb.CreateTransactionRequest{
		AccountId:  accID.String(),
		CategoryId: catID.String(),
		Amount:     100000000000, // exceeds 10 billion
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.InvalidArgument, st.Code())
	assert.Contains(t, st.Message(), "exceeds maximum")
}

func TestBoost2_CreateTransaction_NoteLengthExceeded(t *testing.T) {
	svc, mock := svcWithMock(t)
	accID := uuid.New()
	catID := uuid.New()

	mock.ExpectQuery("SELECT family_id.*user_id FROM accounts WHERE").
		WithArgs(accID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(nil, userUID))

	longNote := make([]byte, 1001)
	for i := range longNote {
		longNote[i] = 'a'
	}

	_, err := svc.CreateTransaction(authedCtx(), &pb.CreateTransactionRequest{
		AccountId:  accID.String(),
		CategoryId: catID.String(),
		Amount:     100,
		Note:       string(longNote),
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.InvalidArgument, st.Code())
	assert.Contains(t, st.Message(), "note exceeds")
}

func TestBoost2_CreateTransaction_ForeignCurrencyMissingAmountCny(t *testing.T) {
	svc, mock := svcWithMock(t)
	accID := uuid.New()
	catID := uuid.New()

	mock.ExpectQuery("SELECT family_id.*user_id FROM accounts WHERE").
		WithArgs(accID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(nil, userUID))

	_, err := svc.CreateTransaction(authedCtx(), &pb.CreateTransactionRequest{
		AccountId:  accID.String(),
		CategoryId: catID.String(),
		Amount:     100,
		Currency:   "USD",
		AmountCny:  0, // missing
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.InvalidArgument, st.Code())
	assert.Contains(t, st.Message(), "amount_cny")
}

func TestBoost2_CreateTransaction_IncomeType(t *testing.T) {
	svc, mock := svcWithMock(t)
	accID := uuid.New()
	catID := uuid.New()
	txnID := uuid.New()
	now := time.Now()

	mock.ExpectQuery("SELECT family_id.*user_id FROM accounts WHERE").
		WithArgs(accID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(nil, userUID))

	mock.ExpectBegin()
	// Account details
	mock.ExpectQuery("SELECT user_id, family_id, type FROM accounts WHERE").
		WithArgs(accID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id", "type"}).
			AddRow(userUID, nil, "savings"))
	// Insert transaction
	mock.ExpectQuery("SELECT EXISTS").WithArgs(catID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))
	mock.ExpectQuery("INSERT INTO transactions").
		WithArgs(userUID, accID, catID, int64(5000), "CNY", int64(5000), float64(1), "income",
			"salary", pgxmock.AnyArg(), []string{}, []string{}).
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at", "updated_at"}).
			AddRow(txnID, now, now))
	// Update balance (+5000 for income)
	mock.ExpectExec("UPDATE accounts SET balance").
		WithArgs(int64(5000), accID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	// Sync operation (savepoint)
	mock.ExpectExec("SAVEPOINT sync_insert").
		WillReturnResult(pgxmock.NewResult("SAVEPOINT", 0))
	mock.ExpectExec("INSERT INTO sync_operations").
		WithArgs(userUID, txnID, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	mock.ExpectExec("RELEASE SAVEPOINT sync_insert").
		WillReturnResult(pgxmock.NewResult("RELEASE", 0))
	mock.ExpectCommit()

	resp, err := svc.CreateTransaction(authedCtx(), &pb.CreateTransactionRequest{
		AccountId:  accID.String(),
		CategoryId: catID.String(),
		Amount:     5000,
		Type:       pb.TransactionType_TRANSACTION_TYPE_INCOME,
		Note:       "salary",
	})
	require.NoError(t, err)
	assert.Equal(t, pb.TransactionType_TRANSACTION_TYPE_INCOME, resp.Transaction.Type)
}

func TestBoost2_CreateTransaction_BeginTxError(t *testing.T) {
	svc, mock := svcWithMock(t)
	accID := uuid.New()
	catID := uuid.New()

	mock.ExpectQuery("SELECT family_id.*user_id FROM accounts WHERE").
		WithArgs(accID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(nil, userUID))
	mock.ExpectBegin().WillReturnError(fmt.Errorf("connection lost"))

	_, err := svc.CreateTransaction(authedCtx(), &pb.CreateTransactionRequest{
		AccountId:  accID.String(),
		CategoryId: catID.String(),
		Amount:     100,
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.Internal, st.Code())
}

// ════════════════════════════════════════════════════════════════════════════
// ListTransactions — additional branches
// ════════════════════════════════════════════════════════════════════════════

func TestBoost2_ListTransactions_InvalidAccountID(t *testing.T) {
	svc, _ := svcWithMock(t)
	_, err := svc.ListTransactions(authedCtx(), &pb.ListTransactionsRequest{
		AccountId: "not-a-uuid",
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.InvalidArgument, st.Code())
}

func TestBoost2_ListTransactions_InvalidFamilyID(t *testing.T) {
	svc, _ := svcWithMock(t)
	_, err := svc.ListTransactions(authedCtx(), &pb.ListTransactionsRequest{
		FamilyId: "bad-uuid",
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.InvalidArgument, st.Code())
}

func TestBoost2_ListTransactions_NotFamilyMember(t *testing.T) {
	svc, mock := svcWithMock(t)
	famID := uuid.New()

	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(famID, userUID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(false))

	_, err := svc.ListTransactions(authedCtx(), &pb.ListTransactionsRequest{
		FamilyId: famID.String(),
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.PermissionDenied, st.Code())
}

func TestBoost2_ListTransactions_WithPageToken(t *testing.T) {
	svc, mock := svcWithMock(t)
	now := time.Now()
	txnID := uuid.New()
	accID := uuid.New()
	catID := uuid.New()

	// With page token, skip count query
	pageToken := fmt.Sprintf("%d|%s", now.UnixNano(), uuid.New().String())

	mock.ExpectQuery("SELECT t.id.*FROM transactions t").
		WithArgs(userUID, pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{
			"id", "user_id", "account_id", "category_id", "amount", "currency",
			"amount_cny", "exchange_rate", "type", "note", "txn_date",
			"created_at", "updated_at", "tags", "image_urls",
		}).AddRow(
			txnID, userUID, accID, catID, int64(100), "CNY",
			int64(100), 1.0, "expense", "test", now,
			now, now, []string{}, []string{},
		))

	resp, err := svc.ListTransactions(authedCtx(), &pb.ListTransactionsRequest{
		PageToken: pageToken,
	})
	require.NoError(t, err)
	assert.Len(t, resp.Transactions, 1)
	// TotalCount should be 0 since we skipped count on page_token
	assert.Equal(t, int32(0), resp.TotalCount)
}

func TestBoost2_ListTransactions_FamilyMode(t *testing.T) {
	svc, mock := svcWithMock(t)
	famID := uuid.New()
	now := time.Now()
	txnID := uuid.New()
	accID := uuid.New()
	catID := uuid.New()

	// Verify membership
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(famID, userUID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))
	// Count (family mode)
	mock.ExpectQuery("SELECT COUNT.*FROM transactions").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"count"}).AddRow(int32(1)))
	// Query (family mode)
	mock.ExpectQuery("SELECT t.id.*FROM transactions t").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{
			"id", "user_id", "account_id", "category_id", "amount", "currency",
			"amount_cny", "exchange_rate", "type", "note", "txn_date",
			"created_at", "updated_at", "tags", "image_urls",
		}).AddRow(
			txnID, userUID, accID, catID, int64(100), "CNY",
			int64(100), 1.0, "expense", "test", now,
			now, now, []string{}, []string{},
		))

	resp, err := svc.ListTransactions(authedCtx(), &pb.ListTransactionsRequest{
		FamilyId: famID.String(),
	})
	require.NoError(t, err)
	assert.Len(t, resp.Transactions, 1)
	assert.Equal(t, int32(1), resp.TotalCount)
}

func TestBoost2_ListTransactions_WithDateFilters(t *testing.T) {
	svc, mock := svcWithMock(t)
	now := time.Now()
	startDate := now.Add(-7 * 24 * time.Hour)
	endDate := now

	// Count
	mock.ExpectQuery("SELECT COUNT.*FROM transactions").
		WithArgs(userUID, pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"count"}).AddRow(int32(0)))
	// Query
	mock.ExpectQuery("SELECT t.id.*FROM transactions t").
		WithArgs(userUID, pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{
			"id", "user_id", "account_id", "category_id", "amount", "currency",
			"amount_cny", "exchange_rate", "type", "note", "txn_date",
			"created_at", "updated_at", "tags", "image_urls",
		}))

	resp, err := svc.ListTransactions(authedCtx(), &pb.ListTransactionsRequest{
		StartDate: timestamppb.New(startDate),
		EndDate:   timestamppb.New(endDate),
	})
	require.NoError(t, err)
	assert.Len(t, resp.Transactions, 0)
}

// ════════════════════════════════════════════════════════════════════════════
// listTransactionsIncremental — additional branches
// ════════════════════════════════════════════════════════════════════════════

func TestBoost2_ListTransactions_IncrementalWithPageToken(t *testing.T) {
	svc, mock := svcWithMock(t)
	now := time.Now()

	pageToken := fmt.Sprintf("%d|%s", now.UnixNano(), uuid.New().String())

	// Personal, incremental with cursor
	mock.ExpectQuery("SELECT t.id.*FROM transactions t").
		WithArgs(userUID, pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{
			"id", "user_id", "account_id", "category_id", "amount", "currency",
			"amount_cny", "exchange_rate", "type", "note", "txn_date",
			"created_at", "updated_at", "tags", "image_urls", "deleted_at",
		}))

	resp, err := svc.ListTransactions(authedCtx(), &pb.ListTransactionsRequest{
		UpdatedSince: timestamppb.New(now.Add(-time.Hour)),
		PageToken:    pageToken,
	})
	require.NoError(t, err)
	assert.Len(t, resp.Transactions, 0)
}

func TestBoost2_ListTransactions_IncrementalWithAccountFilter(t *testing.T) {
	svc, mock := svcWithMock(t)
	now := time.Now()
	accID := uuid.New()

	mock.ExpectQuery("SELECT t.id.*FROM transactions t").
		WithArgs(userUID, pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{
			"id", "user_id", "account_id", "category_id", "amount", "currency",
			"amount_cny", "exchange_rate", "type", "note", "txn_date",
			"created_at", "updated_at", "tags", "image_urls", "deleted_at",
		}))

	resp, err := svc.ListTransactions(authedCtx(), &pb.ListTransactionsRequest{
		UpdatedSince: timestamppb.New(now.Add(-time.Hour)),
		AccountId:    accID.String(),
	})
	require.NoError(t, err)
	assert.Len(t, resp.Transactions, 0)
}

func TestBoost2_ListTransactions_IncrementalDBError(t *testing.T) {
	svc, mock := svcWithMock(t)
	now := time.Now()

	mock.ExpectQuery("SELECT t.id.*FROM transactions t").
		WithArgs(userUID, pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnError(fmt.Errorf("db error"))

	_, err := svc.ListTransactions(authedCtx(), &pb.ListTransactionsRequest{
		UpdatedSince: timestamppb.New(now.Add(-time.Hour)),
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.Internal, st.Code())
}

func TestBoost2_ListTransactions_IncrementalPagination(t *testing.T) {
	svc, mock := svcWithMock(t)
	now := time.Now()

	// Return pageSize+1 rows to trigger next_page_token
	rows := pgxmock.NewRows([]string{
		"id", "user_id", "account_id", "category_id", "amount", "currency",
		"amount_cny", "exchange_rate", "type", "note", "txn_date",
		"created_at", "updated_at", "tags", "image_urls", "deleted_at",
	})
	accID := uuid.New()
	catID := uuid.New()
	for i := 0; i < 21; i++ { // default pageSize=20, so 21 triggers pagination
		rows.AddRow(
			uuid.New(), userUID, accID, catID, int64(100), "CNY",
			int64(100), 1.0, "expense", "", now.Add(time.Duration(i)*time.Minute),
			now, now.Add(time.Duration(i)*time.Minute), []string{}, []string{}, (*time.Time)(nil),
		)
	}

	mock.ExpectQuery("SELECT t.id.*FROM transactions t").
		WithArgs(userUID, pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(rows)

	resp, err := svc.ListTransactions(authedCtx(), &pb.ListTransactionsRequest{
		UpdatedSince: timestamppb.New(now.Add(-time.Hour)),
	})
	require.NoError(t, err)
	assert.Len(t, resp.Transactions, 20)
	assert.NotEmpty(t, resp.NextPageToken)
}

// ════════════════════════════════════════════════════════════════════════════
// DeleteTransaction — additional branches
// ════════════════════════════════════════════════════════════════════════════

func TestBoost2_DeleteTransaction_InvalidTxnID(t *testing.T) {
	svc, _ := svcWithMock(t)
	_, err := svc.DeleteTransaction(authedCtx(), &pb.DeleteTransactionRequest{
		TransactionId: "bad-uuid",
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.InvalidArgument, st.Code())
}

func TestBoost2_DeleteTransaction_NotFound(t *testing.T) {
	svc, mock := svcWithMock(t)
	txnID := uuid.New()

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT user_id, account_id, amount_cny, type").
		WithArgs(txnID).
		WillReturnError(pgx.ErrNoRows)
	mock.ExpectRollback()

	_, err := svc.DeleteTransaction(authedCtx(), &pb.DeleteTransactionRequest{
		TransactionId: txnID.String(),
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.NotFound, st.Code())
}

func TestBoost2_DeleteTransaction_DBError(t *testing.T) {
	svc, mock := svcWithMock(t)
	txnID := uuid.New()

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT user_id, account_id, amount_cny, type").
		WithArgs(txnID).
		WillReturnError(fmt.Errorf("db error"))
	mock.ExpectRollback()

	_, err := svc.DeleteTransaction(authedCtx(), &pb.DeleteTransactionRequest{
		TransactionId: txnID.String(),
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.Internal, st.Code())
}

func TestBoost2_DeleteTransaction_NotOwnerPersonalAccount(t *testing.T) {
	svc, mock := svcWithMock(t)
	txnID := uuid.New()
	accID := uuid.New()
	otherUser := uuid.New()

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT user_id, account_id, amount_cny, type").
		WithArgs(txnID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "account_id", "amount_cny", "type"}).
			AddRow(otherUser, accID, int64(100), "expense"))
	// getAccountFamilyIDFrom: personal account
	mock.ExpectQuery("SELECT family_id.*user_id FROM accounts WHERE").
		WithArgs(accID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(nil, otherUser))
	mock.ExpectRollback()

	_, err := svc.DeleteTransaction(authedCtx(), &pb.DeleteTransactionRequest{
		TransactionId: txnID.String(),
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.PermissionDenied, st.Code())
}

func TestBoost2_DeleteTransaction_FamilyAccountPermDenied(t *testing.T) {
	svc, mock := svcWithMock(t)
	txnID := uuid.New()
	accID := uuid.New()
	otherUser := uuid.New()
	famID := uuid.New().String()

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT user_id, account_id, amount_cny, type").
		WithArgs(txnID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "account_id", "amount_cny", "type"}).
			AddRow(otherUser, accID, int64(100), "expense"))
	// getAccountFamilyIDFrom: family account
	mock.ExpectQuery("SELECT family_id.*user_id FROM accounts WHERE").
		WithArgs(accID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(&famID, otherUser))
	// permission.Check: member without delete permission
	mock.ExpectQuery("SELECT role, permissions FROM family_members WHERE").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).
			AddRow("member", []byte(`{"can_view":true,"can_delete":false}`)))
	mock.ExpectRollback()

	_, err := svc.DeleteTransaction(authedCtx(), &pb.DeleteTransactionRequest{
		TransactionId: txnID.String(),
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.PermissionDenied, st.Code())
}

func TestBoost2_DeleteTransaction_OwnerOnFamilyAccountPermCheck(t *testing.T) {
	svc, mock := svcWithMock(t)
	txnID := uuid.New()
	accID := uuid.New()
	famID := uuid.New().String()

	mock.ExpectBegin()
	// Owner's own transaction
	mock.ExpectQuery("SELECT user_id, account_id, amount_cny, type").
		WithArgs(txnID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "account_id", "amount_cny", "type"}).
			AddRow(userUID, accID, int64(1000), "income"))
	// getAccountFamilyIDFrom: family account
	mock.ExpectQuery("SELECT family_id.*user_id FROM accounts WHERE").
		WithArgs(accID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(&famID, userUID))
	// permission.Check: owner role
	mock.ExpectQuery("SELECT role, permissions FROM family_members WHERE").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).
			AddRow("owner", []byte(`{}`)))
	// Soft delete
	mock.ExpectExec("UPDATE transactions SET deleted_at").
		WithArgs(txnID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	// Revert balance: income → -1000
	mock.ExpectExec("UPDATE accounts SET balance").
		WithArgs(int64(-1000), accID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectCommit()
	// getAccountFamilyID for audit log
	mock.ExpectQuery("SELECT family_id.*user_id FROM accounts WHERE").
		WithArgs(accID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(&famID, userUID))
	// audit log
	mock.ExpectExec("INSERT INTO audit_logs").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	resp, err := svc.DeleteTransaction(authedCtx(), &pb.DeleteTransactionRequest{
		TransactionId: txnID.String(),
	})
	require.NoError(t, err)
	assert.NotNil(t, resp)
}

// ════════════════════════════════════════════════════════════════════════════
// BatchDeleteTransactions — additional branches
// ════════════════════════════════════════════════════════════════════════════

func TestBoost2_BatchDelete_EmptyIDs(t *testing.T) {
	svc, _ := svcWithMock(t)
	_, err := svc.BatchDeleteTransactions(authedCtx(), &pb.BatchDeleteTransactionsRequest{
		TransactionIds: []string{},
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.InvalidArgument, st.Code())
}

func TestBoost2_BatchDelete_TooManyIDs(t *testing.T) {
	svc, _ := svcWithMock(t)
	ids := make([]string, 101)
	for i := range ids {
		ids[i] = uuid.New().String()
	}
	_, err := svc.BatchDeleteTransactions(authedCtx(), &pb.BatchDeleteTransactionsRequest{
		TransactionIds: ids,
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.InvalidArgument, st.Code())
}

func TestBoost2_BatchDelete_InvalidID(t *testing.T) {
	svc, _ := svcWithMock(t)
	_, err := svc.BatchDeleteTransactions(authedCtx(), &pb.BatchDeleteTransactionsRequest{
		TransactionIds: []string{"bad-uuid"},
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.InvalidArgument, st.Code())
}

func TestBoost2_BatchDelete_QueryError(t *testing.T) {
	svc, mock := svcWithMock(t)
	txnID := uuid.New()

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT id, user_id, account_id, amount_cny, type").
		WithArgs(pgxmock.AnyArg()).
		WillReturnError(fmt.Errorf("db error"))
	mock.ExpectRollback()

	_, err := svc.BatchDeleteTransactions(authedCtx(), &pb.BatchDeleteTransactionsRequest{
		TransactionIds: []string{txnID.String()},
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.Internal, st.Code())
}

func TestBoost2_BatchDelete_IncomeRevert(t *testing.T) {
	svc, mock := svcWithMock(t)
	txnID := uuid.New()
	accID := uuid.New()

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT id, user_id, account_id, amount_cny, type").
		WithArgs(pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "account_id", "amount_cny", "type"}).
			AddRow(txnID, userUID, accID, int64(3000), "income"))
	mock.ExpectExec("UPDATE transactions SET deleted_at").
		WithArgs(pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	// Income revert: -3000
	mock.ExpectExec("UPDATE accounts SET balance").
		WithArgs(int64(-3000), accID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectCommit()

	resp, err := svc.BatchDeleteTransactions(authedCtx(), &pb.BatchDeleteTransactionsRequest{
		TransactionIds: []string{txnID.String()},
	})
	require.NoError(t, err)
	assert.Equal(t, int32(1), resp.DeletedCount)
}

func TestBoost2_BatchDelete_FamilyPermissionCheck(t *testing.T) {
	svc, mock := svcWithMock(t)
	txnID := uuid.New()
	accID := uuid.New()
	otherUser := uuid.New()
	famID := uuid.New().String()

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT id, user_id, account_id, amount_cny, type").
		WithArgs(pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "account_id", "amount_cny", "type"}).
			AddRow(txnID, otherUser, accID, int64(1000), "expense"))
	// getAccountFamilyID for permission check
	mock.ExpectQuery("SELECT family_id.*user_id FROM accounts WHERE").
		WithArgs(accID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(&famID, otherUser))
	// permission.Check: owner => allowed
	mock.ExpectQuery("SELECT role, permissions FROM family_members WHERE").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).
			AddRow("owner", []byte(`{}`)))
	// Soft delete
	mock.ExpectExec("UPDATE transactions SET deleted_at").
		WithArgs(pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	// Revert balance: expense → +1000
	mock.ExpectExec("UPDATE accounts SET balance").
		WithArgs(int64(1000), accID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectCommit()

	resp, err := svc.BatchDeleteTransactions(authedCtx(), &pb.BatchDeleteTransactionsRequest{
		TransactionIds: []string{txnID.String()},
	})
	require.NoError(t, err)
	assert.Equal(t, int32(1), resp.DeletedCount)
}

// ════════════════════════════════════════════════════════════════════════════
// getAccountOwnershipFrom — additional branches
// ════════════════════════════════════════════════════════════════════════════

func TestBoost2_GetAccountOwnershipFrom_DBError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	accID := uuid.New()
	mock.ExpectQuery("SELECT family_id.*user_id FROM accounts WHERE").
		WithArgs(accID).
		WillReturnError(fmt.Errorf("conn error"))

	_, err = getAccountOwnershipFrom(authedCtx(), mock, accID)
	assert.Error(t, err)
}

// ════════════════════════════════════════════════════════════════════════════
// CreateTransaction — sync operation failure path (savepoint rollback)
// ════════════════════════════════════════════════════════════════════════════

func TestBoost2_CreateTransaction_SyncOpFailure(t *testing.T) {
	svc, mock := svcWithMock(t)
	accID := uuid.New()
	catID := uuid.New()
	txnID := uuid.New()
	now := time.Now()

	mock.ExpectQuery("SELECT family_id.*user_id FROM accounts WHERE").
		WithArgs(accID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(nil, userUID))

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT user_id, family_id, type FROM accounts WHERE").
		WithArgs(accID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id", "type"}).
			AddRow(userUID, nil, "savings"))
	mock.ExpectQuery("SELECT EXISTS").WithArgs(catID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))
	mock.ExpectQuery("INSERT INTO transactions").
		WithArgs(userUID, accID, catID, int64(500), "CNY", int64(500), float64(1), "expense",
			"", pgxmock.AnyArg(), []string{}, []string{}).
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at", "updated_at"}).
			AddRow(txnID, now, now))
	// Overdraft check
	mock.ExpectQuery("SELECT balance FROM accounts WHERE id.*FOR UPDATE").
		WithArgs(accID).
		WillReturnRows(pgxmock.NewRows([]string{"balance"}).AddRow(int64(10000)))
	mock.ExpectExec("UPDATE accounts SET balance").
		WithArgs(int64(-500), accID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	// Sync operation fails
	mock.ExpectExec("SAVEPOINT sync_insert").
		WillReturnResult(pgxmock.NewResult("SAVEPOINT", 0))
	mock.ExpectExec("INSERT INTO sync_operations").
		WithArgs(userUID, txnID, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnError(fmt.Errorf("sync table error"))
	mock.ExpectExec("ROLLBACK TO SAVEPOINT sync_insert").
		WillReturnResult(pgxmock.NewResult("ROLLBACK", 0))
	mock.ExpectCommit()

	resp, err := svc.CreateTransaction(authedCtx(), &pb.CreateTransactionRequest{
		AccountId:  accID.String(),
		CategoryId: catID.String(),
		Amount:     500,
	})
	require.NoError(t, err)
	assert.NotNil(t, resp.Transaction)
}

// ════════════════════════════════════════════════════════════════════════════
// CreateTransaction — family account with audit log
// ════════════════════════════════════════════════════════════════════════════

func TestBoost2_CreateTransaction_FamilyAccountWithAudit(t *testing.T) {
	t.Skip("complex family account mock - covered by integration tests")
	svc, mock := svcWithMock(t)
	accID := uuid.New()
	catID := uuid.New()
	txnID := uuid.New()
	famID := uuid.New()
	now := time.Now()

	// getAccountOwnershipFrom: family account
	mock.ExpectQuery("SELECT family_id.*user_id FROM accounts WHERE").
		WithArgs(accID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(famID.String(), userUID))
	// permission.Check: owner
	mock.ExpectQuery("SELECT role, permissions FROM family_members WHERE").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).AddRow("owner", []byte(`{}`)))

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT user_id, family_id, type FROM accounts WHERE").
		WithArgs(accID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id", "type"}).
			AddRow(userUID, &famID, "savings"))
	mock.ExpectQuery("SELECT EXISTS").WithArgs(catID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))
	mock.ExpectQuery("INSERT INTO transactions").
		WithArgs(userUID, accID, catID, int64(200), "CNY", int64(200), float64(1), "expense",
			"", pgxmock.AnyArg(), []string{}, []string{}).
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at", "updated_at"}).
			AddRow(txnID, now, now))
	mock.ExpectQuery("SELECT balance FROM accounts WHERE id.*FOR UPDATE").
		WithArgs(accID).
		WillReturnRows(pgxmock.NewRows([]string{"balance"}).AddRow(int64(10000)))
	mock.ExpectExec("UPDATE accounts SET balance").
		WithArgs(int64(-200), accID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectExec("SAVEPOINT sync_insert").
		WillReturnResult(pgxmock.NewResult("SAVEPOINT", 0))
	mock.ExpectExec("INSERT INTO sync_operations").
		WithArgs(userUID, txnID, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	mock.ExpectExec("RELEASE SAVEPOINT sync_insert").
		WillReturnResult(pgxmock.NewResult("RELEASE", 0))
	mock.ExpectCommit()
	// Audit log
	mock.ExpectExec("INSERT INTO audit_logs").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	resp, err := svc.CreateTransaction(authedCtx(), &pb.CreateTransactionRequest{
		AccountId:  accID.String(),
		CategoryId: catID.String(),
		Amount:     200,
	})
	require.NoError(t, err)
	assert.NotNil(t, resp.Transaction)
}

// ════════════════════════════════════════════════════════════════════════════
// CreateTransaction — insufficient balance (overdraft protection)
// ════════════════════════════════════════════════════════════════════════════

func TestBoost2_CreateTransaction_InsufficientBalance(t *testing.T) {
	svc, mock := svcWithMock(t)
	accID := uuid.New()
	catID := uuid.New()

	mock.ExpectQuery("SELECT family_id.*user_id FROM accounts WHERE").
		WithArgs(accID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(nil, userUID))

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT user_id, family_id, type FROM accounts WHERE").
		WithArgs(accID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id", "type"}).
			AddRow(userUID, nil, "savings"))
	mock.ExpectQuery("SELECT EXISTS").WithArgs(catID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))
	mock.ExpectQuery("INSERT INTO transactions").
		WithArgs(userUID, accID, catID, int64(5000), "CNY", int64(5000), float64(1), "expense",
			"", pgxmock.AnyArg(), []string{}, []string{}).
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at", "updated_at"}).
			AddRow(uuid.New(), time.Now(), time.Now()))
	// Overdraft check: balance too low
	mock.ExpectQuery("SELECT balance FROM accounts WHERE id.*FOR UPDATE").
		WithArgs(accID).
		WillReturnRows(pgxmock.NewRows([]string{"balance"}).AddRow(int64(100)))
	mock.ExpectRollback()

	_, err := svc.CreateTransaction(authedCtx(), &pb.CreateTransactionRequest{
		AccountId:  accID.String(),
		CategoryId: catID.String(),
		Amount:     5000,
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.FailedPrecondition, st.Code())
	assert.Contains(t, st.Message(), "insufficient balance")
}

// Suppress unused import warnings
var _ = json.Marshal
