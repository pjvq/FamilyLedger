-- 009_alter_accounts_add_family.up.sql

-- Add family_id to accounts (nullable for personal accounts)
ALTER TABLE accounts ADD COLUMN family_id UUID REFERENCES families(id);

-- Add icon column
ALTER TABLE accounts ADD COLUMN icon VARCHAR(50) DEFAULT '';

-- Add is_active column (soft delete flag; accounts already have deleted_at but we add an explicit flag)
ALTER TABLE accounts ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT true;

-- Create indexes
CREATE INDEX idx_accounts_family_id ON accounts(family_id);
CREATE INDEX idx_accounts_is_active ON accounts(is_active);
