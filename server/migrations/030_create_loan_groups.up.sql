CREATE TABLE loan_groups (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id),
    name        VARCHAR(100) NOT NULL,
    group_type  VARCHAR(20) NOT NULL DEFAULT 'commercial_only',  -- commercial_only / provident_only / combined
    total_principal BIGINT NOT NULL DEFAULT 0,
    payment_day INT NOT NULL DEFAULT 1,
    start_date  DATE NOT NULL,
    account_id  UUID REFERENCES accounts(id),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at  TIMESTAMPTZ
);

CREATE INDEX idx_loan_groups_user_id ON loan_groups(user_id);
