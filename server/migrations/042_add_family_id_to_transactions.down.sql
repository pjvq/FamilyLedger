DROP INDEX IF EXISTS idx_transactions_family_id;
ALTER TABLE transactions DROP COLUMN IF EXISTS family_id;
