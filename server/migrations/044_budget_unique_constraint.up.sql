-- Remove existing duplicates first (keep the earliest by created_at, break ties by id)
DELETE FROM budgets a USING budgets b
WHERE a.user_id = b.user_id
  AND a.year = b.year
  AND a.month = b.month
  AND COALESCE(a.family_id::text, '') = COALESCE(b.family_id::text, '')
  AND (a.created_at > b.created_at OR (a.created_at = b.created_at AND a.id > b.id));

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
