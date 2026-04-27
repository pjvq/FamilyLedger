package audit

import (
	"context"
	"encoding/json"
	"fmt"
	"log"

	"github.com/google/uuid"
	"github.com/familyledger/server/pkg/db"
)

// LogAudit records an audit log entry for a family operation.
// Only call this when the entity belongs to a family (familyID != "").
// changes can be nil for create/delete operations; for updates it should be a map
// of field → {old, new} values.
func LogAudit(ctx context.Context, pool db.Pool, familyID, userID, action, entityType, entityID string, changes map[string]interface{}) {
	if familyID == "" {
		return // Only log family operations
	}

	famUID, err := uuid.Parse(familyID)
	if err != nil {
		log.Printf("audit: invalid family_id %q: %v", familyID, err)
		return
	}
	userUID, err := uuid.Parse(userID)
	if err != nil {
		log.Printf("audit: invalid user_id %q: %v", userID, err)
		return
	}
	entityUID, err := uuid.Parse(entityID)
	if err != nil {
		log.Printf("audit: invalid entity_id %q: %v", entityID, err)
		return
	}

	var changesJSON []byte
	if changes != nil {
		changesJSON, err = json.Marshal(changes)
		if err != nil {
			log.Printf("audit: marshal changes error: %v", err)
			changesJSON = nil
		}
	}

	_, err = pool.Exec(ctx,
		`INSERT INTO audit_logs (family_id, user_id, action, entity_type, entity_id, changes)
		 VALUES ($1, $2, $3, $4, $5, $6)`,
		famUID, userUID, action, entityType, entityUID, changesJSON,
	)
	if err != nil {
		log.Printf("audit: failed to insert audit log: %v", err)
	}
}

// LogAuditTx is similar to LogAudit but works within a transaction.
type Tx interface {
	Exec(ctx context.Context, sql string, args ...any) (interface{ RowsAffected() int64 }, error)
}

// LogAuditWithExecer records an audit log using any execer (pool or tx).
func LogAuditWithExecer(ctx context.Context, execer interface {
	Exec(ctx context.Context, sql string, args ...any) (interface{ RowsAffected() int64 }, error)
}, familyID, userID, action, entityType, entityID string, changes map[string]interface{}) error {
	if familyID == "" {
		return nil
	}

	famUID, err := uuid.Parse(familyID)
	if err != nil {
		return fmt.Errorf("invalid family_id: %w", err)
	}
	userUID, err := uuid.Parse(userID)
	if err != nil {
		return fmt.Errorf("invalid user_id: %w", err)
	}
	entityUID, err := uuid.Parse(entityID)
	if err != nil {
		return fmt.Errorf("invalid entity_id: %w", err)
	}

	var changesJSON []byte
	if changes != nil {
		changesJSON, err = json.Marshal(changes)
		if err != nil {
			return fmt.Errorf("marshal changes: %w", err)
		}
	}

	_, err = execer.Exec(ctx,
		`INSERT INTO audit_logs (family_id, user_id, action, entity_type, entity_id, changes)
		 VALUES ($1, $2, $3, $4, $5, $6)`,
		famUID, userUID, action, entityType, entityUID, changesJSON,
	)
	return err
}
