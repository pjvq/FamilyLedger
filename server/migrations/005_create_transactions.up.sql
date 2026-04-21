-- 005_create_transactions.up.sql
CREATE TYPE transaction_type AS ENUM ('income', 'expense');

CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES categories(id),
    amount BIGINT NOT NULL,
    currency VARCHAR(10) NOT NULL DEFAULT 'CNY',
    amount_cny BIGINT NOT NULL DEFAULT 0,
    exchange_rate DOUBLE PRECISION NOT NULL DEFAULT 1.0,
    type transaction_type NOT NULL,
    note TEXT NOT NULL DEFAULT '',
    txn_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_transactions_user_id ON transactions(user_id);
CREATE INDEX idx_transactions_account_id ON transactions(account_id);
CREATE INDEX idx_transactions_txn_date ON transactions(txn_date);
CREATE INDEX idx_transactions_deleted_at ON transactions(deleted_at);
CREATE INDEX idx_transactions_user_date ON transactions(user_id, txn_date DESC);
