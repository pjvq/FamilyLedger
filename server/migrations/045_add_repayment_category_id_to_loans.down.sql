-- Remove repayment_category_id column from loans table
ALTER TABLE loans DROP COLUMN IF EXISTS repayment_category_id;
