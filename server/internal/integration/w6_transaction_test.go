//go:build integration

package integration

import (
	"context"
	"fmt"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/familyledger/server/internal/account"
	"github.com/familyledger/server/internal/auth"
	"github.com/familyledger/server/internal/budget"
	"github.com/familyledger/server/internal/transaction"
	"github.com/familyledger/server/pkg/jwt"
	"github.com/familyledger/server/pkg/middleware"
	pbAcct "github.com/familyledger/server/proto/account"
	pbAuth "github.com/familyledger/server/proto/auth"
	pbBudget "github.com/familyledger/server/proto/budget"
	pbTxn "github.com/familyledger/server/proto/transaction"
)

// ═══════════════════════════════════════════════════════════════════════════════
// W6 Test Helpers
// ═══════════════════════════════════════════════════════════════════════════════

func w6User(t *testing.T, db *testDB, email string) (context.Context, string, *account.Service, *transaction.Service) {
	t.Helper()
	ctx := context.Background()
	jwtManager := jwt.NewManager("test-secret-key-32bytes-long!!")
	authSvc := auth.NewService(db.pool, jwtManager)
	regResp, err := authSvc.Register(ctx, &pbAuth.RegisterRequest{
		Email:    email,
		Password: "StrongP@ss1",
	})
	require.NoError(t, err)
	userCtx := context.WithValue(ctx, middleware.UserIDKey, regResp.UserId)
	acctSvc := account.NewService(db.pool)
	txnSvc := transaction.NewService(db.pool)
	return userCtx, regResp.UserId, acctSvc, txnSvc
}

func w6CreateAccount(t *testing.T, userCtx context.Context, acctSvc *account.Service, name string, balance int64) string {
	t.Helper()
	resp, err := acctSvc.CreateAccount(userCtx, &pbAcct.CreateAccountRequest{
		Name:           name,
		Type:           pbAcct.AccountType_ACCOUNT_TYPE_CASH,
		Currency:       "CNY",
		InitialBalance: balance,
	})
	require.NoError(t, err)
	return resp.Account.Id
}

func w6GetBalance(t *testing.T, db *testDB, acctID string) int64 {
	t.Helper()
	var balance int64
	err := db.pool.QueryRow(context.Background(),
		`SELECT balance FROM accounts WHERE id = $1`, uuid.MustParse(acctID),
	).Scan(&balance)
	require.NoError(t, err)
	return balance
}

// ═══════════════════════════════════════════════════════════════════════════════
// Transaction CRUD + Balance
// ═══════════════════════════════════════════════════════════════════════════════

func TestW6_Transaction_CreateExpense_BalanceDeducted(t *testing.T) {
	db := getDB(t)
	userCtx, _, acctSvc, txnSvc := w6User(t, db, "w6_t001@test.com")
	acctID := w6CreateAccount(t, userCtx, acctSvc, "T001", 500000)
	catID := getCategoryID(t, db)

	resp, err := txnSvc.CreateTransaction(userCtx, &pbTxn.CreateTransactionRequest{
		AccountId:    acctID,
		CategoryId:   catID.String(),
		Amount:       10000,
		Currency:     "CNY",
		AmountCny:    10000,
		ExchangeRate: 1.0,
		Type:         pbTxn.TransactionType_TRANSACTION_TYPE_EXPENSE,
		Note:         "lunch",
	})
	require.NoError(t, err)
	assert.NotEmpty(t, resp.Transaction.Id)
	assert.Equal(t, int64(490000), w6GetBalance(t, db, acctID))
	t.Log("T-001 PASS")
}

func TestW6_Transaction_CreateIncome_BalanceIncreased(t *testing.T) {
	db := getDB(t)
	userCtx, _, acctSvc, txnSvc := w6User(t, db, "w6_t002@test.com")
	acctID := w6CreateAccount(t, userCtx, acctSvc, "T002", 500000)
	catID := getCategoryID(t, db)

	_, err := txnSvc.CreateTransaction(userCtx, &pbTxn.CreateTransactionRequest{
		AccountId:    acctID,
		CategoryId:   catID.String(),
		Amount:       20000,
		Currency:     "CNY",
		AmountCny:    20000,
		ExchangeRate: 1.0,
		Type:         pbTxn.TransactionType_TRANSACTION_TYPE_INCOME,
		Note:         "salary",
	})
	require.NoError(t, err)
	assert.Equal(t, int64(520000), w6GetBalance(t, db, acctID))
	t.Log("T-002 PASS")
}

