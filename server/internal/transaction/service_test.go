package transaction

import (
	"context"
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

	"github.com/familyledger/server/pkg/middleware"
	pb "github.com/familyledger/server/proto/transaction"
)

const testUserID = "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"

func strPtr(s string) *string { return &s }

func authedCtx() context.Context {
	return context.WithValue(context.Background(), middleware.UserIDKey, testUserID)
}

func noAuthCtx() context.Context {
	return context.Background()
}

// --------------- CreateTransaction ---------------

func TestCreateTransaction_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	userUUID := uuid.MustParse(testUserID)
	accountID := uuid.New()
	categoryID := uuid.New()
	txnID := uuid.New()
	now := time.Now()

	mock.ExpectQuery(`SELECT family_id::text, user_id FROM accounts WHERE id = \$1 AND deleted_at IS NULL`).
		WithArgs(accountID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(nil, userUUID))

	// permission.Check for personal account (no family) - no query needed

	mock.ExpectBegin()

	// Verify account ownership
	mock.ExpectQuery(`SELECT user_id, family_id FROM accounts WHERE id = \$1 AND deleted_at IS NULL`).
		WithArgs(accountID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(userUUID, nil))

	// Insert transaction
	mock.ExpectQuery(`INSERT INTO transactions`).
		WithArgs(
			userUUID, accountID, categoryID,
			pgxmock.AnyArg(), // amount
			pgxmock.AnyArg(), // currency
			pgxmock.AnyArg(), // amount_cny
			pgxmock.AnyArg(), // exchange_rate
			pgxmock.AnyArg(), // type
			pgxmock.AnyArg(), // note
			pgxmock.AnyArg(), // txn_date
			pgxmock.AnyArg(), // tags
			pgxmock.AnyArg(), // image_urls
		).
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at", "updated_at"}).
			AddRow(txnID, now, now))

	// Update account balance
	mock.ExpectExec(`UPDATE accounts SET balance = balance \+ \$1`).
		WithArgs(pgxmock.AnyArg(), accountID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	mock.ExpectCommit()

	resp, err := svc.CreateTransaction(authedCtx(), &pb.CreateTransactionRequest{
		AccountId:  accountID.String(),
		CategoryId: categoryID.String(),
		Amount:     5000,
		Type:       pb.TransactionType_TRANSACTION_TYPE_EXPENSE,
		Note:       "lunch",
		TxnDate:    timestamppb.Now(),
	})

	require.NoError(t, err)
	require.NotNil(t, resp)
	assert.Equal(t, txnID.String(), resp.Transaction.Id)
	assert.Equal(t, testUserID, resp.Transaction.UserId)
	assert.Equal(t, int64(5000), resp.Transaction.Amount)
	assert.Equal(t, "CNY", resp.Transaction.Currency)
	assert.Equal(t, pb.TransactionType_TRANSACTION_TYPE_EXPENSE, resp.Transaction.Type)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestCreateTransaction_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	resp, err := svc.CreateTransaction(noAuthCtx(), &pb.CreateTransactionRequest{
		AccountId:  uuid.New().String(),
		CategoryId: uuid.New().String(),
		Amount:     1000,
	})

	require.Nil(t, resp)
	require.Error(t, err)
	st, ok := status.FromError(err)
	require.True(t, ok)
	assert.Equal(t, codes.Unauthenticated, st.Code())
}

func TestCreateTransaction_MissingFields(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	// Invalid account_id
	resp, err := svc.CreateTransaction(authedCtx(), &pb.CreateTransactionRequest{
		AccountId:  "not-a-uuid",
		CategoryId: uuid.New().String(),
		Amount:     1000,
	})
	require.Nil(t, resp)
	st, _ := status.FromError(err)
	assert.Equal(t, codes.InvalidArgument, st.Code())

	// Invalid category_id
	resp, err = svc.CreateTransaction(authedCtx(), &pb.CreateTransactionRequest{
		AccountId:  uuid.New().String(),
		CategoryId: "not-a-uuid",
		Amount:     1000,
	})
	require.Nil(t, resp)
	st, _ = status.FromError(err)
	assert.Equal(t, codes.InvalidArgument, st.Code())

	// Zero amount — needs family_id mock since parse succeeds
	mock.ExpectQuery(`SELECT family_id::text, user_id FROM accounts WHERE id = \$1 AND deleted_at IS NULL`).
		WithArgs(pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(nil, userUUID))
	resp, err = svc.CreateTransaction(authedCtx(), &pb.CreateTransactionRequest{
		AccountId:  uuid.New().String(),
		CategoryId: uuid.New().String(),
		Amount:     0,
	})
	require.Nil(t, resp)
	st, _ = status.FromError(err)
	assert.Equal(t, codes.InvalidArgument, st.Code())

	assert.NoError(t, mock.ExpectationsWereMet())
}

