-- Remove existing duplicates first (keep the one with lowest id/earliest created_at)
DELETE FROM budgets a USING budgets b
WHERE a.id > b.id
  AND a.user_id = b.user_id
  AND a.year = b.year
  AND a.month = b.month
  AND COALESCE(a.family_id::text, '') = COALESCE(b.family_id::text, '');

-- Drop the old constraint that doesn't account for family_id
ALTER TABLE budgets DROP CONSTRAINT IF EXISTS budgets_user_id_year_month_key;

-- Since family_id is nullable, PostgreSQL treats NULL != NULL in unique constraints.
-- We need two partial indexes to handle both cases correctly.

-- For personal budgets (family_id IS NULL): one budget per user/year/month
CREATE UNIQUE INDEX IF NOT EXISTS budgets_user_year_month_personal_unique
  ON budgets (user_id, year, month) WHERE family_id IS NULL;

-- For family budgets (family_id IS NOT NULL): one budget per user/year/month/family
CREATE UNIQUE INDEX IF NOT EXISTS budgets_user_year_month_family_unique
  ON budgets (user_id, year, month, family_id) WHERE family_id IS NOT NULL;
