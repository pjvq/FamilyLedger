package sync

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
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/familyledger/server/pkg/middleware"
	"github.com/familyledger/server/pkg/ws"
	pb "github.com/familyledger/server/proto/sync"
)

const testUserID = "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"

func authedCtx() context.Context {
	return context.WithValue(context.Background(), middleware.UserIDKey, testUserID)
}

func noAuthCtx() context.Context {
	return context.Background()
}

func newTestHub() *ws.Hub {
	return ws.NewHub(nil)
}

// --------------- PushOperations ---------------

func TestPushOperations_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	hub := newTestHub()
	svc := NewService(mock, hub)

	userUUID := uuid.MustParse(testUserID)
	entityID := uuid.New()
	accountID := uuid.New()

	mock.ExpectBegin()

	// Insert sync_operation
	mock.ExpectExec(`INSERT INTO sync_operations`).
		WithArgs(
			userUUID,
			"transaction",
			entityID,
			pgxmock.AnyArg(), // op_type
			pgxmock.AnyArg(), // payload
			pgxmock.AnyArg(), // client_id
			pgxmock.AnyArg(), // timestamp
		).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	// applyOperation → applyTransactionCreate
	// Verify account ownership
	mock.ExpectQuery(`SELECT user_id FROM accounts WHERE id = \$1 AND deleted_at IS NULL`).
		WithArgs(accountID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}).AddRow(userUUID))

	// Insert transaction
	mock.ExpectExec(`INSERT INTO transactions`).
		WithArgs(
			entityID, userUUID, accountID,
			pgxmock.AnyArg(), // category_id
			pgxmock.AnyArg(), // amount
			pgxmock.AnyArg(), // currency
			pgxmock.AnyArg(), // amount_cny
			pgxmock.AnyArg(), // exchange_rate
			pgxmock.AnyArg(), // type
			pgxmock.AnyArg(), // note
			pgxmock.AnyArg(), // txn_date
			pgxmock.AnyArg(), // tags
			pgxmock.AnyArg(), // image_urls
		).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	// Update account balance
	mock.ExpectExec(`UPDATE accounts SET balance = balance \+ \$1`).
		WithArgs(pgxmock.AnyArg(), accountID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	mock.ExpectCommit()

	categoryID := uuid.New()
	payload := `{"id":"` + entityID.String() + `","account_id":"` + accountID.String() + `","category_id":"` + categoryID.String() + `","amount":5000,"currency":"CNY","type":"expense","note":"test"}`

	resp, err := svc.PushOperations(authedCtx(), &pb.PushOperationsRequest{
		Operations: []*pb.SyncOperation{
			{
				Id:         uuid.New().String(),
				EntityType: "transaction",
				EntityId:   entityID.String(),
				OpType:     pb.OperationType_OPERATION_TYPE_CREATE,
				Payload:    payload,
				ClientId:   "test-client",
				Timestamp:  timestamppb.Now(),
			},
		},
	})

	require.NoError(t, err)
	require.NotNil(t, resp)
	assert.Equal(t, int32(1), resp.AcceptedCount)
	assert.Empty(t, resp.FailedIds)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestPushOperations_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	hub := newTestHub()
	svc := NewService(mock, hub)

	resp, err := svc.PushOperations(noAuthCtx(), &pb.PushOperationsRequest{
		Operations: []*pb.SyncOperation{
			{
				Id:         uuid.New().String(),
				EntityType: "transaction",
				EntityId:   uuid.New().String(),
				OpType:     pb.OperationType_OPERATION_TYPE_CREATE,
				Payload:    "{}",
				ClientId:   "test-client",
				Timestamp:  timestamppb.Now(),
			},
		},
	})

	require.Nil(t, resp)
	require.Error(t, err)
	st, ok := status.FromError(err)
	require.True(t, ok)
	assert.Equal(t, codes.Unauthenticated, st.Code())
}

func TestPushOperations_EmptyOps(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	hub := newTestHub()
	svc := NewService(mock, hub)

	resp, err := svc.PushOperations(authedCtx(), &pb.PushOperationsRequest{
		Operations: []*pb.SyncOperation{},
	})

	require.NoError(t, err)
	require.NotNil(t, resp)
	assert.Equal(t, int32(0), resp.AcceptedCount)
	assert.NoError(t, mock.ExpectationsWereMet())
}

// --------------- PullChanges ---------------

func TestPullChanges_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	hub := newTestHub()
	svc := NewService(mock, hub)

	userUUID := uuid.MustParse(testUserID)
	opID := uuid.New()
	entityID := uuid.New()
	ts := time.Now()
	since := time.Now().Add(-1 * time.Hour)

	mock.ExpectQuery(`SELECT id, entity_type, entity_id, op_type, payload, client_id, timestamp`).
		WithArgs(userUUID, pgxmock.AnyArg(), "other-client").
		WillReturnRows(pgxmock.NewRows([]string{
			"id", "entity_type", "entity_id", "op_type", "payload", "client_id", "timestamp",
		}).AddRow(
			opID, "transaction", entityID, "create", `{"amount":1000}`, "another-client", ts,
		))

	resp, err := svc.PullChanges(authedCtx(), &pb.PullChangesRequest{
		Since:    timestamppb.New(since),
		ClientId: "other-client",
	})

	require.NoError(t, err)
	require.NotNil(t, resp)
	assert.Len(t, resp.Operations, 1)
	assert.Equal(t, opID.String(), resp.Operations[0].Id)
	assert.Equal(t, "transaction", resp.Operations[0].EntityType)
	assert.Equal(t, entityID.String(), resp.Operations[0].EntityId)
	assert.Equal(t, pb.OperationType_OPERATION_TYPE_CREATE, resp.Operations[0].OpType)
	assert.NotNil(t, resp.ServerTime)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestPullChanges_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	hub := newTestHub()
	svc := NewService(mock, hub)

	resp, err := svc.PullChanges(noAuthCtx(), &pb.PullChangesRequest{
		Since:    timestamppb.Now(),
		ClientId: "client-1",
	})

	require.Nil(t, resp)
	require.Error(t, err)
	st, ok := status.FromError(err)
	require.True(t, ok)
	assert.Equal(t, codes.Unauthenticated, st.Code())
}

func TestPullChanges_NoChanges(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	hub := newTestHub()
	svc := NewService(mock, hub)

	userUUID := uuid.MustParse(testUserID)

	mock.ExpectQuery(`SELECT id, entity_type, entity_id, op_type, payload, client_id, timestamp`).
		WithArgs(userUUID, pgxmock.AnyArg(), "my-client").
		WillReturnRows(pgxmock.NewRows([]string{
			"id", "entity_type", "entity_id", "op_type", "payload", "client_id", "timestamp",
		}))

	resp, err := svc.PullChanges(authedCtx(), &pb.PullChangesRequest{
		Since:    timestamppb.Now(),
		ClientId: "my-client",
	})

	require.NoError(t, err)
	require.NotNil(t, resp)
	assert.Empty(t, resp.Operations)
	assert.NotNil(t, resp.ServerTime)
	assert.NoError(t, mock.ExpectationsWereMet())
}
