package sync

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/familyledger/server/pkg/db"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/familyledger/server/pkg/middleware"
	"github.com/familyledger/server/pkg/ws"
	pb "github.com/familyledger/server/proto/sync"
)

type Service struct {
	pb.UnimplementedSyncServiceServer
	pool db.Pool
	hub  *ws.Hub
}

func NewService(pool db.Pool, hub *ws.Hub) *Service {
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

	for i, op := range req.Operations {
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

		// Use savepoint so one failed op doesn't abort the entire transaction
		spName := fmt.Sprintf("sp_%d", i)
		_, err = tx.Exec(ctx, "SAVEPOINT "+spName)
		if err != nil {
			log.Printf("sync: savepoint error for %s: %v", op.Id, err)
			failedIDs = append(failedIDs, op.Id)
			continue
		}

		opFailed := false

		_, err = tx.Exec(ctx,
			`INSERT INTO sync_operations (user_id, entity_type, entity_id, op_type, payload, client_id, timestamp)
			 VALUES ($1, $2, $3, $4::sync_op_type, $5, $6, $7)`,
			uid, op.EntityType, entityID, opType, op.Payload, op.ClientId, ts,
		)
		if err != nil {
			log.Printf("sync: push op error for %s: %v", op.Id, err)
			opFailed = true
		}

		// Apply the operation to business tables
		if !opFailed {
			if err := s.applyOperation(ctx, tx, uid, op.EntityType, entityID, opType, op.Payload); err != nil {
				log.Printf("sync: apply op error for %s/%s %s: %v", op.EntityType, opType, op.Id, err)
				opFailed = true
			}
		}

		if opFailed {
			tx.Exec(ctx, "ROLLBACK TO SAVEPOINT "+spName)
			failedIDs = append(failedIDs, op.Id)
		} else {
			tx.Exec(ctx, "RELEASE SAVEPOINT "+spName)
			accepted++
		}
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

	// Determine if any operation targets a family account; if so, broadcast to all family members
	familyMembers := s.getFamilyMembersForOperations(ctx, req.Operations)
	if len(familyMembers) > 0 {
		for _, memberID := range familyMembers {
			s.hub.BroadcastToUser(memberID, notification)
		}
	} else {
		s.hub.BroadcastToUser(userID, notification)
	}

	return &pb.PushOperationsResponse{
		AcceptedCount: accepted,
		FailedIds:     failedIDs,
	}, nil
}

// applyOperation executes the business logic for a sync operation within the given DB transaction.
func (s *Service) applyOperation(ctx context.Context, tx pgx.Tx, userID uuid.UUID, entityType string, entityID uuid.UUID, opType string, payload string) error {
	switch entityType {
	case "transaction":
		return s.applyTransactionOp(ctx, tx, userID, entityID, opType, payload)
	case "account":
		return s.applyAccountOp(ctx, tx, userID, entityID, opType, payload)
	case "category":
		return s.applyCategoryOp(ctx, tx, userID, entityID, opType, payload)
	default:
		log.Printf("sync: unknown entity_type %q, skipping apply", entityType)
		return nil
	}
}

// transactionPayload represents the JSON payload for transaction operations.
type transactionPayload struct {
	ID           string  `json:"id"`
	AccountID    string  `json:"account_id"`
	CategoryID   string  `json:"category_id"`
	Amount       int64   `json:"amount"`
	Currency     string  `json:"currency"`
	AmountCny    int64   `json:"amount_cny"`
	ExchangeRate float64 `json:"exchange_rate"`
	Type         string  `json:"type"`
	Note         string  `json:"note"`
	TxnDate      string  `json:"txn_date"`
	Tags         []string `json:"tags"`
	ImageURLs    []string `json:"image_urls"`
}

func (s *Service) applyTransactionOp(ctx context.Context, tx pgx.Tx, userID uuid.UUID, entityID uuid.UUID, opType string, payload string) error {
	switch opType {
	case "create":
		return s.applyTransactionCreate(ctx, tx, userID, entityID, payload)
	case "update":
		return s.applyTransactionUpdate(ctx, tx, userID, entityID, payload)
	case "delete":
		return s.applyTransactionDelete(ctx, tx, userID, entityID)
	default:
		log.Printf("sync: unknown op_type %q for transaction, skipping", opType)
		return nil
	}
}

func (s *Service) applyTransactionCreate(ctx context.Context, tx pgx.Tx, userID uuid.UUID, entityID uuid.UUID, payload string) error {
	var p transactionPayload
	if err := json.Unmarshal([]byte(payload), &p); err != nil {
		return fmt.Errorf("invalid transaction create payload: %w", err)
	}

	accountID, err := uuid.Parse(p.AccountID)
	if err != nil {
		return fmt.Errorf("invalid account_id in payload: %w", err)
	}
	categoryID, err := uuid.Parse(p.CategoryID)
	if err != nil {
		return fmt.Errorf("invalid category_id in payload: %w", err)
	}

	// Verify account belongs to user or user is a family member
	var ownerID uuid.UUID
	var syncFamilyID *uuid.UUID
	err = tx.QueryRow(ctx,
		"SELECT user_id, family_id FROM accounts WHERE id = $1 AND deleted_at IS NULL",
		accountID,
	).Scan(&ownerID, &syncFamilyID)
	if err != nil {
		return fmt.Errorf("account not found: %w", err)
	}
	if ownerID != userID {
		if syncFamilyID == nil {
			return fmt.Errorf("account %s does not belong to user", accountID)
		}
		var isMember bool
		err = tx.QueryRow(ctx,
			"SELECT EXISTS(SELECT 1 FROM family_members WHERE family_id = $1 AND user_id = $2)",
			*syncFamilyID, userID,
		).Scan(&isMember)
		if err != nil || !isMember {
			return fmt.Errorf("account %s does not belong to user", accountID)
		}
	}

	currency := p.Currency
	if currency == "" {
		currency = "CNY"
	}
	amountCny := p.AmountCny
	exchangeRate := p.ExchangeRate
	if currency == "CNY" {
		amountCny = p.Amount
		exchangeRate = 1.0
	}

	txnType := p.Type
	if txnType != "income" && txnType != "expense" {
		txnType = "expense"
	}

	txnDate := time.Now()
	if p.TxnDate != "" {
		if parsed, err := time.Parse("2006-01-02T15:04:05.000", p.TxnDate); err == nil {
			txnDate = parsed
		} else if parsed, err := time.Parse(time.RFC3339, p.TxnDate); err == nil {
			txnDate = parsed
		}
	}

	tags := p.Tags
	if tags == nil {
		tags = []string{}
	}
	imageURLs := p.ImageURLs
	if imageURLs == nil {
		imageURLs = []string{}
	}

	_, err = tx.Exec(ctx,
		`INSERT INTO transactions (id, user_id, account_id, category_id, amount, currency, amount_cny, exchange_rate, type, note, txn_date, tags, image_urls)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9::transaction_type, $10, $11, $12, $13)`,
		entityID, userID, accountID, categoryID, p.Amount, currency, amountCny, exchangeRate, txnType, p.Note, txnDate, tags, imageURLs,
	)
	if err != nil {
		return fmt.Errorf("failed to insert transaction: %w", err)
	}

	// Update account balance
	balanceDelta := amountCny
	if txnType == "expense" {
		balanceDelta = -amountCny
	}
	_, err = tx.Exec(ctx,
		"UPDATE accounts SET balance = balance + $1, updated_at = NOW() WHERE id = $2",
		balanceDelta, accountID,
	)
	if err != nil {
		return fmt.Errorf("failed to update account balance: %w", err)
	}

	return nil
}

func (s *Service) applyTransactionUpdate(ctx context.Context, tx pgx.Tx, userID uuid.UUID, entityID uuid.UUID, payload string) error {
	var p transactionPayload
	if err := json.Unmarshal([]byte(payload), &p); err != nil {
		return fmt.Errorf("invalid transaction update payload: %w", err)
	}

	// Fetch existing transaction with lock and verify ownership
	var ownerID, accountID uuid.UUID
	var oldAmountCny int64
	var oldType, currency string
	var exchangeRate float64
	err := tx.QueryRow(ctx,
		`SELECT user_id, account_id, amount_cny, type, currency, exchange_rate
		 FROM transactions WHERE id = $1 AND deleted_at IS NULL FOR UPDATE`,
		entityID,
	).Scan(&ownerID, &accountID, &oldAmountCny, &oldType, &currency, &exchangeRate)
	if err != nil {
		if err == pgx.ErrNoRows {
			return fmt.Errorf("transaction %s not found", entityID)
		}
		return fmt.Errorf("failed to fetch transaction for update: %w", err)
	}
	if ownerID != userID {
		return fmt.Errorf("transaction %s does not belong to user", entityID)
	}

	// Build dynamic UPDATE
	setClauses := []string{"updated_at = NOW()"}
	args := []interface{}{}
	argIdx := 1

	newAmountCny := oldAmountCny
	newType := oldType

	if p.Amount > 0 {
		args = append(args, p.Amount)
		setClauses = append(setClauses, fmt.Sprintf("amount = $%d", argIdx))
		argIdx++

		var computedAmountCny int64
		if currency == "CNY" || currency == "" {
			computedAmountCny = p.Amount
		} else {
			computedAmountCny = int64(float64(p.Amount) * exchangeRate)
		}
		newAmountCny = computedAmountCny
		args = append(args, computedAmountCny)
		setClauses = append(setClauses, fmt.Sprintf("amount_cny = $%d", argIdx))
		argIdx++
	}

	if p.CategoryID != "" {
		catID, err := uuid.Parse(p.CategoryID)
		if err != nil {
			return fmt.Errorf("invalid category_id: %w", err)
		}
		args = append(args, catID)
		setClauses = append(setClauses, fmt.Sprintf("category_id = $%d", argIdx))
		argIdx++
	}

	if p.Note != "" {
		args = append(args, p.Note)
		setClauses = append(setClauses, fmt.Sprintf("note = $%d", argIdx))
		argIdx++
	}

	if p.Type == "income" || p.Type == "expense" {
		newType = p.Type
		args = append(args, p.Type)
		setClauses = append(setClauses, fmt.Sprintf("type = $%d::transaction_type", argIdx))
		argIdx++
	}

	if p.TxnDate != "" {
		var txnDate time.Time
		if parsed, err := time.Parse("2006-01-02T15:04:05.000", p.TxnDate); err == nil {
			txnDate = parsed
		} else if parsed, err := time.Parse(time.RFC3339, p.TxnDate); err == nil {
			txnDate = parsed
		} else {
			return fmt.Errorf("invalid txn_date format: %s", p.TxnDate)
		}
		args = append(args, txnDate)
		setClauses = append(setClauses, fmt.Sprintf("txn_date = $%d", argIdx))
		argIdx++
	}

	// Execute UPDATE
	args = append(args, entityID)
	query := fmt.Sprintf("UPDATE transactions SET %s WHERE id = $%d AND deleted_at IS NULL",
		strings.Join(setClauses, ", "), argIdx)
	_, err = tx.Exec(ctx, query, args...)
	if err != nil {
		return fmt.Errorf("failed to update transaction: %w", err)
	}

	// Recalculate balance: revert old delta, apply new delta
	var oldDelta, newDelta int64
	if oldType == "income" {
		oldDelta = oldAmountCny
	} else {
		oldDelta = -oldAmountCny
	}
	if newType == "income" {
		newDelta = newAmountCny
	} else {
		newDelta = -newAmountCny
	}
	balanceAdjust := newDelta - oldDelta
	if balanceAdjust != 0 {
		_, err = tx.Exec(ctx,
			"UPDATE accounts SET balance = balance + $1, updated_at = NOW() WHERE id = $2",
			balanceAdjust, accountID,
		)
		if err != nil {
			return fmt.Errorf("failed to update account balance: %w", err)
		}
	}

	return nil
}

func (s *Service) applyTransactionDelete(ctx context.Context, tx pgx.Tx, userID uuid.UUID, entityID uuid.UUID) error {
	// Fetch existing transaction with lock
	var ownerID, accountID uuid.UUID
	var amountCny int64
	var txnType string
	err := tx.QueryRow(ctx,
		`SELECT user_id, account_id, amount_cny, type
		 FROM transactions WHERE id = $1 AND deleted_at IS NULL FOR UPDATE`,
		entityID,
	).Scan(&ownerID, &accountID, &amountCny, &txnType)
	if err != nil {
		if err == pgx.ErrNoRows {
			// Already deleted — idempotent
			log.Printf("sync: transaction %s already deleted, skipping", entityID)
			return nil
		}
		return fmt.Errorf("failed to fetch transaction for delete: %w", err)
	}
	if ownerID != userID {
		return fmt.Errorf("transaction %s does not belong to user", entityID)
	}

	// Soft delete
	_, err = tx.Exec(ctx,
		"UPDATE transactions SET deleted_at = NOW(), updated_at = NOW() WHERE id = $1",
		entityID,
	)
	if err != nil {
		return fmt.Errorf("failed to soft-delete transaction: %w", err)
	}

	// Revert account balance
	var balanceRevert int64
	if txnType == "income" {
		balanceRevert = -amountCny
	} else {
		balanceRevert = amountCny
	}
	_, err = tx.Exec(ctx,
		"UPDATE accounts SET balance = balance + $1, updated_at = NOW() WHERE id = $2",
		balanceRevert, accountID,
	)
	if err != nil {
		return fmt.Errorf("failed to revert account balance: %w", err)
	}

	return nil
}

// accountPayload represents the JSON payload for account operations.
type accountPayload struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	Type     string `json:"type"`
	Balance  int64  `json:"balance"`
	Currency string `json:"currency"`
	Icon     string `json:"icon"`
	IsActive *bool  `json:"is_active"`
}

