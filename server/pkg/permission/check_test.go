package permission

import (
	"context"
	"encoding/json"
	"errors"
	"testing"

	"github.com/jackc/pgx/v5"
	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

const (
	validUserID   = "550e8400-e29b-41d4-a716-446655440000"
	validFamilyID = "660e8400-e29b-41d4-a716-446655440001"
)

func permissionsJSON(p Permissions) []byte {
	b, _ := json.Marshal(p)
	return b
}

func TestCheck_EmptyFamilyID_ReturnsNil(t *testing.T) {
	err := Check(context.Background(), nil, validUserID, "", CanView)
	assert.NoError(t, err)
}

func TestCheck_OwnerRole_Passes(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).
			AddRow("owner", []byte(`{}`)))

	err = Check(context.Background(), mock, validUserID, validFamilyID, CanView)
	assert.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestCheck_AdminRole_Passes(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).
			AddRow("admin", []byte(`{}`)))

	err = Check(context.Background(), mock, validUserID, validFamilyID, CanCreate)
	assert.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestCheck_MemberWithPermission_Passes(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	perms := permissionsJSON(Permissions{CanCreate: true})
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).
			AddRow("member", perms))

	err = Check(context.Background(), mock, validUserID, validFamilyID, CanCreate)
	assert.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestCheck_MemberWithoutPermission_PermissionDenied(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	perms := permissionsJSON(Permissions{CanCreate: false})
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).
			AddRow("member", perms))

	err = Check(context.Background(), mock, validUserID, validFamilyID, CanCreate)
	require.Error(t, err)
	st, ok := status.FromError(err)
	require.True(t, ok)
	assert.Equal(t, codes.PermissionDenied, st.Code())
	assert.Contains(t, st.Message(), "insufficient permissions")
}

func TestCheck_NotAMember_PermissionDenied(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnError(pgx.ErrNoRows)

	err = Check(context.Background(), mock, validUserID, validFamilyID, CanView)
	require.Error(t, err)
	st, ok := status.FromError(err)
	require.True(t, ok)
	assert.Equal(t, codes.PermissionDenied, st.Code())
	assert.Contains(t, st.Message(), "not a member")
}

func TestCheck_DatabaseError_Internal(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnError(errors.New("connection refused"))

	err = Check(context.Background(), mock, validUserID, validFamilyID, CanView)
	require.Error(t, err)
	st, ok := status.FromError(err)
	require.True(t, ok)
	assert.Equal(t, codes.Internal, st.Code())
	assert.Contains(t, st.Message(), "failed to check permissions")
}

func TestCheck_InvalidUserID_Internal(t *testing.T) {
	err := Check(context.Background(), nil, "not-a-uuid", validFamilyID, CanView)
	require.Error(t, err)
	st, ok := status.FromError(err)
	require.True(t, ok)
	assert.Equal(t, codes.Internal, st.Code())
	assert.Contains(t, st.Message(), "invalid user id")
}

func TestCheck_InvalidFamilyID_InvalidArgument(t *testing.T) {
	err := Check(context.Background(), nil, validUserID, "not-a-uuid", CanView)
	require.Error(t, err)
	st, ok := status.FromError(err)
	require.True(t, ok)
	assert.Equal(t, codes.InvalidArgument, st.Code())
	assert.Contains(t, st.Message(), "invalid family_id")
}

func TestCheck_CorruptedPermissionsJSON_Internal(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).
			AddRow("member", []byte(`{corrupted json`)))

	err = Check(context.Background(), mock, validUserID, validFamilyID, CanView)
	require.Error(t, err)
	st, ok := status.FromError(err)
	require.True(t, ok)
	assert.Equal(t, codes.Internal, st.Code())
	assert.Contains(t, st.Message(), "corrupted")
}

// TestCheck_AllPermissionFunctions verifies each permission function works correctly.
func TestCheck_CanView_Granted(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	perms := permissionsJSON(Permissions{CanView: true})
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).
			AddRow("member", perms))

	err = Check(context.Background(), mock, validUserID, validFamilyID, CanView)
	assert.NoError(t, err)
}

func TestCheck_CanView_Denied(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	perms := permissionsJSON(Permissions{CanView: false})
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).
			AddRow("member", perms))

	err = Check(context.Background(), mock, validUserID, validFamilyID, CanView)
	require.Error(t, err)
	st, _ := status.FromError(err)
	assert.Equal(t, codes.PermissionDenied, st.Code())
}

func TestCheck_CanEdit_Granted(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	perms := permissionsJSON(Permissions{CanEdit: true})
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).
			AddRow("member", perms))

	err = Check(context.Background(), mock, validUserID, validFamilyID, CanEdit)
	assert.NoError(t, err)
}

func TestCheck_CanEdit_Denied(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	perms := permissionsJSON(Permissions{CanEdit: false})
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).
			AddRow("member", perms))

	err = Check(context.Background(), mock, validUserID, validFamilyID, CanEdit)
	require.Error(t, err)
	st, _ := status.FromError(err)
	assert.Equal(t, codes.PermissionDenied, st.Code())
}

func TestCheck_CanDelete_Granted(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	perms := permissionsJSON(Permissions{CanDelete: true})
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).
			AddRow("member", perms))

	err = Check(context.Background(), mock, validUserID, validFamilyID, CanDelete)
	assert.NoError(t, err)
}

func TestCheck_CanDelete_Denied(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	perms := permissionsJSON(Permissions{CanDelete: false})
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).
			AddRow("member", perms))

	err = Check(context.Background(), mock, validUserID, validFamilyID, CanDelete)
	require.Error(t, err)
	st, _ := status.FromError(err)
	assert.Equal(t, codes.PermissionDenied, st.Code())
}

func TestCheck_CanManageAccounts_Granted(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	perms := permissionsJSON(Permissions{CanManageAccounts: true})
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).
			AddRow("member", perms))

	err = Check(context.Background(), mock, validUserID, validFamilyID, CanManageAccounts)
	assert.NoError(t, err)
}

func TestCheck_CanManageAccounts_Denied(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	perms := permissionsJSON(Permissions{CanManageAccounts: false})
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).
			AddRow("member", perms))

	err = Check(context.Background(), mock, validUserID, validFamilyID, CanManageAccounts)
	require.Error(t, err)
	st, _ := status.FromError(err)
	assert.Equal(t, codes.PermissionDenied, st.Code())
}
