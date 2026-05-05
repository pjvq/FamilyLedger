package account

import (
	"context"
	"encoding/json"
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

const testUser = "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"

// ── protoTypeToString / stringToProtoType ───────────────────────────────────

func TestProtoTypeToString(t *testing.T) {
	tests := []struct {
		in  pb.AccountType
		out string
	}{
		{pb.AccountType_ACCOUNT_TYPE_CASH, "cash"},
		{pb.AccountType_ACCOUNT_TYPE_BANK_CARD, "bank_card"},
		{pb.AccountType_ACCOUNT_TYPE_CREDIT_CARD, "credit_card"},
		{pb.AccountType_ACCOUNT_TYPE_ALIPAY, "alipay"},
		{pb.AccountType_ACCOUNT_TYPE_WECHAT_PAY, "wechat_pay"},
		{pb.AccountType_ACCOUNT_TYPE_INVESTMENT, "investment"},
		{pb.AccountType_ACCOUNT_TYPE_OTHER, "other"},
		{pb.AccountType_ACCOUNT_TYPE_UNSPECIFIED, "cash"}, // default
	}
	for _, tt := range tests {
		assert.Equal(t, tt.out, protoTypeToString(tt.in))
	}
}

func TestStringToProtoType(t *testing.T) {
	tests := []struct {
		in  string
		out pb.AccountType
	}{
		{"cash", pb.AccountType_ACCOUNT_TYPE_CASH},
		{"bank_card", pb.AccountType_ACCOUNT_TYPE_BANK_CARD},
		{"credit_card", pb.AccountType_ACCOUNT_TYPE_CREDIT_CARD},
		{"alipay", pb.AccountType_ACCOUNT_TYPE_ALIPAY},
		{"wechat_pay", pb.AccountType_ACCOUNT_TYPE_WECHAT_PAY},
		{"investment", pb.AccountType_ACCOUNT_TYPE_INVESTMENT},
		{"other", pb.AccountType_ACCOUNT_TYPE_OTHER},
		{"unknown", pb.AccountType_ACCOUNT_TYPE_UNSPECIFIED},
	}
	for _, tt := range tests {
		assert.Equal(t, tt.out, stringToProtoType(tt.in))
	}
}

// ── TransferBetween ─────────────────────────────────────────────────────────

func TestTransfer_NoAuth(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	_, err := svc.TransferBetween(noAuthCtx(), &pb.TransferBetweenRequest{
		FromAccountId: uuid.New().String(), ToAccountId: uuid.New().String(), Amount: 100,
	})
	assert.Error(t, err)
}

func noAuthCtx() context.Context {
	return context.Background() // no UserIDKey set
}

func TestTransfer_EmptyFromTo(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	_, err := svc.TransferBetween(ctxWithUser(testUser), &pb.TransferBetweenRequest{Amount: 100})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.InvalidArgument, st.Code())
}

