-- name: CreateAccount :one
INSERT INTO accounts (user_id, name, type, balance, currency, is_default)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING *;

-- name: GetAccountByID :one
SELECT * FROM accounts
WHERE id = $1 AND deleted_at IS NULL;

-- name: ListAccountsByUserID :many
SELECT * FROM accounts
WHERE user_id = $1 AND deleted_at IS NULL
ORDER BY is_default DESC, created_at ASC;

-- name: GetDefaultAccount :one
SELECT * FROM accounts
WHERE user_id = $1 AND is_default = true AND deleted_at IS NULL;

-- name: UpdateAccountBalance :exec
UPDATE accounts
SET balance = balance + $2, updated_at = NOW()
WHERE id = $1 AND deleted_at IS NULL;

-- name: SoftDeleteAccount :exec
UPDATE accounts
SET deleted_at = NOW(), updated_at = NOW()
WHERE id = $1;
