package config

import (
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// ── LoadAppConfig (os env) ──────────────────────────────────────────────────

func TestLoadAppConfig_Success(t *testing.T) {
	t.Setenv("DB_HOST", "testhost")
	t.Setenv("DB_PORT", "5433")
	t.Setenv("DB_USER", "u")
	t.Setenv("DB_PASSWORD", "p")
	t.Setenv("DB_NAME", "d")
	t.Setenv("DB_SSLMODE", "require")
	t.Setenv("GRPC_PORT", "9090")
	t.Setenv("WS_PORT", "3000")

	cfg, err := LoadAppConfig()
	require.NoError(t, err)
	assert.Equal(t, "testhost", cfg.DBHost)
	assert.Equal(t, 5433, cfg.DBPort)
	assert.Equal(t, "u", cfg.DBUser)
	assert.Equal(t, "p", cfg.DBPassword)
	assert.Equal(t, "d", cfg.DBName)
	assert.Equal(t, "require", cfg.DBSSLMode)
	assert.Equal(t, "9090", cfg.GRPCPort)
	assert.Equal(t, "3000", cfg.WSPort)
}

func TestLoadAppConfig_Defaults(t *testing.T) {
	t.Setenv("DB_HOST", "h")
	os.Unsetenv("DB_PORT")
	os.Unsetenv("DB_USER")
	os.Unsetenv("DB_PASSWORD")
	os.Unsetenv("DB_NAME")
	os.Unsetenv("DB_SSLMODE")
	os.Unsetenv("GRPC_PORT")
	os.Unsetenv("WS_PORT")

	cfg, err := LoadAppConfig()
	require.NoError(t, err)
	assert.Equal(t, 5432, cfg.DBPort)
	assert.Equal(t, "familyledger", cfg.DBUser)
	assert.Equal(t, "50051", cfg.GRPCPort)
	assert.Equal(t, "8080", cfg.WSPort)
}

func TestLoadAppConfig_MissingHost(t *testing.T) {
	os.Unsetenv("DB_HOST")
	_, err := LoadAppConfig()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "DB_HOST")
}

func TestLoadAppConfig_InvalidPort(t *testing.T) {
	t.Setenv("DB_HOST", "h")
	t.Setenv("DB_PORT", "abc")
	_, err := LoadAppConfig()
	assert.Error(t, err)
}

func TestLoadAppConfig_InvalidGRPC(t *testing.T) {
	t.Setenv("DB_HOST", "h")
	os.Unsetenv("DB_PORT")
	t.Setenv("GRPC_PORT", "bad")
	_, err := LoadAppConfig()
	assert.Error(t, err)
}

func TestLoadAppConfig_InvalidWS(t *testing.T) {
	t.Setenv("DB_HOST", "h")
	os.Unsetenv("DB_PORT")
	os.Unsetenv("GRPC_PORT")
	t.Setenv("WS_PORT", "bad")
	_, err := LoadAppConfig()
	assert.Error(t, err)
}

func TestLoadAppConfig_PortOutOfRange(t *testing.T) {
	t.Setenv("DB_HOST", "h")
	t.Setenv("DB_PORT", "99999")
	_, err := LoadAppConfig()
	assert.Error(t, err)
}

// ── getEnvDefault ───────────────────────────────────────────────────────────

func TestGetEnvDefault_Set(t *testing.T) {
	t.Setenv("TEST_KEY_12345", "val")
	assert.Equal(t, "val", getEnvDefault("TEST_KEY_12345", "fallback"))
}

func TestGetEnvDefault_Unset(t *testing.T) {
	os.Unsetenv("TEST_KEY_NONE_54321")
	assert.Equal(t, "fallback", getEnvDefault("TEST_KEY_NONE_54321", "fallback"))
}

// ── ValidateJWTSecret ───────────────────────────────────────────────────────

func TestValidateJWTSecretFromValues_DevEmpty(t *testing.T) {
	secret, err := ValidateJWTSecretFromValues("", "dev")
	require.NoError(t, err)
	assert.Equal(t, defaultDevSecret, secret)
}

func TestValidateJWTSecretFromValues_ProdEmpty(t *testing.T) {
	_, err := ValidateJWTSecretFromValues("", "production")
	assert.Error(t, err)
}

func TestValidateJWTSecretFromValues_ProdShort(t *testing.T) {
	_, err := ValidateJWTSecretFromValues("short", "prod")
	assert.Error(t, err)
}

func TestValidateJWTSecretFromValues_ProdOK(t *testing.T) {
	long := "this-is-a-very-long-secret-that-is-at-least-32-chars"
	secret, err := ValidateJWTSecretFromValues(long, "production")
	require.NoError(t, err)
	assert.Equal(t, long, secret)
}

func TestValidateJWTSecretFromValues_DevShort(t *testing.T) {
	// Dev with short secret → still OK (just a warning)
	secret, err := ValidateJWTSecretFromValues("short", "dev")
	require.NoError(t, err)
	assert.Equal(t, "short", secret)
}

func TestIsSecretWeak_Boost(t *testing.T) {
	assert.True(t, IsSecretWeak("short"))
	assert.False(t, IsSecretWeak("this-is-a-very-long-secret-that-exceeds-32"))
}

func TestValidateJWTSecret_DevNoEnv(t *testing.T) {
	t.Setenv("JWT_SECRET", "")
	t.Setenv("APP_ENV", "development")
	secret := ValidateJWTSecret()
	assert.NotEmpty(t, secret, "should return default dev secret")
}

func TestValidateJWTSecret_DevWithSecret(t *testing.T) {
	t.Setenv("JWT_SECRET", "my-dev-secret")
	t.Setenv("APP_ENV", "development")
	secret := ValidateJWTSecret()
	assert.Equal(t, "my-dev-secret", secret)
}
