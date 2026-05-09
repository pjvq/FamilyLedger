-- Add repayment_category_id column to loans table
ALTER TABLE loans ADD COLUMN IF NOT EXISTS repayment_category_id uuid REFERENCES categories(id);
