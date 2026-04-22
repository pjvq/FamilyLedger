-- 027_alter_transactions_add_tags.up.sql
ALTER TABLE transactions ADD COLUMN tags TEXT[] DEFAULT '{}';
ALTER TABLE transactions ADD COLUMN image_urls TEXT[] DEFAULT '{}';
CREATE INDEX idx_transactions_tags ON transactions USING GIN(tags);