func (s *Service) applyAccountOp(ctx context.Context, tx pgx.Tx, userID uuid.UUID, entityID uuid.UUID, opType string, payload string) error {
	switch opType {
	case "create":
		return s.applyAccountCreate(ctx, tx, userID, entityID, payload)
	case "update":
		return s.applyAccountUpdate(ctx, tx, userID, entityID, payload)
	default:
		log.Printf("sync: unknown op_type %q for account, skipping", opType)
		return nil
	}
}

func (s *Service) applyAccountCreate(ctx context.Context, tx pgx.Tx, userID uuid.UUID, entityID uuid.UUID, payload string) error {
	var p accountPayload
	if err := json.Unmarshal([]byte(payload), &p); err != nil {
		return fmt.Errorf("invalid account create payload: %w", err)
	}

	if p.Name == "" {
		return fmt.Errorf("account name is required")
	}

	currency := p.Currency
	if currency == "" {
		currency = "CNY"
	}

	acctType := p.Type
	if acctType == "" {
		acctType = "cash"
	}

	_, err := tx.Exec(ctx,
		`INSERT INTO accounts (id, user_id, name, type, balance, currency, icon, is_active, is_default)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, true, false)`,
		entityID, userID, p.Name, acctType, p.Balance, currency, p.Icon,
	)
	if err != nil {
		return fmt.Errorf("failed to insert account: %w", err)
	}

	return nil
}

