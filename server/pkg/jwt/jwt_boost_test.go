package jwt

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestWithAccessTTL(t *testing.T) {
	m := NewManager("secret", WithAccessTTL(5*time.Minute))
	assert.Equal(t, 5*time.Minute, m.accessDuration)
}

func TestWithRefreshTTL(t *testing.T) {
	m := NewManager("secret", WithRefreshTTL(48*time.Hour))
	assert.Equal(t, 48*time.Hour, m.refreshDuration)
}

func TestNewManager_Defaults(t *testing.T) {
	m := NewManager("secret")
	assert.Equal(t, 15*time.Minute, m.accessDuration)
	assert.Equal(t, 30*24*time.Hour, m.refreshDuration)
}

func TestNewManager_BothOptions(t *testing.T) {
	m := NewManager("sec", WithAccessTTL(1*time.Minute), WithRefreshTTL(1*time.Hour))
	assert.Equal(t, 1*time.Minute, m.accessDuration)
	assert.Equal(t, 1*time.Hour, m.refreshDuration)
}

func TestGenerateTokenPair_InvalidKey(t *testing.T) {
	// Empty key should still work for HS256
	m := NewManager("")
	pair, err := m.GenerateTokenPair("user1")
	require.NoError(t, err)
	assert.NotEmpty(t, pair.AccessToken)
	assert.NotEmpty(t, pair.RefreshToken)
}

func TestVerify_Expired(t *testing.T) {
	m := NewManager("secret", WithAccessTTL(-1*time.Second))
	pair, err := m.GenerateTokenPair("user1")
	require.NoError(t, err)
	_, err = m.Verify(pair.AccessToken)
	assert.Error(t, err)
}

func TestVerify_WrongKey(t *testing.T) {
	m1 := NewManager("secret1")
	m2 := NewManager("secret2")
	pair, _ := m1.GenerateTokenPair("user1")
	_, err := m2.Verify(pair.AccessToken)
	assert.Error(t, err)
}

func TestVerify_Garbage(t *testing.T) {
	m := NewManager("secret")
	_, err := m.Verify("not.a.token")
	assert.Error(t, err)
}

func TestVerify_RefreshToken(t *testing.T) {
	m := NewManager("secret")
	pair, _ := m.GenerateTokenPair("uid123")
	claims, err := m.Verify(pair.RefreshToken)
	require.NoError(t, err)
	assert.Equal(t, "uid123", claims.UserID)
}
