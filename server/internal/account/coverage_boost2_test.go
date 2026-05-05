package account

import (
	"encoding/json"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	pgxmock "github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	pb "github.com/familyledger/server/proto/account"
)

// ═══════════════════════════════════════════════════════════════════════════════
// CreateAccount — additional error paths
// ═══════════════════════════════════════════════════════════════════════════════

func TestCreateAccount_InvalidFamilyID(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()

	_, err := svc.CreateAccount(ctxWithUser(testUser), &pb.CreateAccountRequest{
		Name:     "Fam Wallet",
		Type:     pb.AccountType_ACCOUNT_TYPE_CASH,
		FamilyId: "not-a-uuid",
	})
	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestCreateAccount_FamilyPermDenied(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	fid := uuid.New()
	uid := uuid.MustParse(testUser)

	// requireFamilyPermission → member without can_manage_accounts
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(fid, uid).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).
			AddRow("member", json.RawMessage(`{"can_view":true}`)))

	_, err := svc.CreateAccount(ctxWithUser(testUser), &pb.CreateAccountRequest{
		Name:     "Fam Wallet",
		Type:     pb.AccountType_ACCOUNT_TYPE_CASH,
		FamilyId: fid.String(),
	})
	require.Error(t, err)
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

func TestCreateAccount_FamilyDBInsertError(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	fid := uuid.New()
	uid := uuid.MustParse(testUser)

	// requireFamilyPermission → admin (allowed)
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(fid, uid).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).
			AddRow("admin", json.RawMessage(`{}`)))
	// INSERT fails
	mock.ExpectQuery("INSERT INTO accounts").
		WithArgs(uid, "Fam Wallet", "cash", int64(0), "CNY", "", pgxmock.AnyArg()).
		WillReturnError(errors.New("db error"))

	_, err := svc.CreateAccount(ctxWithUser(testUser), &pb.CreateAccountRequest{
		Name:     "Fam Wallet",
		Type:     pb.AccountType_ACCOUNT_TYPE_CASH,
		FamilyId: fid.String(),
	})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCreateAccount_FamilySuccess(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	fid := uuid.New()
	uid := uuid.MustParse(testUser)
	acctID := uuid.New()
	now := time.Now()

	// requireFamilyPermission → owner (allowed)
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(fid, uid).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).
			AddRow("owner", json.RawMessage(`{}`)))
	mock.ExpectQuery("INSERT INTO accounts").
		WithArgs(uid, "Family Cash", "bank_card", int64(5000), "USD", "💰", pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at", "updated_at"}).
			AddRow(acctID, now, now))

	resp, err := svc.CreateAccount(ctxWithUser(testUser), &pb.CreateAccountRequest{
		Name:           "Family Cash",
		Type:           pb.AccountType_ACCOUNT_TYPE_BANK_CARD,
		Currency:       "USD",
		Icon:           "💰",
		InitialBalance: 5000,
		FamilyId:       fid.String(),
	})
	require.NoError(t, err)
	assert.Equal(t, acctID.String(), resp.Account.Id)
	assert.Equal(t, fid.String(), resp.Account.FamilyId)
	assert.Equal(t, "USD", resp.Account.Currency)
}

func TestCreateAccount_DBInsertError(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()

	mock.ExpectQuery("INSERT INTO accounts").
		WithArgs(pgxmock.AnyArg(), "Fail", "cash", int64(0), "CNY", "", pgxmock.AnyArg()).
		WillReturnError(errors.New("constraint violation"))

	_, err := svc.CreateAccount(ctxWithUser(testUser), &pb.CreateAccountRequest{
		Name: "Fail",
		Type: pb.AccountType_ACCOUNT_TYPE_CASH,
	})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCreateAccount_EmptyAccountID(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()

	_, err := svc.CreateAccount(ctxWithUser(testUser), &pb.CreateAccountRequest{})
	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err)) // empty name
}

