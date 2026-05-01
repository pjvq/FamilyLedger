package security

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	pgxmock "github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/familyledger/server/internal/transaction"
	"github.com/familyledger/server/pkg/middleware"
	pb "github.com/familyledger/server/proto/transaction"
)

const testUserID = "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"

func authedCtx() context.Context {
	return context.WithValue(context.Background(), middleware.UserIDKey, testUserID)
}

// maliciousInputs contains SQL injection payloads and edge cases.
var maliciousInputs = []struct {
	name  string
	value string
}{
	{"sql_drop_table", "'; DROP TABLE transactions;--"},
	{"sql_or_bypass", "' OR '1'='1"},
	{"sql_union_select", "' UNION SELECT * FROM users--"},
	{"sql_comment", "admin'--"},
	{"sql_semicolon_chain", "1; DELETE FROM accounts WHERE 1=1;"},
	{"unicode_null_byte", "hello\x00world"},
	{"unicode_rtl_override", "hello\u202Eworld"},
	{"unicode_zerowidth", "hello\u200Bworld"},
	{"super_long_string", strings.Repeat("A", 10240)}, // 10KB
	{"empty_string", ""},
	{"only_whitespace", "   \t\n  "},
	{"html_script_tag", "<script>alert('xss')</script>"},
}

// TestCreateTransaction_SQLInjection_Note verifies that malicious note values
// are passed as parameterized query args and don't cause panics.
func TestCreateTransaction_SQLInjection_Note(t *testing.T) {
	for _, tc := range maliciousInputs {
		t.Run(tc.name, func(t *testing.T) {
			mock, err := pgxmock.NewPool()
			require.NoError(t, err)
			defer mock.Close()

			svc := transaction.NewService(mock)

			userUUID := uuid.MustParse(testUserID)
			accountID := uuid.New()
			categoryID := uuid.New()
			txnID := uuid.New()
			now := time.Now()

			// Setup mock expectations
			// Note: for super_long_string, only the ownership check fires (validation rejects after)
			mock.ExpectQuery("SELECT family_id::text, user_id FROM accounts").
				WithArgs(accountID).
				WillReturnRows(pgxmock.NewRows([]string{"family_id", "user_id"}).AddRow(nil, userUUID))

			if tc.name != "super_long_string" {
				mock.ExpectBegin()

				mock.ExpectQuery("SELECT user_id, family_id, type FROM accounts").
					WithArgs(accountID).
					WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id", "type"}).AddRow(userUUID, nil, "cash"))

				// Key assertion: the INSERT should receive the malicious string as a
				// parameterized argument ($9 = note), NOT spliced into the SQL.
				mock.ExpectQuery("INSERT INTO transactions").
					WithArgs(
						userUUID, accountID, categoryID,
						pgxmock.AnyArg(), // amount
						pgxmock.AnyArg(), // currency
						pgxmock.AnyArg(), // amount_cny
						pgxmock.AnyArg(), // exchange_rate
						pgxmock.AnyArg(), // type
						tc.value,         // note — exact malicious string as parameter
						pgxmock.AnyArg(), // txn_date
						pgxmock.AnyArg(), // tags
						pgxmock.AnyArg(), // image_urls
					).
					WillReturnRows(pgxmock.NewRows([]string{"id", "created_at", "updated_at"}).
						AddRow(txnID, now, now))

				mock.ExpectExec("UPDATE accounts SET balance").
					WithArgs(pgxmock.AnyArg(), accountID).
					WillReturnResult(pgxmock.NewResult("UPDATE", 1))

				// Overdraft check
				mock.ExpectQuery("SELECT balance FROM accounts WHERE id").
					WithArgs(accountID).
					WillReturnRows(pgxmock.NewRows([]string{"balance"}).AddRow(int64(100000)))

				// Sync operations
				mock.ExpectExec("SAVEPOINT sync_insert").WillReturnResult(pgxmock.NewResult("SAVEPOINT", 0))
				mock.ExpectExec("INSERT INTO sync_operations").
					WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
					WillReturnResult(pgxmock.NewResult("INSERT", 1))
				mock.ExpectExec("RELEASE SAVEPOINT sync_insert").WillReturnResult(pgxmock.NewResult("RELEASE", 0))

				mock.ExpectCommit()
			}

			resp, err := svc.CreateTransaction(authedCtx(), &pb.CreateTransactionRequest{
				AccountId:  accountID.String(),
				CategoryId: categoryID.String(),
				Amount:     1000,
				Type:       pb.TransactionType_TRANSACTION_TYPE_EXPENSE,
				Note:       tc.value,
				TxnDate:    timestamppb.Now(),
			})

			// Should NOT panic and should succeed with parameterized queries
			// Exception: super_long_string is now rejected by note length validation
			if tc.name == "super_long_string" {
				require.Error(t, err, "super_long_string should be rejected by validation")
				assert.Contains(t, err.Error(), "note exceeds maximum length")
			} else {
				require.NoError(t, err, "CreateTransaction should not fail for input: %s", tc.name)
				require.NotNil(t, resp)
				assert.Equal(t, tc.value, resp.Transaction.Note)
				assert.NoError(t, mock.ExpectationsWereMet())
			}
		})
	}
}

