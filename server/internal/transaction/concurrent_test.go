package transaction

import (
	"context"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	pgxmock "github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/familyledger/server/pkg/middleware"
	pb "github.com/familyledger/server/proto/transaction"
)

// These tests verify that the transaction service does not have data races
// when called concurrently. Run with: go test -race ./internal/transaction/...
//
// Note: pgxmock is not thread-safe, so we create separate mocks per goroutine
// or use MatchExpectationsInOrder(false) with sufficient expectations.

func TestConcurrent_CreateTransaction_NoRace(t *testing.T) {
	// Test that multiple concurrent CreateTransaction calls don't cause data races.
	// Each goroutine gets its own mock pool to avoid pgxmock thread-safety issues.
	const goroutines = 10

	var wg sync.WaitGroup
	wg.Add(goroutines)

	errors := make([]error, goroutines)

	for i := 0; i < goroutines; i++ {
		go func(idx int) {
			defer wg.Done()

			mock, err := pgxmock.NewPool()
			if err != nil {
				errors[idx] = err
				return
			}
			defer mock.Close()
			mock.MatchExpectationsInOrder(false)

			svc := NewService(mock)

			userUUID := uuid.MustParse(testUserID)
			accountID := uuid.New()
			categoryID := uuid.New()
			txnID := uuid.New()
			now := time.Now()

			// Setup expectations
			mock.ExpectQuery(`SELECT family_id::text, user_id FROM accounts WHERE id = \$1 AND deleted_at IS NULL`).
				WithArgs(accountID).
				WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(nil, userUUID))

			mock.ExpectBegin()

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
			mock.ExpectQuery(`SELECT balance FROM accounts WHERE id = \$1 FOR UPDATE`).WithArgs(accountID).WillReturnRows(pgxmock.NewRows([]string{"balance"}).AddRow(int64(100000)))

			mock.ExpectExec(`UPDATE accounts SET balance = balance \+ \$1`).
				WithArgs(pgxmock.AnyArg(), accountID).
				WillReturnResult(pgxmock.NewResult("UPDATE", 1))

			mock.ExpectExec(`SAVEPOINT sync_insert`).WillReturnResult(pgxmock.NewResult("SAVEPOINT", 0))
			mock.ExpectExec(`INSERT INTO sync_operations`).WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).WillReturnResult(pgxmock.NewResult("INSERT", 1))
			mock.ExpectExec(`RELEASE SAVEPOINT sync_insert`).WillReturnResult(pgxmock.NewResult("RELEASE", 0))
			mock.ExpectCommit()

			ctx := context.WithValue(context.Background(), middleware.UserIDKey, testUserID)
			_, err = svc.CreateTransaction(ctx, &pb.CreateTransactionRequest{
				AccountId:  accountID.String(),
				CategoryId: categoryID.String(),
				Amount:     1000,
				Type:       pb.TransactionType_TRANSACTION_TYPE_EXPENSE,
				Note:       "concurrent test",
				TxnDate:    timestamppb.Now(),
			})
			errors[idx] = err
		}(i)
	}

	wg.Wait()

	for i, err := range errors {
		assert.NoError(t, err, "goroutine %d failed", i)
	}
}

func TestConcurrent_UpdateTransaction_SameID_NoRace(t *testing.T) {
	// Test that concurrent UpdateTransaction calls targeting the same transaction ID
	// don't cause data races in the service layer.
	const goroutines = 5

	var wg sync.WaitGroup
	wg.Add(goroutines)

	txnID := uuid.New()
	accountID := uuid.New()
	categoryID := uuid.New()
	userUUID := uuid.MustParse(testUserID)
	errors := make([]error, goroutines)

	for i := 0; i < goroutines; i++ {
		go func(idx int) {
			defer wg.Done()

			mock, err := pgxmock.NewPool()
			if err != nil {
				errors[idx] = err
				return
			}
			defer mock.Close()
			mock.MatchExpectationsInOrder(false)

			svc := NewService(mock)

			mock.ExpectBegin()

			// Fetch existing transaction with FOR UPDATE
			mock.ExpectQuery(`SELECT user_id, account_id, category_id, amount, type, currency, note, tags, exchange_rate, amount_cny`).
				WithArgs(txnID).
				WillReturnRows(pgxmock.NewRows([]string{
					"user_id", "account_id", "category_id", "amount", "type",
					"currency", "note", "tags", "exchange_rate", "amount_cny",
				}).AddRow(
					userUUID, accountID, categoryID, int64(5000), "expense",
					"CNY", "old note", []string{}, float64(1.0), int64(5000),
				))

			// Dynamic UPDATE
			mock.ExpectExec(`UPDATE transactions SET`).
				WithArgs(pgxmock.AnyArg(), txnID).
				WillReturnResult(pgxmock.NewResult("UPDATE", 1))

			mock.ExpectCommit()

			// Fetch updated transaction for response
			mock.ExpectQuery(`SELECT id, user_id, account_id, category_id, amount, currency, amount_cny, exchange_rate, type, note, txn_date, created_at, updated_at, tags, image_urls`).
				WithArgs(txnID).
				WillReturnRows(pgxmock.NewRows([]string{
					"id", "user_id", "account_id", "category_id", "amount",
					"currency", "amount_cny", "exchange_rate", "type", "note",
					"txn_date", "created_at", "updated_at", "tags", "image_urls",
				}).AddRow(
					txnID, userUUID, accountID, categoryID, int64(6000),
					"CNY", int64(6000), float64(1.0), "expense", "updated note",
					time.Now(), time.Now(), time.Now(), []string{}, []string{},
				))

			ctx := context.WithValue(context.Background(), middleware.UserIDKey, testUserID)
			newNote := "updated note"
			_, err = svc.UpdateTransaction(ctx, &pb.UpdateTransactionRequest{
				TransactionId: txnID.String(),
				Note:          &newNote,
			})
			errors[idx] = err
		}(i)
	}

	wg.Wait()

	for i, err := range errors {
		assert.NoError(t, err, "goroutine %d failed", i)
	}
}

