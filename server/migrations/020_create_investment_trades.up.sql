CREATE TABLE investment_trades (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    investment_id UUID NOT NULL REFERENCES investments(id) ON DELETE CASCADE,
    trade_type VARCHAR(10) NOT NULL,  -- buy/sell
    quantity DECIMAL(20,8) NOT NULL,
    price BIGINT NOT NULL,            -- 分/股
    total_amount BIGINT NOT NULL,     -- 分
    fee BIGINT NOT NULL DEFAULT 0,    -- 分
    trade_date TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_investment_trades_investment_id ON investment_trades(investment_id);
