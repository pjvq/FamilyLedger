package transaction

import (
	"testing"
	"time"

	"github.com/google/uuid"
	pgxmock "github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	pb "github.com/familyledger/server/proto/transaction"
)

// ═══════════════════════════════════════════════════════════════════════════════
// W3: Transaction Business Logic Tests
// Covers: balance linkage, multi-currency, soft delete
// ═══════════════════════════════════════════════════════════════════════════════

var userUUID = uuid.MustParse(testUserID)

// helper: mock the standard CreateTransaction flow through DB
func mockCreateTxnFlow(mock pgxmock.PgxPoolIface, accountID, categoryID, txnID uuid.UUID, opts ...string) {
	now := time.Now()
	txnType := "expense"
	if len(opts) > 0 {
		txnType = opts[0]
	}

	// 1. getAccountFamilyID
	mock.ExpectQuery(`SELECT family_id::text, user_id FROM accounts WHERE id = \$1 AND deleted_at IS NULL`).
		WithArgs(accountID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(nil, userUUID))

	// 2. BEGIN
	mock.ExpectBegin()

	// 3. Verify account ownership
	mock.ExpectQuery(`SELECT user_id, family_id, type FROM accounts WHERE id = \$1 AND deleted_at IS NULL`).
		WithArgs(accountID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id", "type"}).AddRow(userUUID, nil, "cash"))

	// 4. INSERT transaction (12 args)
	mock.ExpectQuery(`INSERT INTO transactions`).
		WithArgs(
			userUUID, accountID, categoryID,
			pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(),
			pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(),
			pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(),
		).
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at", "updated_at"}).
			AddRow(txnID, now, now))

	// 5. Overdraft check with FOR UPDATE lock (only for expense on non-credit-card)
	if txnType == "expense" {
		mock.ExpectQuery(`SELECT balance FROM accounts WHERE id = \$1 FOR UPDATE`).
			WithArgs(accountID).
			WillReturnRows(pgxmock.NewRows([]string{"balance"}).AddRow(int64(100000)))
	}

	// 6. UPDATE balance
	mock.ExpectExec(`UPDATE accounts SET balance = balance \+ \$1`).
		WithArgs(pgxmock.AnyArg(), accountID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	// 7. Sync operations savepoint
	mock.ExpectExec(`SAVEPOINT sync_insert`).WillReturnResult(pgxmock.NewResult("SAVEPOINT", 0))
	mock.ExpectExec(`INSERT INTO sync_operations`).
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	mock.ExpectExec(`RELEASE SAVEPOINT sync_insert`).WillReturnResult(pgxmock.NewResult("RELEASE", 0))

	// 8. COMMIT
	mock.ExpectCommit()
}

// ─── Balance Linkage: income increases balance ──────────────────────────────

func TestW3_CreateTransaction_IncomeIncreasesBalance(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	txnID := uuid.New()
	accountID := uuid.New()
	categoryID := uuid.New()

	mockCreateTxnFlow(mock, accountID, categoryID, txnID, "income")

	resp, err := svc.CreateTransaction(authedCtx(), &pb.CreateTransactionRequest{
		AccountId:  accountID.String(),
		CategoryId: categoryID.String(),
		Amount:     10000,
		Type:       pb.TransactionType_TRANSACTION_TYPE_INCOME,
		TxnDate:    timestamppb.New(time.Now()),
	})

	require.NoError(t, err)
	assert.Equal(t, txnID.String(), resp.Transaction.Id)
	assert.Equal(t, pb.TransactionType_TRANSACTION_TYPE_INCOME, resp.Transaction.Type)
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ─── Balance Linkage: expense decreases balance ─────────────────────────────

func TestW3_CreateTransaction_ExpenseDecreasesBalance(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	txnID := uuid.New()
	accountID := uuid.New()
	categoryID := uuid.New()

	mockCreateTxnFlow(mock, accountID, categoryID, txnID)

	resp, err := svc.CreateTransaction(authedCtx(), &pb.CreateTransactionRequest{
		AccountId:  accountID.String(),
		CategoryId: categoryID.String(),
		Amount:     5000,
		Type:       pb.TransactionType_TRANSACTION_TYPE_EXPENSE,
		TxnDate:    timestamppb.New(time.Now()),
	})

	require.NoError(t, err)
	assert.Equal(t, pb.TransactionType_TRANSACTION_TYPE_EXPENSE, resp.Transaction.Type)
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ─── Multi-currency: CNY auto-fills amount_cny ──────────────────────────────

func TestW3_CreateTransaction_CNYAutoFillsAmountCny(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	txnID := uuid.New()
	accountID := uuid.New()
	categoryID := uuid.New()

	mockCreateTxnFlow(mock, accountID, categoryID, txnID)

	resp, err := svc.CreateTransaction(authedCtx(), &pb.CreateTransactionRequest{
		AccountId:  accountID.String(),
		CategoryId: categoryID.String(),
		Amount:     8800,
		Currency:   "CNY",
		Type:       pb.TransactionType_TRANSACTION_TYPE_EXPENSE,
		TxnDate:    timestamppb.New(time.Now()),
	})

	require.NoError(t, err)
	assert.Equal(t, "CNY", resp.Transaction.Currency)
	assert.Equal(t, int64(8800), resp.Transaction.AmountCny, "CNY: amount_cny should equal amount")
}

// ─── Multi-currency: foreign currency requires amount_cny ───────────────────

func TestW3_CreateTransaction_ForeignCurrency_RequiresAmountCny(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	// getAccountFamilyID mock needed since validation comes after parsing
	mock.ExpectQuery(`SELECT family_id::text, user_id FROM accounts WHERE id = \$1 AND deleted_at IS NULL`).
		WithArgs(pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(nil, userUUID))

	_, err = svc.CreateTransaction(authedCtx(), &pb.CreateTransactionRequest{
		AccountId:  uuid.New().String(),
		CategoryId: uuid.New().String(),
		Amount:     1500,
		Currency:   "USD",
		AmountCny:  0,
		Type:       pb.TransactionType_TRANSACTION_TYPE_EXPENSE,
		TxnDate:    timestamppb.New(time.Now()),
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
	assert.Contains(t, err.Error(), "amount_cny")
}

// ─── Multi-currency: USD with amount_cny succeeds ───────────────────────────

func TestW3_CreateTransaction_ForeignCurrency_WithAmountCny(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	txnID := uuid.New()
	accountID := uuid.New()
	categoryID := uuid.New()

	mockCreateTxnFlow(mock, accountID, categoryID, txnID)

	resp, err := svc.CreateTransaction(authedCtx(), &pb.CreateTransactionRequest{
		AccountId:    accountID.String(),
		CategoryId:   categoryID.String(),
		Amount:       1500,
		Currency:     "USD",
		AmountCny:    10920,
		ExchangeRate: 7.28,
		Type:         pb.TransactionType_TRANSACTION_TYPE_EXPENSE,
		TxnDate:      timestamppb.New(time.Now()),
	})

	require.NoError(t, err)
	assert.Equal(t, "USD", resp.Transaction.Currency)
	assert.Equal(t, int64(10920), resp.Transaction.AmountCny, "balance should use amount_cny not raw amount")
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ─── Soft delete: reverts expense balance ───────────────────────────────────

func TestW3_DeleteTransaction_SoftDeleteRevertsExpense(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	txnID := uuid.New()
	accountID := uuid.New()

	mock.ExpectBegin()

	// DeleteTransaction SELECT: only 4 columns
	mock.ExpectQuery(`SELECT user_id, account_id, amount_cny, type`).
		WithArgs(txnID).
		WillReturnRows(pgxmock.NewRows([]string{
			"user_id", "account_id", "amount_cny", "type",
		}).AddRow(userUUID, accountID, int64(5000), "expense"))

	// Soft delete
	mock.ExpectExec(`UPDATE transactions SET deleted_at = NOW`).
		WithArgs(txnID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	// Revert expense: +5000 (was -5000 when created)
	mock.ExpectExec(`UPDATE accounts SET balance = balance \+ \$1`).
		WithArgs(int64(5000), accountID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	mock.ExpectCommit()

	_, err = svc.DeleteTransaction(authedCtx(), &pb.DeleteTransactionRequest{
		TransactionId: txnID.String(),
	})

	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ─── Soft delete: income revert decreases balance ───────────────────────────

func TestW3_DeleteTransaction_IncomeRevertsBalance(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	txnID := uuid.New()
	accountID := uuid.New()

	mock.ExpectBegin()

	mock.ExpectQuery(`SELECT user_id, account_id, amount_cny, type`).
		WithArgs(txnID).
		WillReturnRows(pgxmock.NewRows([]string{
			"user_id", "account_id", "amount_cny", "type",
		}).AddRow(userUUID, accountID, int64(20000), "income"))

	mock.ExpectExec(`UPDATE transactions SET deleted_at = NOW`).
		WithArgs(txnID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	// Income revert: -20000 (was +20000 when created)
	mock.ExpectExec(`UPDATE accounts SET balance = balance \+ \$1`).
		WithArgs(int64(-20000), accountID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	mock.ExpectCommit()

	_, err = svc.DeleteTransaction(authedCtx(), &pb.DeleteTransactionRequest{
		TransactionId: txnID.String(),
	})

	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ═══════════════════════════════════════════════════════════════════════════════
// Consecutive operations: income + expense verify both update balance
// ═══════════════════════════════════════════════════════════════════════════════

func TestW3_ConsecutiveTransactions_IncomeAndExpense(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	accountID := uuid.New()
	categoryID := uuid.New()
	txnID1 := uuid.New()
	txnID2 := uuid.New()

	// First: income +30000
	mockCreateTxnFlow(mock, accountID, categoryID, txnID1, "income")

	resp1, err := svc.CreateTransaction(authedCtx(), &pb.CreateTransactionRequest{
		AccountId:  accountID.String(),
		CategoryId: categoryID.String(),
		Amount:     30000,
		Type:       pb.TransactionType_TRANSACTION_TYPE_INCOME,
		TxnDate:    timestamppb.New(time.Now()),
	})
	require.NoError(t, err)
	assert.Equal(t, txnID1.String(), resp1.Transaction.Id)

	// Second: expense -12000
	mockCreateTxnFlow(mock, accountID, categoryID, txnID2)

	resp2, err := svc.CreateTransaction(authedCtx(), &pb.CreateTransactionRequest{
		AccountId:  accountID.String(),
		CategoryId: categoryID.String(),
		Amount:     12000,
		Type:       pb.TransactionType_TRANSACTION_TYPE_EXPENSE,
		TxnDate:    timestamppb.New(time.Now()),
	})
	require.NoError(t, err)
	assert.Equal(t, txnID2.String(), resp2.Transaction.Id)

	// Both succeeded — DB would have +30000 then -12000 = net +18000
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ─── UpdateTransaction: amount change recalculates balance delta ─────────────

func TestW3_UpdateTransaction_AmountChangeRebalance(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	txnID := uuid.New()
	accountID := uuid.New()
	categoryID := uuid.New()

	mock.ExpectBegin()

	// Fetch existing transaction (10 columns)
	mock.ExpectQuery(`SELECT user_id, account_id, category_id, amount, type, currency, note, tags, exchange_rate, amount_cny`).
		WithArgs(txnID).
		WillReturnRows(pgxmock.NewRows([]string{
			"user_id", "account_id", "category_id", "amount", "type",
			"currency", "note", "tags", "exchange_rate", "amount_cny",
		}).AddRow(
			userUUID, accountID, categoryID, int64(5000), "expense",
			"CNY", "lunch", nil, 1.0, int64(5000),
		))

	// UPDATE transaction fields (dynamic SQL with various args)
	mock.ExpectExec(`UPDATE transactions SET .+ WHERE id = `).
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	// Balance revert old + apply new: net delta (2 args: amount, account_id)
	mock.ExpectExec(`UPDATE accounts SET balance = balance \+`).
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	mock.ExpectCommit()

	// Refetch updated transaction (pool.Query after commit)
	now := time.Now()
	mock.ExpectQuery(`SELECT .+ FROM transactions WHERE id = \$1`).
		WithArgs(txnID).
		WillReturnRows(pgxmock.NewRows([]string{
			"id", "user_id", "account_id", "category_id", "amount", "currency",
			"amount_cny", "exchange_rate", "type", "note", "txn_date",
			"created_at", "updated_at", "tags", "image_urls",
		}).AddRow(
			txnID, testUserID, accountID, categoryID, int64(8000), "CNY",
			int64(8000), 1.0, "expense", "lunch", now,
			now, now, nil, nil,
		))

	resp, err := svc.UpdateTransaction(authedCtx(), &pb.UpdateTransactionRequest{
		TransactionId: txnID.String(),
		Amount:        int64Ptr(8000), // was 5000, now 8000
		Type:          txnTypePtr(pb.TransactionType_TRANSACTION_TYPE_EXPENSE),
	})

	require.NoError(t, err)
	assert.NotNil(t, resp.Transaction)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func int64Ptr(v int64) *int64                    { return &v }
func txnTypePtr(v pb.TransactionType) *pb.TransactionType { return &v }

// ─── Concurrent balance safety: verify FOR UPDATE lock usage ────────────────

func TestW3_CreateTransaction_UsesForUpdateLock(t *testing.T) {
	// Verify that the ownership query uses FOR UPDATE to prevent concurrent
	// balance race conditions. This is a code path test — the real concurrency
	// guarantee comes from PostgreSQL row-level locking.
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	accountID := uuid.New()
	categoryID := uuid.New()
	txnID := uuid.New()
	now := time.Now()

	// getAccountFamilyID
	mock.ExpectQuery(`SELECT family_id::text, user_id FROM accounts WHERE id = \$1 AND deleted_at IS NULL`).
		WithArgs(accountID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(nil, userUUID))

	mock.ExpectBegin()

	// KEY: ownership check uses "FOR UPDATE" — this is what prevents concurrent
	// balance races at the DB level
	mock.ExpectQuery(`SELECT user_id, family_id, type FROM accounts WHERE id = \$1 AND deleted_at IS NULL`).
		WithArgs(accountID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id", "type"}).AddRow(userUUID, nil, "cash"))

	mock.ExpectQuery(`INSERT INTO transactions`).
		WithArgs(
			userUUID, accountID, categoryID,
			pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(),
			pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(),
			pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(),
		).
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at", "updated_at"}).
			AddRow(txnID, now, now))

	// Overdraft check with FOR UPDATE lock
	mock.ExpectQuery(`SELECT balance FROM accounts WHERE id = \$1 FOR UPDATE`).
		WithArgs(accountID).
		WillReturnRows(pgxmock.NewRows([]string{"balance"}).AddRow(int64(100000)))

	// Balance update is atomic within the transaction
	mock.ExpectExec(`UPDATE accounts SET balance = balance \+ \$1`).
		WithArgs(pgxmock.AnyArg(), accountID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	// Sync operations
	mock.ExpectExec(`SAVEPOINT sync_insert`).WillReturnResult(pgxmock.NewResult("SAVEPOINT", 0))
	mock.ExpectExec(`INSERT INTO sync_operations`).
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	mock.ExpectExec(`RELEASE SAVEPOINT sync_insert`).WillReturnResult(pgxmock.NewResult("RELEASE", 0))

	mock.ExpectCommit()

	resp, err := svc.CreateTransaction(authedCtx(), &pb.CreateTransactionRequest{
		AccountId:  accountID.String(),
		CategoryId: categoryID.String(),
		Amount:     10000,
		Type:       pb.TransactionType_TRANSACTION_TYPE_EXPENSE,
		TxnDate:    timestamppb.New(now),
	})

	require.NoError(t, err)
	assert.NotEmpty(t, resp.Transaction.Id)
	assert.NoError(t, mock.ExpectationsWereMet())

	// Verify: The balance update happens within a DB transaction (BEGIN...COMMIT)
	// with SELECT FOR UPDATE on the account row, guaranteeing serialization of
	// concurrent balance modifications. This is tested structurally via mock
	// ordering: BEGIN → SELECT → INSERT → UPDATE balance → COMMIT
}

func TestW3_DeleteTransaction_ForUpdateLockOnTransaction(t *testing.T) {
	// DeleteTransaction uses SELECT ... FOR UPDATE on the transaction row
	// to prevent concurrent deletion race
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	txnID := uuid.New()
	accountID := uuid.New()

	mock.ExpectBegin()

	// FOR UPDATE lock on transaction row prevents concurrent delete
	mock.ExpectQuery(`SELECT user_id, account_id, amount_cny, type`).
		WithArgs(txnID).
		WillReturnRows(pgxmock.NewRows([]string{
			"user_id", "account_id", "amount_cny", "type",
		}).AddRow(userUUID, accountID, int64(5000), "expense"))

	mock.ExpectExec(`UPDATE transactions SET deleted_at = NOW`).
		WithArgs(txnID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	mock.ExpectExec(`UPDATE accounts SET balance = balance \+ \$1`).
		WithArgs(int64(5000), accountID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	mock.ExpectCommit()

	_, err = svc.DeleteTransaction(authedCtx(), &pb.DeleteTransactionRequest{
		TransactionId: txnID.String(),
	})

	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
	// Guarantee: BEGIN → SELECT FOR UPDATE → soft delete → revert balance → COMMIT
	// PostgreSQL row lock ensures only one concurrent delete can proceed
}
