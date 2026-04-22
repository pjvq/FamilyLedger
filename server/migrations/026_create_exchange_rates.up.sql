-- 026_create_exchange_rates.up.sql
CREATE TABLE exchange_rates (
    currency_pair VARCHAR(10) NOT NULL, -- USD_CNY, EUR_CNY, etc
    rate DECIMAL(20,8) NOT NULL,
    source VARCHAR(30) NOT NULL DEFAULT 'api',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (currency_pair)
);

-- 插入初始汇率
INSERT INTO exchange_rates (currency_pair, rate) VALUES
    ('USD_CNY', 7.2500),
    ('EUR_CNY', 7.8900),
    ('GBP_CNY', 9.1500),
    ('JPY_CNY', 0.0480),
    ('HKD_CNY', 0.9280),
    ('BTC_CNY', 460000.00),
    ('CNY_CNY', 1.0000);
