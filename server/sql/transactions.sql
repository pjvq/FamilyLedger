-- name: CreateTransaction :one
INSERT INTO transactions (user_id, account_id, category_id, amount, currency, amount_cny, exchange_rate, type, note, txn_date)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
RETURNING *;

-- name: GetTransactionByID :one
SELECT * FROM transactions
WHERE id = $1 AND deleted_at IS NULL;

-- name: ListTransactionsByUserID :many
SELECT * FROM transactions
WHERE user_id = $1
  AND deleted_at IS NULL
  AND ($2::uuid IS NULL OR account_id = $2)
  AND ($3::timestamptz IS NULL OR txn_date >= $3)
  AND ($4::timestamptz IS NULL OR txn_date <= $4)
ORDER BY txn_date DESC, created_at DESC
LIMIT $5 OFFSET $6;

-- name: CountTransactionsByUserID :one
SELECT COUNT(*) FROM transactions
WHERE user_id = $1
  AND deleted_at IS NULL
  AND ($2::uuid IS NULL OR account_id = $2)
  AND ($3::timestamptz IS NULL OR txn_date >= $3)
  AND ($4::timestamptz IS NULL OR txn_date <= $4);

-- name: SoftDeleteTransaction :exec
UPDATE transactions
SET deleted_at = NOW(), updated_at = NOW()
WHERE id = $1;
