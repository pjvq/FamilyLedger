package family

import (
	"context"
	"encoding/json"
	"fmt"
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

const boost2UserID = "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"

var boost2UID = uuid.MustParse(boost2UserID)

func boost2Ctx() context.Context {
	return context.WithValue(context.Background(), middleware.UserIDKey, boost2UserID)
}

// ════════════════════════════════════════════════════════════════════════════
// GenerateInviteCode — additional branches
// ════════════════════════════════════════════════════════════════════════════

func TestBoost2_GenerateInviteCode_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.GenerateInviteCode(context.Background(), &pb.GenerateInviteCodeRequest{
		FamilyId: uuid.New().String(),
	})
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestBoost2_GenerateInviteCode_EmptyFamilyID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.GenerateInviteCode(boost2Ctx(), &pb.GenerateInviteCodeRequest{
		FamilyId: "",
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoost2_GenerateInviteCode_InvalidFamilyID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.GenerateInviteCode(boost2Ctx(), &pb.GenerateInviteCodeRequest{
		FamilyId: "not-uuid",
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoost2_GenerateInviteCode_NotOwnerOrAdmin(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()

	// requireRole: caller is "member" — not allowed
	mock.ExpectQuery("SELECT role FROM family_members").
		WithArgs(famID, boost2UID).
		WillReturnRows(pgxmock.NewRows([]string{"role"}).AddRow("member"))

	_, err = svc.GenerateInviteCode(boost2Ctx(), &pb.GenerateInviteCodeRequest{
		FamilyId: famID.String(),
	})
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

func TestBoost2_GenerateInviteCode_NotMember(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()

	mock.ExpectQuery("SELECT role FROM family_members").
		WithArgs(famID, boost2UID).
		WillReturnError(pgx.ErrNoRows)

	_, err = svc.GenerateInviteCode(boost2Ctx(), &pb.GenerateInviteCodeRequest{
		FamilyId: famID.String(),
	})
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

func TestBoost2_GenerateInviteCode_DBErrorOnUpdate(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()

	mock.ExpectQuery("SELECT role FROM family_members").
		WithArgs(famID, boost2UID).
		WillReturnRows(pgxmock.NewRows([]string{"role"}).AddRow("owner"))
	mock.ExpectExec("UPDATE families SET invite_code").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), famID).
		WillReturnError(fmt.Errorf("db error"))

	_, err = svc.GenerateInviteCode(boost2Ctx(), &pb.GenerateInviteCodeRequest{
		FamilyId: famID.String(),
	})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestBoost2_GenerateInviteCode_AdminSuccess(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()

	mock.ExpectQuery("SELECT role FROM family_members").
		WithArgs(famID, boost2UID).
		WillReturnRows(pgxmock.NewRows([]string{"role"}).AddRow("admin"))
	mock.ExpectExec("UPDATE families SET invite_code").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), famID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	resp, err := svc.GenerateInviteCode(boost2Ctx(), &pb.GenerateInviteCodeRequest{
		FamilyId: famID.String(),
	})
	require.NoError(t, err)
	assert.Len(t, resp.InviteCode, inviteCodeLength)
	assert.NotNil(t, resp.ExpiresAt)
}

func TestBoost2_GenerateInviteCode_OwnerSuccess(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()

	mock.ExpectQuery("SELECT role FROM family_members").
		WithArgs(famID, boost2UID).
		WillReturnRows(pgxmock.NewRows([]string{"role"}).AddRow("owner"))
	mock.ExpectExec("UPDATE families SET invite_code").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), famID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	resp, err := svc.GenerateInviteCode(boost2Ctx(), &pb.GenerateInviteCodeRequest{
		FamilyId: famID.String(),
	})
	require.NoError(t, err)
	assert.Len(t, resp.InviteCode, inviteCodeLength)
}

// ════════════════════════════════════════════════════════════════════════════
// requireRole — additional branches
// ════════════════════════════════════════════════════════════════════════════

func TestBoost2_RequireRole_InvalidUserID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	// Use context with invalid user id
	ctx := context.WithValue(context.Background(), middleware.UserIDKey, "not-a-uuid")
	famID := uuid.New()

	err = svc.requireRole(ctx, famID, "not-a-uuid", "owner")
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestBoost2_RequireRole_DBError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()

	mock.ExpectQuery("SELECT role FROM family_members").
		WithArgs(famID, boost2UID).
		WillReturnError(fmt.Errorf("connection lost"))

	err = svc.requireRole(context.Background(), famID, boost2UserID, "owner")
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestBoost2_RequireRole_InsufficientRole(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()

	mock.ExpectQuery("SELECT role FROM family_members").
		WithArgs(famID, boost2UID).
		WillReturnRows(pgxmock.NewRows([]string{"role"}).AddRow("member"))

	err = svc.requireRole(context.Background(), famID, boost2UserID, "owner", "admin")
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
	assert.Contains(t, status.Convert(err).Message(), "insufficient role")
}

func TestBoost2_RequireRole_AdminAllowed(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()

	mock.ExpectQuery("SELECT role FROM family_members").
		WithArgs(famID, boost2UID).
		WillReturnRows(pgxmock.NewRows([]string{"role"}).AddRow("admin"))

	err = svc.requireRole(context.Background(), famID, boost2UserID, "owner", "admin")
	assert.NoError(t, err)
}

// ════════════════════════════════════════════════════════════════════════════
// GetFamily — additional branches
// ════════════════════════════════════════════════════════════════════════════

func TestBoost2_GetFamily_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.GetFamily(context.Background(), &pb.GetFamilyRequest{
		FamilyId: uuid.New().String(),
	})
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestBoost2_GetFamily_EmptyFamilyID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.GetFamily(boost2Ctx(), &pb.GetFamilyRequest{FamilyId: ""})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoost2_GetFamily_InvalidFamilyID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.GetFamily(boost2Ctx(), &pb.GetFamilyRequest{FamilyId: "bad"})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoost2_GetFamily_NotMember(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()

	// requireMembership
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(famID, boost2UID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(false))

	_, err = svc.GetFamily(boost2Ctx(), &pb.GetFamilyRequest{FamilyId: famID.String()})
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

func TestBoost2_GetFamily_NotFound(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()

	// requireMembership
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(famID, boost2UID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))

	// Get family — not found
	mock.ExpectQuery("SELECT name, owner_id").
		WithArgs(famID).
		WillReturnError(pgx.ErrNoRows)

	_, err = svc.GetFamily(boost2Ctx(), &pb.GetFamilyRequest{FamilyId: famID.String()})
	assert.Equal(t, codes.NotFound, status.Code(err))
}

func TestBoost2_GetFamily_DBError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()

	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(famID, boost2UID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))
	mock.ExpectQuery("SELECT name, owner_id").
		WithArgs(famID).
		WillReturnError(fmt.Errorf("db error"))

	_, err = svc.GetFamily(boost2Ctx(), &pb.GetFamilyRequest{FamilyId: famID.String()})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestBoost2_GetFamily_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()
	now := time.Now()
	inviteCode := "TESTCODE"
	inviteExpires := now.Add(24 * time.Hour)
	memberID := uuid.New()
	permsJSON, _ := json.Marshal(ownerPermissions())

	// requireMembership
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(famID, boost2UID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))

	// Get family
	mock.ExpectQuery("SELECT name, owner_id").
		WithArgs(famID).
		WillReturnRows(pgxmock.NewRows([]string{"name", "owner_id", "invite_code", "invite_expires_at", "created_at", "updated_at"}).
			AddRow("TestFamily", boost2UserID, &inviteCode, &inviteExpires, now, now))

	// listMembers
	mock.ExpectQuery("SELECT fm.id, fm.user_id, u.email, fm.role, fm.permissions, fm.joined_at").
		WithArgs(famID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "email", "role", "permissions", "joined_at"}).
			AddRow(memberID, boost2UID, "test@test.com", "owner", permsJSON, now))

	resp, err := svc.GetFamily(boost2Ctx(), &pb.GetFamilyRequest{FamilyId: famID.String()})
	require.NoError(t, err)
	assert.Equal(t, "TestFamily", resp.Family.Name)
	assert.Equal(t, "TESTCODE", resp.Family.InviteCode)
	assert.NotNil(t, resp.Family.InviteExpiresAt)
	require.Len(t, resp.Members, 1)
	assert.Equal(t, pb.FamilyRole_FAMILY_ROLE_OWNER, resp.Members[0].Role)
}