func (s *Service) applyAccountUpdate(ctx context.Context, tx pgx.Tx, userID uuid.UUID, entityID uuid.UUID, payload string) error {
	var p accountPayload
	if err := json.Unmarshal([]byte(payload), &p); err != nil {
		return fmt.Errorf("invalid account update payload: %w", err)
	}

	// Verify ownership
	var ownerID uuid.UUID
	err := tx.QueryRow(ctx,
		"SELECT user_id FROM accounts WHERE id = $1 AND deleted_at IS NULL FOR UPDATE",
		entityID,
	).Scan(&ownerID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return fmt.Errorf("account %s not found", entityID)
		}
		return fmt.Errorf("failed to fetch account for update: %w", err)
	}
	if ownerID != userID {
		return fmt.Errorf("account %s does not belong to user", entityID)
	}

	// Build dynamic UPDATE
	setClauses := []string{"updated_at = NOW()"}
	args := []interface{}{}
	argIdx := 1

	if p.Name != "" {
		args = append(args, p.Name)
		setClauses = append(setClauses, fmt.Sprintf("name = $%d", argIdx))
		argIdx++
	}
	if p.Type != "" {
		args = append(args, p.Type)
		setClauses = append(setClauses, fmt.Sprintf("type = $%d", argIdx))
		argIdx++
	}
	if p.Currency != "" {
		args = append(args, p.Currency)
		setClauses = append(setClauses, fmt.Sprintf("currency = $%d", argIdx))
		argIdx++
	}
	if p.Icon != "" {
		args = append(args, p.Icon)
		setClauses = append(setClauses, fmt.Sprintf("icon = $%d", argIdx))
		argIdx++
	}
	if p.IsActive != nil {
		args = append(args, *p.IsActive)
		setClauses = append(setClauses, fmt.Sprintf("is_active = $%d", argIdx))
		argIdx++
	}

	if len(args) == 0 {
		// Nothing to update besides updated_at
		_, err = tx.Exec(ctx, "UPDATE accounts SET updated_at = NOW() WHERE id = $1", entityID)
		return err
	}

	args = append(args, entityID)
	query := fmt.Sprintf("UPDATE accounts SET %s WHERE id = $%d AND deleted_at IS NULL",
		strings.Join(setClauses, ", "), argIdx)
	_, err = tx.Exec(ctx, query, args...)
	if err != nil {
		return fmt.Errorf("failed to update account: %w", err)
	}

	return nil
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

	var rows pgx.Rows

	if req.FamilyId != "" {
		// Family mode: verify membership, then pull ops from all family members
		familyID, err := uuid.Parse(req.FamilyId)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid family_id")
		}

		// Verify user is a member of this family
		var isMember bool
		err = s.pool.QueryRow(ctx,
			"SELECT EXISTS(SELECT 1 FROM family_members WHERE family_id = $1 AND user_id = $2)",
			familyID, uid,
		).Scan(&isMember)
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to verify family membership")
		}
		if !isMember {
			return nil, status.Error(codes.PermissionDenied, "user is not a member of this family")
		}

		// Pull operations from all family members that target family accounts.
		// We JOIN with accounts to ensure only operations on family-owned entities are returned.
		// For entity types without accounts (e.g. category), we include ops from family members directly.
		rows, err = s.pool.Query(ctx,
			`SELECT so.id, so.entity_type, so.entity_id, so.op_type, so.payload, so.client_id, so.timestamp
			 FROM sync_operations so
			 WHERE so.user_id IN (SELECT user_id FROM family_members WHERE family_id = $1)
			   AND so.timestamp > $2
			   AND so.client_id != $3
			   AND (
			     -- For transaction ops: entity must belong to a family account
			     (so.entity_type = 'transaction' AND so.entity_id IN (
			       SELECT t.id FROM transactions t
			       JOIN accounts a ON t.account_id = a.id
			       WHERE a.family_id = $1
			     ))
			     OR
			     -- For account ops: entity must be a family account
			     (so.entity_type = 'account' AND so.entity_id IN (
			       SELECT id FROM accounts WHERE family_id = $1
			     ))
			     OR
			     -- For other entity types (category, etc): include all from family members
			     (so.entity_type NOT IN ('transaction', 'account'))
			   )
			 ORDER BY so.timestamp ASC`,
			familyID, since, clientID,
		)
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to query family sync operations")
		}
	} else {
		// Personal mode: only pull operations for this user
		rows, err = s.pool.Query(ctx,
			`SELECT id, entity_type, entity_id, op_type, payload, client_id, timestamp
			 FROM sync_operations
			 WHERE user_id = $1 AND timestamp > $2 AND client_id != $3
			 ORDER BY timestamp ASC`,
			uid, since, clientID,
		)
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to query sync operations")
		}
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

