package family

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"github.com/familyledger/server/pkg/middleware"
	pb "github.com/familyledger/server/proto/family"
)

const testUserID = "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"

var testUID = uuid.MustParse(testUserID)

func authedCtx() context.Context {
	return context.WithValue(context.Background(), middleware.UserIDKey, testUserID)
}

// ─── CreateFamily ───────────────────────────────────────────────────────────

func TestCreateFamily_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	famID := uuid.New()
	now := time.Now()

	mock.ExpectBegin()
	mock.ExpectQuery("INSERT INTO families").
		WithArgs("张家", testUID, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at", "updated_at"}).AddRow(famID, now, now))
	mock.ExpectExec("INSERT INTO family_members").
		WithArgs(famID, testUID, pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	mock.ExpectCommit()

	resp, err := svc.CreateFamily(authedCtx(), &pb.CreateFamilyRequest{Name: "张家"})
	require.NoError(t, err)
	assert.Equal(t, "张家", resp.Family.Name)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestCreateFamily_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.CreateFamily(context.Background(), &pb.CreateFamilyRequest{Name: "x"})
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestCreateFamily_EmptyName(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.CreateFamily(authedCtx(), &pb.CreateFamilyRequest{Name: ""})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── GetFamily ──────────────────────────────────────────────────────────────

func TestGetFamily_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	famID := uuid.New()
	now := time.Now()
	memID := uuid.New()

	// requireMembership → SELECT EXISTS
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(famID, testUID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))

	// family query (6 cols)
	mock.ExpectQuery("SELECT .+ FROM families").
		WithArgs(famID).
		WillReturnRows(pgxmock.NewRows([]string{"name", "owner_id", "invite_code", "invite_expires_at", "created_at", "updated_at"}).
			AddRow("张家", testUserID, (*string)(nil), (*time.Time)(nil), now, now))

	// listMembers (6 cols with JOIN)
	mock.ExpectQuery("SELECT .+ FROM family_members").
		WithArgs(famID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "email", "role", "permissions", "joined_at"}).
			AddRow(memID, testUID, "test@test.com", "owner", []byte(`{"can_view":true,"can_create":true,"can_edit":true,"can_delete":true,"can_manage_accounts":true}`), now))

	resp, err := svc.GetFamily(authedCtx(), &pb.GetFamilyRequest{FamilyId: famID.String()})
	require.NoError(t, err)
	assert.Equal(t, "张家", resp.Family.Name)
	assert.Len(t, resp.Members, 1)
}

func TestGetFamily_NotMember(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	famID := uuid.New()

	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(famID, testUID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(false))

	_, err = svc.GetFamily(authedCtx(), &pb.GetFamilyRequest{FamilyId: famID.String()})
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

func TestGetFamily_EmptyID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.GetFamily(authedCtx(), &pb.GetFamilyRequest{FamilyId: ""})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── JoinFamily ─────────────────────────────────────────────────────────────

func TestJoinFamily_InvalidCode(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT .+ FROM families WHERE invite_code").
		WithArgs("BADCODE1").
		WillReturnError(pgx.ErrNoRows)
	mock.ExpectRollback()

	_, err = svc.JoinFamily(authedCtx(), &pb.JoinFamilyRequest{InviteCode: "BADCODE1"})
	assert.Equal(t, codes.NotFound, status.Code(err))
}

func TestJoinFamily_EmptyCode(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.JoinFamily(authedCtx(), &pb.JoinFamilyRequest{InviteCode: ""})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── GenerateInviteCode ─────────────────────────────────────────────────────

func TestGenerateInviteCode_NotOwner(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	famID := uuid.New()

	// requireRole → SELECT role FROM family_members
	mock.ExpectQuery("SELECT role FROM family_members").
		WithArgs(famID, testUID).
		WillReturnRows(pgxmock.NewRows([]string{"role"}).AddRow("member"))

	_, err = svc.GenerateInviteCode(authedCtx(), &pb.GenerateInviteCodeRequest{FamilyId: famID.String()})
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

func TestGenerateInviteCode_EmptyID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.GenerateInviteCode(authedCtx(), &pb.GenerateInviteCodeRequest{FamilyId: ""})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── SetMemberRole ──────────────────────────────────────────────────────────

func TestSetMemberRole_EmptyFamilyID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.SetMemberRole(authedCtx(), &pb.SetMemberRoleRequest{FamilyId: ""})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestSetMemberRole_InvalidRole(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	famID := uuid.New()

	// requireRole → owner
	mock.ExpectQuery("SELECT role FROM family_members").
		WithArgs(famID, testUID).
		WillReturnRows(pgxmock.NewRows([]string{"role"}).AddRow("owner"))

	_, err = svc.SetMemberRole(authedCtx(), &pb.SetMemberRoleRequest{
		FamilyId: famID.String(),
		UserId:   uuid.New().String(),
		Role:     pb.FamilyRole_FAMILY_ROLE_UNSPECIFIED,
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── LeaveFamily ────────────────────────────────────────────────────────────

func TestLeaveFamily_EmptyID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.LeaveFamily(authedCtx(), &pb.LeaveFamilyRequest{FamilyId: ""})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── ListFamilyMembers ──────────────────────────────────────────────────────

func TestListFamilyMembers_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	famID := uuid.New()
	now := time.Now()
	memID := uuid.New()

	// requireMembership → SELECT EXISTS
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(famID, testUID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))

	// listMembers
	mock.ExpectQuery("SELECT .+ FROM family_members").
		WithArgs(famID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "email", "role", "permissions", "joined_at"}).
			AddRow(memID, testUID, "test@test.com", "owner", []byte(`{"can_view":true,"can_create":true,"can_edit":true,"can_delete":true,"can_manage_accounts":true}`), now))

	resp, err := svc.ListFamilyMembers(authedCtx(), &pb.ListFamilyMembersRequest{FamilyId: famID.String()})
	require.NoError(t, err)
	assert.Len(t, resp.Members, 1)
}

func TestListFamilyMembers_EmptyID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.ListFamilyMembers(authedCtx(), &pb.ListFamilyMembersRequest{FamilyId: ""})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── Pure logic ─────────────────────────────────────────────────────────────

func TestDefaultMemberPermissions(t *testing.T) {
	p := defaultMemberPermissions()
	assert.True(t, p.CanView)
	assert.True(t, p.CanCreate)
	assert.False(t, p.CanEdit)
	assert.False(t, p.CanDelete)
	assert.False(t, p.CanManageAccounts)
}

func TestOwnerPermissions(t *testing.T) {
	p := ownerPermissions()
	assert.True(t, p.CanView)
	assert.True(t, p.CanCreate)
	assert.True(t, p.CanEdit)
	assert.True(t, p.CanDelete)
	assert.True(t, p.CanManageAccounts)
}