func TestTransfer_ZeroAmount(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	_, err := svc.TransferBetween(ctxWithUser(testUser), &pb.TransferBetweenRequest{
		FromAccountId: uuid.New().String(), ToAccountId: uuid.New().String(), Amount: 0,
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.InvalidArgument, st.Code())
}

func TestTransfer_SameAccount(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	id := uuid.New().String()
	_, err := svc.TransferBetween(ctxWithUser(testUser), &pb.TransferBetweenRequest{
		FromAccountId: id, ToAccountId: id, Amount: 100,
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.InvalidArgument, st.Code())
}

func TestTransfer_InvalidFromID(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	_, err := svc.TransferBetween(ctxWithUser(testUser), &pb.TransferBetweenRequest{
		FromAccountId: "bad", ToAccountId: uuid.New().String(), Amount: 100,
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.InvalidArgument, st.Code())
}

func TestTransfer_InvalidToID(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	_, err := svc.TransferBetween(ctxWithUser(testUser), &pb.TransferBetweenRequest{
		FromAccountId: uuid.New().String(), ToAccountId: "bad", Amount: 100,
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.InvalidArgument, st.Code())
}

func TestTransfer_FromNotFound(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	from := uuid.New()
	to := uuid.New()

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT user_id.*FROM accounts WHERE id.*FOR UPDATE").
		WithArgs(from).
		WillReturnError(pgx.ErrNoRows)
	mock.ExpectRollback()

	_, err := svc.TransferBetween(ctxWithUser(testUser), &pb.TransferBetweenRequest{
		FromAccountId: from.String(), ToAccountId: to.String(), Amount: 100,
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.NotFound, st.Code())
}

func TestTransfer_ToNotFound(t *testing.T) {
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
		WillReturnError(pgx.ErrNoRows)
	mock.ExpectRollback()

	_, err := svc.TransferBetween(ctxWithUser(testUser), &pb.TransferBetweenRequest{
		FromAccountId: from.String(), ToAccountId: to.String(), Amount: 100,
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.NotFound, st.Code())
}

func TestTransfer_Success(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	from := uuid.New()
	to := uuid.New()
	transferID := uuid.New()
	now := time.Now()

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT user_id.*FROM accounts WHERE id.*FOR UPDATE").
		WithArgs(from).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(testUser, ""))
	mock.ExpectQuery("SELECT user_id.*FROM accounts WHERE id.*FOR UPDATE").
		WithArgs(to).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(testUser, ""))
	mock.ExpectQuery("UPDATE accounts SET balance = balance.*RETURNING balance").
		WithArgs(int64(500), from).
		WillReturnRows(pgxmock.NewRows([]string{"balance"}).AddRow(int64(9500)))
	mock.ExpectExec("UPDATE accounts SET balance = balance.*WHERE id").
		WithArgs(int64(500), to).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectQuery("INSERT INTO transfers").
		WithArgs(pgxmock.AnyArg(), from, to, int64(500), "note").
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at"}).AddRow(transferID, now))
	mock.ExpectCommit()

	resp, err := svc.TransferBetween(ctxWithUser(testUser), &pb.TransferBetweenRequest{
		FromAccountId: from.String(), ToAccountId: to.String(), Amount: 500, Note: "note",
	})
	require.NoError(t, err)
	assert.Equal(t, transferID.String(), resp.Transfer.Id)
	assert.Equal(t, int64(500), resp.Transfer.Amount)
}

func TestTransfer_InsufficientBalance(t *testing.T) {
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
	mock.ExpectQuery("UPDATE accounts SET balance = balance.*RETURNING balance").
		WithArgs(int64(100), from).
		WillReturnError(pgx.ErrNoRows)
	mock.ExpectRollback()

	_, err := svc.TransferBetween(ctxWithUser(testUser), &pb.TransferBetweenRequest{
		FromAccountId: from.String(), ToAccountId: to.String(), Amount: 100,
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.FailedPrecondition, st.Code())
}

func TestTransfer_NoAccessToSource(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	from := uuid.New()
	to := uuid.New()
	otherUser := uuid.New().String()

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT user_id.*FROM accounts WHERE id.*FOR UPDATE").
		WithArgs(from).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(otherUser, ""))
	mock.ExpectQuery("SELECT user_id.*FROM accounts WHERE id.*FOR UPDATE").
		WithArgs(to).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(testUser, ""))
	mock.ExpectRollback()

	_, err := svc.TransferBetween(ctxWithUser(testUser), &pb.TransferBetweenRequest{
		FromAccountId: from.String(), ToAccountId: to.String(), Amount: 100,
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.PermissionDenied, st.Code())
}

// ── checkAccountAccess ──────────────────────────────────────────────────────

func TestCheckAccountAccess_Owner(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	err := svc.checkAccountAccess(ctxWithUser(testUser), testUser, "", testUser)
	assert.NoError(t, err)
}

func TestCheckAccountAccess_NoFamily(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	err := svc.checkAccountAccess(ctxWithUser(testUser), uuid.New().String(), "", testUser)
	assert.Error(t, err) // PermissionDenied
}

func TestCheckAccountAccess_FamilyOwner(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	fid := uuid.New()
	uid := uuid.MustParse(testUser)

	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(fid, uid).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).AddRow("owner", json.RawMessage(`{}`)))

	err := svc.checkAccountAccess(ctxWithUser(testUser), uuid.New().String(), fid.String(), testUser)
	assert.NoError(t, err)
}

func TestCheckAccountAccess_FamilyAdmin(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	fid := uuid.New()
	uid := uuid.MustParse(testUser)

	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(fid, uid).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).AddRow("admin", json.RawMessage(`{}`)))

	err := svc.checkAccountAccess(ctxWithUser(testUser), uuid.New().String(), fid.String(), testUser)
	assert.NoError(t, err)
}