// ── Category sync operations ────────────────────────────────────────────────

type categoryPayload struct {
	Name      string  `json:"name"`
	Icon      string  `json:"icon"`
	IconKey   string  `json:"icon_key"`
	Type      string  `json:"type"` // expense or income
	SortOrder int     `json:"sort_order"`
	ParentID  *string `json:"parent_id,omitempty"`
}

func (s *Service) applyCategoryOp(ctx context.Context, tx pgx.Tx, userID uuid.UUID, entityID uuid.UUID, opType string, payload string) error {
	switch opType {
	case "create":
		return s.applyCategoryCreate(ctx, tx, userID, entityID, payload)
	case "update":
		return s.applyCategoryUpdate(ctx, tx, userID, entityID, payload)
	case "delete":
		return s.applyCategoryDelete(ctx, tx, userID, entityID)
	default:
		log.Printf("sync: unknown op_type %q for category, skipping", opType)
		return nil
	}
}

func (s *Service) applyCategoryCreate(ctx context.Context, tx pgx.Tx, userID uuid.UUID, entityID uuid.UUID, payload string) error {
	var p categoryPayload
	if err := json.Unmarshal([]byte(payload), &p); err != nil {
		return fmt.Errorf("invalid category create payload: %w", err)
	}

	if p.Name == "" {
		return fmt.Errorf("category name is required")
	}
	if p.Type == "" {
		p.Type = "expense"
	}

	var parentID *uuid.UUID
	if p.ParentID != nil && *p.ParentID != "" {
		pid, err := uuid.Parse(*p.ParentID)
		if err != nil {
			return fmt.Errorf("invalid parent_id: %w", err)
		}
		parentID = &pid
	}

	_, err := tx.Exec(ctx,
		`INSERT INTO categories (id, name, icon, icon_key, type, is_preset, sort_order, user_id, parent_id)
		 VALUES ($1, $2, $3, $4, $5, false, $6, $7, $8)
		 ON CONFLICT (id) DO UPDATE SET
		   name = EXCLUDED.name, icon = EXCLUDED.icon, icon_key = EXCLUDED.icon_key,
		   sort_order = EXCLUDED.sort_order, parent_id = EXCLUDED.parent_id`,
		entityID, p.Name, p.Icon, p.IconKey, p.Type, p.SortOrder, userID, parentID,
	)
	if err != nil {
		return fmt.Errorf("failed to insert category: %w", err)
	}

	return nil
}

