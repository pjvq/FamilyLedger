-- 027_alter_transactions_add_tags.down.sql
DROP INDEX IF EXISTS idx_transactions_tags;
ALTER TABLE transactions DROP COLUMN IF EXISTS image_urls;
ALTER TABLE transactions DROP COLUMN IF EXISTS tags;