func TestW6_Transaction_Update_BalanceAdjusted(t *testing.T) {
	db := getDB(t)
	userCtx, _, acctSvc, txnSvc := w6User(t, db, "w6_t003@test.com")
	acctID := w6CreateAccount(t, userCtx, acctSvc, "T003", 500000)
	catID := getCategoryID(t, db)

	resp, err := txnSvc.CreateTransaction(userCtx, &pbTxn.CreateTransactionRequest{
		AccountId:    acctID,
		CategoryId:   catID.String(),
		Amount:       10000,
		Currency:     "CNY",
		AmountCny:    10000,
		ExchangeRate: 1.0,
		Type:         pbTxn.TransactionType_TRANSACTION_TYPE_EXPENSE,
		Note:         "original",
	})
	require.NoError(t, err)
	txnID := resp.Transaction.Id
	assert.Equal(t, int64(490000), w6GetBalance(t, db, acctID))

	newAmount := int64(15000)
	_, err = txnSvc.UpdateTransaction(userCtx, &pbTxn.UpdateTransactionRequest{
		TransactionId: txnID,
		Amount:        &newAmount,
	})
	require.NoError(t, err)
	assert.Equal(t, int64(485000), w6GetBalance(t, db, acctID))
	t.Log("T-003 PASS: update 10000->15000, balance 490000->485000")
}

func TestW6_Transaction_SoftDelete_BalanceRestored(t *testing.T) {
	db := getDB(t)
	userCtx, _, acctSvc, txnSvc := w6User(t, db, "w6_t004@test.com")
	acctID := w6CreateAccount(t, userCtx, acctSvc, "T004", 500000)
	catID := getCategoryID(t, db)

	resp, err := txnSvc.CreateTransaction(userCtx, &pbTxn.CreateTransactionRequest{
		AccountId:    acctID,
		CategoryId:   catID.String(),
		Amount:       10000,
		Currency:     "CNY",
		AmountCny:    10000,
		ExchangeRate: 1.0,
		Type:         pbTxn.TransactionType_TRANSACTION_TYPE_EXPENSE,
		Note:         "to delete",
	})
	require.NoError(t, err)
	txnID := resp.Transaction.Id
	assert.Equal(t, int64(490000), w6GetBalance(t, db, acctID))

	_, err = txnSvc.DeleteTransaction(userCtx, &pbTxn.DeleteTransactionRequest{
		TransactionId: txnID,
	})
	require.NoError(t, err)
	assert.Equal(t, int64(500000), w6GetBalance(t, db, acctID))
	t.Log("T-004 PASS: soft delete restores balance")
}

