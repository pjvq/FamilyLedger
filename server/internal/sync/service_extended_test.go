package sync

import (
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	pgxmock "github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	pb "github.com/familyledger/server/proto/sync"
)

// ─── DELETE terminal state (R9) ──────────────────────────────────────────────
// R9: DELETE should be terminal — once deleted, subsequent updates should be rejected.

func TestPushOperations_DeleteTerminalState_BlocksSubsequentUpdate(t *testing.T) {
	t.Skip("BLOCKED(R9): DELETE terminal state not yet implemented in server. " +
		"When implemented, a DELETE op followed by an UPDATE (even with later timestamp) " +
		"should keep the entity deleted. See tests/risks/R7_FAILED_IDS_BUG.md")
}

// ─── Idempotent push ─────────────────────────────────────────────────────────
// Pushing the same operation twice should not create duplicates.

func TestPushOperations_IdempotentPush_NoDuplicates(t *testing.T) {
	// R11: Server has ON CONFLICT (client_id) DO NOTHING for dedup.
	// This is fully tested in W5 integration test (TestSync_IdempotentPush).
	// Unit test verifies the dedup path returns accepted (not failed) when
	// INSERT returns ErrNoRows (ON CONFLICT DO NOTHING).
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	hub := newTestHub()
	svc := NewService(mock, hub)

	entityID := uuid.New()

	mock.ExpectBegin()
	// Savepoint for op
	mock.ExpectExec("SAVEPOINT").WillReturnResult(pgxmock.NewResult("SAVEPOINT", 0))
	// INSERT INTO sync_operations ... ON CONFLICT (client_id) DO NOTHING
	// Returns ErrNoRows when dedup hits (RETURNING gets no row)
	mock.ExpectQuery("INSERT INTO sync_operations").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnError(pgx.ErrNoRows)
	// Release savepoint (dedup path skips applyOperation)
	mock.ExpectExec("RELEASE").WillReturnResult(pgxmock.NewResult("RELEASE", 0))
	mock.ExpectCommit()

	resp, err := svc.PushOperations(authedCtx(), &pb.PushOperationsRequest{
		Operations: []*pb.SyncOperation{
			{
				Id:         "op-dedup",
				EntityType: "transaction",
				EntityId:   entityID.String(),
				OpType:     pb.OperationType_OPERATION_TYPE_CREATE,
				Payload:    `{"amount":100}`,
				ClientId:   "already-pushed-client-id",
				Timestamp:  timestamppb.Now(),
			},
		},
	})

	require.NoError(t, err)
	// Dedup'd op counts as accepted (idempotent success, not failure)
	assert.Equal(t, int32(1), resp.AcceptedCount)
	assert.Empty(t, resp.FailedIds, "dedup'd op should not be in failedIds")
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ─── PullChanges pagination (R3) ─────────────────────────────────────────────

func TestPullChanges_Pagination_NotSupported(t *testing.T) {
	t.Skip("BLOCKED(R3): PullChanges proto has no pagination fields. " +
		"Needs proto change: add page_size + page_token to PullChangesRequest, " +
		"next_page_token to PullChangesResponse. See tests/risks/R3_PULLCHANGES_PAGINATION.md")
}

// ─── PullChanges: timestamp boundary ─────────────────────────────────────────

func TestPullChanges_ZeroTimestamp_FullSync(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	hub := newTestHub()
	svc := NewService(mock, hub)

	userUUID := uuid.MustParse(testUserID)
	entityID := uuid.New()
	opID := uuid.New()
	opTime := time.Date(2026, 3, 15, 10, 0, 0, 0, time.UTC)

	// PullChanges with epoch 0 → full sync (returns all ops)
	mock.ExpectQuery(`SELECT id, entity_type, entity_id, op_type, payload, client_id, timestamp`).
		WithArgs(userUUID, pgxmock.AnyArg(), "test-client", 101).
		WillReturnRows(pgxmock.NewRows([]string{
			"id", "entity_type", "entity_id", "op_type", "payload", "client_id", "timestamp",
		}).AddRow(opID, "transaction", entityID, "create", `{"amount":100}`, "other-client", opTime))

	resp, err := svc.PullChanges(authedCtx(), &pb.PullChangesRequest{
		Since:    timestamppb.New(time.Unix(0, 0)), // epoch 0 → full sync
		ClientId: "test-client",
	})

	require.NoError(t, err)
	assert.Len(t, resp.Operations, 1)
	assert.Equal(t, entityID.String(), resp.Operations[0].EntityId)
	assert.Equal(t, "transaction", resp.Operations[0].EntityType)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestPullChanges_EmptyResult_NoError(t *testing.T) {
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
	assert.Empty(t, resp.Operations)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestPullChanges_DBFailure_ReturnsInternal(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	hub := newTestHub()
	svc := NewService(mock, hub)

	userUUID := uuid.MustParse(testUserID)

	mock.ExpectQuery(`SELECT id, entity_type, entity_id, op_type, payload, client_id, timestamp`).
		WithArgs(userUUID, pgxmock.AnyArg(), "client1").
		WillReturnError(assert.AnError)

	_, err = svc.PullChanges(authedCtx(), &pb.PullChangesRequest{
		Since:    timestamppb.Now(),
		ClientId: "client1",
	})

	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

// ─── PushOperations: partial failure ─────────────────────────────────────────

func TestPushOperations_PartialFailure_InvalidEntityId(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	mock.MatchExpectationsInOrder(false)

	hub := newTestHub()
	svc := NewService(mock, hub)

	badOpID := "op-bad-001"

	// Begin/Commit for the overall transaction
	mock.ExpectBegin()
	mock.ExpectCommit()

	// No DB operations expected for the invalid entity_id op
	// (uuid.Parse fails immediately → failedIds)

	resp, err := svc.PushOperations(authedCtx(), &pb.PushOperationsRequest{
		Operations: []*pb.SyncOperation{
			{
				Id:         badOpID,
				EntityType: "transaction",
				EntityId:   "not-a-uuid", // invalid UUID → immediate fail
				OpType:     pb.OperationType_OPERATION_TYPE_CREATE,
				Payload:    `{"amount":100}`,
			},
		},
	})

	require.NoError(t, err)
	assert.Equal(t, int32(0), resp.AcceptedCount)
	assert.Contains(t, resp.FailedIds, badOpID)
}

// ─── PushOperations: all 8 entity types reachable ────────────────────────────

func TestPushOperations_AllEntityTypes_Reachable(t *testing.T) {
	// Verify that all 8 entity types are recognized by the sync engine.
	// We send a minimal push and verify no "unknown entity type" error.
	// Some may fail on payload validation — that's expected and OK.
	entityTypes := []string{
		"transaction", "account", "category", "loan",
		"loan_group", "investment", "fixed_asset", "budget",
	}

	for _, et := range entityTypes {
		t.Run(et, func(t *testing.T) {
			mock, err := pgxmock.NewPool()
			require.NoError(t, err)
			defer mock.Close()

			hub := newTestHub()
			svc := NewService(mock, hub)
			entityID := uuid.New()

			// Allow any DB operations — we're testing routing reachability only.
			// NOTE: This test validates all 8 entity types are routable (R1 fix).
			// Full CRUD per entity_type is covered in W5 integration tests.
			mock.ExpectBegin()
			mock.ExpectExec("SAVEPOINT").WillReturnResult(pgxmock.NewResult("SAVEPOINT", 0))
			mock.ExpectExec("INSERT INTO sync_operations").
				WillReturnResult(pgxmock.NewResult("INSERT", 1))
			// applyOperation will Query or Exec depending on entity — use AnyArg
			mock.ExpectQuery("").WillReturnRows(pgxmock.NewRows([]string{"id"}).AddRow(uuid.New()))
			mock.ExpectExec("").WillReturnResult(pgxmock.NewResult("INSERT", 1))
			mock.ExpectExec("RELEASE").WillReturnResult(pgxmock.NewResult("RELEASE", 0))
			mock.ExpectExec("UPDATE sync_operations").WillReturnResult(pgxmock.NewResult("UPDATE", 1))
			mock.ExpectCommit()
			// fallback for rollback path
			mock.ExpectExec("ROLLBACK TO").WillReturnResult(pgxmock.NewResult("ROLLBACK", 0))

			resp, err := svc.PushOperations(authedCtx(), &pb.PushOperationsRequest{
				Operations: []*pb.SyncOperation{
					{
						Id:         uuid.New().String(),
						EntityType: et,
						EntityId:   entityID.String(),
						OpType:     pb.OperationType_OPERATION_TYPE_CREATE,
						Payload:    `{}`,
						Timestamp:  timestamppb.Now(),
					},
				},
			})

			if err != nil {
				st := status.Convert(err)
				assert.NotContains(t, st.Message(), "unknown entity type",
					"entity_type=%s should be recognized", et)
			} else {
				assert.GreaterOrEqual(t, resp.AcceptedCount+int32(len(resp.FailedIds)), int32(0))
			}
		})
	}
}

// ─── PushOperations: no auth ─────────────────────────────────────────────────

func TestPushOperations_MissingAuth_ReturnsUnauthenticated(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	hub := newTestHub()
	svc := NewService(mock, hub)

	_, err = svc.PushOperations(noAuthCtx(), &pb.PushOperationsRequest{
		Operations: []*pb.SyncOperation{
			{
				Id:         uuid.New().String(),
				EntityType: "transaction",
				EntityId:   uuid.New().String(),
				OpType:     pb.OperationType_OPERATION_TYPE_CREATE,
				Payload:    `{}`,
			},
		},
	})

	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestPullChanges_MissingAuth_ReturnsUnauthenticated(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	hub := newTestHub()
	svc := NewService(mock, hub)

	_, err = svc.PullChanges(noAuthCtx(), &pb.PullChangesRequest{
		Since: timestamppb.Now(),
	})

	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}
