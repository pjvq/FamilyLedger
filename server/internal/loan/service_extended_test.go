package loan

import (
	"context"
	"testing"

	"github.com/google/uuid"
	pgxmock "github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"github.com/familyledger/server/pkg/middleware"
	pb "github.com/familyledger/server/proto/loan"
)

func extAuthedCtx() context.Context {
	return context.WithValue(context.Background(), middleware.UserIDKey, testUserID)
}

func extNoAuthCtx() context.Context {
	return context.Background()
}

// ─── RecordRateChange ────────────────────────────────────────────────────────

func TestRecordRateChange_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.RecordRateChange(extNoAuthCtx(), &pb.RecordRateChangeRequest{
		LoanId:  uuid.New().String(),
		NewRate: 3.5,
	})

	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestRecordRateChange_EmptyId(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.RecordRateChange(extAuthedCtx(), &pb.RecordRateChangeRequest{
		LoanId:  "",
		NewRate: 3.5,
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── CreateLoanGroup ─────────────────────────────────────────────────────────

func TestCreateLoanGroup_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.CreateLoanGroup(extNoAuthCtx(), &pb.CreateLoanGroupRequest{
		Name: "Test Group",
	})

	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestCreateLoanGroup_EmptyName(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.CreateLoanGroup(extAuthedCtx(), &pb.CreateLoanGroupRequest{
		Name: "",
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── GetLoanGroup ────────────────────────────────────────────────────────────

func TestGetLoanGroup_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.GetLoanGroup(extNoAuthCtx(), &pb.GetLoanGroupRequest{
		GroupId: uuid.New().String(),
	})

	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestGetLoanGroup_EmptyId(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.GetLoanGroup(extAuthedCtx(), &pb.GetLoanGroupRequest{
		GroupId: "",
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── SimulateGroupPrepayment ─────────────────────────────────────────────────

func TestSimulateGroupPrepayment_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.SimulateGroupPrepayment(extNoAuthCtx(), &pb.SimulateGroupPrepaymentRequest{
		GroupId:          uuid.New().String(),
		PrepaymentAmount: 50000,
	})

	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestSimulateGroupPrepayment_ZeroAmount(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.SimulateGroupPrepayment(extAuthedCtx(), &pb.SimulateGroupPrepaymentRequest{
		GroupId:          uuid.New().String(),
		PrepaymentAmount: 0,
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── ListLoanGroups ──────────────────────────────────────────────────────────

func TestListLoanGroups_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)

	_, err = svc.ListLoanGroups(extNoAuthCtx(), &pb.ListLoanGroupsRequest{})

	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}
