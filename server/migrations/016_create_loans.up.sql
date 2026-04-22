CREATE TABLE loans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id),
    name VARCHAR(100) NOT NULL,
    loan_type VARCHAR(30) NOT NULL,
    principal BIGINT NOT NULL,
    remaining_principal BIGINT NOT NULL,
    annual_rate DECIMAL(6,4) NOT NULL,
    total_months INT NOT NULL,
    paid_months INT NOT NULL DEFAULT 0,
    repayment_method VARCHAR(30) NOT NULL,
    payment_day INT NOT NULL CHECK (payment_day BETWEEN 1 AND 28),
    start_date DATE NOT NULL,
    account_id UUID REFERENCES accounts(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_loans_user ON loans(user_id) WHERE deleted_at IS NULL;
