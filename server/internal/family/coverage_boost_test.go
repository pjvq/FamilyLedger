package family

import (
	"context"
	"encoding/json"
	"errors"
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

// Re-use constants from existing test files via local aliases.
const boostUserID = "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"

var boostUID = uuid.MustParse(boostUserID)

func boostCtx() context.Context {
	return context.WithValue(context.Background(), middleware.UserIDKey, boostUserID)
}

// ════════════════════════════════════════════════════════════════════════════
// parseOffset / protoRoleToString / stringToProtoRole
// ════════════════════════════════════════════════════════════════════════════

func TestBoost_ParseOffset_Valid(t *testing.T) {
	n, err := parseOffset("42")
	require.NoError(t, err)
	assert.Equal(t, int32(42), n)
}

func TestBoost_ParseOffset_Zero(t *testing.T) {
	n, err := parseOffset("0")
	require.NoError(t, err)
	assert.Equal(t, int32(0), n)
}

func TestBoost_ParseOffset_Invalid(t *testing.T) {
	_, err := parseOffset("abc")
	assert.Error(t, err)
}

func TestBoost_ParseOffset_Empty(t *testing.T) {
	_, err := parseOffset("")
	assert.Error(t, err)
}

func TestBoost_ProtoRoleToString_Owner(t *testing.T) {
	s, err := protoRoleToString(pb.FamilyRole_FAMILY_ROLE_OWNER)
	require.NoError(t, err)
	assert.Equal(t, "owner", s)
}

func TestBoost_ProtoRoleToString_Admin(t *testing.T) {
	s, err := protoRoleToString(pb.FamilyRole_FAMILY_ROLE_ADMIN)
	require.NoError(t, err)
	assert.Equal(t, "admin", s)
}

func TestBoost_ProtoRoleToString_Member(t *testing.T) {
	s, err := protoRoleToString(pb.FamilyRole_FAMILY_ROLE_MEMBER)
	require.NoError(t, err)
	assert.Equal(t, "member", s)
}

func TestBoost_ProtoRoleToString_Invalid(t *testing.T) {
	_, err := protoRoleToString(pb.FamilyRole_FAMILY_ROLE_UNSPECIFIED)
	assert.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoost_StringToProtoRole_AllCases(t *testing.T) {
	assert.Equal(t, pb.FamilyRole_FAMILY_ROLE_OWNER, stringToProtoRole("owner"))
	assert.Equal(t, pb.FamilyRole_FAMILY_ROLE_ADMIN, stringToProtoRole("admin"))
	assert.Equal(t, pb.FamilyRole_FAMILY_ROLE_MEMBER, stringToProtoRole("member"))
	assert.Equal(t, pb.FamilyRole_FAMILY_ROLE_UNSPECIFIED, stringToProtoRole("unknown"))
	assert.Equal(t, pb.FamilyRole_FAMILY_ROLE_UNSPECIFIED, stringToProtoRole(""))
}

// ════════════════════════════════════════════════════════════════════════════
// JoinFamily
// ════════════════════════════════════════════════════════════════════════════

func TestBoost_JoinFamily_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()
	now := time.Now()
	expiresAt := now.Add(24 * time.Hour)

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT .+ FROM families WHERE invite_code").
		WithArgs("ABCD1234").
		WillReturnRows(pgxmock.NewRows([]string{"id", "name", "owner_id", "invite_expires_at", "created_at", "updated_at"}).
			AddRow(famID, "TestFamily", uuid.New().String(), &expiresAt, now, now))
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(famID, boostUID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(false))
	mock.ExpectExec("INSERT INTO family_members").
		WithArgs(famID, boostUID, pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	mock.ExpectCommit()
	// audit.LogAudit fires a background exec
	mock.ExpectExec("INSERT INTO audit_logs").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	resp, err := svc.JoinFamily(boostCtx(), &pb.JoinFamilyRequest{InviteCode: "ABCD1234"})
	require.NoError(t, err)
	assert.Equal(t, famID.String(), resp.Family.Id)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoost_JoinFamily_ExpiredCode(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()
	now := time.Now()
	expired := now.Add(-24 * time.Hour)

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT .+ FROM families WHERE invite_code").
		WithArgs("EXPIRED1").
		WillReturnRows(pgxmock.NewRows([]string{"id", "name", "owner_id", "invite_expires_at", "created_at", "updated_at"}).
			AddRow(famID, "TestFamily", uuid.New().String(), &expired, now, now))
	mock.ExpectRollback()

	_, err = svc.JoinFamily(boostCtx(), &pb.JoinFamilyRequest{InviteCode: "EXPIRED1"})
	assert.Equal(t, codes.FailedPrecondition, status.Code(err))
}

func TestBoost_JoinFamily_AlreadyMember(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()
	now := time.Now()
	expiresAt := now.Add(24 * time.Hour)

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT .+ FROM families WHERE invite_code").
		WithArgs("EXIST123").
		WillReturnRows(pgxmock.NewRows([]string{"id", "name", "owner_id", "invite_expires_at", "created_at", "updated_at"}).
			AddRow(famID, "TestFamily", uuid.New().String(), &expiresAt, now, now))
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(famID, boostUID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))
	mock.ExpectRollback()

	_, err = svc.JoinFamily(boostCtx(), &pb.JoinFamilyRequest{InviteCode: "EXIST123"})
	assert.Equal(t, codes.AlreadyExists, status.Code(err))
}

func TestBoost_JoinFamily_DBErrorOnFind(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT .+ FROM families WHERE invite_code").
		WithArgs("DBERROR1").
		WillReturnError(errors.New("db connection lost"))
	mock.ExpectRollback()

	_, err = svc.JoinFamily(boostCtx(), &pb.JoinFamilyRequest{InviteCode: "DBERROR1"})
	assert.Equal(t, codes.Internal, status.Code(err))
}

// ════════════════════════════════════════════════════════════════════════════
// ListMyFamilies
// ════════════════════════════════════════════════════════════════════════════

func TestBoost_ListMyFamilies_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New().String()
	now := time.Now()
	inviteCode := "TESTCODE"
	expiresAt := now.Add(24 * time.Hour)
	perms := permissions{CanView: true, CanCreate: true}
	permsJSON, _ := json.Marshal(perms)

	mock.ExpectQuery("SELECT .+ FROM families .+ JOIN family_members").
		WithArgs(boostUserID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "name", "owner_id", "invite_code", "invite_expires_at", "created_at", "updated_at", "role", "permissions"}).
			AddRow(famID, "TestFamily", boostUserID, &inviteCode, &expiresAt, now, now, "owner", permsJSON))

	resp, err := svc.ListMyFamilies(boostCtx(), &pb.ListMyFamiliesRequest{})
	require.NoError(t, err)
	require.Len(t, resp.Families, 1)
	assert.Equal(t, "TestFamily", resp.Families[0].Name)
	assert.Equal(t, "TESTCODE", resp.Families[0].InviteCode)
	require.Len(t, resp.Memberships, 1)
	assert.Equal(t, pb.FamilyRole_FAMILY_ROLE_OWNER, resp.Memberships[0].Role)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoost_ListMyFamilies_MultipleFamilies(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	now := time.Now()
	permsJSON, _ := json.Marshal(defaultMemberPermissions())

	rows := pgxmock.NewRows([]string{"id", "name", "owner_id", "invite_code", "invite_expires_at", "created_at", "updated_at", "role", "permissions"}).
		AddRow(uuid.New().String(), "Family1", boostUserID, (*string)(nil), (*time.Time)(nil), now, now, "owner", permsJSON).
		AddRow(uuid.New().String(), "Family2", uuid.New().String(), (*string)(nil), (*time.Time)(nil), now, now, "member", permsJSON).
		AddRow(uuid.New().String(), "Family3", uuid.New().String(), (*string)(nil), (*time.Time)(nil), now, now, "admin", permsJSON)

	mock.ExpectQuery("SELECT .+ FROM families .+ JOIN family_members").
		WithArgs(boostUserID).
		WillReturnRows(rows)

	resp, err := svc.ListMyFamilies(boostCtx(), &pb.ListMyFamiliesRequest{})
	require.NoError(t, err)
	assert.Len(t, resp.Families, 3)
	assert.Equal(t, pb.FamilyRole_FAMILY_ROLE_OWNER, resp.Memberships[0].Role)
	assert.Equal(t, pb.FamilyRole_FAMILY_ROLE_MEMBER, resp.Memberships[1].Role)
	assert.Equal(t, pb.FamilyRole_FAMILY_ROLE_ADMIN, resp.Memberships[2].Role)
}

