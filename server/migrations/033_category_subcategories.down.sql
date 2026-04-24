-- 033_category_subcategories.down.sql

DROP INDEX IF EXISTS idx_categories_deleted_at;
DROP INDEX IF EXISTS idx_categories_user_id;
DROP INDEX IF EXISTS idx_categories_parent_id;

-- Remove subcategories first (they reference parent_id)
DELETE FROM categories WHERE parent_id IS NOT NULL;

ALTER TABLE categories
    DROP COLUMN IF EXISTS deleted_at,
    DROP COLUMN IF EXISTS icon_key,
    DROP COLUMN IF EXISTS user_id,
    DROP COLUMN IF EXISTS parent_id;
