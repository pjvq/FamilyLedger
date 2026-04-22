-- 009_alter_accounts_add_family.down.sql
DROP INDEX IF EXISTS idx_accounts_is_active;
DROP INDEX IF EXISTS idx_accounts_family_id;
ALTER TABLE accounts DROP COLUMN IF EXISTS is_active;
ALTER TABLE accounts DROP COLUMN IF EXISTS icon;
ALTER TABLE accounts DROP COLUMN IF EXISTS family_id;
