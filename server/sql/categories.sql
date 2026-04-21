-- name: ListCategories :many
SELECT * FROM categories
ORDER BY type, sort_order ASC;

-- name: ListCategoriesByType :many
SELECT * FROM categories
WHERE type = $1
ORDER BY sort_order ASC;

-- name: GetCategoryByID :one
SELECT * FROM categories
WHERE id = $1;

-- name: CreateCategory :one
INSERT INTO categories (name, icon, type, is_preset, sort_order)
VALUES ($1, $2, $3, $4, $5)
RETURNING *;
