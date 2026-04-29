-- Rollback sync idempotency and amount check
DROP INDEX IF EXISTS idx_sync_operations_client_id;
ALTER TABLE transactions DROP CONSTRAINT IF EXISTS chk_transactions_amount_positive;
