CREATE TABLE asset_valuations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    asset_id UUID NOT NULL REFERENCES fixed_assets(id) ON DELETE CASCADE,
    value BIGINT NOT NULL,
    source VARCHAR(30) NOT NULL DEFAULT 'manual',
    valuation_date DATE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_asset_valuations_asset ON asset_valuations(asset_id, valuation_date DESC);
