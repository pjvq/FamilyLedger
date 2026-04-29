package family

import (
	"context"
	"testing"

	"github.com/google/uuid"
	pgxmock "github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	pb "github.com/familyledger/server/proto/family"
)

func noAuthCtx() context.Context {
	return context.Background()
}

// ─── ListMyFamilies ──────────────────────────────────────────────────────────

func TestListMyFamilies_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.ListMyFamilies(noAuthCtx(), &pb.ListMyFamiliesRequest{})

	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestListMyFamilies_DBFailure(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	mock.ExpectQuery(`SELECT`).WillReturnError(assert.AnError)

	_, err = svc.ListMyFamilies(authedCtx(), &pb.ListMyFamiliesRequest{})

	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

// ─── SetMemberPermissions ────────────────────────────────────────────────────

func TestSetMemberPermissions_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.SetMemberPermissions(noAuthCtx(), &pb.SetMemberPermissionsRequest{
		FamilyId: uuid.New().String(),
		UserId:   uuid.New().String(),
	})

	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestSetMemberPermissions_EmptyFamilyId(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.SetMemberPermissions(authedCtx(), &pb.SetMemberPermissionsRequest{
		FamilyId: "",
		UserId:   uuid.New().String(),
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── TransferOwnership ───────────────────────────────────────────────────────

func TestTransferOwnership_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.TransferOwnership(noAuthCtx(), &pb.TransferOwnershipRequest{
		FamilyId:   uuid.New().String(),
		NewOwnerId: uuid.New().String(),
	})

	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestTransferOwnership_EmptyFamilyId(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.TransferOwnership(authedCtx(), &pb.TransferOwnershipRequest{
		FamilyId:   "",
		NewOwnerId: uuid.New().String(),
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestTransferOwnership_EmptyNewOwnerId(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.TransferOwnership(authedCtx(), &pb.TransferOwnershipRequest{
		FamilyId:   uuid.New().String(),
		NewOwnerId: "",
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── DeleteFamily ────────────────────────────────────────────────────────────

func TestDeleteFamily_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.DeleteFamily(noAuthCtx(), &pb.DeleteFamilyRequest{
		FamilyId: uuid.New().String(),
	})

	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestDeleteFamily_EmptyId(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.DeleteFamily(authedCtx(), &pb.DeleteFamilyRequest{
		FamilyId: "",
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── JoinFamily: edge cases ──────────────────────────────────────────────────

func TestJoinFamily_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.JoinFamily(noAuthCtx(), &pb.JoinFamilyRequest{
		InviteCode: "ABC123",
	})

	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

// ─── GenerateInviteCode: edge cases ──────────────────────────────────────────

func TestGenerateInviteCode_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.GenerateInviteCode(noAuthCtx(), &pb.GenerateInviteCodeRequest{
		FamilyId: uuid.New().String(),
	})

	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestGenerateInviteCode_EmptyFamilyId(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.GenerateInviteCode(authedCtx(), &pb.GenerateInviteCodeRequest{
		FamilyId: "",
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}
