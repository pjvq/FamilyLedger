-- Add UNIQUE constraint on client_id to prevent duplicate sync operations
-- and CHECK constraint on transactions.amount to enforce positive values at DB level.

-- S-004: Prevent duplicate push operations
CREATE UNIQUE INDEX IF NOT EXISTS idx_sync_operations_client_id
    ON sync_operations (client_id) WHERE client_id IS NOT NULL AND client_id != '';

-- T-007/T-008: Defense-in-depth for transaction amount
-- Use NOT VALID to avoid failing on potential historical dirty data,
-- then VALIDATE to enable full constraint checking for new rows.
ALTER TABLE transactions ADD CONSTRAINT chk_transactions_amount_positive
    CHECK (amount > 0) NOT VALID;
ALTER TABLE transactions VALIDATE CONSTRAINT chk_transactions_amount_positive;
