CREATE TABLE market_quotes (
    symbol VARCHAR(20) NOT NULL,
    market_type VARCHAR(20) NOT NULL,
    name VARCHAR(100),
    current_price BIGINT NOT NULL,
    change_amount BIGINT NOT NULL DEFAULT 0,
    change_percent DECIMAL(10,4) NOT NULL DEFAULT 0,
    open_price BIGINT,
    high_price BIGINT,
    low_price BIGINT,
    prev_close BIGINT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (symbol, market_type)
);
