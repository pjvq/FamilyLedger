-- Token blacklist for refresh token rotation.
-- When a refresh token is used, it gets blacklisted so it cannot be reused.
-- Entries are automatically cleaned up by a background job or TTL.
CREATE TABLE IF NOT EXISTS revoked_tokens (
    token_hash TEXT PRIMARY KEY,           -- SHA-256 hash of the refresh token
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    revoked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL        -- original token expiration (for cleanup)
);

-- Index for cleanup job: delete expired entries
CREATE INDEX idx_revoked_tokens_expires_at ON revoked_tokens (expires_at);
