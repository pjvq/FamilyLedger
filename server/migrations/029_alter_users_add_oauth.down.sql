-- 029_alter_users_add_oauth.down.sql
DROP INDEX IF EXISTS idx_users_oauth;
ALTER TABLE users DROP COLUMN IF EXISTS display_name;
ALTER TABLE users DROP COLUMN IF EXISTS avatar_url;
ALTER TABLE users DROP COLUMN IF EXISTS oauth_id;
ALTER TABLE users DROP COLUMN IF EXISTS oauth_provider;