// TestCreateTransaction_SQLInjection_MaliciousUserID verifies that a malicious
// user ID (even if somehow injected into context) is handled safely as a UUID parse.
func TestCreateTransaction_SQLInjection_MaliciousUserID(t *testing.T) {
	maliciousIDs := []string{
		"' OR '1'='1",
		"'; DROP TABLE users;--",
		"00000000-0000-0000-0000-000000000000' OR 1=1--",
		strings.Repeat("x", 10240),
	}

	for _, malID := range maliciousIDs {
		t.Run(malID[:min(len(malID), 30)], func(t *testing.T) {
			mock, err := pgxmock.NewPool()
			require.NoError(t, err)
			defer mock.Close()

			svc := transaction.NewService(mock)

			// Inject malicious user ID into context
			ctx := context.WithValue(context.Background(), middleware.UserIDKey, malID)

			// Should fail gracefully at UUID parse, not at SQL level
			assert.NotPanics(t, func() {
				_, err := svc.CreateTransaction(ctx, &pb.CreateTransactionRequest{
					AccountId:  uuid.New().String(),
					CategoryId: uuid.New().String(),
					Amount:     1000,
					Type:       pb.TransactionType_TRANSACTION_TYPE_EXPENSE,
					Note:       "test",
				})
				// Should return an error (invalid UUID), but never panic
				assert.Error(t, err)
			})
		})
	}
}

// TestListTransactions_SQLInjection_AccountID verifies that malicious account_id
// values are safely handled (rejected at UUID parse level).
func TestListTransactions_SQLInjection_AccountID(t *testing.T) {
	maliciousAccountIDs := []string{
		"'; DROP TABLE transactions;--",
		"' OR '1'='1",
		"not-a-uuid",
		strings.Repeat("B", 10240),
	}

	for _, malID := range maliciousAccountIDs {
		t.Run(malID[:min(len(malID), 30)], func(t *testing.T) {
			mock, err := pgxmock.NewPool()
			require.NoError(t, err)
			defer mock.Close()

			svc := transaction.NewService(mock)

			assert.NotPanics(t, func() {
				_, err := svc.ListTransactions(authedCtx(), &pb.ListTransactionsRequest{
					AccountId: malID,
				})
				// Should return InvalidArgument, not panic or execute injected SQL
				assert.Error(t, err)
			})
		})
	}
}

// TestUpdateTransaction_SQLInjection_Note verifies parameterized note in updates.
func TestUpdateTransaction_SQLInjection_Note(t *testing.T) {
	injectionPayloads := []string{
		"'; DROP TABLE transactions;--",
		"' OR '1'='1",
		"'; UPDATE users SET role='admin' WHERE '1'='1",
		strings.Repeat("X", 10240),
	}

	for _, payload := range injectionPayloads {
		t.Run(payload[:min(len(payload), 30)], func(t *testing.T) {
			mock, err := pgxmock.NewPool()
			require.NoError(t, err)
			defer mock.Close()

			svc := transaction.NewService(mock)

			userUUID := uuid.MustParse(testUserID)
			txnID := uuid.New()
			accountID := uuid.New()
			categoryID := uuid.New()

			mock.ExpectBegin()

			// Fetch existing transaction
			mock.ExpectQuery("SELECT user_id, account_id, category_id").
				WithArgs(txnID).
				WillReturnRows(pgxmock.NewRows([]string{
					"user_id", "account_id", "category_id", "amount", "type",
					"currency", "note", "tags", "exchange_rate", "amount_cny",
				}).AddRow(
					userUUID, accountID, categoryID, int64(1000), "expense",
					"CNY", "old note", []string{}, float64(1.0), int64(1000),
				))

			// Dynamic UPDATE: note is passed as parameter
			mock.ExpectExec("UPDATE transactions SET").
				WithArgs(payload, txnID). // note = payload as parameter
				WillReturnResult(pgxmock.NewResult("UPDATE", 1))

			mock.ExpectCommit()

			// Return updated transaction
			cols := []string{"id", "user_id", "account_id", "category_id", "amount", "currency",
				"amount_cny", "exchange_rate", "type", "note", "txn_date", "created_at", "updated_at", "tags", "image_urls"}
			mock.ExpectQuery("SELECT id, user_id").
				WithArgs(txnID).
				WillReturnRows(pgxmock.NewRows(cols).AddRow(
					txnID, userUUID, accountID, categoryID, int64(1000), "CNY",
					int64(1000), float64(1.0), "expense", payload,
					time.Now(), time.Now(), time.Now(), []string{}, []string{},
				))

			notePtr := payload
			resp, err := svc.UpdateTransaction(authedCtx(), &pb.UpdateTransactionRequest{
				TransactionId: txnID.String(),
				Note:          &notePtr,
			})

			require.NoError(t, err)
			require.NotNil(t, resp)
			// The note should be stored verbatim as a parameter, not interpreted as SQL
			assert.Equal(t, payload, resp.Transaction.Note)
			assert.NoError(t, mock.ExpectationsWereMet())
		})
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
