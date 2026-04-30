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
const testUserID2 = "b1ffcd00-ad1c-5f09-cc7e-7cc0ce491b22"

func authedCtx() context.Context {
	return context.WithValue(context.Background(), middleware.UserIDKey, testUserID)
}

func authedCtxAs(uid string) context.Context {
	return context.WithValue(context.Background(), middleware.UserIDKey, uid)
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

	// Savepoint for this operation
	mock.ExpectExec(`SAVEPOINT sp_0`).WillReturnResult(pgxmock.NewResult("SAVEPOINT", 0))

	// Insert sync_operation (now uses QueryRow with ON CONFLICT ... RETURNING)
	mock.ExpectQuery(`INSERT INTO sync_operations`).
		WithArgs(
			userUUID,
			"transaction",
			entityID,
			pgxmock.AnyArg(), // op_type
			pgxmock.AnyArg(), // payload
			pgxmock.AnyArg(), // client_id
			pgxmock.AnyArg(), // timestamp
		).
		WillReturnRows(pgxmock.NewRows([]string{""}).AddRow(true))

	// applyOperation → applyTransactionCreate
	// Verify account ownership (now includes family_id)
	mock.ExpectQuery(`SELECT user_id, family_id FROM accounts WHERE id = \$1 AND deleted_at IS NULL`).
		WithArgs(accountID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(userUUID, nil))

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

	// Release savepoint
	mock.ExpectExec(`RELEASE SAVEPOINT sp_0`).WillReturnResult(pgxmock.NewResult("RELEASE", 0))

	mock.ExpectCommit()

	// getFamilyMembersForOperations: check if transaction's account is a family account
	mock.ExpectQuery(`SELECT a.family_id FROM transactions t`).
		WithArgs(entityID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id"})) // no rows = personal

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

// TestPushOperations_FamilyBroadcast verifies that when a push targets a family account,
// the notification is broadcast to all family members.
func TestPushOperations_FamilyBroadcast(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	hub := newTestHub()
	svc := NewService(mock, hub)

	userUUID := uuid.MustParse(testUserID)
	user2UUID := uuid.MustParse(testUserID2)
	entityID := uuid.New()
	accountID := uuid.New()
	familyID := uuid.New()
	categoryID := uuid.New()

	mock.ExpectBegin()
	mock.ExpectExec(`SAVEPOINT sp_0`).WillReturnResult(pgxmock.NewResult("SAVEPOINT", 0))

	// Insert sync_operation (QueryRow with ON CONFLICT)
	mock.ExpectQuery(`INSERT INTO sync_operations`).
		WithArgs(
			userUUID,
			"transaction",
			entityID,
			pgxmock.AnyArg(),
			pgxmock.AnyArg(),
			pgxmock.AnyArg(),
			pgxmock.AnyArg(),
		).
		WillReturnRows(pgxmock.NewRows([]string{""}).AddRow(true))

	// applyTransactionCreate: account is a family account
	familyIDPtr := &familyID
	mock.ExpectQuery(`SELECT user_id, family_id FROM accounts WHERE id = \$1 AND deleted_at IS NULL`).
		WithArgs(accountID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(userUUID, familyIDPtr))

	// Insert transaction
	mock.ExpectExec(`INSERT INTO transactions`).
		WithArgs(
			entityID, userUUID, accountID,
			pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(),
			pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(),
			pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(),
			pgxmock.AnyArg(),
		).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	// Update account balance
	mock.ExpectExec(`UPDATE accounts SET balance = balance \+ \$1`).
		WithArgs(pgxmock.AnyArg(), accountID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	mock.ExpectExec(`RELEASE SAVEPOINT sp_0`).WillReturnResult(pgxmock.NewResult("RELEASE", 0))
	mock.ExpectCommit()

	// getFamilyMembersForOperations: transaction's account has family_id
	mock.ExpectQuery(`SELECT a.family_id FROM transactions t`).
		WithArgs(entityID).
		WillReturnRows(pgxmock.NewRows([]string{"family_id"}).AddRow(familyIDPtr))

	// Query family members
	mock.ExpectQuery(`SELECT user_id FROM family_members WHERE family_id = \$1`).
		WithArgs(familyID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}).
			AddRow(userUUID).
			AddRow(user2UUID))

	payload := `{"id":"` + entityID.String() + `","account_id":"` + accountID.String() + `","category_id":"` + categoryID.String() + `","amount":3000,"currency":"CNY","type":"expense","note":"family dinner"}`

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

// --------------- PullChanges ---------------

func TestPullChanges_PersonalMode_Success(t *testing.T) {
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
		WithArgs(userUUID, pgxmock.AnyArg(), "other-client", 101).
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

func TestPullChanges_PersonalMode_OnlyReturnsOwnOps(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	hub := newTestHub()
	svc := NewService(mock, hub)

	userUUID := uuid.MustParse(testUserID)

	// Personal mode only returns the user's own operations
	mock.ExpectQuery(`SELECT id, entity_type, entity_id, op_type, payload, client_id, timestamp`).
		WithArgs(userUUID, pgxmock.AnyArg(), "my-client", 101).
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

func TestPullChanges_FamilyMode_ReturnsFamilyMembersOps(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	hub := newTestHub()
	svc := NewService(mock, hub)

	userUUID := uuid.MustParse(testUserID)
	familyID := uuid.New()
	opID1 := uuid.New()
	opID2 := uuid.New()
	entityID1 := uuid.New()
	entityID2 := uuid.New()
	ts := time.Now()

	// Verify family membership
	mock.ExpectQuery(`SELECT EXISTS\(SELECT 1 FROM family_members WHERE family_id = \$1 AND user_id = \$2\)`).
		WithArgs(familyID, userUUID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))

	// Pull family operations (returns ops from both user1 and user2)
	mock.ExpectQuery(`SELECT so.id, so.entity_type, so.entity_id, so.op_type, so.payload, so.client_id, so.timestamp`).
		WithArgs(familyID, pgxmock.AnyArg(), "my-client", 101).
		WillReturnRows(pgxmock.NewRows([]string{
			"id", "entity_type", "entity_id", "op_type", "payload", "client_id", "timestamp",
		}).
			AddRow(opID1, "transaction", entityID1, "create", `{"amount":1000}`, "client-a", ts).
			AddRow(opID2, "account", entityID2, "update", `{"name":"shared"}`, "client-b", ts))

	resp, err := svc.PullChanges(authedCtx(), &pb.PullChangesRequest{
		Since:    timestamppb.New(ts.Add(-1 * time.Hour)),
		ClientId: "my-client",
		FamilyId: familyID.String(),
	})

	require.NoError(t, err)
	require.NotNil(t, resp)
	assert.Len(t, resp.Operations, 2)
	assert.Equal(t, opID1.String(), resp.Operations[0].Id)
	assert.Equal(t, opID2.String(), resp.Operations[1].Id)
	assert.NotNil(t, resp.ServerTime)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestPullChanges_FamilyMode_NonMemberDenied(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	hub := newTestHub()
	svc := NewService(mock, hub)

	userUUID := uuid.MustParse(testUserID)
	familyID := uuid.New()

	// Verify family membership - user is NOT a member
	mock.ExpectQuery(`SELECT EXISTS\(SELECT 1 FROM family_members WHERE family_id = \$1 AND user_id = \$2\)`).
		WithArgs(familyID, userUUID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(false))

	resp, err := svc.PullChanges(authedCtx(), &pb.PullChangesRequest{
		Since:    timestamppb.Now(),
		ClientId: "my-client",
		FamilyId: familyID.String(),
	})

	require.Nil(t, resp)
	require.Error(t, err)
	st, ok := status.FromError(err)
	require.True(t, ok)
	assert.Equal(t, codes.PermissionDenied, st.Code())
	assert.Contains(t, st.Message(), "not a member")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestPullChanges_FamilyMode_InvalidFamilyId(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	hub := newTestHub()
	svc := NewService(mock, hub)

	resp, err := svc.PullChanges(authedCtx(), &pb.PullChangesRequest{
		Since:    timestamppb.Now(),
		ClientId: "my-client",
		FamilyId: "not-a-valid-uuid",
	})

	require.Nil(t, resp)
	require.Error(t, err)
	st, ok := status.FromError(err)
	require.True(t, ok)
	assert.Equal(t, codes.InvalidArgument, st.Code())
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
		WithArgs(userUUID, pgxmock.AnyArg(), "my-client", 101).
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
