package config

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestValidateJWTSecretFromValues_ProductionNoSecret(t *testing.T) {
	_, err := ValidateJWTSecretFromValues("", "production")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "required in production")
}

func TestValidateJWTSecretFromValues_ProdNoSecret(t *testing.T) {
	_, err := ValidateJWTSecretFromValues("", "prod")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "required in production")
}

func TestValidateJWTSecretFromValues_ProductionShortSecret(t *testing.T) {
	_, err := ValidateJWTSecretFromValues("short", "production")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "at least 32 characters")
}

func TestValidateJWTSecretFromValues_ProductionValidSecret(t *testing.T) {
	secret := "this-is-a-very-long-secret-key-for-production-use-abcdef"
	result, err := ValidateJWTSecretFromValues(secret, "production")
	require.NoError(t, err)
	assert.Equal(t, secret, result)
}

func TestValidateJWTSecretFromValues_DevNoSecret(t *testing.T) {
	result, err := ValidateJWTSecretFromValues("", "development")
	require.NoError(t, err)
	assert.Equal(t, defaultDevSecret, result)
}

func TestValidateJWTSecretFromValues_DevEmptyAppEnv(t *testing.T) {
	result, err := ValidateJWTSecretFromValues("", "")
	require.NoError(t, err)
	assert.Equal(t, defaultDevSecret, result)
}

func TestValidateJWTSecretFromValues_DevWithSecret(t *testing.T) {
	secret := "my-dev-secret"
	result, err := ValidateJWTSecretFromValues(secret, "dev")
	require.NoError(t, err)
	assert.Equal(t, secret, result)
}

func TestValidateJWTSecretFromValues_DevLongSecret(t *testing.T) {
	secret := "this-is-a-sufficiently-long-secret-key-12345"
	result, err := ValidateJWTSecretFromValues(secret, "development")
	require.NoError(t, err)
	assert.Equal(t, secret, result)
}

func TestIsSecretWeak(t *testing.T) {
	assert.True(t, IsSecretWeak("short"))
	assert.True(t, IsSecretWeak("less-than-32-chars"))
	assert.False(t, IsSecretWeak("this-is-a-very-long-secret-key-for-testing"))
}

func TestValidateJWTSecretFromValues_ProductionExactly32Chars(t *testing.T) {
	secret := "12345678901234567890123456789012" // exactly 32
	result, err := ValidateJWTSecretFromValues(secret, "production")
	require.NoError(t, err)
	assert.Equal(t, secret, result)
}

func TestValidateJWTSecretFromValues_Production31Chars(t *testing.T) {
	secret := "1234567890123456789012345678901" // 31 chars
	_, err := ValidateJWTSecretFromValues(secret, "production")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "at least 32 characters")
}
