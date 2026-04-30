-- Revert: restore billing_day constraint to 1-28
ALTER TABLE accounts DROP CONSTRAINT IF EXISTS accounts_billing_day_check;
ALTER TABLE accounts ADD CONSTRAINT accounts_billing_day_check CHECK (billing_day IS NULL OR (billing_day BETWEEN 1 AND 28));

ALTER TABLE accounts DROP CONSTRAINT IF EXISTS accounts_payment_due_day_check;
ALTER TABLE accounts ADD CONSTRAINT accounts_payment_due_day_check CHECK (payment_due_day IS NULL OR (payment_due_day BETWEEN 1 AND 28));
