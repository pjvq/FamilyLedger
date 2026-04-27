-- 036: Add billing_day and payment_due_day to accounts for credit card reminders (#25)
ALTER TABLE accounts ADD COLUMN billing_day INT CHECK (billing_day IS NULL OR (billing_day BETWEEN 1 AND 28));
ALTER TABLE accounts ADD COLUMN payment_due_day INT CHECK (payment_due_day IS NULL OR (payment_due_day BETWEEN 1 AND 28));
