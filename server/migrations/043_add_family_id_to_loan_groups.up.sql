ALTER TABLE loan_groups ADD COLUMN family_id UUID REFERENCES families(id);
CREATE INDEX idx_loan_groups_family_id ON loan_groups(family_id);