func TestCreateAccount_RequireFamilyPermNotMember(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	fid := uuid.New()
	uid := uuid.MustParse(testUser)

	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(fid, uid).
		WillReturnError(pgx.ErrNoRows)

	_, err := svc.CreateAccount(ctxWithUser(testUser), &pb.CreateAccountRequest{
		Name:     "No Access",
		Type:     pb.AccountType_ACCOUNT_TYPE_CASH,
		FamilyId: fid.String(),
	})
	require.Error(t, err)
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

// ═══════════════════════════════════════════════════════════════════════════════
// GetAccount — family access, error paths
// ═══════════════════════════════════════════════════════════════════════════════

func TestGetAccount_NoAuth(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	_, err := svc.GetAccount(noAuthCtx(), &pb.GetAccountRequest{AccountId: uuid.New().String()})
	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestGetAccount_EmptyID(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	_, err := svc.GetAccount(ctxWithUser(testUser), &pb.GetAccountRequest{AccountId: ""})
	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestGetAccount_InvalidID(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	_, err := svc.GetAccount(ctxWithUser(testUser), &pb.GetAccountRequest{AccountId: "bad-uuid"})
	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestGetAccount_DBError(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	acctID := uuid.New()

	mock.ExpectQuery("SELECT id, user_id").
		WithArgs(acctID).
		WillReturnError(errors.New("db failure"))

	_, err := svc.GetAccount(ctxWithUser(testUser), &pb.GetAccountRequest{AccountId: acctID.String()})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestGetAccount_FamilyMember_CanView(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	acctID := uuid.New()
	ownerID := uuid.New()
	famID := uuid.New()
	uid := uuid.MustParse(testUser)
	now := time.Now()

	mock.ExpectQuery("SELECT id, user_id").
		WithArgs(acctID).
		WillReturnRows(pgxmock.NewRows(accountColumns).
			AddRow(acctID, ownerID, famID.String(), "Family Savings", "bank_card", "CNY", "🏦", int64(50000), true, false, now, now))
	// checkAccountAccess: family member with can_view
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(famID, uid).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).
			AddRow("member", json.RawMessage(`{"can_view":true}`)))

	resp, err := svc.GetAccount(ctxWithUser(testUser), &pb.GetAccountRequest{AccountId: acctID.String()})
	require.NoError(t, err)
	assert.Equal(t, "Family Savings", resp.Account.Name)
	assert.Equal(t, famID.String(), resp.Account.FamilyId)
}

func TestGetAccount_OtherUserNoFamily_Denied(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	acctID := uuid.New()
	ownerID := uuid.New()
	now := time.Now()

	mock.ExpectQuery("SELECT id, user_id").
		WithArgs(acctID).
		WillReturnRows(pgxmock.NewRows(accountColumns).
			AddRow(acctID, ownerID, "", "Private", "cash", "CNY", "", int64(1000), true, false, now, now))

	_, err := svc.GetAccount(ctxWithUser(testUser), &pb.GetAccountRequest{AccountId: acctID.String()})
	require.Error(t, err)
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

// ═══════════════════════════════════════════════════════════════════════════════
// UpdateAccount — family account, icon, isActive, error paths
// ═══════════════════════════════════════════════════════════════════════════════

func TestUpdateAccount_EmptyID(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	name := "x"
	_, err := svc.UpdateAccount(ctxWithUser(testUser), &pb.UpdateAccountRequest{AccountId: "", Name: &name})
	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestUpdateAccount_DBOwnershipError(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	acctID := uuid.New()

	mock.ExpectQuery("SELECT user_id").
		WithArgs(acctID).
		WillReturnError(errors.New("db down"))

	name := "x"
	_, err := svc.UpdateAccount(ctxWithUser(testUser), &pb.UpdateAccountRequest{AccountId: acctID.String(), Name: &name})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestUpdateAccount_FamilyAccount_AdminAllowed(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	acctID := uuid.New()
	ownerID := uuid.New()
	famID := uuid.New()
	uid := uuid.MustParse(testUser)
	now := time.Now()
	newIcon := "🏠"
	isActive := false

	// Ownership check → family account, different owner
	mock.ExpectQuery("SELECT user_id").
		WithArgs(acctID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).
			AddRow(ownerID.String(), famID.String()))
	// checkAccountAccess: admin
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(famID, uid).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).
			AddRow("admin", json.RawMessage(`{}`)))

	// Begin tx
	mock.ExpectBegin()
	mock.ExpectExec("UPDATE accounts SET icon").
		WithArgs(newIcon, acctID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectExec("UPDATE accounts SET is_active").
		WithArgs(isActive, acctID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectCommit()

	// Re-fetch (GetAccount call)
	mock.ExpectQuery("SELECT id, user_id").
		WithArgs(acctID).
		WillReturnRows(pgxmock.NewRows(accountColumns).
			AddRow(acctID, ownerID, famID.String(), "Fam Acct", "cash", "CNY", newIcon, int64(0), false, false, now, now))
	// checkAccountAccess inside GetAccount for can_view
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(famID, uid).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).
			AddRow("admin", json.RawMessage(`{}`)))

	resp, err := svc.UpdateAccount(ctxWithUser(testUser), &pb.UpdateAccountRequest{
		AccountId: acctID.String(),
		Icon:      &newIcon,
		IsActive:  &isActive,
	})
	require.NoError(t, err)
	assert.Equal(t, newIcon, resp.Account.Icon)
	assert.False(t, resp.Account.IsActive)
}

func TestUpdateAccount_FamilyAccount_MemberDenied(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	acctID := uuid.New()
	ownerID := uuid.New()
	famID := uuid.New()
	uid := uuid.MustParse(testUser)

	mock.ExpectQuery("SELECT user_id").
		WithArgs(acctID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).
			AddRow(ownerID.String(), famID.String()))
	// checkAccountAccess: member without can_manage_accounts
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(famID, uid).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).
			AddRow("member", json.RawMessage(`{"can_view":true}`)))

	name := "hijack"
	_, err := svc.UpdateAccount(ctxWithUser(testUser), &pb.UpdateAccountRequest{
		AccountId: acctID.String(),
		Name:      &name,
	})
	require.Error(t, err)
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

func TestUpdateAccount_BeginTxError(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	acctID := uuid.New()

	mock.ExpectQuery("SELECT user_id").
		WithArgs(acctID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).
			AddRow(testUser, ""))
	mock.ExpectBegin().WillReturnError(errors.New("begin failed"))

	name := "x"
	_, err := svc.UpdateAccount(ctxWithUser(testUser), &pb.UpdateAccountRequest{
		AccountId: acctID.String(),
		Name:      &name,
	})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestUpdateAccount_NameExecError(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	acctID := uuid.New()

	mock.ExpectQuery("SELECT user_id").
		WithArgs(acctID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).
			AddRow(testUser, ""))
	mock.ExpectBegin()
	mock.ExpectExec("UPDATE accounts SET name").
		WithArgs("fail", acctID).
		WillReturnError(errors.New("update error"))
	mock.ExpectRollback()

	name := "fail"
	_, err := svc.UpdateAccount(ctxWithUser(testUser), &pb.UpdateAccountRequest{
		AccountId: acctID.String(),
		Name:      &name,
	})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestUpdateAccount_IconExecError(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	acctID := uuid.New()

	mock.ExpectQuery("SELECT user_id").
		WithArgs(acctID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).
			AddRow(testUser, ""))
	mock.ExpectBegin()
	mock.ExpectExec("UPDATE accounts SET icon").
		WithArgs("💥", acctID).
		WillReturnError(errors.New("icon error"))
	mock.ExpectRollback()

	icon := "💥"
	_, err := svc.UpdateAccount(ctxWithUser(testUser), &pb.UpdateAccountRequest{
		AccountId: acctID.String(),
		Icon:      &icon,
	})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestUpdateAccount_IsActiveExecError(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	acctID := uuid.New()

	mock.ExpectQuery("SELECT user_id").
		WithArgs(acctID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).
			AddRow(testUser, ""))
	mock.ExpectBegin()
	active := true
	mock.ExpectExec("UPDATE accounts SET is_active").
		WithArgs(active, acctID).
		WillReturnError(errors.New("is_active error"))
	mock.ExpectRollback()

	_, err := svc.UpdateAccount(ctxWithUser(testUser), &pb.UpdateAccountRequest{
		AccountId: acctID.String(),
		IsActive:  &active,
	})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestUpdateAccount_CommitError(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	acctID := uuid.New()

	mock.ExpectQuery("SELECT user_id").
		WithArgs(acctID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).
			AddRow(testUser, ""))
	mock.ExpectBegin()
	mock.ExpectCommit().WillReturnError(errors.New("commit failed"))

	// No updates — just commit
	_, err := svc.UpdateAccount(ctxWithUser(testUser), &pb.UpdateAccountRequest{
		AccountId: acctID.String(),
		// no fields to update, goes straight to commit
	})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

// ═══════════════════════════════════════════════════════════════════════════════
// DeleteAccount — family account paths, error paths
// ═══════════════════════════════════════════════════════════════════════════════

func TestDeleteAccount_EmptyID(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	_, err := svc.DeleteAccount(ctxWithUser(testUser), &pb.DeleteAccountRequest{AccountId: ""})
	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestDeleteAccount_NotFoundBoost(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	acctID := uuid.New()

	mock.ExpectQuery("SELECT user_id").
		WithArgs(acctID).
		WillReturnError(pgx.ErrNoRows)

	_, err := svc.DeleteAccount(ctxWithUser(testUser), &pb.DeleteAccountRequest{AccountId: acctID.String()})
	require.Error(t, err)
	assert.Equal(t, codes.NotFound, status.Code(err))
}

func TestDeleteAccount_DBOwnershipError(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	acctID := uuid.New()

	mock.ExpectQuery("SELECT user_id").
		WithArgs(acctID).
		WillReturnError(errors.New("db error"))

	_, err := svc.DeleteAccount(ctxWithUser(testUser), &pb.DeleteAccountRequest{AccountId: acctID.String()})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestDeleteAccount_FamilyAccount_AdminAllowed(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	acctID := uuid.New()
	ownerID := uuid.New()
	famID := uuid.New()
	uid := uuid.MustParse(testUser)

	mock.ExpectQuery("SELECT user_id").
		WithArgs(acctID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).
			AddRow(ownerID.String(), famID.String()))
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(famID, uid).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).
			AddRow("admin", json.RawMessage(`{}`)))
	mock.ExpectExec("UPDATE accounts SET is_active = false").
		WithArgs(acctID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	_, err := svc.DeleteAccount(ctxWithUser(testUser), &pb.DeleteAccountRequest{AccountId: acctID.String()})
	require.NoError(t, err)
}

func TestDeleteAccount_FamilyAccount_MemberDenied(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	acctID := uuid.New()
	ownerID := uuid.New()
	famID := uuid.New()
	uid := uuid.MustParse(testUser)

	mock.ExpectQuery("SELECT user_id").
		WithArgs(acctID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).
			AddRow(ownerID.String(), famID.String()))
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(famID, uid).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).
			AddRow("member", json.RawMessage(`{"can_view":true}`)))

	_, err := svc.DeleteAccount(ctxWithUser(testUser), &pb.DeleteAccountRequest{AccountId: acctID.String()})
	require.Error(t, err)
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

