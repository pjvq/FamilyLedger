package sync

import (
	"context"
	"encoding/json"
	"log"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/familyledger/server/pkg/middleware"
	"github.com/familyledger/server/pkg/ws"
	pb "github.com/familyledger/server/proto/sync"
)

type Service struct {
	pb.UnimplementedSyncServiceServer
	pool *pgxpool.Pool
	hub  *ws.Hub
}

func NewService(pool *pgxpool.Pool, hub *ws.Hub) *Service {
	return &Service{
		pool: pool,
		hub:  hub,
	}
}

func (s *Service) PushOperations(ctx context.Context, req *pb.PushOperationsRequest) (*pb.PushOperationsResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	uid, err := uuid.Parse(userID)
	if err != nil {
		return nil, status.Error(codes.Internal, "invalid user id")
	}

	if len(req.Operations) == 0 {
		return &pb.PushOperationsResponse{AcceptedCount: 0}, nil
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to begin transaction")
	}
	defer tx.Rollback(ctx)

	var failedIDs []string
	accepted := int32(0)

	for _, op := range req.Operations {
		entityID, err := uuid.Parse(op.EntityId)
		if err != nil {
			failedIDs = append(failedIDs, op.Id)
			continue
		}

		opType := "create"
		switch op.OpType {
		case pb.OperationType_OPERATION_TYPE_UPDATE:
			opType = "update"
		case pb.OperationType_OPERATION_TYPE_DELETE:
			opType = "delete"
		}

		ts := time.Now()
		if op.Timestamp != nil {
			ts = op.Timestamp.AsTime()
		}

		_, err = tx.Exec(ctx,
			`INSERT INTO sync_operations (user_id, entity_type, entity_id, op_type, payload, client_id, timestamp)
			 VALUES ($1, $2, $3, $4::sync_op_type, $5, $6, $7)`,
			uid, op.EntityType, entityID, opType, op.Payload, op.ClientId, ts,
		)
		if err != nil {
			log.Printf("sync: push op error for %s: %v", op.Id, err)
			failedIDs = append(failedIDs, op.Id)
			continue
		}
		accepted++
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Error(codes.Internal, "failed to commit")
	}

	// Broadcast change notification via WebSocket
	notification, _ := json.Marshal(ws.ChangeNotification{
		EntityType: "sync",
		EntityID:   "",
		OpType:     "push",
		UserID:     userID,
	})
	s.hub.BroadcastToUser(userID, notification)

	return &pb.PushOperationsResponse{
		AcceptedCount: accepted,
		FailedIds:     failedIDs,
	}, nil
}

func (s *Service) PullChanges(ctx context.Context, req *pb.PullChangesRequest) (*pb.PullChangesResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	uid, err := uuid.Parse(userID)
	if err != nil {
		return nil, status.Error(codes.Internal, "invalid user id")
	}

	since := time.Unix(0, 0)
	if req.Since != nil {
		since = req.Since.AsTime()
	}

	clientID := req.ClientId
	if clientID == "" {
		clientID = "unknown"
	}

	rows, err := s.pool.Query(ctx,
		`SELECT id, entity_type, entity_id, op_type, payload, client_id, timestamp
		 FROM sync_operations
		 WHERE user_id = $1 AND timestamp > $2 AND client_id != $3
		 ORDER BY timestamp ASC`,
		uid, since, clientID,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to query sync operations")
	}
	defer rows.Close()

	var operations []*pb.SyncOperation
	for rows.Next() {
		var id, entityID uuid.UUID
		var entityType, opTypeStr, payload, cID string
		var ts time.Time

		if err := rows.Scan(&id, &entityType, &entityID, &opTypeStr, &payload, &cID, &ts); err != nil {
			return nil, status.Error(codes.Internal, "failed to scan sync operation")
		}

		opType := pb.OperationType_OPERATION_TYPE_CREATE
		switch opTypeStr {
		case "update":
			opType = pb.OperationType_OPERATION_TYPE_UPDATE
		case "delete":
			opType = pb.OperationType_OPERATION_TYPE_DELETE
		}

		operations = append(operations, &pb.SyncOperation{
			Id:         id.String(),
			EntityType: entityType,
			EntityId:   entityID.String(),
			OpType:     opType,
			Payload:    payload,
			ClientId:   cID,
			Timestamp:  timestamppb.New(ts),
		})
	}

	if operations == nil {
		operations = []*pb.SyncOperation{}
	}

	return &pb.PullChangesResponse{
		Operations: operations,
		ServerTime: timestamppb.Now(),
	}, nil
}
