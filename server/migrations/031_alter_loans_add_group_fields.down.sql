DROP INDEX IF EXISTS idx_loans_group_id;

ALTER TABLE loans
    DROP COLUMN IF EXISTS group_id,
    DROP COLUMN IF EXISTS sub_type,
    DROP COLUMN IF EXISTS rate_type,
    DROP COLUMN IF EXISTS lpr_base,
    DROP COLUMN IF EXISTS lpr_spread,
    DROP COLUMN IF EXISTS rate_adjust_month;
