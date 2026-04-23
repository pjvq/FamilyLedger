ALTER TABLE loans
    ADD COLUMN group_id UUID REFERENCES loan_groups(id),
    ADD COLUMN sub_type VARCHAR(20) DEFAULT 'commercial',
    ADD COLUMN rate_type VARCHAR(20) DEFAULT 'fixed',
    ADD COLUMN lpr_base DECIMAL(6,4),
    ADD COLUMN lpr_spread DECIMAL(6,4),
    ADD COLUMN rate_adjust_month INT;

CREATE INDEX idx_loans_group_id ON loans(group_id);
