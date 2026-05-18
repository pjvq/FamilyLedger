package sync

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"strconv"
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

// parseTxnDate parses txn_date strings from sync payloads.
// Supports multiple formats produced by Dart's toIso8601String() and Go's Format():
//   - RFC3339:            "2026-05-16T23:31:00+08:00" or "2026-05-16T23:31:00Z"
//   - 6-digit µs no tz:  "2026-05-16T23:31:00.000000" (Dart local DateTime)
//   - 3-digit ms no tz:  "2026-05-16T23:31:00.000"
//   - no fraction no tz: "2026-05-16T23:31:00"
//   - date only:         "2026-05-16"
//
// For formats without timezone info, we assume UTC. New clients (v14+) always
// send UTC via DateTime.toUtc().toIso8601String(). Legacy clients may have sent
// local time without timezone — treating those as UTC is the lesser evil vs.
// guessing the client's timezone.
//
// Returns (time, hadTimezone, error). Callers can use hadTimezone to decide
// whether to log a warning (avoids per-call log spam in batch scenarios).
func parseTxnDate(s string) (time.Time, bool, error) {
	s = strings.TrimSpace(s)
	if s == "" {
		return time.Time{}, false, fmt.Errorf("parseTxnDate: empty string")
	}

	// Fast path: try RFC3339Nano first — its fractional-second part is optional
	// in Go's time.Parse, so it also handles plain RFC3339 strings.
	// RFC3339 kept as explicit fallback for safety.
	if t, err := time.Parse(time.RFC3339Nano, s); err == nil {
		return t, true, nil
	}
	if t, err := time.Parse(time.RFC3339, s); err == nil {
		return t, true, nil
	}

	// No timezone — pick format by string length, then parse as UTC.
	var format string
	switch {
	case len(s) == 10: // "2006-01-02"
		format = "2006-01-02"
	case len(s) == 19: // "2006-01-02T15:04:05"
		format = "2006-01-02T15:04:05"
	case len(s) == 23: // "2006-01-02T15:04:05.000"
		format = "2006-01-02T15:04:05.000"
	case len(s) == 26: // "2006-01-02T15:04:05.000000"
		format = "2006-01-02T15:04:05.000000"
	default:
		return time.Time{}, false, fmt.Errorf("parseTxnDate: unrecognized format (len=%d): %q", len(s), s)
	}

	t, err := time.ParseInLocation(format, s, time.UTC)
	if err != nil {
		return time.Time{}, false, fmt.Errorf("parseTxnDate: parse failed for format %q: %w", format, err)
	}

	return t, false, nil
}

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

		var inserted bool
		err = tx.QueryRow(ctx,
			`INSERT INTO sync_operations (user_id, entity_type, entity_id, op_type, payload, client_id, timestamp)
			 VALUES ($1, $2, $3, $4::sync_op_type, $5, $6, $7)
			 ON CONFLICT (client_id) WHERE client_id IS NOT NULL AND client_id != ''
			 DO NOTHING
			 RETURNING true`,
			uid, op.EntityType, entityID, opType, op.Payload, op.ClientId, ts,
		).Scan(&inserted)
		if err == pgx.ErrNoRows {
			// Duplicate client_id — idempotent success (skip applying again)
			accepted++
			_, _ = tx.Exec(ctx, "RELEASE SAVEPOINT "+spName)
			continue
		}
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

	// Broadcast to all family members if user belongs to any family.
	// Previously only checked account/transaction entities for family_id,
	// which meant budget/loan/investment/asset/category changes were never
	// broadcast to other family members.
	familyMembers := s.getFamilyMembersForUser(ctx, userID)
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
	case "loan":
		return s.applyLoanOp(ctx, tx, userID, entityID, opType, payload)
	case "loan_group":
		return s.applyLoanGroupOp(ctx, tx, userID, entityID, opType, payload)
	case "investment":
		return s.applyInvestmentOp(ctx, tx, userID, entityID, opType, payload)
	case "fixed_asset":
		return s.applyFixedAssetOp(ctx, tx, userID, entityID, opType, payload)
	case "budget":
		return s.applyBudgetOp(ctx, tx, userID, entityID, opType, payload)
	default:
		return fmt.Errorf("unknown entity_type %q", entityType)
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
		parsed, hadTZ, err := parseTxnDate(p.TxnDate)
		if err != nil {
			log.Printf("sync: create: parseTxnDate failed for %q: %v", p.TxnDate, err)
			return fmt.Errorf("invalid txn_date format")
		}
		if !hadTZ {
			log.Printf("sync: create: txn_date %q has no timezone, parsed as UTC (legacy client?)", p.TxnDate)
		}
		txnDate = parsed
	}

	tags := p.Tags
	if tags == nil {
		tags = []string{}
	}
	imageURLs := p.ImageURLs
	if imageURLs == nil {
		imageURLs = []string{}
	}

	cmdTag, err := tx.Exec(ctx,
		`INSERT INTO transactions (id, user_id, account_id, category_id, amount, currency, amount_cny, exchange_rate, type, note, txn_date, tags, image_urls)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9::transaction_type, $10, $11, $12, $13)
		 ON CONFLICT (id) DO NOTHING`,
		entityID, userID, accountID, categoryID, p.Amount, currency, amountCny, exchangeRate, txnType, p.Note, txnDate, tags, imageURLs,
	)
	if err != nil {
		return fmt.Errorf("failed to insert transaction: %w", err)
	}

	// If the row already existed (duplicate push), skip balance update
	if cmdTag.RowsAffected() == 0 {
		log.Printf("sync: transaction %s already exists, skipping (idempotent)", entityID)
		return nil
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
	var ownerID, oldAccountID uuid.UUID
	var oldAmountCny int64
	var oldType, currency string
	var exchangeRate float64
	err := tx.QueryRow(ctx,
		`SELECT user_id, account_id, amount_cny, type, currency, exchange_rate
		 FROM transactions WHERE id = $1 AND deleted_at IS NULL FOR UPDATE`,
		entityID,
	).Scan(&ownerID, &oldAccountID, &oldAmountCny, &oldType, &currency, &exchangeRate)
	if err != nil {
		if err == pgx.ErrNoRows {
			return fmt.Errorf("transaction %s not found", entityID)
		}
		return fmt.Errorf("failed to fetch transaction for update: %w", err)
	}
	if ownerID != userID {
		return fmt.Errorf("transaction %s does not belong to user", entityID)
	}

	// Track if account is changing
	newAccountID := oldAccountID
	accountChanged := false

	// Build dynamic UPDATE
	setClauses := []string{"updated_at = NOW()"}
	args := []interface{}{}
	argIdx := 1

	newAmountCny := oldAmountCny
	newType := oldType

	if p.AccountID != "" {
		parsedAccID, err := uuid.Parse(p.AccountID)
		if err != nil {
			return fmt.Errorf("invalid account_id: %w", err)
		}
		if parsedAccID != oldAccountID {
			// Verify new account exists and belongs to user
			var accOwner uuid.UUID
			err = tx.QueryRow(ctx,
				"SELECT user_id FROM accounts WHERE id = $1 AND deleted_at IS NULL",
				parsedAccID,
			).Scan(&accOwner)
			if err != nil {
				return fmt.Errorf("new account %s not found", parsedAccID)
			}
			if accOwner != userID {
				// Check family membership + CanCreate permission
				var famID *string
				_ = tx.QueryRow(ctx,
					"SELECT family_id::text FROM accounts WHERE id = $1", parsedAccID,
				).Scan(&famID)
				if famID == nil {
					return fmt.Errorf("new account %s does not belong to user", parsedAccID)
				}
				// Verify user is a member of this family
				var isMember bool
				err := tx.QueryRow(ctx,
					"SELECT EXISTS(SELECT 1 FROM family_members WHERE family_id = $1::uuid AND user_id = $2)",
					*famID, userID,
				).Scan(&isMember)
				if err != nil || !isMember {
					return fmt.Errorf("user is not a member of the family owning account %s", parsedAccID)
				}
				// Check CanCreate permission
				var canCreate bool
				err = tx.QueryRow(ctx,
					`SELECT COALESCE(can_create, true) FROM family_members WHERE family_id = $1::uuid AND user_id = $2`,
					*famID, userID,
				).Scan(&canCreate)
				if err != nil || !canCreate {
					return fmt.Errorf("user lacks create permission on family account %s", parsedAccID)
				}
			}
			newAccountID = parsedAccID
			accountChanged = true
			args = append(args, parsedAccID)
			setClauses = append(setClauses, fmt.Sprintf("account_id = $%d", argIdx))
			argIdx++
		}
	}

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
		txnDate, hadTZ, err := parseTxnDate(p.TxnDate)
		if err != nil {
			log.Printf("sync: update: parseTxnDate failed for %q: %v", p.TxnDate, err)
			return fmt.Errorf("invalid txn_date format")
		}
		if !hadTZ {
			log.Printf("sync: update: txn_date %q has no timezone, parsed as UTC (legacy client?)", p.TxnDate)
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

	// Recalculate balance
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

	if accountChanged {
		// Revert old delta from old account
		if oldDelta != 0 {
			_, err = tx.Exec(ctx,
				"UPDATE accounts SET balance = balance - $1, updated_at = NOW() WHERE id = $2",
				oldDelta, oldAccountID,
			)
			if err != nil {
				return fmt.Errorf("failed to revert old account balance: %w", err)
			}
		}
		// Apply new delta to new account
		if newDelta != 0 {
			// Overdraft check for expense on new account
			if newDelta < 0 {
				var newAccBalance int64
				var overdraftLimit int64
				err = tx.QueryRow(ctx,
					"SELECT balance, COALESCE(overdraft_limit, 0) FROM accounts WHERE id = $1 FOR UPDATE",
					newAccountID,
				).Scan(&newAccBalance, &overdraftLimit)
				if err == nil {
					if newAccBalance+newDelta < -overdraftLimit {
						return fmt.Errorf("insufficient balance on new account %s (balance=%d, delta=%d, limit=%d)",
							newAccountID, newAccBalance, newDelta, overdraftLimit)
					}
				}
			}
			_, err = tx.Exec(ctx,
				"UPDATE accounts SET balance = balance + $1, updated_at = NOW() WHERE id = $2",
				newDelta, newAccountID,
			)
			if err != nil {
				return fmt.Errorf("failed to update new account balance: %w", err)
			}
		}
	} else {
		// Same account — apply balance adjustment
		balanceAdjust := newDelta - oldDelta
		if balanceAdjust != 0 {
			_, err = tx.Exec(ctx,
				"UPDATE accounts SET balance = balance + $1, updated_at = NOW() WHERE id = $2",
				balanceAdjust, oldAccountID,
			)
			if err != nil {
				return fmt.Errorf("failed to update account balance: %w", err)
			}
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
	FamilyID string `json:"family_id"`
}

func (s *Service) applyAccountOp(ctx context.Context, tx pgx.Tx, userID uuid.UUID, entityID uuid.UUID, opType string, payload string) error {
	switch opType {
	case "create":
		return s.applyAccountCreate(ctx, tx, userID, entityID, payload)
	case "update":
		return s.applyAccountUpdate(ctx, tx, userID, entityID, payload)
	case "delete":
		return s.applyAccountDelete(ctx, tx, userID, entityID)
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
		`INSERT INTO accounts (id, user_id, name, type, balance, currency, icon, is_active, is_default, family_id)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, true, false, $8)`,
		entityID, userID, p.Name, acctType, p.Balance, currency, p.Icon, nilIfEmpty(p.FamilyID),
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

func (s *Service) applyAccountDelete(ctx context.Context, tx pgx.Tx, userID uuid.UUID, entityID uuid.UUID) error {
	// Verify ownership and not already deleted
	var ownerID uuid.UUID
	err := tx.QueryRow(ctx,
		"SELECT user_id FROM accounts WHERE id = $1 AND deleted_at IS NULL FOR UPDATE",
		entityID,
	).Scan(&ownerID)
	if err != nil {
		if err == pgx.ErrNoRows {
			log.Printf("sync: account %s already deleted, skipping", entityID)
			return fmt.Errorf("account %s already deleted or not found", entityID)
		}
		return fmt.Errorf("failed to fetch account for delete: %w", err)
	}
	if ownerID != userID {
		return fmt.Errorf("account %s does not belong to user", entityID)
	}

	_, err = tx.Exec(ctx,
		"UPDATE accounts SET deleted_at = NOW(), updated_at = NOW() WHERE id = $1",
		entityID,
	)
	if err != nil {
		return fmt.Errorf("failed to soft-delete account: %w", err)
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

	// Pagination: default 100, max 500
	pageSize := int(req.PageSize)
	if pageSize <= 0 {
		pageSize = 100
	}
	if pageSize > 500 {
		pageSize = 500
	}

	// Decode page_token (format: "timestamp_nanos:uuid" of last seen item)
	var cursorTime time.Time
	var cursorID uuid.UUID
	hasCursor := false
	if req.PageToken != "" {
		parts := strings.SplitN(req.PageToken, ":", 2)
		if len(parts) == 2 {
			if nanos, err := strconv.ParseInt(parts[0], 10, 64); err == nil {
				cursorTime = time.Unix(0, nanos)
				if id, err := uuid.Parse(parts[1]); err == nil {
					cursorID = id
					hasCursor = true
				}
			}
		}
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

		var cursorClause string
		var queryArgs []interface{}
		if hasCursor {
			cursorClause = "AND (so.timestamp, so.id) > ($5, $6)"
			queryArgs = []interface{}{familyID, since, clientID, pageSize + 1, cursorTime, cursorID}
		} else {
			cursorClause = ""
			queryArgs = []interface{}{familyID, since, clientID, pageSize + 1}
		}

		rows, err = s.pool.Query(ctx, fmt.Sprintf(
			`WITH family_accounts AS (
				SELECT id FROM accounts WHERE family_id = $1
			), family_txns AS (
				SELECT t.id FROM transactions t WHERE t.account_id IN (SELECT id FROM family_accounts)
			)
			SELECT so.id, so.entity_type, so.entity_id, so.op_type, so.payload, so.client_id, so.timestamp
			 FROM sync_operations so
			 WHERE so.user_id IN (SELECT user_id FROM family_members WHERE family_id = $1)
			   AND so.timestamp > $2
			   AND so.client_id != $3
			   %s
			   AND (
			     (so.entity_type = 'transaction' AND so.entity_id IN (SELECT id FROM family_txns))
			     OR
			     (so.entity_type = 'account' AND so.entity_id IN (SELECT id FROM family_accounts))
			     OR
			     (so.entity_type NOT IN ('transaction', 'account'))
			   )
			 ORDER BY so.timestamp ASC, so.id ASC
			 LIMIT $4`, cursorClause),
			queryArgs...,
		)
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to query family sync operations")
		}
	} else {
		// Personal mode: only pull operations for this user
		var cursorClause string
		var queryArgs []interface{}
		if hasCursor {
			cursorClause = "AND (timestamp, id) > ($5, $6)"
			queryArgs = []interface{}{uid, since, clientID, pageSize + 1, cursorTime, cursorID}
		} else {
			cursorClause = ""
			queryArgs = []interface{}{uid, since, clientID, pageSize + 1}
		}

		rows, err = s.pool.Query(ctx, fmt.Sprintf(
			`SELECT id, entity_type, entity_id, op_type, payload, client_id, timestamp
			 FROM sync_operations
			 WHERE user_id = $1 AND timestamp > $2 AND client_id != $3
			   %s
			 ORDER BY timestamp ASC, id ASC
			 LIMIT $4`, cursorClause),
			queryArgs...,
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

	// Pagination: if we got pageSize+1 results, there are more pages
	var nextPageToken string
	hasMore := false
	if len(operations) > pageSize {
		hasMore = true
		// Last item of current page is operations[pageSize-1]
		lastOp := operations[pageSize-1]
		nextPageToken = fmt.Sprintf("%d:%s", lastOp.Timestamp.AsTime().UnixNano(), lastOp.Id)
		operations = operations[:pageSize]
	}

	return &pb.PullChangesResponse{
		Operations:    operations,
		ServerTime:    timestamppb.Now(),
		NextPageToken: nextPageToken,
		HasMore:       hasMore,
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
			return fmt.Errorf("category %s not found or deleted", entityID)
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

// getFamilyMembersForUser returns all family member user IDs (including the user themselves)
// if the user belongs to any family. Returns nil if user is not in any family.
// This is used for broadcast — any sync operation from a family member should notify all others.
func (s *Service) getFamilyMembersForUser(ctx context.Context, userID string) []string {
	uid, err := uuid.Parse(userID)
	if err != nil {
		return nil
	}

	rows, err := s.pool.Query(ctx,
		`SELECT DISTINCT fm2.user_id FROM family_members fm1
		 JOIN family_members fm2 ON fm1.family_id = fm2.family_id
		 WHERE fm1.user_id = $1`, uid)
	if err != nil {
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

	// Only return if there are multiple members (no point broadcasting to just yourself)
	if len(members) <= 1 {
		return nil
	}
	return members
}

// nilIfEmpty returns nil if s is empty, otherwise a pointer to the UUID parsed from s.
// Used for optional foreign key columns (e.g., family_id).
func nilIfEmpty(s string) interface{} {
	if s == "" {
		return nil
	}
	id, err := uuid.Parse(s)
	if err != nil {
		return nil
	}
	return id
}
