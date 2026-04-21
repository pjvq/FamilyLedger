-- 006_create_sync_operations.up.sql
CREATE TYPE sync_op_type AS ENUM ('create', 'update', 'delete');

CREATE TABLE sync_operations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    entity_type VARCHAR(50) NOT NULL,
    entity_id UUID NOT NULL,
    op_type sync_op_type NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}',
    client_id VARCHAR(100) NOT NULL DEFAULT '',
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sync_operations_user_id ON sync_operations(user_id);
CREATE INDEX idx_sync_operations_timestamp ON sync_operations(timestamp);
CREATE INDEX idx_sync_operations_user_timestamp ON sync_operations(user_id, timestamp);