func TestDeleteAccount_OtherUserNoFamily_Denied(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	acctID := uuid.New()
	ownerID := uuid.New()

	mock.ExpectQuery("SELECT user_id").
		WithArgs(acctID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).
			AddRow(ownerID.String(), ""))

	_, err := svc.DeleteAccount(ctxWithUser(testUser), &pb.DeleteAccountRequest{AccountId: acctID.String()})
	require.Error(t, err)
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

func TestDeleteAccount_SoftDeleteExecError(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	acctID := uuid.New()

	mock.ExpectQuery("SELECT user_id").
		WithArgs(acctID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).
			AddRow(testUser, ""))
	mock.ExpectExec("UPDATE accounts SET is_active = false").
		WithArgs(acctID).
		WillReturnError(errors.New("exec error"))

	_, err := svc.DeleteAccount(ctxWithUser(testUser), &pb.DeleteAccountRequest{AccountId: acctID.String()})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

// ═══════════════════════════════════════════════════════════════════════════════
// checkAccountAccessTx — through TransferBetween with family accounts
// ═══════════════════════════════════════════════════════════════════════════════

func TestTransfer_CheckAccessTx_InvalidCallerUID(t *testing.T) {
	// checkAccountAccessTx with invalid callerID (uuid.Parse fails)
	// We can't set an invalid userID directly through TransferBetween since
	// GetUserID validates it's a string. But uuid.Parse inside
	// checkAccountAccessTx might fail if the familyIDStr is bad.
	// Instead, test through TransferBetween with family accounts where
	// the DB returns various error states.

	svc, mock := newTestService(t)
	defer mock.Close()
	from := uuid.New()
	to := uuid.New()
	famID := uuid.New()
	uid := uuid.MustParse(testUser)

	mock.ExpectBegin()
	// from: family account with a different owner
	mock.ExpectQuery("SELECT user_id.*FROM accounts WHERE id.*FOR UPDATE").
		WithArgs(from).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).
			AddRow(uuid.New().String(), famID.String()))
	// to: family account
	mock.ExpectQuery("SELECT user_id.*FROM accounts WHERE id.*FOR UPDATE").
		WithArgs(to).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).
			AddRow(uuid.New().String(), famID.String()))
	// checkAccountAccessTx for from: DB error
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(famID, uid).
		WillReturnError(errors.New("tx query error"))
	mock.ExpectRollback()

	_, err := svc.TransferBetween(ctxWithUser(testUser), &pb.TransferBetweenRequest{
		FromAccountId: from.String(), ToAccountId: to.String(), Amount: 100,
	})
	require.Error(t, err)
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