func TestBoost2_GetFamily_NoInviteCode(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()
	now := time.Now()

	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(famID, boost2UID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))
	mock.ExpectQuery("SELECT name, owner_id").
		WithArgs(famID).
		WillReturnRows(pgxmock.NewRows([]string{"name", "owner_id", "invite_code", "invite_expires_at", "created_at", "updated_at"}).
			AddRow("TestFamily", boost2UserID, (*string)(nil), (*time.Time)(nil), now, now))
	// listMembers empty
	mock.ExpectQuery("SELECT fm.id, fm.user_id, u.email, fm.role, fm.permissions, fm.joined_at").
		WithArgs(famID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "email", "role", "permissions", "joined_at"}))

	resp, err := svc.GetFamily(boost2Ctx(), &pb.GetFamilyRequest{FamilyId: famID.String()})
	require.NoError(t, err)
	assert.Empty(t, resp.Family.InviteCode)
	assert.Nil(t, resp.Family.InviteExpiresAt)
}

// ════════════════════════════════════════════════════════════════════════════
// ListFamilyMembers — additional branches
// ════════════════════════════════════════════════════════════════════════════

func TestBoost2_ListFamilyMembers_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.ListFamilyMembers(context.Background(), &pb.ListFamilyMembersRequest{
		FamilyId: uuid.New().String(),
	})
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestBoost2_ListFamilyMembers_EmptyFamilyID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.ListFamilyMembers(boost2Ctx(), &pb.ListFamilyMembersRequest{FamilyId: ""})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoost2_ListFamilyMembers_InvalidFamilyID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.ListFamilyMembers(boost2Ctx(), &pb.ListFamilyMembersRequest{FamilyId: "bad"})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoost2_ListFamilyMembers_NotMember(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()

	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(famID, boost2UID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(false))

	_, err = svc.ListFamilyMembers(boost2Ctx(), &pb.ListFamilyMembersRequest{FamilyId: famID.String()})
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

func TestBoost2_ListFamilyMembers_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()
	memberID := uuid.New()
	now := time.Now()
	permsJSON, _ := json.Marshal(defaultMemberPermissions())

	// requireMembership
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(famID, boost2UID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))

	// listMembers
	mock.ExpectQuery("SELECT fm.id, fm.user_id, u.email, fm.role, fm.permissions, fm.joined_at").
		WithArgs(famID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "email", "role", "permissions", "joined_at"}).
			AddRow(memberID, boost2UID, "user@test.com", "member", permsJSON, now))

	resp, err := svc.ListFamilyMembers(boost2Ctx(), &pb.ListFamilyMembersRequest{FamilyId: famID.String()})
	require.NoError(t, err)
	require.Len(t, resp.Members, 1)
	assert.Equal(t, pb.FamilyRole_FAMILY_ROLE_MEMBER, resp.Members[0].Role)
	assert.True(t, resp.Members[0].Permissions.CanView)
	assert.True(t, resp.Members[0].Permissions.CanCreate)
	assert.False(t, resp.Members[0].Permissions.CanEdit)
}