func (s *Service) applyCategoryUpdate(ctx context.Context, tx pgx.Tx, userID uuid.UUID, entityID uuid.UUID, payload string) error {
	var p categoryPayload
	if err := json.Unmarshal([]byte(payload), &p); err != nil {
		return fmt.Errorf("invalid category update payload: %w", err)
	}

	// Verify ownership: user-created categories have user_id set;
	// preset categories (user_id IS NULL) cannot be edited via sync.
	var catUserID *uuid.UUID
	var isPreset bool
	err := tx.QueryRow(ctx,
		"SELECT user_id, is_preset FROM categories WHERE id = $1 AND deleted_at IS NULL",
		entityID,
	).Scan(&catUserID, &isPreset)
	if err != nil {
		if err == pgx.ErrNoRows {
			log.Printf("sync: category %s not found, skipping update", entityID)
			return nil
		}
		return fmt.Errorf("failed to fetch category for update: %w", err)
	}
	if isPreset {
		log.Printf("sync: cannot update preset category %s, skipping", entityID)
		return nil
	}
	if catUserID != nil && *catUserID != userID {
		return fmt.Errorf("category %s does not belong to user", entityID)
	}

	// Build dynamic UPDATE
	setClauses := []string{}
	args := []interface{}{}
	argIdx := 1

	if p.Name != "" {
		setClauses = append(setClauses, fmt.Sprintf("name = $%d", argIdx))
		args = append(args, p.Name)
		argIdx++
	}
	if p.Icon != "" {
		setClauses = append(setClauses, fmt.Sprintf("icon = $%d", argIdx))
		args = append(args, p.Icon)
		argIdx++
	}
	if p.IconKey != "" {
		setClauses = append(setClauses, fmt.Sprintf("icon_key = $%d", argIdx))
		args = append(args, p.IconKey)
		argIdx++
	}
	if p.SortOrder > 0 {
		setClauses = append(setClauses, fmt.Sprintf("sort_order = $%d", argIdx))
		args = append(args, p.SortOrder)
		argIdx++
	}

	if len(setClauses) == 0 {
		return nil // nothing to update
	}

	query := fmt.Sprintf(
		"UPDATE categories SET %s WHERE id = $%d AND deleted_at IS NULL",
		strings.Join(setClauses, ", "), argIdx,
	)
	args = append(args, entityID)

	_, err = tx.Exec(ctx, query, args...)
	if err != nil {
		return fmt.Errorf("failed to update category: %w", err)
	}

	return nil
}

