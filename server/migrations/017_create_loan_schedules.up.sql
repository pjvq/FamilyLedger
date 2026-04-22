CREATE TABLE loan_schedules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    loan_id UUID NOT NULL REFERENCES loans(id) ON DELETE CASCADE,
    month_number INT NOT NULL,
    payment BIGINT NOT NULL,
    principal_part BIGINT NOT NULL,
    interest_part BIGINT NOT NULL,
    remaining_principal BIGINT NOT NULL,
    due_date DATE NOT NULL,
    is_paid BOOLEAN NOT NULL DEFAULT false,
    paid_date DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(loan_id, month_number)
);