// ════════════════════════════════════════════════════════════════════════════
// listMembers — additional branches
// ════════════════════════════════════════════════════════════════════════════

func TestBoost2_ListMembers_DBError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()

	mock.ExpectQuery("SELECT fm.id, fm.user_id, u.email, fm.role, fm.permissions, fm.joined_at").
		WithArgs(famID).
		WillReturnError(fmt.Errorf("db error"))

	_, err = svc.listMembers(boost2Ctx(), famID)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestBoost2_ListMembers_BadPermissionsJSON(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()
	memberID := uuid.New()
	now := time.Now()

	mock.ExpectQuery("SELECT fm.id, fm.user_id, u.email, fm.role, fm.permissions, fm.joined_at").
		WithArgs(famID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "email", "role", "permissions", "joined_at"}).
			AddRow(memberID, boost2UID, "test@test.com", "member", []byte(`not-json`), now))

	_, err = svc.listMembers(boost2Ctx(), famID)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestBoost2_ListMembers_Empty(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()

	mock.ExpectQuery("SELECT fm.id, fm.user_id, u.email, fm.role, fm.permissions, fm.joined_at").
		WithArgs(famID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "email", "role", "permissions", "joined_at"}))

	members, err := svc.listMembers(boost2Ctx(), famID)
	require.NoError(t, err)
	assert.Len(t, members, 0)
}

