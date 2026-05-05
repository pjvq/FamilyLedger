-- Add family_id to transactions for family-mode filtering
ALTER TABLE transactions ADD COLUMN family_id UUID REFERENCES families(id);
CREATE INDEX idx_transactions_family_id ON transactions(family_id) WHERE family_id IS NOT NULL;