func TestCheckAccountAccess_FamilyMember_NoPermKey(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	fid := uuid.New()
	uid := uuid.MustParse(testUser)

	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(fid, uid).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).AddRow("member", json.RawMessage(`{}`)))

	err := svc.checkAccountAccess(ctxWithUser(testUser), uuid.New().String(), fid.String(), testUser)
	assert.NoError(t, err) // no perm keys required → pass
}

func TestCheckAccountAccess_FamilyMember_WithPermKey(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	fid := uuid.New()
	uid := uuid.MustParse(testUser)

	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(fid, uid).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).AddRow("member", json.RawMessage(`{"can_edit":true}`)))

	err := svc.checkAccountAccess(ctxWithUser(testUser), uuid.New().String(), fid.String(), testUser, "can_edit")
	assert.NoError(t, err)
}

func TestCheckAccountAccess_FamilyMember_InsufficientPerm(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	fid := uuid.New()
	uid := uuid.MustParse(testUser)

	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(fid, uid).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).AddRow("member", json.RawMessage(`{"can_view":true}`)))

	err := svc.checkAccountAccess(ctxWithUser(testUser), uuid.New().String(), fid.String(), testUser, "can_delete")
	assert.Error(t, err)
}

func TestCheckAccountAccess_NotMember(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	fid := uuid.New()
	uid := uuid.MustParse(testUser)

	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(fid, uid).
		WillReturnError(pgx.ErrNoRows)

	err := svc.checkAccountAccess(ctxWithUser(testUser), uuid.New().String(), fid.String(), testUser)
	st, _ := status.FromError(err)
	assert.Equal(t, codes.PermissionDenied, st.Code())
}

// ── requireFamilyPermission ─────────────────────────────────────────────────

func TestRequireFamilyPermission_Owner(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	fid := uuid.New()
	uid := uuid.MustParse(testUser)

	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(fid, uid).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).AddRow("owner", json.RawMessage(`{}`)))

	err := svc.requireFamilyPermission(ctxWithUser(testUser), fid, testUser, "can_edit")
	assert.NoError(t, err)
}

func TestRequireFamilyPermission_Admin(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	fid := uuid.New()
	uid := uuid.MustParse(testUser)

	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(fid, uid).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).AddRow("admin", json.RawMessage(`{}`)))

	err := svc.requireFamilyPermission(ctxWithUser(testUser), fid, testUser, "can_delete")
	assert.NoError(t, err)
}

func TestRequireFamilyPermission_MemberAllowed(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	fid := uuid.New()
	uid := uuid.MustParse(testUser)

	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(fid, uid).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).AddRow("member", json.RawMessage(`{"can_edit":true}`)))

	err := svc.requireFamilyPermission(ctxWithUser(testUser), fid, testUser, "can_edit")
	assert.NoError(t, err)
}

func TestRequireFamilyPermission_MemberDenied(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	fid := uuid.New()
	uid := uuid.MustParse(testUser)

	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(fid, uid).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).AddRow("member", json.RawMessage(`{"can_view":true}`)))

	err := svc.requireFamilyPermission(ctxWithUser(testUser), fid, testUser, "can_delete")
	assert.Error(t, err)
}

