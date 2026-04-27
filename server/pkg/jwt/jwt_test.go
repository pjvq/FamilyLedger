package jwt

import (
	"testing"
	"time"

	jwtgo "github.com/golang-jwt/jwt/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const testSecret = "test-secret-key-for-unit-tests"

func TestNewManager(t *testing.T) {
	m := NewManager(testSecret)
	require.NotNil(t, m)
	assert.Equal(t, testSecret, m.secretKey)
	assert.Equal(t, 15*time.Minute, m.accessDuration)
	assert.Equal(t, 30*24*time.Hour, m.refreshDuration)
}

func TestGenerateTokenPair_ReturnsValidTokens(t *testing.T) {
	m := NewManager(testSecret)
	pair, err := m.GenerateTokenPair("user-123")
	require.NoError(t, err)
	require.NotNil(t, pair)
	assert.NotEmpty(t, pair.AccessToken)
	assert.NotEmpty(t, pair.RefreshToken)
	assert.NotEqual(t, pair.AccessToken, pair.RefreshToken)
}

func TestGenerateTokenPair_AccessTokenExpiry15Min(t *testing.T) {
	m := NewManager(testSecret)
	before := time.Now()
	pair, err := m.GenerateTokenPair("user-123")
	require.NoError(t, err)

	// ExpiresAt should be approximately now + 15 minutes
	expected := before.Add(15 * time.Minute)
	assert.WithinDuration(t, expected, pair.ExpiresAt, 2*time.Second)
}

func TestGenerateTokenPair_RefreshTokenExpiry30Days(t *testing.T) {
	m := NewManager(testSecret)
	pair, err := m.GenerateTokenPair("user-123")
	require.NoError(t, err)

	// Verify refresh token by parsing and checking expiry
	claims, err := m.Verify(pair.RefreshToken)
	require.NoError(t, err)

	expected := time.Now().Add(30 * 24 * time.Hour)
	assert.WithinDuration(t, expected, claims.ExpiresAt.Time, 2*time.Second)
}

func TestGenerateTokenPair_EmptyUserID(t *testing.T) {
	m := NewManager(testSecret)
	pair, err := m.GenerateTokenPair("")
	require.NoError(t, err)
	require.NotNil(t, pair)
	assert.NotEmpty(t, pair.AccessToken)

	claims, err := m.Verify(pair.AccessToken)
	require.NoError(t, err)
	assert.Equal(t, "", claims.UserID)
}

func TestGenerateTokenPair_DifferentUserIDProducesDifferentTokens(t *testing.T) {
	m := NewManager(testSecret)
	pair1, err := m.GenerateTokenPair("user-1")
	require.NoError(t, err)
	pair2, err := m.GenerateTokenPair("user-2")
	require.NoError(t, err)

	assert.NotEqual(t, pair1.AccessToken, pair2.AccessToken)
	assert.NotEqual(t, pair1.RefreshToken, pair2.RefreshToken)
}

func TestVerify_ValidToken(t *testing.T) {
	m := NewManager(testSecret)
	pair, err := m.GenerateTokenPair("user-456")
	require.NoError(t, err)

	claims, err := m.Verify(pair.AccessToken)
	require.NoError(t, err)
	assert.Equal(t, "user-456", claims.UserID)
}

func TestVerify_IssuedAtCorrect(t *testing.T) {
	m := NewManager(testSecret)
	before := time.Now()
	pair, err := m.GenerateTokenPair("user-789")
	require.NoError(t, err)

	claims, err := m.Verify(pair.AccessToken)
	require.NoError(t, err)
	require.NotNil(t, claims.IssuedAt)
	assert.WithinDuration(t, before, claims.IssuedAt.Time, 2*time.Second)
}

func TestVerify_ExpiredToken(t *testing.T) {
	m := &Manager{
		secretKey:       testSecret,
		accessDuration:  -1 * time.Hour, // already expired
		refreshDuration: 30 * 24 * time.Hour,
	}
	pair, err := m.GenerateTokenPair("user-expired")
	require.NoError(t, err)

	_, err = m.Verify(pair.AccessToken)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "parse token")
}

func TestVerify_TamperedPayload(t *testing.T) {
	m := NewManager(testSecret)
	pair, err := m.GenerateTokenPair("user-original")
	require.NoError(t, err)

	// Tamper with the token by changing a character in the payload (middle section)
	tokenBytes := []byte(pair.AccessToken)
	// Find the second dot (payload section)
	dots := 0
	tamperedIdx := 0
	for i, b := range tokenBytes {
		if b == '.' {
			dots++
			if dots == 1 {
				tamperedIdx = i + 1
				break
			}
		}
	}
	// Flip a character in the payload
	if tokenBytes[tamperedIdx] == 'A' {
		tokenBytes[tamperedIdx] = 'B'
	} else {
		tokenBytes[tamperedIdx] = 'A'
	}

	_, err = m.Verify(string(tokenBytes))
	require.Error(t, err)
}

func TestVerify_EmptyString(t *testing.T) {
	m := NewManager(testSecret)
	_, err := m.Verify("")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "parse token")
}

func TestVerify_UnexpectedSigningMethod(t *testing.T) {
	// Create a token signed with RSA method header but HMAC secret
	claims := &Claims{
		UserID: "user-rsa",
		RegisteredClaims: jwtgo.RegisteredClaims{
			ExpiresAt: jwtgo.NewNumericDate(time.Now().Add(1 * time.Hour)),
			IssuedAt:  jwtgo.NewNumericDate(time.Now()),
		},
	}
	// Use none algorithm by manually crafting token with different alg
	token := jwtgo.NewWithClaims(jwtgo.SigningMethodHS256, claims)
	// Override the header to claim RS256
	token.Header["alg"] = "RS256"
	// Sign with HMAC secret (this creates a token that claims RS256 but is really HMAC)
	tokenString, err := token.SignedString([]byte(testSecret))
	require.NoError(t, err)

	m := NewManager(testSecret)
	_, err = m.Verify(tokenString)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "unexpected signing method")
}

func TestVerify_WrongSecret(t *testing.T) {
	m1 := NewManager("secret-one")
	pair, err := m1.GenerateTokenPair("user-wrong-secret")
	require.NoError(t, err)

	m2 := NewManager("secret-two")
	_, err = m2.Verify(pair.AccessToken)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "parse token")
}
