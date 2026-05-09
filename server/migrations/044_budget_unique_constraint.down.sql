-- Drop the partial unique indexes
DROP INDEX IF EXISTS budgets_user_year_month_personal_unique;
DROP INDEX IF EXISTS budgets_user_year_month_family_unique;

-- Restore the original constraint
ALTER TABLE budgets ADD CONSTRAINT budgets_user_id_year_month_key UNIQUE (user_id, year, month);