// --------------- ListTransactions ---------------

func TestListTransactions_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	txnID := uuid.New()
	userUUID := uuid.MustParse(testUserID)
	accountID := uuid.New()
	categoryID := uuid.New()
	now := time.Now()

	// Count query (first page, no cursor) — personal mode (family_id IS NULL)
	mock.ExpectQuery(`SELECT COUNT\(\*\) FROM transactions t`).  // now JOINs accounts
		WithArgs(
			userUUID,
			pgxmock.AnyArg(), // account_id
			pgxmock.AnyArg(), // start_date
			pgxmock.AnyArg(), // end_date
		).
		WillReturnRows(pgxmock.NewRows([]string{"count"}).AddRow(int32(1)))

	// List query — personal mode (family_id IS NULL)
	mock.ExpectQuery(`SELECT t.id, t.user_id, t.account_id, t.category_id, t.amount, t.currency, t.amount_cny, t.exchange_rate, t.type, t.note, t.txn_date, t.created_at, t.updated_at, t.tags, t.image_urls`).  // now JOINs accounts
		WithArgs(
			userUUID,
			pgxmock.AnyArg(), // account_id
			pgxmock.AnyArg(), // start_date
			pgxmock.AnyArg(), // end_date
			pgxmock.AnyArg(), // cursor_date
			pgxmock.AnyArg(), // cursor_id
			pgxmock.AnyArg(), // limit (pageSize+1)
		).
		WillReturnRows(pgxmock.NewRows([]string{
			"id", "user_id", "account_id", "category_id", "amount",
			"currency", "amount_cny", "exchange_rate", "type", "note",
			"txn_date", "created_at", "updated_at", "tags", "image_urls",
		}).AddRow(
			txnID, userUUID, accountID, categoryID, int64(5000),
			"CNY", int64(5000), float64(1.0), "expense", "lunch",
			now, now, now, []string{"food"}, []string{},
		))

	resp, err := svc.ListTransactions(authedCtx(), &pb.ListTransactionsRequest{
		PageSize: 20,
	})

	require.NoError(t, err)
	require.NotNil(t, resp)
	assert.Len(t, resp.Transactions, 1)
	assert.Equal(t, txnID.String(), resp.Transactions[0].Id)
	assert.Equal(t, int32(1), resp.TotalCount)
	assert.Equal(t, "", resp.NextPageToken) // only 1 item, no next page
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestListTransactions_Empty(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	userUUID := uuid.MustParse(testUserID)

	mock.ExpectQuery(`SELECT COUNT\(\*\) FROM transactions t`).
		WithArgs(userUUID, pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"count"}).AddRow(int32(0)))

	mock.ExpectQuery(`SELECT t.id, t.user_id, t.account_id`).
		WithArgs(userUUID, pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{
			"id", "user_id", "account_id", "category_id", "amount",
			"currency", "amount_cny", "exchange_rate", "type", "note",
			"txn_date", "created_at", "updated_at", "tags", "image_urls",
		}))

	resp, err := svc.ListTransactions(authedCtx(), &pb.ListTransactionsRequest{})

	require.NoError(t, err)
	require.NotNil(t, resp)
	assert.Empty(t, resp.Transactions)
	assert.Equal(t, int32(0), resp.TotalCount)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestListTransactions_WithPagination(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	userUUID := uuid.MustParse(testUserID)
	now := time.Now()

	// First page: count query runs (no cursor)
	mock.ExpectQuery(`SELECT COUNT\(\*\) FROM transactions t`).
		WithArgs(userUUID, pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"count"}).AddRow(int32(30)))

	// Return pageSize+1 (11) rows to trigger next_page_token
	rows := pgxmock.NewRows([]string{
		"id", "user_id", "account_id", "category_id", "amount",
		"currency", "amount_cny", "exchange_rate", "type", "note",
		"txn_date", "created_at", "updated_at", "tags", "image_urls",
	})
	for i := 0; i < 11; i++ {
		rows.AddRow(
			uuid.New(), userUUID, uuid.New(), uuid.New(), int64(1000),
			"CNY", int64(1000), float64(1.0), "expense", "item",
			now.Add(-time.Duration(i)*time.Hour), now, now, []string{}, []string{},
		)
	}

	mock.ExpectQuery(`SELECT t.id, t.user_id, t.account_id`).
		WithArgs(userUUID, pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(rows)

	resp, err := svc.ListTransactions(authedCtx(), &pb.ListTransactionsRequest{
		PageSize: 10,
	})

	require.NoError(t, err)
	require.NotNil(t, resp)
	assert.Len(t, resp.Transactions, 10)  // trimmed from 11 to 10
	assert.Equal(t, int32(30), resp.TotalCount)
	assert.NotEmpty(t, resp.NextPageToken) // cursor token present
	assert.Contains(t, resp.NextPageToken, "|") // format: "unixnano|uuid"
	assert.NoError(t, mock.ExpectationsWereMet())
}