func TestConcurrent_CreateAndList_NoRace(t *testing.T) {
	// Test that concurrent CreateTransaction and ListTransactions don't panic.
	const writers = 5
	const readers = 5

	var wg sync.WaitGroup
	wg.Add(writers + readers)

	panicCaught := make(chan string, writers+readers)

	// Writers
	for i := 0; i < writers; i++ {
		go func() {
			defer wg.Done()
			defer func() {
				if r := recover(); r != nil {
					panicCaught <- "create panic"
				}
			}()

			mock, err := pgxmock.NewPool()
			if err != nil {
				return
			}
			defer mock.Close()
			mock.MatchExpectationsInOrder(false)

			svc := NewService(mock)
			userUUID := uuid.MustParse(testUserID)
			accountID := uuid.New()
			categoryID := uuid.New()
			txnID := uuid.New()
			now := time.Now()

			mock.ExpectQuery(`SELECT family_id::text, user_id FROM accounts WHERE id = \$1 AND deleted_at IS NULL`).
				WithArgs(accountID).
				WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(nil, userUUID))

			mock.ExpectBegin()

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

			mock.ExpectExec(`UPDATE accounts SET balance = balance \+ \$1`).
				WithArgs(pgxmock.AnyArg(), accountID).
				WillReturnResult(pgxmock.NewResult("UPDATE", 1))

			mock.ExpectExec(`SAVEPOINT sync_insert`).WillReturnResult(pgxmock.NewResult("SAVEPOINT", 0))
			mock.ExpectExec(`INSERT INTO sync_operations`).WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).WillReturnResult(pgxmock.NewResult("INSERT", 1))
			mock.ExpectExec(`RELEASE SAVEPOINT sync_insert`).WillReturnResult(pgxmock.NewResult("RELEASE", 0))
			mock.ExpectCommit()

			ctx := context.WithValue(context.Background(), middleware.UserIDKey, testUserID)
			_, _ = svc.CreateTransaction(ctx, &pb.CreateTransactionRequest{
				AccountId:  accountID.String(),
				CategoryId: categoryID.String(),
				Amount:     1000,
				Type:       pb.TransactionType_TRANSACTION_TYPE_INCOME,
				Note:       "concurrent",
				TxnDate:    timestamppb.Now(),
			})
		}()
	}

	// Readers
	for i := 0; i < readers; i++ {
		go func() {
			defer wg.Done()
			defer func() {
				if r := recover(); r != nil {
					panicCaught <- "list panic"
				}
			}()

			mock, err := pgxmock.NewPool()
			if err != nil {
				return
			}
			defer mock.Close()
			mock.MatchExpectationsInOrder(false)

			svc := NewService(mock)
			userUUID := uuid.MustParse(testUserID)

			// Count query
			mock.ExpectQuery(`SELECT COUNT\(\*\) FROM transactions`).
				WithArgs(userUUID, pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
				WillReturnRows(pgxmock.NewRows([]string{"count"}).AddRow(int32(0)))

			// List query - return empty result set
			mock.ExpectQuery(`SELECT t.id, t.user_id, t.account_id`).
				WithArgs(
					pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(),
					pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(),
					pgxmock.AnyArg(),
				).
				WillReturnError(pgx.ErrNoRows)

			ctx := context.WithValue(context.Background(), middleware.UserIDKey, testUserID)
			_, _ = svc.ListTransactions(ctx, &pb.ListTransactionsRequest{
				PageSize: 20,
			})
		}()
	}

	wg.Wait()
	close(panicCaught)

	for p := range panicCaught {
		t.Fatalf("caught panic: %s", p)
	}
}

func TestConcurrent_ServiceCreation_NoRace(t *testing.T) {
	// Verify that creating multiple Service instances concurrently is safe.
	const goroutines = 20

	var wg sync.WaitGroup
	wg.Add(goroutines)

	services := make([]*Service, goroutines)

	for i := 0; i < goroutines; i++ {
		go func(idx int) {
			defer wg.Done()
			mock, err := pgxmock.NewPool()
			require.NoError(t, err)
			services[idx] = NewService(mock, WithUploadDir("/tmp/test"), WithBaseURL("/test"))
		}(i)
	}

	wg.Wait()

	for i, svc := range services {
		assert.NotNil(t, svc, "service %d is nil", i)
	}
}
