-- name: CreateSyncOperation :one
INSERT INTO sync_operations (user_id, entity_type, entity_id, op_type, payload, client_id, timestamp)
VALUES ($1, $2, $3, $4, $5, $6, $7)
RETURNING *;

-- name: ListSyncOperationsSince :many
SELECT * FROM sync_operations
WHERE user_id = $1
  AND timestamp > $2
  AND client_id != $3
ORDER BY timestamp ASC;

-- name: BatchCreateSyncOperations :copyfrom
INSERT INTO sync_operations (user_id, entity_type, entity_id, op_type, payload, client_id, timestamp)
VALUES ($1, $2, $3, $4, $5, $6, $7);
