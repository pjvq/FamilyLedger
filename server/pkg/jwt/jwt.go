package jwt

import (
	"fmt"
	"time"

	jwtgo "github.com/golang-jwt/jwt/v5"
)

type Manager struct {
	secretKey       string
	accessDuration  time.Duration
	refreshDuration time.Duration
}

type Claims struct {
	UserID string `json:"user_id"`
	jwtgo.RegisteredClaims
}

type TokenPair struct {
	AccessToken  string
	RefreshToken string
	ExpiresAt    time.Time
}

func NewManager(secretKey string) *Manager {
	return &Manager{
		secretKey:       secretKey,
		accessDuration:  15 * time.Minute,
		refreshDuration: 30 * 24 * time.Hour,
	}
}

func (m *Manager) GenerateTokenPair(userID string) (*TokenPair, error) {
	accessToken, expiresAt, err := m.generateToken(userID, m.accessDuration)
	if err != nil {
		return nil, fmt.Errorf("generate access token: %w", err)
	}

	refreshToken, _, err := m.generateToken(userID, m.refreshDuration)
	if err != nil {
		return nil, fmt.Errorf("generate refresh token: %w", err)
	}

	return &TokenPair{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		ExpiresAt:    expiresAt,
	}, nil
}

func (m *Manager) generateToken(userID string, duration time.Duration) (string, time.Time, error) {
	expiresAt := time.Now().Add(duration)
	claims := &Claims{
		UserID: userID,
		RegisteredClaims: jwtgo.RegisteredClaims{
			ExpiresAt: jwtgo.NewNumericDate(expiresAt),
			IssuedAt:  jwtgo.NewNumericDate(time.Now()),
		},
	}

	token := jwtgo.NewWithClaims(jwtgo.SigningMethodHS256, claims)
	tokenString, err := token.SignedString([]byte(m.secretKey))
	if err != nil {
		return "", time.Time{}, err
	}

	return tokenString, expiresAt, nil
}

func (m *Manager) Verify(tokenString string) (*Claims, error) {
	token, err := jwtgo.ParseWithClaims(tokenString, &Claims{}, func(token *jwtgo.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwtgo.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return []byte(m.secretKey), nil
	})
	if err != nil {
		return nil, fmt.Errorf("parse token: %w", err)
	}

	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return nil, fmt.Errorf("invalid token claims")
	}

	return claims, nil
}