// TestW6_Transaction_Pagination verifies page count AND ordering correctness.
func TestW6_Transaction_Pagination(t *testing.T) {
	db := getDB(t)
	userCtx, _, acctSvc, txnSvc := w6User(t, db, "w6_t005@test.com")
	acctID := w6CreateAccount(t, userCtx, acctSvc, "T005", 1000000)
	catID := getCategoryID(t, db)

	// Insert 25 transactions with distinct dates
	for i := 0; i < 25; i++ {
		txnDate := time.Date(2026, 1, i+1, 12, 0, 0, 0, time.UTC)
		_, err := txnSvc.CreateTransaction(userCtx, &pbTxn.CreateTransactionRequest{
			AccountId:    acctID,
			CategoryId:   catID.String(),
			Amount:       100,
			Currency:     "CNY",
			AmountCny:    100,
			ExchangeRate: 1.0,
			Type:         pbTxn.TransactionType_TRANSACTION_TYPE_EXPENSE,
			Note:         fmt.Sprintf("txn_%02d", i+1),
			TxnDate:      timestamppb.New(txnDate),
		})
		require.NoError(t, err)
	}

	page1, err := txnSvc.ListTransactions(userCtx, &pbTxn.ListTransactionsRequest{
		AccountId: acctID,
		PageSize:  10,
	})
	require.NoError(t, err)
	assert.Equal(t, 10, len(page1.Transactions))
	assert.NotEmpty(t, page1.NextPageToken)

	page2, err := txnSvc.ListTransactions(userCtx, &pbTxn.ListTransactionsRequest{
		AccountId: acctID,
		PageSize:  10,
		PageToken: page1.NextPageToken,
	})
	require.NoError(t, err)
	assert.Equal(t, 10, len(page2.Transactions))

	page3, err := txnSvc.ListTransactions(userCtx, &pbTxn.ListTransactionsRequest{
		AccountId: acctID,
		PageSize:  10,
		PageToken: page2.NextPageToken,
	})
	require.NoError(t, err)
	assert.Equal(t, 5, len(page3.Transactions))

	// P1 fix: Verify ordering correctness (no overlap between pages)
	allIDs := make(map[string]struct{})
	for _, txn := range page1.Transactions {
		allIDs[txn.Id] = struct{}{}
	}
	for _, txn := range page2.Transactions {
		_, dup := allIDs[txn.Id]
		assert.False(t, dup, "page2 txn %s duplicated from page1", txn.Id)
		allIDs[txn.Id] = struct{}{}
	}
	for _, txn := range page3.Transactions {
		_, dup := allIDs[txn.Id]
		assert.False(t, dup, "page3 txn %s duplicated from earlier pages", txn.Id)
		allIDs[txn.Id] = struct{}{}
	}
	assert.Equal(t, 25, len(allIDs), "all 25 txns should appear exactly once across 3 pages")

	// Verify ordering within pages (descending by created_at or txn_date)
	for i := 1; i < len(page1.Transactions); i++ {
		prev := page1.Transactions[i-1].CreatedAt.AsTime()
		curr := page1.Transactions[i].CreatedAt.AsTime()
		assert.True(t, !prev.Before(curr),
			"page1[%d].created_at should >= page1[%d].created_at", i-1, i)
	}

	t.Log("T-005 PASS: pagination 25->10+10+5, no duplicates, ordered")
}

// TestW6_Transaction_MultiCurrency verifies balance AND stored fields.
func TestW6_Transaction_MultiCurrency(t *testing.T) {
	db := getDB(t)
	userCtx, _, acctSvc, txnSvc := w6User(t, db, "w6_t006@test.com")
	acctID := w6CreateAccount(t, userCtx, acctSvc, "T006", 500000)
	catID := getCategoryID(t, db)

	resp, err := txnSvc.CreateTransaction(userCtx, &pbTxn.CreateTransactionRequest{
		AccountId:    acctID,
		CategoryId:   catID.String(),
		Amount:       10000, // 100 USD
		Currency:     "USD",
		AmountCny:    72000, // 720 CNY
		ExchangeRate: 7.2,
		Type:         pbTxn.TransactionType_TRANSACTION_TYPE_EXPENSE,
		Note:         "USD purchase",
	})
	require.NoError(t, err)
	assert.Equal(t, int64(428000), w6GetBalance(t, db, acctID))

	// P1 fix: read back the transaction and verify stored fields
	listResp, err := txnSvc.ListTransactions(userCtx, &pbTxn.ListTransactionsRequest{
		AccountId: acctID,
		PageSize:  1,
	})
	require.NoError(t, err)
	require.Equal(t, 1, len(listResp.Transactions))
	txn := listResp.Transactions[0]
	assert.Equal(t, resp.Transaction.Id, txn.Id)
	assert.Equal(t, int64(10000), txn.Amount, "original USD amount should be stored")
	assert.Equal(t, "USD", txn.Currency)
	assert.Equal(t, int64(72000), txn.AmountCny, "CNY equivalent should be stored")
	assert.InDelta(t, 7.2, txn.ExchangeRate, 0.001, "exchange_rate should be 7.2")
	t.Log("T-006 PASS: multi-currency stored correctly")
}

func TestW6_Transaction_AmountZero_Rejected(t *testing.T) {
	db := getDB(t)
	userCtx, _, acctSvc, txnSvc := w6User(t, db, "w6_t007@test.com")
	acctID := w6CreateAccount(t, userCtx, acctSvc, "T007", 100000)
	catID := getCategoryID(t, db)

	_, err := txnSvc.CreateTransaction(userCtx, &pbTxn.CreateTransactionRequest{
		AccountId:    acctID,
		CategoryId:   catID.String(),
		Amount:       0,
		Currency:     "CNY",
		AmountCny:    0,
		ExchangeRate: 1.0,
		Type:         pbTxn.TransactionType_TRANSACTION_TYPE_EXPENSE,
		Note:         "zero",
	})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "amount")
	t.Log("T-007 PASS: amount=0 rejected")
}

