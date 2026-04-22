CREATE TABLE depreciation_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    asset_id UUID NOT NULL REFERENCES fixed_assets(id) ON DELETE CASCADE UNIQUE,
    method VARCHAR(30) NOT NULL,
    useful_life_years INT NOT NULL,
    salvage_rate DECIMAL(5,4) NOT NULL DEFAULT 0.0500,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
