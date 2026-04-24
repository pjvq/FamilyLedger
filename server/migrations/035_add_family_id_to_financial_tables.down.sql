DROP INDEX IF EXISTS idx_fixed_assets_family_id;
DROP INDEX IF EXISTS idx_investments_family_id;
DROP INDEX IF EXISTS idx_loans_family_id;
ALTER TABLE fixed_assets DROP COLUMN IF EXISTS family_id;
ALTER TABLE investments DROP COLUMN IF EXISTS family_id;
ALTER TABLE loans DROP COLUMN IF EXISTS family_id;