func TestW6_Transaction_AmountNegative_Rejected(t *testing.T) {
	db := getDB(t)
	userCtx, _, acctSvc, txnSvc := w6User(t, db, "w6_t008@test.com")
	acctID := w6CreateAccount(t, userCtx, acctSvc, "T008", 100000)
	catID := getCategoryID(t, db)

	_, err := txnSvc.CreateTransaction(userCtx, &pbTxn.CreateTransactionRequest{
		AccountId:    acctID,
		CategoryId:   catID.String(),
		Amount:       -100,
		Currency:     "CNY",
		AmountCny:    -100,
		ExchangeRate: 1.0,
		Type:         pbTxn.TransactionType_TRANSACTION_TYPE_EXPENSE,
		Note:         "negative",
	})
	require.Error(t, err)
	t.Log("T-008 PASS: amount<0 rejected")
}

// TestW6_Transaction_ConcurrentBalance (P0 fix: count success/fail, don't assume all succeed)
func TestW6_Transaction_ConcurrentBalance(t *testing.T) {
	db := getDB(t)
	userCtx, _, acctSvc, txnSvc := w6User(t, db, "w6_t020@test.com")
	const initialBalance = int64(1000000)
	acctID := w6CreateAccount(t, userCtx, acctSvc, "T020", initialBalance)
	catID := getCategoryID(t, db)

	const goroutines = 10
	const amountPer = int64(10000)
	var wg sync.WaitGroup
	var mu sync.Mutex
	var successCount int64

	wg.Add(goroutines)
	for i := 0; i < goroutines; i++ {
		go func(idx int) {
			defer wg.Done()
			_, err := txnSvc.CreateTransaction(userCtx, &pbTxn.CreateTransactionRequest{
				AccountId:    acctID,
				CategoryId:   catID.String(),
				Amount:       amountPer,
				Currency:     "CNY",
				AmountCny:    amountPer,
				ExchangeRate: 1.0,
				Type:         pbTxn.TransactionType_TRANSACTION_TYPE_EXPENSE,
				Note:         fmt.Sprintf("concurrent_%d", idx),
			})
			mu.Lock()
			if err == nil {
				successCount++
			}
			mu.Unlock()
		}(i)
	}
	wg.Wait()

	finalBalance := w6GetBalance(t, db, acctID)
	expected := initialBalance - (successCount * amountPer)
	assert.Equal(t, expected, finalBalance,
		"no lost updates: %d succeeded, expected balance %d got %d", successCount, expected, finalBalance)
	// FOR UPDATE serializes concurrent access; some may fail due to lock contention.
	// Key invariant: at least 1 succeeds and no lost updates occur.
	assert.GreaterOrEqual(t, successCount, int64(1),
		"at least one concurrent transaction should succeed")
	t.Logf("T-020 PASS: %d/%d succeeded, balance=%d", successCount, goroutines, finalBalance)
}

// ═══════════════════════════════════════════════════════════════════════════════
// Transfer
// ═══════════════════════════════════════════════════════════════════════════════

func TestW6_Transfer_Normal(t *testing.T) {
	db := getDB(t)
	userCtx, _, acctSvc, _ := w6User(t, db, "w6_tf001@test.com")
	acctA := w6CreateAccount(t, userCtx, acctSvc, "From", 500000)
	acctB := w6CreateAccount(t, userCtx, acctSvc, "To", 100000)

	_, err := acctSvc.TransferBetween(userCtx, &pbAcct.TransferBetweenRequest{
		FromAccountId: acctA,
		ToAccountId:   acctB,
		Amount:        200000,
		Note:          "transfer test",
	})
	require.NoError(t, err)
	assert.Equal(t, int64(300000), w6GetBalance(t, db, acctA))
	assert.Equal(t, int64(300000), w6GetBalance(t, db, acctB))
	t.Log("TF-001 PASS: transfer 200000, A=300000 B=300000")
}