// ════════════════════════════════════════════════════════════════════════════
// requireMembership — additional branches
// ════════════════════════════════════════════════════════════════════════════

func TestBoost2_RequireMembership_InvalidUserID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()
	err = svc.requireMembership(context.Background(), famID, "not-a-uuid")
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestBoost2_RequireMembership_DBError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()

	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(famID, boost2UID).
		WillReturnError(fmt.Errorf("db error"))

	err = svc.requireMembership(context.Background(), famID, boost2UserID)
	assert.Equal(t, codes.Internal, status.Code(err))
}

// ════════════════════════════════════════════════════════════════════════════
// generateInviteCode — test code format
// ════════════════════════════════════════════════════════════════════════════

func TestBoost2_GenerateInviteCode_Format(t *testing.T) {
	code, err := generateInviteCode()
	require.NoError(t, err)
	assert.Len(t, code, inviteCodeLength)

	// All chars should be in charset
	for _, c := range code {
		assert.Contains(t, inviteCodeCharset, string(c))
	}
}

func TestBoost2_GenerateInviteCode_Uniqueness(t *testing.T) {
	codes := make(map[string]bool)
	for i := 0; i < 100; i++ {
		code, err := generateInviteCode()
		require.NoError(t, err)
		codes[code] = true
	}
	// With 36^8 possible codes, 100 should all be unique
	assert.Equal(t, 100, len(codes))
}

// ════════════════════════════════════════════════════════════════════════════
// JoinFamily — additional branches
// ════════════════════════════════════════════════════════════════════════════

