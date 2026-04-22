CREATE TABLE fixed_assets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id),
    name VARCHAR(100) NOT NULL,
    asset_type VARCHAR(30) NOT NULL,
    purchase_price BIGINT NOT NULL,
    current_value BIGINT NOT NULL,
    purchase_date DATE NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);
CREATE INDEX idx_fixed_assets_user ON fixed_assets(user_id) WHERE deleted_at IS NULL;