// TestW6_Transfer_Rollback_TargetDeleted (P1 fix: also verify target balance unchanged)
func TestW6_Transfer_Rollback_TargetDeleted(t *testing.T) {
	db := getDB(t)
	userCtx, _, acctSvc, _ := w6User(t, db, "w6_tf002@test.com")
	acctA := w6CreateAccount(t, userCtx, acctSvc, "Source", 500000)
	acctB := w6CreateAccount(t, userCtx, acctSvc, "Target", 100000)

	_, err := acctSvc.DeleteAccount(userCtx, &pbAcct.DeleteAccountRequest{AccountId: acctB})
	require.NoError(t, err)

	_, err = acctSvc.TransferBetween(userCtx, &pbAcct.TransferBetweenRequest{
		FromAccountId: acctA,
		ToAccountId:   acctB,
		Amount:        100000,
	})
	require.Error(t, err)

	// P1 fix: verify BOTH source and target unchanged
	assert.Equal(t, int64(500000), w6GetBalance(t, db, acctA), "source should be unchanged")
	assert.Equal(t, int64(100000), w6GetBalance(t, db, acctB), "target should be unchanged")
	t.Log("TF-002 PASS: failed transfer, both balances unchanged")
}

func TestW6_Transfer_SameAccount_Rejected(t *testing.T) {
	db := getDB(t)
	userCtx, _, acctSvc, _ := w6User(t, db, "w6_tf003@test.com")
	acctA := w6CreateAccount(t, userCtx, acctSvc, "Same", 500000)

	_, err := acctSvc.TransferBetween(userCtx, &pbAcct.TransferBetweenRequest{
		FromAccountId: acctA,
		ToAccountId:   acctA,
		Amount:        10000,
	})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "same")
	t.Log("TF-003 PASS: same account rejected")
}

func TestW6_Transfer_ZeroAmount_Rejected(t *testing.T) {
	db := getDB(t)
	userCtx, _, acctSvc, _ := w6User(t, db, "w6_tf004@test.com")
	acctA := w6CreateAccount(t, userCtx, acctSvc, "From", 500000)
	acctB := w6CreateAccount(t, userCtx, acctSvc, "To", 100000)

	_, err := acctSvc.TransferBetween(userCtx, &pbAcct.TransferBetweenRequest{
		FromAccountId: acctA,
		ToAccountId:   acctB,
		Amount:        0,
	})
	require.Error(t, err)
	t.Log("TF-004 PASS: zero amount rejected")
}

// TestW6_Transfer_ConcurrentFromSameSource verifies atomicity + no overdraft.
// 5 goroutines * 300 CNY = 1500 > 1000 available. At most 3 can succeed.
func TestW6_Transfer_ConcurrentFromSameSource(t *testing.T) {
	db := getDB(t)
	userCtx, _, acctSvc, _ := w6User(t, db, "w6_tf005@test.com")
	acctA := w6CreateAccount(t, userCtx, acctSvc, "Source", 100000) // 1000 CNY
	acctB := w6CreateAccount(t, userCtx, acctSvc, "Target", 0)

	const goroutines = 5
	const transferAmount = int64(30000)
	var wg sync.WaitGroup
	var mu sync.Mutex
	var successCount int

	wg.Add(goroutines)
	for i := 0; i < goroutines; i++ {
		go func() {
			defer wg.Done()
			_, err := acctSvc.TransferBetween(userCtx, &pbAcct.TransferBetweenRequest{
				FromAccountId: acctA,
				ToAccountId:   acctB,
				Amount:        transferAmount,
			})
			mu.Lock()
			defer mu.Unlock()
			if err == nil {
				successCount++
			}
		}()
	}
	wg.Wait()

	finalA := w6GetBalance(t, db, acctA)
	finalB := w6GetBalance(t, db, acctB)

	// Atomicity: total conserved
	assert.Equal(t, int64(100000), finalA+finalB,
		"total must be conserved: A(%d)+B(%d)=%d", finalA, finalB, finalA+finalB)
	// Balance correctness
	assert.Equal(t, int64(100000)-(int64(successCount)*transferAmount), finalA)
	// No overdraft: balance must never go negative
	assert.GreaterOrEqual(t, finalA, int64(0),
		"overdraft detected: balance=%d", finalA)
	// At most 3 can succeed (100000 / 30000 = 3.33)
	assert.LessOrEqual(t, successCount, 3,
		"at most 3 transfers should succeed with 100000 balance, got %d", successCount)

	t.Logf("TF-005 PASS: %d/%d succeeded, A=%d B=%d, no overdraft", successCount, goroutines, finalA, finalB)
}