func TestRequireFamilyPermission_NotMember(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	fid := uuid.New()
	uid := uuid.MustParse(testUser)

	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(fid, uid).
		WillReturnError(pgx.ErrNoRows)

	err := svc.requireFamilyPermission(ctxWithUser(testUser), fid, testUser, "can_edit")
	st, _ := status.FromError(err)
	assert.Equal(t, codes.PermissionDenied, st.Code())
}

func TestRequireFamilyPermission_InvalidUserID(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	err := svc.requireFamilyPermission(ctxWithUser("bad"), uuid.New(), "bad", "can_edit")
	assert.Error(t, err)
}

// ── ListAccounts edge cases ─────────────────────────────────────────────────

func TestListAccounts_Personal_IncludeInactive(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	uid := uuid.MustParse(testUser)
	now := time.Now()

	mock.ExpectQuery("SELECT id, user_id.*FROM accounts WHERE user_id.*family_id IS NULL AND deleted_at IS NULL").
		WithArgs(uid).
		WillReturnRows(pgxmock.NewRows(accountColumns).
			AddRow(uuid.New(), uid, "", "cash", "cash", "CNY", "", int64(0), false, false, now, now))

	resp, err := svc.ListAccounts(ctxWithUser(testUser), &pb.ListAccountsRequest{IncludeInactive: true})
	require.NoError(t, err)
	assert.Len(t, resp.Accounts, 1)
}

func TestListAccounts_Family_Success(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	uid := uuid.MustParse(testUser)
	famID := uuid.New()
	now := time.Now()

	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(famID, uid).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))
	mock.ExpectQuery("SELECT id, user_id.*FROM accounts WHERE family_id.*is_active = true").
		WithArgs(famID).
		WillReturnRows(pgxmock.NewRows(accountColumns).
			AddRow(uuid.New(), uid, famID.String(), "bank", "bank_card", "CNY", "", int64(1000), true, false, now, now))

	resp, err := svc.ListAccounts(ctxWithUser(testUser), &pb.ListAccountsRequest{FamilyId: famID.String()})
	require.NoError(t, err)
	assert.Len(t, resp.Accounts, 1)
}

func TestListAccounts_Family_IncludeInactive(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	uid := uuid.MustParse(testUser)
	famID := uuid.New()

	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(famID, uid).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))
	mock.ExpectQuery("SELECT id, user_id.*FROM accounts WHERE family_id.*deleted_at IS NULL").
		WithArgs(famID).
		WillReturnRows(pgxmock.NewRows(accountColumns))

	resp, err := svc.ListAccounts(ctxWithUser(testUser), &pb.ListAccountsRequest{FamilyId: famID.String(), IncludeInactive: true})
	require.NoError(t, err)
	assert.Empty(t, resp.Accounts)
}

func TestListAccounts_Family_NotMember(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	uid := uuid.MustParse(testUser)
	famID := uuid.New()

	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(famID, uid).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(false))

	_, err := svc.ListAccounts(ctxWithUser(testUser), &pb.ListAccountsRequest{FamilyId: famID.String()})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.PermissionDenied, st.Code())
}

func TestListAccounts_Family_InvalidFamilyID(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	_, err := svc.ListAccounts(ctxWithUser(testUser), &pb.ListAccountsRequest{FamilyId: "bad"})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.InvalidArgument, st.Code())
}

func TestListAccounts_NoAuthBoost(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	_, err := svc.ListAccounts(noAuthCtx(), &pb.ListAccountsRequest{})
	assert.Error(t, err)
}

// ── TransferBetween family paths (covers checkAccountAccessTx) ───────────