// --------------- UpdateTransaction ---------------

func TestUpdateTransaction_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	userUUID := uuid.MustParse(testUserID)
	txnID := uuid.New()
	accountID := uuid.New()
	categoryID := uuid.New()
	now := time.Now()

	mock.ExpectBegin()

	// Fetch existing transaction (FOR UPDATE)
	mock.ExpectQuery(`SELECT user_id, account_id, category_id, amount, type, currency, note, tags, exchange_rate, amount_cny`).
		WithArgs(txnID).
		WillReturnRows(pgxmock.NewRows([]string{
			"user_id", "account_id", "category_id", "amount", "type",
			"currency", "note", "tags", "exchange_rate", "amount_cny",
		}).AddRow(
			userUUID, accountID, categoryID, int64(5000), "expense",
			"CNY", "old note", []string{}, float64(1.0), int64(5000),
		))

	// ownerID == uid → no permission check needed

	// Dynamic UPDATE
	mock.ExpectExec(`UPDATE transactions SET`).
		WithArgs(pgxmock.AnyArg(), txnID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	mock.ExpectCommit()

	// Fetch updated transaction (after commit, outside tx)
	mock.ExpectQuery(`SELECT id, user_id, account_id, category_id, amount, currency, amount_cny, exchange_rate, type, note, txn_date, created_at, updated_at, tags, image_urls`).
		WithArgs(txnID).
		WillReturnRows(pgxmock.NewRows([]string{
			"id", "user_id", "account_id", "category_id", "amount",
			"currency", "amount_cny", "exchange_rate", "type", "note",
			"txn_date", "created_at", "updated_at", "tags", "image_urls",
		}).AddRow(
			txnID, userUUID, accountID, categoryID, int64(5000),
			"CNY", int64(5000), float64(1.0), "expense", "new note",
			now, now, now, []string{}, []string{},
		))

	newNote := "new note"
	resp, err := svc.UpdateTransaction(authedCtx(), &pb.UpdateTransactionRequest{
		TransactionId: txnID.String(),
		Note:          &newNote,
	})

	require.NoError(t, err)
	require.NotNil(t, resp)
	assert.Equal(t, "new note", resp.Transaction.Note)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestUpdateTransaction_NotFound(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	txnID := uuid.New()

	mock.ExpectBegin()

	mock.ExpectQuery(`SELECT user_id, account_id, category_id, amount, type, currency, note, tags, exchange_rate, amount_cny`).
		WithArgs(txnID).
		WillReturnError(pgx.ErrNoRows)

	mock.ExpectRollback()

	newNote := "updated"
	resp, err := svc.UpdateTransaction(authedCtx(), &pb.UpdateTransactionRequest{
		TransactionId: txnID.String(),
		Note:          &newNote,
	})

	require.Nil(t, resp)
	require.Error(t, err)
	st, ok := status.FromError(err)
	require.True(t, ok)
	assert.Equal(t, codes.NotFound, st.Code())
	assert.NoError(t, mock.ExpectationsWereMet())
}

// --------------- DeleteTransaction ---------------

func TestDeleteTransaction_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	userUUID := uuid.MustParse(testUserID)
	txnID := uuid.New()
	accountID := uuid.New()

	mock.ExpectBegin()

	// Fetch transaction for ownership verification
	mock.ExpectQuery(`SELECT user_id, account_id, amount_cny, type`).
		WithArgs(txnID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "account_id", "amount_cny", "type"}).
			AddRow(userUUID, accountID, int64(5000), "expense"))

	// ownerID == uid → no permission check needed

	// Soft delete
	mock.ExpectExec(`UPDATE transactions SET deleted_at = NOW\(\), updated_at = NOW\(\) WHERE id = \$1`).
		WithArgs(txnID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	// Revert balance (expense → add back)
	mock.ExpectExec(`UPDATE accounts SET balance = balance \+ \$1`).
		WithArgs(int64(5000), accountID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	mock.ExpectCommit()

	resp, err := svc.DeleteTransaction(authedCtx(), &pb.DeleteTransactionRequest{
		TransactionId: txnID.String(),
	})

	require.NoError(t, err)
	require.NotNil(t, resp)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestDeleteTransaction_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	resp, err := svc.DeleteTransaction(noAuthCtx(), &pb.DeleteTransactionRequest{
		TransactionId: uuid.New().String(),
	})

	require.Nil(t, resp)
	require.Error(t, err)
	st, ok := status.FromError(err)
	require.True(t, ok)
	assert.Equal(t, codes.Unauthenticated, st.Code())
}

func TestDeleteTransaction_NotFound(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	txnID := uuid.New()

	mock.ExpectBegin()

	mock.ExpectQuery(`SELECT user_id, account_id, amount_cny, type`).
		WithArgs(txnID).
		WillReturnError(pgx.ErrNoRows)

	mock.ExpectRollback()

	resp, err := svc.DeleteTransaction(authedCtx(), &pb.DeleteTransactionRequest{
		TransactionId: txnID.String(),
	})

	require.Nil(t, resp)
	require.Error(t, err)
	st, ok := status.FromError(err)
	require.True(t, ok)
	assert.Equal(t, codes.NotFound, st.Code())
	assert.NoError(t, mock.ExpectationsWereMet())
}

// --------------- Family Permission Tests ---------------

const otherUserID = "b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22"

func TestUpdateTransaction_FamilyMemberWithEditPermission(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	// The transaction belongs to otherUserID, but current user (testUserID) has edit permission
	ownerUUID := uuid.MustParse(otherUserID)
	txnID := uuid.New()
	accountID := uuid.New()
	categoryID := uuid.New()
	familyID := uuid.New()
	now := time.Now()

	mock.ExpectBegin()

	// Fetch existing transaction (owned by other user)
	mock.ExpectQuery(`SELECT user_id, account_id, category_id, amount, type, currency, note, tags, exchange_rate, amount_cny`).
		WithArgs(txnID).
		WillReturnRows(pgxmock.NewRows([]string{
			"user_id", "account_id", "category_id", "amount", "type",
			"currency", "note", "tags", "exchange_rate", "amount_cny",
		}).AddRow(
			ownerUUID, accountID, categoryID, int64(5000), "expense",
			"CNY", "old note", []string{}, float64(1.0), int64(5000),
		))

	// getAccountFamilyID returns the family
	mock.ExpectQuery(`SELECT family_id::text, user_id FROM accounts WHERE id = \$1 AND deleted_at IS NULL`).
		WithArgs(accountID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(strPtr(familyID.String()), ownerUUID))

	// permission.Check: query family_members for current user's role/permissions
	mock.ExpectQuery(`SELECT role, permissions FROM family_members WHERE family_id = \$1 AND user_id = \$2`).
		WithArgs(familyID, uuid.MustParse(testUserID)).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).
			AddRow("member", []byte(`{"can_view":true,"can_create":true,"can_edit":true,"can_delete":false,"can_manage_accounts":false}`)))

	// Dynamic UPDATE
	mock.ExpectExec(`UPDATE transactions SET`).
		WithArgs(pgxmock.AnyArg(), txnID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	mock.ExpectCommit()

	// Fetch updated transaction
	mock.ExpectQuery(`SELECT id, user_id, account_id, category_id, amount, currency, amount_cny, exchange_rate, type, note, txn_date, created_at, updated_at, tags, image_urls`).
		WithArgs(txnID).
		WillReturnRows(pgxmock.NewRows([]string{
			"id", "user_id", "account_id", "category_id", "amount",
			"currency", "amount_cny", "exchange_rate", "type", "note",
			"txn_date", "created_at", "updated_at", "tags", "image_urls",
		}).AddRow(
			txnID, ownerUUID, accountID, categoryID, int64(5000),
			"CNY", int64(5000), float64(1.0), "expense", "updated by family member",
			now, now, now, []string{}, []string{},
		))

	newNote := "updated by family member"
	resp, err := svc.UpdateTransaction(authedCtx(), &pb.UpdateTransactionRequest{
		TransactionId: txnID.String(),
		Note:          &newNote,
	})

	require.NoError(t, err)
	require.NotNil(t, resp)
	assert.Equal(t, "updated by family member", resp.Transaction.Note)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestUpdateTransaction_FamilyAdminCanEdit(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	ownerUUID := uuid.MustParse(otherUserID)
	txnID := uuid.New()
	accountID := uuid.New()
	categoryID := uuid.New()
	familyID := uuid.New()
	now := time.Now()

	mock.ExpectBegin()

	mock.ExpectQuery(`SELECT user_id, account_id, category_id, amount, type, currency, note, tags, exchange_rate, amount_cny`).
		WithArgs(txnID).
		WillReturnRows(pgxmock.NewRows([]string{
			"user_id", "account_id", "category_id", "amount", "type",
			"currency", "note", "tags", "exchange_rate", "amount_cny",
		}).AddRow(
			ownerUUID, accountID, categoryID, int64(3000), "income",
			"CNY", "salary", []string{}, float64(1.0), int64(3000),
		))

	// getAccountFamilyID
	mock.ExpectQuery(`SELECT family_id::text, user_id FROM accounts WHERE id = \$1 AND deleted_at IS NULL`).
		WithArgs(accountID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(strPtr(familyID.String()), ownerUUID))

	// permission.Check: admin bypasses permission checks
	mock.ExpectQuery(`SELECT role, permissions FROM family_members WHERE family_id = \$1 AND user_id = \$2`).
		WithArgs(familyID, uuid.MustParse(testUserID)).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).
			AddRow("admin", []byte(`{"can_view":true,"can_create":true,"can_edit":true,"can_delete":true,"can_manage_accounts":true}`)))

	mock.ExpectExec(`UPDATE transactions SET`).
		WithArgs(pgxmock.AnyArg(), txnID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	mock.ExpectCommit()

	mock.ExpectQuery(`SELECT id, user_id, account_id, category_id, amount, currency, amount_cny, exchange_rate, type, note, txn_date, created_at, updated_at, tags, image_urls`).
		WithArgs(txnID).
		WillReturnRows(pgxmock.NewRows([]string{
			"id", "user_id", "account_id", "category_id", "amount",
			"currency", "amount_cny", "exchange_rate", "type", "note",
			"txn_date", "created_at", "updated_at", "tags", "image_urls",
		}).AddRow(
			txnID, ownerUUID, accountID, categoryID, int64(3000),
			"CNY", int64(3000), float64(1.0), "income", "updated",
			now, now, now, []string{}, []string{},
		))

	newNote := "updated"
	resp, err := svc.UpdateTransaction(authedCtx(), &pb.UpdateTransactionRequest{
		TransactionId: txnID.String(),
		Note:          &newNote,
	})

	require.NoError(t, err)
	require.NotNil(t, resp)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestUpdateTransaction_FamilyMemberWithoutEditPermission(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	ownerUUID := uuid.MustParse(otherUserID)
	txnID := uuid.New()
	accountID := uuid.New()
	categoryID := uuid.New()
	familyID := uuid.New()

	mock.ExpectBegin()

	mock.ExpectQuery(`SELECT user_id, account_id, category_id, amount, type, currency, note, tags, exchange_rate, amount_cny`).
		WithArgs(txnID).
		WillReturnRows(pgxmock.NewRows([]string{
			"user_id", "account_id", "category_id", "amount", "type",
			"currency", "note", "tags", "exchange_rate", "amount_cny",
		}).AddRow(
			ownerUUID, accountID, categoryID, int64(5000), "expense",
			"CNY", "note", []string{}, float64(1.0), int64(5000),
		))

	// getAccountFamilyID
	mock.ExpectQuery(`SELECT family_id::text, user_id FROM accounts WHERE id = \$1 AND deleted_at IS NULL`).
		WithArgs(accountID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(strPtr(familyID.String()), ownerUUID))

	// permission.Check: member without edit permission
	mock.ExpectQuery(`SELECT role, permissions FROM family_members WHERE family_id = \$1 AND user_id = \$2`).
		WithArgs(familyID, uuid.MustParse(testUserID)).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).
			AddRow("member", []byte(`{"can_view":true,"can_create":true,"can_edit":false,"can_delete":false,"can_manage_accounts":false}`)))

	mock.ExpectRollback()

	newNote := "should fail"
	resp, err := svc.UpdateTransaction(authedCtx(), &pb.UpdateTransactionRequest{
		TransactionId: txnID.String(),
		Note:          &newNote,
	})

	require.Nil(t, resp)
	require.Error(t, err)
	st, ok := status.FromError(err)
	require.True(t, ok)
	assert.Equal(t, codes.PermissionDenied, st.Code())
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestUpdateTransaction_NonFamilyMemberCannotEdit(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	ownerUUID := uuid.MustParse(otherUserID)
	txnID := uuid.New()
	accountID := uuid.New()
	categoryID := uuid.New()
	familyID := uuid.New()

	mock.ExpectBegin()

	mock.ExpectQuery(`SELECT user_id, account_id, category_id, amount, type, currency, note, tags, exchange_rate, amount_cny`).
		WithArgs(txnID).
		WillReturnRows(pgxmock.NewRows([]string{
			"user_id", "account_id", "category_id", "amount", "type",
			"currency", "note", "tags", "exchange_rate", "amount_cny",
		}).AddRow(
			ownerUUID, accountID, categoryID, int64(5000), "expense",
			"CNY", "note", []string{}, float64(1.0), int64(5000),
		))

	// getAccountFamilyID
	mock.ExpectQuery(`SELECT family_id::text, user_id FROM accounts WHERE id = \$1 AND deleted_at IS NULL`).
		WithArgs(accountID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(strPtr(familyID.String()), ownerUUID))

	// permission.Check: user not found in family_members
	mock.ExpectQuery(`SELECT role, permissions FROM family_members WHERE family_id = \$1 AND user_id = \$2`).
		WithArgs(familyID, uuid.MustParse(testUserID)).
		WillReturnError(pgx.ErrNoRows)

	mock.ExpectRollback()

	newNote := "should fail"
	resp, err := svc.UpdateTransaction(authedCtx(), &pb.UpdateTransactionRequest{
		TransactionId: txnID.String(),
		Note:          &newNote,
	})

	require.Nil(t, resp)
	require.Error(t, err)
	st, ok := status.FromError(err)
	require.True(t, ok)
	assert.Equal(t, codes.PermissionDenied, st.Code())
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestUpdateTransaction_PersonalAccountOtherUserBlocked(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	ownerUUID := uuid.MustParse(otherUserID)
	txnID := uuid.New()
	accountID := uuid.New()
	categoryID := uuid.New()

	mock.ExpectBegin()

	mock.ExpectQuery(`SELECT user_id, account_id, category_id, amount, type, currency, note, tags, exchange_rate, amount_cny`).
		WithArgs(txnID).
		WillReturnRows(pgxmock.NewRows([]string{
			"user_id", "account_id", "category_id", "amount", "type",
			"currency", "note", "tags", "exchange_rate", "amount_cny",
		}).AddRow(
			ownerUUID, accountID, categoryID, int64(5000), "expense",
			"CNY", "note", []string{}, float64(1.0), int64(5000),
		))

	// getAccountFamilyID returns empty (personal account)
	mock.ExpectQuery(`SELECT family_id::text, user_id FROM accounts WHERE id = \$1 AND deleted_at IS NULL`).
		WithArgs(accountID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(nil, ownerUUID))

	mock.ExpectRollback()

	newNote := "should fail"
	resp, err := svc.UpdateTransaction(authedCtx(), &pb.UpdateTransactionRequest{
		TransactionId: txnID.String(),
		Note:          &newNote,
	})

	require.Nil(t, resp)
	require.Error(t, err)
	st, ok := status.FromError(err)
	require.True(t, ok)
	assert.Equal(t, codes.PermissionDenied, st.Code())
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestDeleteTransaction_FamilyMemberWithDeletePermission(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	ownerUUID := uuid.MustParse(otherUserID)
	txnID := uuid.New()
	accountID := uuid.New()
	familyID := uuid.New()

	mock.ExpectBegin()

	mock.ExpectQuery(`SELECT user_id, account_id, amount_cny, type`).
		WithArgs(txnID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "account_id", "amount_cny", "type"}).
			AddRow(ownerUUID, accountID, int64(3000), "expense"))

	// getAccountFamilyID
	mock.ExpectQuery(`SELECT family_id::text, user_id FROM accounts WHERE id = \$1 AND deleted_at IS NULL`).
		WithArgs(accountID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(strPtr(familyID.String()), ownerUUID))

	// permission.Check: member with delete permission
	mock.ExpectQuery(`SELECT role, permissions FROM family_members WHERE family_id = \$1 AND user_id = \$2`).
		WithArgs(familyID, uuid.MustParse(testUserID)).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).
			AddRow("member", []byte(`{"can_view":true,"can_create":true,"can_edit":true,"can_delete":true,"can_manage_accounts":false}`)))

	// Soft delete
	mock.ExpectExec(`UPDATE transactions SET deleted_at = NOW\(\), updated_at = NOW\(\) WHERE id = \$1`).
		WithArgs(txnID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	// Revert balance
	mock.ExpectExec(`UPDATE accounts SET balance = balance \+ \$1`).
		WithArgs(int64(3000), accountID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	mock.ExpectCommit()

	resp, err := svc.DeleteTransaction(authedCtx(), &pb.DeleteTransactionRequest{
		TransactionId: txnID.String(),
	})

	require.NoError(t, err)
	require.NotNil(t, resp)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestDeleteTransaction_FamilyMemberWithoutDeletePermission(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	ownerUUID := uuid.MustParse(otherUserID)
	txnID := uuid.New()
	accountID := uuid.New()
	familyID := uuid.New()

	mock.ExpectBegin()

	mock.ExpectQuery(`SELECT user_id, account_id, amount_cny, type`).
		WithArgs(txnID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "account_id", "amount_cny", "type"}).
			AddRow(ownerUUID, accountID, int64(3000), "expense"))

	// getAccountFamilyID
	mock.ExpectQuery(`SELECT family_id::text, user_id FROM accounts WHERE id = \$1 AND deleted_at IS NULL`).
		WithArgs(accountID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(strPtr(familyID.String()), ownerUUID))

	// permission.Check: member without delete permission
	mock.ExpectQuery(`SELECT role, permissions FROM family_members WHERE family_id = \$1 AND user_id = \$2`).
		WithArgs(familyID, uuid.MustParse(testUserID)).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).
			AddRow("member", []byte(`{"can_view":true,"can_create":true,"can_edit":true,"can_delete":false,"can_manage_accounts":false}`)))

	mock.ExpectRollback()

	resp, err := svc.DeleteTransaction(authedCtx(), &pb.DeleteTransactionRequest{
		TransactionId: txnID.String(),
	})

	require.Nil(t, resp)
	require.Error(t, err)
	st, ok := status.FromError(err)
	require.True(t, ok)
	assert.Equal(t, codes.PermissionDenied, st.Code())
	assert.NoError(t, mock.ExpectationsWereMet())
}
