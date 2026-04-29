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
func mockCreateTxnFlow(mock pgxmock.PgxPoolIface, accountID, categoryID, txnID uuid.UUID) {
	now := time.Now()

	// 1. getAccountFamilyID
	mock.ExpectQuery(`SELECT family_id::text FROM accounts WHERE id = \$1 AND deleted_at IS NULL`).
		WithArgs(accountID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id"}).AddRow(nil))

	// 2. BEGIN
	mock.ExpectBegin()

	// 3. Verify account ownership
	mock.ExpectQuery(`SELECT user_id, family_id FROM accounts WHERE id = \$1 AND deleted_at IS NULL`).
		WithArgs(accountID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(userUUID, nil))

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

	// 5. UPDATE balance
	mock.ExpectExec(`UPDATE accounts SET balance = balance \+ \$1`).
		WithArgs(pgxmock.AnyArg(), accountID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	// 6. COMMIT
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

	mockCreateTxnFlow(mock, accountID, categoryID, txnID)

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
	mock.ExpectQuery(`SELECT family_id::text FROM accounts WHERE id = \$1`).
		WithArgs(pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"family_id"}).AddRow(nil))

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
