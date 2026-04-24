package account

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	pgxmock "github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"github.com/familyledger/server/pkg/middleware"
	pb "github.com/familyledger/server/proto/account"
)

func newTestService(t *testing.T) (*Service, pgxmock.PgxPoolIface) {
	t.Helper()
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	svc := NewService(mock)
	return svc, mock
}

func ctxWithUser(userID string) context.Context {
	return context.WithValue(context.Background(), middleware.UserIDKey, userID)
}

// columns shared by most SELECT queries on the accounts table
var accountColumns = []string{
	"id", "user_id", "family_id", "name", "type", "currency", "icon",
	"balance", "is_active", "is_default", "created_at", "updated_at",
}

// ─── CreateAccount ───────────────────────────────────────────────────────────

func TestCreateAccount_Success(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	userID := uuid.New().String()
	acctID := uuid.New()
	now := time.Now()

	mock.ExpectQuery("INSERT INTO accounts").
		WithArgs(
			pgxmock.AnyArg(), // user_id (uuid)
			"My Wallet",      // name
			"cash",           // type
			int64(0),         // balance
			"CNY",            // currency
			"",               // icon
			pgxmock.AnyArg(), // family_id (*uuid.UUID, nil)
		).
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at", "updated_at"}).AddRow(acctID, now, now))

	resp, err := svc.CreateAccount(ctxWithUser(userID), &pb.CreateAccountRequest{
		Name: "My Wallet",
		Type: pb.AccountType_ACCOUNT_TYPE_CASH,
	})

	require.NoError(t, err)
	assert.Equal(t, acctID.String(), resp.Account.Id)
	assert.Equal(t, "My Wallet", resp.Account.Name)
	assert.Equal(t, "CNY", resp.Account.Currency)
	assert.True(t, resp.Account.IsActive)
	assert.False(t, resp.Account.IsDefault)
}

func TestCreateAccount_NoAuth(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	_, err := svc.CreateAccount(context.Background(), &pb.CreateAccountRequest{
		Name: "My Wallet",
	})

	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestCreateAccount_EmptyName(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	userID := uuid.New().String()

	_, err := svc.CreateAccount(ctxWithUser(userID), &pb.CreateAccountRequest{
		Name: "",
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── ListAccounts ────────────────────────────────────────────────────────────

func TestListAccounts_Success(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	userID := uuid.New()
	acctID := uuid.New()
	now := time.Now()

	mock.ExpectQuery("SELECT id, user_id").
		WithArgs(userID).
		WillReturnRows(
			pgxmock.NewRows(accountColumns).
				AddRow(acctID, userID, "", "默认账户", "cash", "CNY", "", int64(0), true, true, now, now),
		)

	resp, err := svc.ListAccounts(ctxWithUser(userID.String()), &pb.ListAccountsRequest{})

	require.NoError(t, err)
	require.Len(t, resp.Accounts, 1)
	assert.Equal(t, "默认账户", resp.Accounts[0].Name)
}

func TestListAccounts_Empty(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	userID := uuid.New()

	mock.ExpectQuery("SELECT id, user_id").
		WithArgs(userID).
		WillReturnRows(pgxmock.NewRows(accountColumns))

	resp, err := svc.ListAccounts(ctxWithUser(userID.String()), &pb.ListAccountsRequest{})

	require.NoError(t, err)
	assert.Empty(t, resp.Accounts)
}

// ─── GetAccount ──────────────────────────────────────────────────────────────

func TestGetAccount_Success(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	userID := uuid.New()
	acctID := uuid.New()
	now := time.Now()

	mock.ExpectQuery("SELECT id, user_id").
		WithArgs(acctID).
		WillReturnRows(
			pgxmock.NewRows(accountColumns).
				AddRow(acctID, userID, "", "Cash", "cash", "CNY", "", int64(1000), true, false, now, now),
		)

	resp, err := svc.GetAccount(ctxWithUser(userID.String()), &pb.GetAccountRequest{
		AccountId: acctID.String(),
	})

	require.NoError(t, err)
	assert.Equal(t, acctID.String(), resp.Account.Id)
	assert.Equal(t, int64(1000), resp.Account.Balance)
}

func TestGetAccount_NotFound(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	userID := uuid.New()
	acctID := uuid.New()

	// Return empty rows → QueryRow.Scan gets pgx.ErrNoRows
	mock.ExpectQuery("SELECT id, user_id").
		WithArgs(acctID).
		WillReturnRows(pgxmock.NewRows(accountColumns))

	_, err := svc.GetAccount(ctxWithUser(userID.String()), &pb.GetAccountRequest{
		AccountId: acctID.String(),
	})

	require.Error(t, err)
	assert.Equal(t, codes.NotFound, status.Code(err))
}

// ─── UpdateAccount ───────────────────────────────────────────────────────────

func TestUpdateAccount_Success(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	userID := uuid.New()
	acctID := uuid.New()
	now := time.Now()
	newName := "Updated Wallet"

	// 1. Ownership check
	mock.ExpectQuery("SELECT user_id").
		WithArgs(acctID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(userID.String(), ""))

	// 2. Begin tx for partial update
	mock.ExpectBegin()
	mock.ExpectExec("UPDATE accounts SET name").
		WithArgs(newName, acctID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectCommit()

	// 3. Re-fetch via GetAccount
	mock.ExpectQuery("SELECT id, user_id").
		WithArgs(acctID).
		WillReturnRows(
			pgxmock.NewRows(accountColumns).
				AddRow(acctID, userID, "", newName, "cash", "CNY", "", int64(0), true, false, now, now),
		)

	resp, err := svc.UpdateAccount(ctxWithUser(userID.String()), &pb.UpdateAccountRequest{
		AccountId: acctID.String(),
		Name:      &newName,
	})

	require.NoError(t, err)
	assert.Equal(t, newName, resp.Account.Name)
}

func TestUpdateAccount_NotFound(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	userID := uuid.New()
	acctID := uuid.New()

	// Ownership check → not found
	mock.ExpectQuery("SELECT user_id").
		WithArgs(acctID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}))

	newName := "Won't Work"
	_, err := svc.UpdateAccount(ctxWithUser(userID.String()), &pb.UpdateAccountRequest{
		AccountId: acctID.String(),
		Name:      &newName,
	})

	require.Error(t, err)
	assert.Equal(t, codes.NotFound, status.Code(err))
}

// ─── DeleteAccount ───────────────────────────────────────────────────────────

func TestDeleteAccount_Success(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	userID := uuid.New()
	acctID := uuid.New()

	// Ownership check
	mock.ExpectQuery("SELECT user_id").
		WithArgs(acctID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(userID.String(), ""))

	// Soft delete
	mock.ExpectExec("UPDATE accounts SET is_active = false").
		WithArgs(acctID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	_, err := svc.DeleteAccount(ctxWithUser(userID.String()), &pb.DeleteAccountRequest{
		AccountId: acctID.String(),
	})

	require.NoError(t, err)
}