func TestTransfer_FamilyAccount_OwnerAccess(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	from := uuid.New()
	to := uuid.New()
	famID := uuid.New()
	uid := uuid.MustParse(testUser)
	transferID := uuid.New()
	now := time.Now()

	mock.ExpectBegin()
	// From: family account, different owner
	mock.ExpectQuery("SELECT user_id.*FROM accounts WHERE id.*FOR UPDATE").
		WithArgs(from).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(uuid.New().String(), famID.String()))
	// To: own personal
	mock.ExpectQuery("SELECT user_id.*FROM accounts WHERE id.*FOR UPDATE").
		WithArgs(to).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(testUser, ""))
	// checkAccountAccessTx for from: family query
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(famID, uid).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).AddRow("owner", json.RawMessage(`{}`)))
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
		WithArgs(uid, from, to, int64(100), "").
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at"}).AddRow(transferID, now))
	mock.ExpectCommit()

	resp, err := svc.TransferBetween(ctxWithUser(testUser), &pb.TransferBetweenRequest{
		FromAccountId: from.String(), ToAccountId: to.String(), Amount: 100,
	})
	require.NoError(t, err)
	assert.NotNil(t, resp.Transfer)
}

func TestTransfer_FamilyAccount_NotMember(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	from := uuid.New()
	to := uuid.New()
	famID := uuid.New()
	uid := uuid.MustParse(testUser)

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT user_id.*FROM accounts WHERE id.*FOR UPDATE").
		WithArgs(from).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(uuid.New().String(), famID.String()))
	mock.ExpectQuery("SELECT user_id.*FROM accounts WHERE id.*FOR UPDATE").
		WithArgs(to).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(testUser, ""))
	// Not a member
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(famID, uid).
		WillReturnError(pgx.ErrNoRows)
	mock.ExpectRollback()

	_, err := svc.TransferBetween(ctxWithUser(testUser), &pb.TransferBetweenRequest{
		FromAccountId: from.String(), ToAccountId: to.String(), Amount: 100,
	})
	st, _ := status.FromError(err)
	assert.Equal(t, codes.PermissionDenied, st.Code())
}

func TestTransfer_FamilyAccount_MemberWithPerm(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	from := uuid.New()
	to := uuid.New()
	famID := uuid.New()
	uid := uuid.MustParse(testUser)
	transferID := uuid.New()
	now := time.Now()

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT user_id.*FROM accounts WHERE id.*FOR UPDATE").
		WithArgs(from).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(uuid.New().String(), famID.String()))
	mock.ExpectQuery("SELECT user_id.*FROM accounts WHERE id.*FOR UPDATE").
		WithArgs(to).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(uuid.New().String(), famID.String()))
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(famID, uid).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).AddRow("member", json.RawMessage(`{}`)))
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(famID, uid).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).AddRow("member", json.RawMessage(`{}`)))
	mock.ExpectQuery("UPDATE accounts SET balance.*RETURNING balance").
		WithArgs(int64(50), from).
		WillReturnRows(pgxmock.NewRows([]string{"balance"}).AddRow(int64(950)))
	mock.ExpectExec("UPDATE accounts SET balance.*WHERE id").
		WithArgs(int64(50), to).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectQuery("INSERT INTO transfers").
		WithArgs(uid, from, to, int64(50), "").
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at"}).AddRow(transferID, now))
	mock.ExpectCommit()

	resp, err := svc.TransferBetween(ctxWithUser(testUser), &pb.TransferBetweenRequest{
		FromAccountId: from.String(), ToAccountId: to.String(), Amount: 50,
	})
	require.NoError(t, err)
	assert.NotNil(t, resp.Transfer)
}

func TestCheckAccountAccess_DBError(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	fid := uuid.New()
	uid := uuid.MustParse(testUser)
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(fid, uid).
		WillReturnError(pgx.ErrTxClosed)
	err := svc.checkAccountAccess(ctxWithUser(testUser), uuid.New().String(), fid.String(), testUser)
	assert.Error(t, err)
}

func TestCheckAccountAccess_BadPermJSON(t *testing.T) {
	svc, mock := newTestService(t)
	defer mock.Close()
	fid := uuid.New()
	uid := uuid.MustParse(testUser)
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(fid, uid).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).AddRow("member", json.RawMessage(`invalid`)))
	err := svc.checkAccountAccess(ctxWithUser(testUser), uuid.New().String(), fid.String(), testUser, "can_edit")
	assert.Error(t, err) // parse error
}
