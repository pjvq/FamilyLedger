-- 040: Relax billing_day constraint from 1-28 to 1-31
-- Cards can have billing/due dates on 29th, 30th, or 31st.
-- For months with fewer days, the notification check rounds down to last day.
ALTER TABLE accounts DROP CONSTRAINT IF EXISTS accounts_billing_day_check;
ALTER TABLE accounts ADD CONSTRAINT accounts_billing_day_check CHECK (billing_day IS NULL OR (billing_day BETWEEN 1 AND 31));

ALTER TABLE accounts DROP CONSTRAINT IF EXISTS accounts_payment_due_day_check;
ALTER TABLE accounts ADD CONSTRAINT accounts_payment_due_day_check CHECK (payment_due_day IS NULL OR (payment_due_day BETWEEN 1 AND 31));