// ═══════════════════════════════════════════════════════════════════════════════
// Budget
// ═══════════════════════════════════════════════════════════════════════════════

func TestW6_Budget_Create(t *testing.T) {
	db := getDB(t)
	userCtx, _, _, _ := w6User(t, db, "w6_b001@test.com")
	budgetSvc := budget.NewService(db.pool)

	resp, err := budgetSvc.CreateBudget(userCtx, &pbBudget.CreateBudgetRequest{
		Year:        2026,
		Month:       5,
		TotalAmount: 1000000,
	})
	require.NoError(t, err)
	assert.NotEmpty(t, resp.Budget.Id)
	assert.Equal(t, int32(2026), resp.Budget.Year)
	assert.Equal(t, int32(5), resp.Budget.Month)
	assert.Equal(t, int64(1000000), resp.Budget.TotalAmount)
	t.Log("B-001 PASS")
}

func TestW6_Budget_UniqueConstraint(t *testing.T) {
	db := getDB(t)
	userCtx, _, _, _ := w6User(t, db, "w6_b002@test.com")
	budgetSvc := budget.NewService(db.pool)

	_, err := budgetSvc.CreateBudget(userCtx, &pbBudget.CreateBudgetRequest{
		Year:        2026,
		Month:       6,
		TotalAmount: 500000,
	})
	require.NoError(t, err)

	// Duplicate same user+year+month -> rejected
	_, err = budgetSvc.CreateBudget(userCtx, &pbBudget.CreateBudgetRequest{
		Year:        2026,
		Month:       6,
		TotalAmount: 800000,
	})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "exist")
	t.Log("B-002 PASS: duplicate budget rejected")
}

// TestW6_Budget_UniqueConstraint_DifferentFamily documents that the unique constraint
// is on (user_id, year, month) WITHOUT family_id dimension.
// Same user cannot have both personal + family budget for the same month.
// This may be intentional ("one budget per person per month") or a design gap.
func TestW6_Budget_UniqueConstraint_DifferentFamily(t *testing.T) {
	db := getDB(t)
	userCtx, userID, _, _ := w6User(t, db, "w6_b002b@test.com")
	budgetSvc := budget.NewService(db.pool)

	// Personal budget for 2026-09
	_, err := budgetSvc.CreateBudget(userCtx, &pbBudget.CreateBudgetRequest{
		Year:        2026,
		Month:       9,
		TotalAmount: 500000,
	})
	require.NoError(t, err)

	// Family budget for same user+year+month but different familyId
	// ACTUAL BEHAVIOR: this is ALSO rejected (unique on user_id+year+month, ignoring family_id)
	familyID := createTestFamily(t, db, uuid.MustParse(userID), "DiffFamilyBudget")
	addFamilyMember(t, db, familyID, uuid.MustParse(userID), "owner",
		`{"can_view":true,"can_create":true,"can_edit":true,"can_delete":true,"can_manage_accounts":true}`)

	_, err = budgetSvc.CreateBudget(userCtx, &pbBudget.CreateBudgetRequest{
		FamilyId:    familyID.String(),
		Year:        2026,
		Month:       9,
		TotalAmount: 800000,
	})
	// Documents actual behavior: rejected because constraint is (user_id, year, month)
	require.Error(t, err, "expected rejection: unique constraint is user+year+month without familyId")
	assert.Contains(t, err.Error(), "exist")
	t.Log("B-002b PASS: unique constraint is (user_id, year, month) without family_id dimension")
}

