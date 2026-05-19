package transaction

import (
	"context"
	"encoding/json"

	"github.com/google/uuid"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"github.com/familyledger/server/pkg/audit"
	db "github.com/familyledger/server/pkg/db"
)

// ─── Stage 1: ValidateStage ─────────────────────────────────────────────────

// ValidateStage performs all input validation and parsing.
// Writes: state.Parsed
type ValidateStage struct{}

func (ValidateStage) Name() string { return "validate" }

func (ValidateStage) Execute(_ context.Context, state *PipelineState) error {
	cr, err := validateCreateInput(state.UserID, state.Request)
	if err != nil {
		return err
	}
	state.Parsed = cr
	return nil
}

// ─── Stage 2: PermissionStage ───────────────────────────────────────────────

// PermissionStage checks that the caller has permission to create transactions
// on the target account. Runs OUTSIDE the DB transaction (read-only check).
// Reads: state.Parsed.userID, state.Parsed.accountID
type PermissionStage struct{}

func (PermissionStage) Name() string { return "permission" }

func (PermissionStage) Execute(ctx context.Context, state *PipelineState) error {
	return checkAccountPermission(ctx, state.Pool, state.Parsed.userID, state.Parsed.accountID)
}

// ─── Stage 3: BeginTxStage ──────────────────────────────────────────────────

// BeginTxStage opens a database transaction and re-verifies account ownership
// within the serializable context.
// Writes: state.Tx, state.AccountMeta
type BeginTxStage struct{}

func (BeginTxStage) Name() string { return "begin_tx" }

func (BeginTxStage) Execute(ctx context.Context, state *PipelineState) error {
	tx, err := state.Pool.Begin(ctx)
	if err != nil {
		return status.Error(codes.Internal, "failed to begin transaction")
	}
	state.Tx = tx

	meta, err := verifyAccountInTx(ctx, tx, state.Parsed.userID, state.Parsed.accountID)
	if err != nil {
		return err
	}
	state.AccountMeta = meta
	return nil
}

// ─── Stage 4: CategoryStage ────────────────────────────────────────────────

// CategoryStage resolves the category, with auto-creation fallback in batch mode.
// Reads: state.Tx, state.Parsed, state.BatchMode
// Writes: state.ResolvedCatID
type CategoryStage struct{}

func (CategoryStage) Name() string { return "category" }

func (CategoryStage) Execute(ctx context.Context, state *PipelineState) error {
	resolvedID, err := verifyCategory(ctx, state.Tx, state.Parsed, state.BatchMode)
	if err != nil {
		return err
	}
	state.ResolvedCatID = resolvedID
	return nil
}

// ─── Stage 5: OverdraftStage ────────────────────────────────────────────────

// OverdraftStage checks account balance before allowing expense transactions.
// Skipped entirely when state.BatchMode is true (batch import mode).
//
// Note: "transfer" type is handled by a separate TransferTransaction RPC,
// not by CreateTransaction. The pipeline only sees "income" or "expense".
//
// Reads: state.Parsed, state.AccountMeta
// Writes: state.BalanceDelta
type OverdraftStage struct{}

func (OverdraftStage) Name() string { return "overdraft" }

func (OverdraftStage) Execute(ctx context.Context, state *PipelineState) error {
	state.BalanceDelta = state.Parsed.amountCny
	if state.Parsed.txnType == "expense" {
		state.BalanceDelta = -state.Parsed.amountCny
		if state.BatchMode {
			return nil
		}
		if err := checkOverdraft(ctx, state.Tx, state.Parsed.accountID, state.Parsed.amountCny, state.AccountMeta.acctType); err != nil {
			return err
		}
	}
	return nil
}

// ─── Stage 6: PersistStage ──────────────────────────────────────────────────

// PersistStage inserts the transaction row and updates the account balance.
// Reads: state.Tx, state.Parsed, state.ResolvedCatID, state.BalanceDelta
// Writes: state.TxnID, state.CreatedAt, state.UpdatedAt
type PersistStage struct{}

func (PersistStage) Name() string { return "persist" }