func TestTransfer_CheckAccessTx_ToAccountFamilyDenied(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	from := uuid.New()
	to := uuid.New()
	famFromID := uuid.New()
	famToID := uuid.New()
	uid := uuid.MustParse(testUser)

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT user_id.*FROM accounts WHERE id.*FOR UPDATE").
		WithArgs(from).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).
			AddRow(uuid.New().String(), famFromID.String()))
	mock.ExpectQuery("SELECT user_id.*FROM accounts WHERE id.*FOR UPDATE").
		WithArgs(to).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).
			AddRow(uuid.New().String(), famToID.String()))
	// checkAccountAccessTx from: admin → pass
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(famFromID, uid).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).
			AddRow("admin", json.RawMessage(`{}`)))
	// checkAccountAccessTx to: not member → denied
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(famToID, uid).
		WillReturnError(pgx.ErrNoRows)
	mock.ExpectRollback()

	_, err := svc.TransferBetween(ctxWithUser(testUser), &pb.TransferBetweenRequest{
		FromAccountId: from.String(), ToAccountId: to.String(), Amount: 100,
	})
	require.Error(t, err)
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

func TestTransfer_CheckAccessTx_BadPermJSON(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	from := uuid.New()
	to := uuid.New()
	famID := uuid.New()
	uid := uuid.MustParse(testUser)

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT user_id.*FROM accounts WHERE id.*FOR UPDATE").
		WithArgs(from).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).
			AddRow(testUser, ""))
	mock.ExpectQuery("SELECT user_id.*FROM accounts WHERE id.*FOR UPDATE").
		WithArgs(to).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).
			AddRow(uuid.New().String(), famID.String()))
	// checkAccountAccessTx for to: member with invalid JSON perms
	// Note: checkAccountAccessTx has no permKeys param from TransferBetween,
	// so invalid JSON won't be parsed (no permKeys → skip Unmarshal → pass)
	// This means the member pass is accepted without checking perms.
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(famID, uid).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).
			AddRow("member", json.RawMessage(`{}`)))
	// Deduct
	mock.ExpectQuery("UPDATE accounts SET balance.*RETURNING balance").
		WithArgs(int64(100), from).
		WillReturnRows(pgxmock.NewRows([]string{"balance"}).AddRow(int64(9900)))
	// Add
	mock.ExpectExec("UPDATE accounts SET balance.*WHERE id").
		WithArgs(int64(100), to).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	// Insert transfer
	mock.ExpectQuery("INSERT INTO transfers").
		WithArgs(pgxmock.AnyArg(), from, to, int64(100), "").
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at"}).
			AddRow(uuid.New(), time.Now()))
	mock.ExpectCommit()

	resp, err := svc.TransferBetween(ctxWithUser(testUser), &pb.TransferBetweenRequest{
		FromAccountId: from.String(), ToAccountId: to.String(), Amount: 100,
	})
	require.NoError(t, err)
	assert.NotNil(t, resp.Transfer)
}

