CREATE TABLE investments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id),
    symbol VARCHAR(20) NOT NULL,
    name VARCHAR(100) NOT NULL,
    market_type VARCHAR(20) NOT NULL,
    quantity DECIMAL(20,8) NOT NULL DEFAULT 0,
    cost_basis BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    UNIQUE(user_id, symbol, market_type)
);

CREATE INDEX idx_investments_user_id ON investments(user_id) WHERE deleted_at IS NULL;
