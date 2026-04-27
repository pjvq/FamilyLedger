-- 037: Create audit_logs table for family member operation auditing (#28)
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES families(id),
    user_id UUID NOT NULL REFERENCES users(id),
    action VARCHAR(20) NOT NULL,        -- 'create', 'update', 'delete'
    entity_type VARCHAR(50) NOT NULL,   -- 'transaction', 'account', 'loan', etc.
    entity_id UUID NOT NULL,
    changes JSONB,                      -- {"field": {"old": x, "new": y}}
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_logs_family ON audit_logs(family_id, created_at DESC);
CREATE INDEX idx_audit_logs_entity_type ON audit_logs(family_id, entity_type, created_at DESC);