func TestBoost_ListMyFamilies_Empty(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectQuery("SELECT .+ FROM families .+ JOIN family_members").
		WithArgs(boostUserID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "name", "owner_id", "invite_code", "invite_expires_at", "created_at", "updated_at", "role", "permissions"}))

	resp, err := svc.ListMyFamilies(boostCtx(), &pb.ListMyFamiliesRequest{})
	require.NoError(t, err)
	assert.Empty(t, resp.Families)
}

// ════════════════════════════════════════════════════════════════════════════
// SetMemberRole
// ════════════════════════════════════════════════════════════════════════════

func TestBoost_SetMemberRole_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()
	targetUser := uuid.New()

	// requireRole: query role of caller
	mock.ExpectQuery("SELECT role FROM family_members").
		WithArgs(famID, boostUID).
		WillReturnRows(pgxmock.NewRows([]string{"role"}).AddRow("owner"))
	// Query current role of target
	mock.ExpectQuery("SELECT role FROM family_members").
		WithArgs(famID, targetUser).
		WillReturnRows(pgxmock.NewRows([]string{"role"}).AddRow("member"))
	// Update role
	mock.ExpectExec("UPDATE family_members SET role").
		WithArgs("admin", famID, targetUser).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	// audit log
	mock.ExpectExec("INSERT INTO audit_logs").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	_, err = svc.SetMemberRole(boostCtx(), &pb.SetMemberRoleRequest{
		FamilyId: famID.String(),
		UserId:   targetUser.String(),
		Role:     pb.FamilyRole_FAMILY_ROLE_ADMIN,
	})
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoost_SetMemberRole_CannotSetOwner(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()
	targetUser := uuid.New()

	// requireRole
	mock.ExpectQuery("SELECT role FROM family_members").
		WithArgs(famID, boostUID).
		WillReturnRows(pgxmock.NewRows([]string{"role"}).AddRow("owner"))

	_, err = svc.SetMemberRole(boostCtx(), &pb.SetMemberRoleRequest{
		FamilyId: famID.String(),
		UserId:   targetUser.String(),
		Role:     pb.FamilyRole_FAMILY_ROLE_OWNER,
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoost_SetMemberRole_CannotChangeOwnerRole(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()
	targetUser := uuid.New()

	// requireRole
	mock.ExpectQuery("SELECT role FROM family_members").
		WithArgs(famID, boostUID).
		WillReturnRows(pgxmock.NewRows([]string{"role"}).AddRow("owner"))
	// current role of target is owner
	mock.ExpectQuery("SELECT role FROM family_members").
		WithArgs(famID, targetUser).
		WillReturnRows(pgxmock.NewRows([]string{"role"}).AddRow("owner"))

	_, err = svc.SetMemberRole(boostCtx(), &pb.SetMemberRoleRequest{
		FamilyId: famID.String(),
		UserId:   targetUser.String(),
		Role:     pb.FamilyRole_FAMILY_ROLE_MEMBER,
	})
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

func TestBoost_SetMemberRole_TargetNotFound(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()
	targetUser := uuid.New()

	mock.ExpectQuery("SELECT role FROM family_members").
		WithArgs(famID, boostUID).
		WillReturnRows(pgxmock.NewRows([]string{"role"}).AddRow("owner"))
	mock.ExpectQuery("SELECT role FROM family_members").
		WithArgs(famID, targetUser).
		WillReturnError(pgx.ErrNoRows)

	_, err = svc.SetMemberRole(boostCtx(), &pb.SetMemberRoleRequest{
		FamilyId: famID.String(),
		UserId:   targetUser.String(),
		Role:     pb.FamilyRole_FAMILY_ROLE_ADMIN,
	})
	assert.Equal(t, codes.NotFound, status.Code(err))
}

func TestBoost_SetMemberRole_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.SetMemberRole(context.Background(), &pb.SetMemberRoleRequest{
		FamilyId: uuid.New().String(),
		UserId:   uuid.New().String(),
		Role:     pb.FamilyRole_FAMILY_ROLE_ADMIN,
	})
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestBoost_SetMemberRole_EmptyUserID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.SetMemberRole(boostCtx(), &pb.SetMemberRoleRequest{
		FamilyId: uuid.New().String(),
		UserId:   "",
		Role:     pb.FamilyRole_FAMILY_ROLE_ADMIN,
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ════════════════════════════════════════════════════════════════════════════
// SetMemberPermissions
// ════════════════════════════════════════════════════════════════════════════

func TestBoost_SetMemberPermissions_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()
	targetUser := uuid.New()

	// requireRole
	mock.ExpectQuery("SELECT role FROM family_members").
		WithArgs(famID, boostUID).
		WillReturnRows(pgxmock.NewRows([]string{"role"}).AddRow("owner"))
	// Update permissions
	mock.ExpectExec("UPDATE family_members SET permissions").
		WithArgs(pgxmock.AnyArg(), famID, targetUser).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	// audit log
	mock.ExpectExec("INSERT INTO audit_logs").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	_, err = svc.SetMemberPermissions(boostCtx(), &pb.SetMemberPermissionsRequest{
		FamilyId: famID.String(),
		UserId:   targetUser.String(),
		Permissions: &pb.MemberPermissions{
			CanView:   true,
			CanCreate: true,
			CanEdit:   true,
		},
	})
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoost_SetMemberPermissions_NilPermissions(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.SetMemberPermissions(boostCtx(), &pb.SetMemberPermissionsRequest{
		FamilyId:    uuid.New().String(),
		UserId:      uuid.New().String(),
		Permissions: nil,
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoost_SetMemberPermissions_NotFound(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()
	targetUser := uuid.New()

	mock.ExpectQuery("SELECT role FROM family_members").
		WithArgs(famID, boostUID).
		WillReturnRows(pgxmock.NewRows([]string{"role"}).AddRow("owner"))
	mock.ExpectExec("UPDATE family_members SET permissions").
		WithArgs(pgxmock.AnyArg(), famID, targetUser).
		WillReturnResult(pgxmock.NewResult("UPDATE", 0))

	_, err = svc.SetMemberPermissions(boostCtx(), &pb.SetMemberPermissionsRequest{
		FamilyId: famID.String(),
		UserId:   targetUser.String(),
		Permissions: &pb.MemberPermissions{
			CanView: true,
		},
	})
	assert.Equal(t, codes.NotFound, status.Code(err))
}

func TestBoost_SetMemberPermissions_InvalidFamilyID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.SetMemberPermissions(boostCtx(), &pb.SetMemberPermissionsRequest{
		FamilyId: "not-a-uuid",
		UserId:   uuid.New().String(),
		Permissions: &pb.MemberPermissions{
			CanView: true,
		},
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoost_SetMemberPermissions_InvalidUserID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.SetMemberPermissions(boostCtx(), &pb.SetMemberPermissionsRequest{
		FamilyId: uuid.New().String(),
		UserId:   "not-a-uuid",
		Permissions: &pb.MemberPermissions{
			CanView: true,
		},
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ════════════════════════════════════════════════════════════════════════════
// LeaveFamily
// ════════════════════════════════════════════════════════════════════════════

func TestBoost_LeaveFamily_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()

	mock.ExpectQuery("SELECT role FROM family_members").
		WithArgs(famID, boostUID).
		WillReturnRows(pgxmock.NewRows([]string{"role"}).AddRow("member"))
	mock.ExpectExec("DELETE FROM family_members").
		WithArgs(famID, boostUID).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))
	// audit log
	mock.ExpectExec("INSERT INTO audit_logs").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	_, err = svc.LeaveFamily(boostCtx(), &pb.LeaveFamilyRequest{FamilyId: famID.String()})
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoost_LeaveFamily_OwnerCannotLeave(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()

	mock.ExpectQuery("SELECT role FROM family_members").
		WithArgs(famID, boostUID).
		WillReturnRows(pgxmock.NewRows([]string{"role"}).AddRow("owner"))

	_, err = svc.LeaveFamily(boostCtx(), &pb.LeaveFamilyRequest{FamilyId: famID.String()})
	assert.Equal(t, codes.FailedPrecondition, status.Code(err))
}

func TestBoost_LeaveFamily_NotMember(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()

	mock.ExpectQuery("SELECT role FROM family_members").
		WithArgs(famID, boostUID).
		WillReturnError(pgx.ErrNoRows)

	_, err = svc.LeaveFamily(boostCtx(), &pb.LeaveFamilyRequest{FamilyId: famID.String()})
	assert.Equal(t, codes.NotFound, status.Code(err))
}

func TestBoost_LeaveFamily_InvalidFamilyID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.LeaveFamily(boostCtx(), &pb.LeaveFamilyRequest{FamilyId: "not-a-uuid"})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ════════════════════════════════════════════════════════════════════════════
// TransferOwnership
// ════════════════════════════════════════════════════════════════════════════

func TestBoost_TransferOwnership_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()
	newOwner := uuid.New()

	// requireRole: caller is owner
	mock.ExpectQuery("SELECT role FROM family_members").
		WithArgs(famID, boostUID).
		WillReturnRows(pgxmock.NewRows([]string{"role"}).AddRow("owner"))

	mock.ExpectBegin()
	// Check new owner is member
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(famID, newOwner).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))
	// Demote current owner
	mock.ExpectExec("UPDATE family_members SET role = 'admin'").
		WithArgs(famID, boostUID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	// Promote new owner
	mock.ExpectExec("UPDATE family_members SET role = 'owner'").
		WithArgs(pgxmock.AnyArg(), famID, newOwner).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	// Update families table
	mock.ExpectExec("UPDATE families SET owner_id").
		WithArgs(newOwner, famID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectCommit()
	// audit log
	mock.ExpectExec("INSERT INTO audit_logs").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	_, err = svc.TransferOwnership(boostCtx(), &pb.TransferOwnershipRequest{
		FamilyId:   famID.String(),
		NewOwnerId: newOwner.String(),
	})
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoost_TransferOwnership_NotOwner(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()
	newOwner := uuid.New()

	mock.ExpectQuery("SELECT role FROM family_members").
		WithArgs(famID, boostUID).
		WillReturnRows(pgxmock.NewRows([]string{"role"}).AddRow("admin"))

	_, err = svc.TransferOwnership(boostCtx(), &pb.TransferOwnershipRequest{
		FamilyId:   famID.String(),
		NewOwnerId: newOwner.String(),
	})
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

func TestBoost_TransferOwnership_NewOwnerNotMember(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()
	newOwner := uuid.New()

	mock.ExpectQuery("SELECT role FROM family_members").
		WithArgs(famID, boostUID).
		WillReturnRows(pgxmock.NewRows([]string{"role"}).AddRow("owner"))

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(famID, newOwner).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(false))
	mock.ExpectRollback()

	_, err = svc.TransferOwnership(boostCtx(), &pb.TransferOwnershipRequest{
		FamilyId:   famID.String(),
		NewOwnerId: newOwner.String(),
	})
	assert.Equal(t, codes.NotFound, status.Code(err))
}

func TestBoost_TransferOwnership_InvalidNewOwnerID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.TransferOwnership(boostCtx(), &pb.TransferOwnershipRequest{
		FamilyId:   uuid.New().String(),
		NewOwnerId: "not-a-uuid",
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ════════════════════════════════════════════════════════════════════════════
// DeleteFamily
// ════════════════════════════════════════════════════════════════════════════

func TestBoost_DeleteFamily_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()

	// requireRole: caller is owner
	mock.ExpectQuery("SELECT role FROM family_members").
		WithArgs(famID, boostUID).
		WillReturnRows(pgxmock.NewRows([]string{"role"}).AddRow("owner"))

	mock.ExpectBegin()
	// Delete transfers
	mock.ExpectExec("DELETE FROM transfers").
		WithArgs(famID).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))
	// Delete transactions
	mock.ExpectExec("DELETE FROM transactions").
		WithArgs(famID).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))
	// Delete accounts
	mock.ExpectExec("DELETE FROM accounts").
		WithArgs(famID).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))
	// Delete budgets
	mock.ExpectExec("DELETE FROM budgets").
		WithArgs(famID).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))
	// Delete loans
	mock.ExpectExec("DELETE FROM loans").
		WithArgs(famID).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))
	// Delete investments
	mock.ExpectExec("DELETE FROM investments").
		WithArgs(famID).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))
	// Delete fixed_assets
	mock.ExpectExec("DELETE FROM fixed_assets").
		WithArgs(famID).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))
	// Delete audit_logs
	mock.ExpectExec("DELETE FROM audit_logs").
		WithArgs(famID).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))
	// Delete family_members
	mock.ExpectExec("DELETE FROM family_members").
		WithArgs(famID).
		WillReturnResult(pgxmock.NewResult("DELETE", 2))
	// Delete family
	mock.ExpectExec("DELETE FROM families").
		WithArgs(famID).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))
	mock.ExpectCommit()

	_, err = svc.DeleteFamily(boostCtx(), &pb.DeleteFamilyRequest{FamilyId: famID.String()})
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoost_DeleteFamily_NotOwner(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	famID := uuid.New()

	mock.ExpectQuery("SELECT role FROM family_members").
		WithArgs(famID, boostUID).
		WillReturnRows(pgxmock.NewRows([]string{"role"}).AddRow("admin"))

	_, err = svc.DeleteFamily(boostCtx(), &pb.DeleteFamilyRequest{FamilyId: famID.String()})
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

func TestBoost_DeleteFamily_InvalidFamilyID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.DeleteFamily(boostCtx(), &pb.DeleteFamilyRequest{FamilyId: "bad-uuid"})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}