func (PersistStage) Execute(ctx context.Context, state *PipelineState) error {
	cr := state.Parsed
	err := state.Tx.QueryRow(ctx,
		`INSERT INTO transactions (user_id, account_id, category_id, amount, currency, amount_cny, exchange_rate, type, note, txn_date, tags, image_urls)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8::transaction_type, $9, $10, $11, $12)
		 RETURNING id, created_at, updated_at`,
		cr.userID, cr.accountID, state.ResolvedCatID, cr.amount, cr.currency, cr.amountCny, cr.exchangeRate, cr.txnType, cr.note, cr.txnDate, cr.tags, cr.imageURLs,
	).Scan(&state.TxnID, &state.CreatedAt, &state.UpdatedAt)
	if err != nil {
		return status.Error(codes.Internal, "failed to create transaction")
	}

	// Update account balance
	_, err = state.Tx.Exec(ctx,
		"UPDATE accounts SET balance = balance + $1, updated_at = NOW() WHERE id = $2",
		state.BalanceDelta, cr.accountID,
	)
	if err != nil {
		return status.Error(codes.Internal, "failed to update account balance")
	}
	return nil
}

// ─── Stage 7: SyncStage ────────────────────────────────────────────────────

// SyncStage records the sync operation for offline-first replication.
// Reads: state.Tx, state.Parsed, state.TxnID, state.ResolvedCatID
type SyncStage struct{}

func (SyncStage) Name() string { return "sync" }

func (SyncStage) Execute(ctx context.Context, state *PipelineState) error {
	cr := state.Parsed
	return insertTransactionSyncOp(ctx, state.Tx, cr.userID, state.TxnID, "create", map[string]interface{}{
		"id":            state.TxnID.String(),
		"account_id":    cr.accountID.String(),
		"category_id":   state.ResolvedCatID.String(),
		"amount":        cr.amount,
		"currency":      cr.currency,
		"amount_cny":    cr.amountCny,
		"exchange_rate":  cr.exchangeRate,
		"type":          cr.txnType,
		"note":          cr.note,
		"txn_date":      cr.txnDate.Format("2006-01-02"),
		"tags":          cr.tags,
		"image_urls":    cr.imageURLs,
	})
}

// ─── Post-Commit Hook (NOT a Stage) ─────────────────────────────────────────

// notifyPostCommit performs best-effort post-commit side effects:
// audit logging for family accounts and WebSocket change notifications.
// This is NOT a pipeline Stage because it must run AFTER commit — placing it
// inside the pipeline would execute it before commit (wrong timing).
// Failures here are non-critical and silently ignored.
func notifyPostCommit(ctx context.Context, pool db.Pool, hub wsHub, state *PipelineState) {
	if state.AccountMeta != nil && state.AccountMeta.familyID != nil {
		audit.LogAudit(ctx, pool, state.AccountMeta.familyID.String(), state.Parsed.userID.String(), "create", "transaction", state.TxnID.String(), nil)
	}
	if hub != nil {
		broadcastFamilyChange(ctx, pool, hub, state.Parsed.userID.String(), state.Parsed.accountID, "create", state.TxnID.String())
	}
}

// broadcastFamilyChange sends a WS notification to all family members (or just the user).
// Extracted as a package-level function to avoid creating half-initialized Service instances.
func broadcastFamilyChange(ctx context.Context, pool db.Pool, hub wsHub, userID string, accountID uuid.UUID, opType, entityID string) {
	notification, err := json.Marshal(map[string]interface{}{
		"type":        "sync_notify",
		"entity_type": "transaction",
		"entity_id":   entityID,
		"op_type":     opType,
		"user_id":     userID,
	})
	if err != nil {
		return
	}

	familyID, _ := getAccountFamilyIDFrom(ctx, pool, accountID)
	if familyID != "" {
		rows, err := pool.Query(ctx,
			"SELECT user_id::text FROM family_members WHERE family_id = $1",
			familyID,
		)
		if err == nil {
			defer rows.Close()
			for rows.Next() {
				var memberID string
				if rows.Scan(&memberID) == nil {
					hub.BroadcastToUser(memberID, notification)
				}
			}
			return
		}
	}
	hub.BroadcastToUser(userID, notification)
}