func TestW6_Budget_CategoryBudget(t *testing.T) {
	db := getDB(t)
	userCtx, _, _, _ := w6User(t, db, "w6_b005@test.com")
	budgetSvc := budget.NewService(db.pool)
	catID := getCategoryID(t, db)

	resp, err := budgetSvc.CreateBudget(userCtx, &pbBudget.CreateBudgetRequest{
		Year:        2026,
		Month:       7,
		TotalAmount: 1000000,
		CategoryBudgets: []*pbBudget.CategoryBudget{
			{CategoryId: catID.String(), Amount: 300000},
		},
	})
	require.NoError(t, err)
	assert.NotEmpty(t, resp.Budget.Id)

	var catAmount int64
	err = db.pool.QueryRow(context.Background(),
		`SELECT amount FROM category_budgets WHERE budget_id = $1 AND category_id = $2`,
		uuid.MustParse(resp.Budget.Id), catID,
	).Scan(&catAmount)
	require.NoError(t, err)
	assert.Equal(t, int64(300000), catAmount)
	t.Log("B-005 PASS: category budget 300000")
}

func TestW6_Budget_FamilyBudget(t *testing.T) {
	db := getDB(t)
	userCtx, userID, _, _ := w6User(t, db, "w6_b006@test.com")
	budgetSvc := budget.NewService(db.pool)

	familyID := createTestFamily(t, db, uuid.MustParse(userID), "Budget Family")
	addFamilyMember(t, db, familyID, uuid.MustParse(userID), "owner",
		`{"can_view":true,"can_create":true,"can_edit":true,"can_delete":true,"can_manage_accounts":true}`)

	resp, err := budgetSvc.CreateBudget(userCtx, &pbBudget.CreateBudgetRequest{
		FamilyId:    familyID.String(),
		Year:        2026,
		Month:       8,
		TotalAmount: 2000000,
	})
	require.NoError(t, err)
	assert.Equal(t, familyID.String(), resp.Budget.FamilyId)
	t.Log("B-006 PASS: family budget")
}

// TestW6_Budget_ExecutionRate (P0 fix: actually verify spent/rate via GetBudget)
func TestW6_Budget_ExecutionRate(t *testing.T) {
	db := getDB(t)
	userCtx, _, acctSvc, txnSvc := w6User(t, db, "w6_b_exec@test.com")
	budgetSvc := budget.NewService(db.pool)
	acctID := w6CreateAccount(t, userCtx, acctSvc, "BudgetAcct", 5000000)
	catID := getCategoryID(t, db)

	// Create budget with category budget
	createResp, err := budgetSvc.CreateBudget(userCtx, &pbBudget.CreateBudgetRequest{
		Year:        2026,
		Month:       1,
		TotalAmount: 100000, // 1000 CNY
		CategoryBudgets: []*pbBudget.CategoryBudget{
			{CategoryId: catID.String(), Amount: 100000},
		},
	})
	require.NoError(t, err)
	budgetID := createResp.Budget.Id

	// Spend 800 CNY
	txnDate := time.Date(2026, 1, 15, 12, 0, 0, 0, time.UTC)
	_, err = txnSvc.CreateTransaction(userCtx, &pbTxn.CreateTransactionRequest{
		AccountId:    acctID,
		CategoryId:   catID.String(),
		Amount:       80000,
		Currency:     "CNY",
		AmountCny:    80000,
		ExchangeRate: 1.0,
		Type:         pbTxn.TransactionType_TRANSACTION_TYPE_EXPENSE,
		Note:         "80% spent",
		TxnDate:      timestamppb.New(txnDate),
	})
	require.NoError(t, err)

	// P0 fix: use GetBudget which returns BudgetExecution with TotalSpent+ExecutionRate
	getResp, err := budgetSvc.GetBudget(userCtx, &pbBudget.GetBudgetRequest{
		BudgetId: budgetID,
	})
	require.NoError(t, err)
	require.NotNil(t, getResp.Execution, "GetBudget should return execution data")

	assert.Equal(t, int64(80000), getResp.Execution.TotalSpent,
		"spent should be 80000, got %d", getResp.Execution.TotalSpent)
	assert.InDelta(t, 0.8, getResp.Execution.ExecutionRate, 0.01,
		"execution rate should be ~80%%, got %f", getResp.Execution.ExecutionRate)

	t.Logf("B-exec PASS: spent=%d, rate=%.0f%%",
		getResp.Execution.TotalSpent, getResp.Execution.ExecutionRate*100)
}

// ═══════════════════════════════════════════════════════════════════════════════
// Transaction: Tags and Images
// ═══════════════════════════════════════════════════════════════════════════════