func (s *Service) applyCategoryDelete(ctx context.Context, tx pgx.Tx, userID uuid.UUID, entityID uuid.UUID) error {
	// Soft delete: only user-created categories can be deleted
	var isPreset bool
	var catUserID *uuid.UUID
	err := tx.QueryRow(ctx,
		"SELECT user_id, is_preset FROM categories WHERE id = $1 AND deleted_at IS NULL",
		entityID,
	).Scan(&catUserID, &isPreset)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil // already deleted
		}
		return fmt.Errorf("failed to fetch category for delete: %w", err)
	}
	if isPreset {
		log.Printf("sync: cannot delete preset category %s, skipping", entityID)
		return nil
	}
	if catUserID != nil && *catUserID != userID {
		return fmt.Errorf("category %s does not belong to user", entityID)
	}

	// Soft delete category and its children
	_, err = tx.Exec(ctx,
		"UPDATE categories SET deleted_at = NOW() WHERE id = $1 OR parent_id = $1",
		entityID,
	)
	if err != nil {
		return fmt.Errorf("failed to soft-delete category: %w", err)
	}

	return nil
}

// getFamilyMembersForOperations checks if any of the pushed operations target a family account.
// If so, it returns the user IDs of all family members (for broadcast). Returns nil if personal-only.
func (s *Service) getFamilyMembersForOperations(ctx context.Context, operations []*pb.SyncOperation) []string {
	// Collect entity IDs from operations that might reference family accounts
	var accountIDs []string
	var transactionIDs []string

	for _, op := range operations {
		switch op.EntityType {
		case "account":
			accountIDs = append(accountIDs, op.EntityId)
		case "transaction":
			transactionIDs = append(transactionIDs, op.EntityId)
		}
	}

	if len(accountIDs) == 0 && len(transactionIDs) == 0 {
		return nil
	}

	// Check if any referenced accounts have a family_id
	// For transactions, look up their account_id first
	var familyID *uuid.UUID

	// Check direct account operations
	for _, idStr := range accountIDs {
		accID, err := uuid.Parse(idStr)
		if err != nil {
			continue
		}
		var fid *uuid.UUID
		err = s.pool.QueryRow(ctx,
			"SELECT family_id FROM accounts WHERE id = $1 AND family_id IS NOT NULL",
			accID,
		).Scan(&fid)
		if err == nil && fid != nil {
			familyID = fid
			break
		}
	}

	// If not found yet, check transaction operations
	if familyID == nil {
		for _, idStr := range transactionIDs {
			txnID, err := uuid.Parse(idStr)
			if err != nil {
				continue
			}
			var fid *uuid.UUID
			err = s.pool.QueryRow(ctx,
				`SELECT a.family_id FROM transactions t
				 JOIN accounts a ON t.account_id = a.id
				 WHERE t.id = $1 AND a.family_id IS NOT NULL`,
				txnID,
			).Scan(&fid)
			if err == nil && fid != nil {
				familyID = fid
				break
			}
		}
	}

	if familyID == nil {
		return nil
	}

	// Get all family member user IDs
	rows, err := s.pool.Query(ctx,
		"SELECT user_id FROM family_members WHERE family_id = $1",
		*familyID,
	)
	if err != nil {
		log.Printf("sync: failed to query family members for broadcast: %v", err)
		return nil
	}
	defer rows.Close()

	var members []string
	for rows.Next() {
		var memberUID uuid.UUID
		if err := rows.Scan(&memberUID); err != nil {
			continue
		}
		members = append(members, memberUID.String())
	}

	return members
}
