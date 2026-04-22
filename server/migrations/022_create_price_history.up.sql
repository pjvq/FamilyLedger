CREATE TABLE price_history (
    symbol VARCHAR(20) NOT NULL,
    market_type VARCHAR(20) NOT NULL,
    price_date DATE NOT NULL,
    close_price BIGINT NOT NULL,
    PRIMARY KEY (symbol, market_type, price_date)
);
