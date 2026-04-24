-- Add family_id to loans, investments, fixed_assets for family sharing
ALTER TABLE loans ADD COLUMN family_id UUID REFERENCES families(id);
ALTER TABLE investments ADD COLUMN family_id UUID REFERENCES families(id);
ALTER TABLE fixed_assets ADD COLUMN family_id UUID REFERENCES families(id);

-- Index for family queries
CREATE INDEX idx_loans_family_id ON loans(family_id) WHERE family_id IS NOT NULL;
CREATE INDEX idx_investments_family_id ON investments(family_id) WHERE family_id IS NOT NULL;
CREATE INDEX idx_fixed_assets_family_id ON fixed_assets(family_id) WHERE family_id IS NOT NULL;