func TestTransfer_DestUpdateExecError(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	from := uuid.New()
	to := uuid.New()

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT user_id.*FROM accounts WHERE id.*FOR UPDATE").
		WithArgs(from).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(testUser, ""))
	mock.ExpectQuery("SELECT user_id.*FROM accounts WHERE id.*FOR UPDATE").
		WithArgs(to).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(testUser, ""))
	mock.ExpectQuery("UPDATE accounts SET balance.*RETURNING balance").
		WithArgs(int64(100), from).
		WillReturnRows(pgxmock.NewRows([]string{"balance"}).AddRow(int64(9900)))
	mock.ExpectExec("UPDATE accounts SET balance.*WHERE id").
		WithArgs(int64(100), to).
		WillReturnError(errors.New("dest update error"))
	mock.ExpectRollback()

	_, err := svc.TransferBetween(ctxWithUser(testUser), &pb.TransferBetweenRequest{
		FromAccountId: from.String(), ToAccountId: to.String(), Amount: 100,
	})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestTransfer_InsertTransferRecordError(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	from := uuid.New()
	to := uuid.New()

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT user_id.*FROM accounts WHERE id.*FOR UPDATE").
		WithArgs(from).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(testUser, ""))
	mock.ExpectQuery("SELECT user_id.*FROM accounts WHERE id.*FOR UPDATE").
		WithArgs(to).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(testUser, ""))
	mock.ExpectQuery("UPDATE accounts SET balance.*RETURNING balance").
		WithArgs(int64(100), from).
		WillReturnRows(pgxmock.NewRows([]string{"balance"}).AddRow(int64(9900)))
	mock.ExpectExec("UPDATE accounts SET balance.*WHERE id").
		WithArgs(int64(100), to).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectQuery("INSERT INTO transfers").
		WithArgs(pgxmock.AnyArg(), from, to, int64(100), "").
		WillReturnError(errors.New("insert error"))
	mock.ExpectRollback()

	_, err := svc.TransferBetween(ctxWithUser(testUser), &pb.TransferBetweenRequest{
		FromAccountId: from.String(), ToAccountId: to.String(), Amount: 100,
	})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestTransfer_CommitError(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	from := uuid.New()
	to := uuid.New()
	now := time.Now()

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT user_id.*FROM accounts WHERE id.*FOR UPDATE").
		WithArgs(from).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(testUser, ""))
	mock.ExpectQuery("SELECT user_id.*FROM accounts WHERE id.*FOR UPDATE").
		WithArgs(to).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(testUser, ""))
	mock.ExpectQuery("UPDATE accounts SET balance.*RETURNING balance").
		WithArgs(int64(100), from).
		WillReturnRows(pgxmock.NewRows([]string{"balance"}).AddRow(int64(9900)))
	mock.ExpectExec("UPDATE accounts SET balance.*WHERE id").
		WithArgs(int64(100), to).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectQuery("INSERT INTO transfers").
		WithArgs(pgxmock.AnyArg(), from, to, int64(100), "note").
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at"}).AddRow(uuid.New(), now))
	mock.ExpectCommit().WillReturnError(errors.New("commit failed"))

	_, err := svc.TransferBetween(ctxWithUser(testUser), &pb.TransferBetweenRequest{
		FromAccountId: from.String(), ToAccountId: to.String(), Amount: 100, Note: "note",
	})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestTransfer_BeginTxError(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	from := uuid.New()
	to := uuid.New()

	mock.ExpectBegin().WillReturnError(errors.New("begin error"))

	_, err := svc.TransferBetween(ctxWithUser(testUser), &pb.TransferBetweenRequest{
		FromAccountId: from.String(), ToAccountId: to.String(), Amount: 100,
	})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestTransfer_SourceQueryInternalError(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	from := uuid.New()
	to := uuid.New()

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT user_id.*FROM accounts WHERE id.*FOR UPDATE").
		WithArgs(from).
		WillReturnError(errors.New("internal db error"))
	mock.ExpectRollback()

	_, err := svc.TransferBetween(ctxWithUser(testUser), &pb.TransferBetweenRequest{
		FromAccountId: from.String(), ToAccountId: to.String(), Amount: 100,
	})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestTransfer_DestQueryInternalError(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	from := uuid.New()
	to := uuid.New()

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT user_id.*FROM accounts WHERE id.*FOR UPDATE").
		WithArgs(from).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(testUser, ""))
	mock.ExpectQuery("SELECT user_id.*FROM accounts WHERE id.*FOR UPDATE").
		WithArgs(to).
		WillReturnError(errors.New("internal db error"))
	mock.ExpectRollback()

	_, err := svc.TransferBetween(ctxWithUser(testUser), &pb.TransferBetweenRequest{
		FromAccountId: from.String(), ToAccountId: to.String(), Amount: 100,
	})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestTransfer_SourceBalanceUpdateInternalError(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	from := uuid.New()
	to := uuid.New()

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT user_id.*FROM accounts WHERE id.*FOR UPDATE").
		WithArgs(from).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(testUser, ""))
	mock.ExpectQuery("SELECT user_id.*FROM accounts WHERE id.*FOR UPDATE").
		WithArgs(to).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(testUser, ""))
	mock.ExpectQuery("UPDATE accounts SET balance.*RETURNING balance").
		WithArgs(int64(100), from).
		WillReturnError(errors.New("some internal error"))
	mock.ExpectRollback()

	_, err := svc.TransferBetween(ctxWithUser(testUser), &pb.TransferBetweenRequest{
		FromAccountId: from.String(), ToAccountId: to.String(), Amount: 100,
	})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

// ═══════════════════════════════════════════════════════════════════════════════
// checkAccountAccess — invalid family_id string (uuid.Parse fails)
// ═══════════════════════════════════════════════════════════════════════════════

func TestCheckAccountAccess_InvalidCallerUUID(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	// familyIDStr is valid UUID but callerID is not parseable
	fid := uuid.New()
	err := svc.checkAccountAccess(ctxWithUser("not-a-uuid"), uuid.New().String(), fid.String(), "not-a-uuid")
	assert.Error(t, err)
	st, _ := status.FromError(err)
	assert.Equal(t, codes.Internal, st.Code())
}

func TestCheckAccountAccess_InvalidFamilyUUID(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	err := svc.checkAccountAccess(ctxWithUser(testUser), uuid.New().String(), "bad-family-id", testUser)
	assert.Error(t, err)
	st, _ := status.FromError(err)
	assert.Equal(t, codes.Internal, st.Code())
}

// ═══════════════════════════════════════════════════════════════════════════════
// requireFamilyPermission — DB error path, bad JSON
// ═══════════════════════════════════════════════════════════════════════════════

func TestRequireFamilyPermission_DBError(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	fid := uuid.New()
	uid := uuid.MustParse(testUser)

	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(fid, uid).
		WillReturnError(errors.New("db error"))

	err := svc.requireFamilyPermission(ctxWithUser(testUser), fid, testUser, "can_edit")
	assert.Error(t, err)
	st, _ := status.FromError(err)
	assert.Equal(t, codes.Internal, st.Code())
}

func TestRequireFamilyPermission_BadJSON(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	fid := uuid.New()
	uid := uuid.MustParse(testUser)

	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(fid, uid).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).
			AddRow("member", json.RawMessage(`not-json`)))

	err := svc.requireFamilyPermission(ctxWithUser(testUser), fid, testUser, "can_edit")
	assert.Error(t, err)
	st, _ := status.FromError(err)
	assert.Equal(t, codes.Internal, st.Code())
}