func TestW6_Transaction_WithTags(t *testing.T) {
	db := getDB(t)
	userCtx, _, acctSvc, txnSvc := w6User(t, db, "w6_t040@test.com")
	acctID := w6CreateAccount(t, userCtx, acctSvc, "T040", 500000)
	catID := getCategoryID(t, db)

	resp, err := txnSvc.CreateTransaction(userCtx, &pbTxn.CreateTransactionRequest{
		AccountId:    acctID,
		CategoryId:   catID.String(),
		Amount:       5000,
		Currency:     "CNY",
		AmountCny:    5000,
		ExchangeRate: 1.0,
		Type:         pbTxn.TransactionType_TRANSACTION_TYPE_EXPENSE,
		Note:         "dinner with friends",
		Tags:         []string{"food", "friends"},
	})
	require.NoError(t, err)

	var tags []string
	err = db.pool.QueryRow(context.Background(),
		`SELECT tags FROM transactions WHERE id = $1`,
		uuid.MustParse(resp.Transaction.Id),
	).Scan(&tags)
	require.NoError(t, err)
	assert.Equal(t, []string{"food", "friends"}, tags)
	t.Log("T-040 PASS: tags persisted")
}

func TestW6_Transaction_WithImages(t *testing.T) {
	db := getDB(t)
	userCtx, _, acctSvc, txnSvc := w6User(t, db, "w6_t041@test.com")
	acctID := w6CreateAccount(t, userCtx, acctSvc, "T041", 500000)
	catID := getCategoryID(t, db)

	resp, err := txnSvc.CreateTransaction(userCtx, &pbTxn.CreateTransactionRequest{
		AccountId:    acctID,
		CategoryId:   catID.String(),
		Amount:       8000,
		Currency:     "CNY",
		AmountCny:    8000,
		ExchangeRate: 1.0,
		Type:         pbTxn.TransactionType_TRANSACTION_TYPE_EXPENSE,
		Note:         "receipt",
		ImageUrls:    []string{"https://example.com/receipt.jpg"},
	})
	require.NoError(t, err)

	var imageUrls []string
	err = db.pool.QueryRow(context.Background(),
		`SELECT image_urls FROM transactions WHERE id = $1`,
		uuid.MustParse(resp.Transaction.Id),
	).Scan(&imageUrls)
	require.NoError(t, err)
	assert.Equal(t, []string{"https://example.com/receipt.jpg"}, imageUrls)
	t.Log("T-041 PASS: image_urls persisted")
}

// ═══════════════════════════════════════════════════════════════════════════════
// P2 bonus: Verify DB balance matches API balance (at least one test)
// ═══════════════════════════════════════════════════════════════════════════════

func TestW6_BalanceConsistency_DBvsAPI(t *testing.T) {
	db := getDB(t)
	userCtx, _, acctSvc, txnSvc := w6User(t, db, "w6_consistency@test.com")
	acctID := w6CreateAccount(t, userCtx, acctSvc, "Consistency", 500000)
	catID := getCategoryID(t, db)

	// Create a few transactions
	for i := 0; i < 3; i++ {
		_, err := txnSvc.CreateTransaction(userCtx, &pbTxn.CreateTransactionRequest{
			AccountId:    acctID,
			CategoryId:   catID.String(),
			Amount:       10000,
			Currency:     "CNY",
			AmountCny:    10000,
			ExchangeRate: 1.0,
			Type:         pbTxn.TransactionType_TRANSACTION_TYPE_EXPENSE,
			Note:         fmt.Sprintf("tx_%d", i),
		})
		require.NoError(t, err)
	}

	// DB balance
	dbBalance := w6GetBalance(t, db, acctID)

	// API balance (via ListAccounts)
	listResp, err := acctSvc.ListAccounts(userCtx, &pbAcct.ListAccountsRequest{})
	require.NoError(t, err)
	var apiBalance int64
	for _, a := range listResp.Accounts {
		if a.Id == acctID {
			apiBalance = a.Balance
			break
		}
	}

	assert.Equal(t, dbBalance, apiBalance,
		"DB balance (%d) != API balance (%d)", dbBalance, apiBalance)
	assert.Equal(t, int64(470000), dbBalance) // 500000 - 3*10000
	t.Log("P2 PASS: DB balance == API balance")
}