func TestBoost2_JoinFamily_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.JoinFamily(context.Background(), &pb.JoinFamilyRequest{InviteCode: "ABC"})
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestBoost2_JoinFamily_EmptyCode(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.JoinFamily(boost2Ctx(), &pb.JoinFamilyRequest{InviteCode: ""})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoost2_JoinFamily_CodeNotFound(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT .+ FROM families WHERE invite_code").
		WithArgs("NOTEXIST").
		WillReturnError(pgx.ErrNoRows)
	mock.ExpectRollback()

	_, err = svc.JoinFamily(boost2Ctx(), &pb.JoinFamilyRequest{InviteCode: "NOTEXIST"})
	assert.Equal(t, codes.NotFound, status.Code(err))
}

func TestBoost2_JoinFamily_NilExpiry(t *testing.T) {
	// invite_expires_at is NULL — should not fail
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()
	now := time.Now()

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT .+ FROM families WHERE invite_code").
		WithArgs("NOEXP123").
		WillReturnRows(pgxmock.NewRows([]string{"id", "name", "owner_id", "invite_expires_at", "created_at", "updated_at"}).
			AddRow(famID, "TestFamily", uuid.New().String(), (*time.Time)(nil), now, now))
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(famID, boost2UID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(false))
	mock.ExpectExec("INSERT INTO family_members").
		WithArgs(famID, boost2UID, pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	mock.ExpectCommit()
	mock.ExpectExec("INSERT INTO audit_logs").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	resp, err := svc.JoinFamily(boost2Ctx(), &pb.JoinFamilyRequest{InviteCode: "NOEXP123"})
	require.NoError(t, err)
	assert.Equal(t, famID.String(), resp.Family.Id)
}

// ════════════════════════════════════════════════════════════════════════════
// GetAuditLog — additional branches
// ════════════════════════════════════════════════════════════════════════════

func TestBoost2_GetAuditLog_WithEntityTypeFilter(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()

	// requireMembership
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(famID, boost2UID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))

	// Query with entity_type filter
	mock.ExpectQuery("SELECT al.id.*FROM audit_logs").
		WithArgs(famID, "transaction", pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "email", "action", "entity_type", "entity_id", "changes", "created_at"}))

	resp, err := svc.GetAuditLog(boost2Ctx(), &pb.GetAuditLogRequest{
		FamilyId:   famID.String(),
		EntityType: "transaction",
	})
	require.NoError(t, err)
	assert.Len(t, resp.Entries, 0)
}

func TestBoost2_GetAuditLog_WithPageToken(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()

	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(famID, boost2UID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))

	mock.ExpectQuery("SELECT al.id.*FROM audit_logs").
		WithArgs(famID, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "email", "action", "entity_type", "entity_id", "changes", "created_at"}))

	resp, err := svc.GetAuditLog(boost2Ctx(), &pb.GetAuditLogRequest{
		FamilyId:  famID.String(),
		PageToken: "20",
	})
	require.NoError(t, err)
	assert.Len(t, resp.Entries, 0)
}

// ════════════════════════════════════════════════════════════════════════════
// CreateFamily — additional branches
// ════════════════════════════════════════════════════════════════════════════

func TestBoost2_CreateFamily_EmptyName(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.CreateFamily(boost2Ctx(), &pb.CreateFamilyRequest{Name: ""})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoost2_CreateFamily_BeginTxError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectBegin().WillReturnError(fmt.Errorf("pool exhausted"))

	_, err = svc.CreateFamily(boost2Ctx(), &pb.CreateFamilyRequest{Name: "Test"})
	assert.Equal(t, codes.Internal, status.Code(err))
}

// ════════════════════════════════════════════════════════════════════════════
// LeaveFamily — additional branches
// ════════════════════════════════════════════════════════════════════════════

func TestBoost2_LeaveFamily_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.LeaveFamily(context.Background(), &pb.LeaveFamilyRequest{FamilyId: uuid.New().String()})
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestBoost2_LeaveFamily_EmptyFamilyID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.LeaveFamily(boost2Ctx(), &pb.LeaveFamilyRequest{FamilyId: ""})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoost2_LeaveFamily_DBErrorOnDelete(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()

	mock.ExpectQuery("SELECT role FROM family_members").
		WithArgs(famID, boost2UID).
		WillReturnRows(pgxmock.NewRows([]string{"role"}).AddRow("member"))
	mock.ExpectExec("DELETE FROM family_members").
		WithArgs(famID, boost2UID).
		WillReturnError(fmt.Errorf("fk constraint"))

	_, err = svc.LeaveFamily(boost2Ctx(), &pb.LeaveFamilyRequest{FamilyId: famID.String()})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestBoost2_LeaveFamily_DBErrorOnCheckRole(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()

	mock.ExpectQuery("SELECT role FROM family_members").
		WithArgs(famID, boost2UID).
		WillReturnError(fmt.Errorf("db error"))

	_, err = svc.LeaveFamily(boost2Ctx(), &pb.LeaveFamilyRequest{FamilyId: famID.String()})
	assert.Equal(t, codes.Internal, status.Code(err))
}
