DROP INDEX IF EXISTS idx_loan_groups_family_id;
ALTER TABLE loan_groups DROP COLUMN IF EXISTS family_id;
