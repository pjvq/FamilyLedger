package config

import (
	"fmt"
	"log"
	"os"
	"strings"
)

const (
	defaultDevSecret    = "familyledger-dev-secret-change-in-production"
	minSecretLenForProd = 32
)

// ValidateJWTSecret validates and returns the JWT secret based on environment.
// In production, it requires the JWT_SECRET env var to be set and at least 32 characters.
// In development, it warns and uses a default secret if not set.
func ValidateJWTSecret() string {
	secret := os.Getenv("JWT_SECRET")
	appEnv := strings.ToLower(os.Getenv("APP_ENV"))
	isProduction := appEnv == "production" || appEnv == "prod"

	if secret == "" {
		if isProduction {
			log.Fatalf("FATAL: JWT_SECRET environment variable is required in production (APP_ENV=%s)", appEnv)
		}
		log.Printf("WARN: JWT_SECRET not set, using default development secret. DO NOT use in production!")
		return defaultDevSecret
	}

	if isProduction && len(secret) < minSecretLenForProd {
		log.Fatalf("FATAL: JWT_SECRET must be at least %d characters in production (got %d)", minSecretLenForProd, len(secret))
	}

	if !isProduction && len(secret) < minSecretLenForProd {
		log.Printf("WARN: JWT_SECRET is shorter than %d characters. Consider using a stronger secret.", minSecretLenForProd)
	}

	return secret
}

// ValidateJWTSecretFromValues is a testable version that doesn't call log.Fatal or os.Getenv.
// Returns (secret, error). If error is non-nil, the caller should fatal.
func ValidateJWTSecretFromValues(secret, appEnv string) (string, error) {
	isProduction := strings.ToLower(appEnv) == "production" || strings.ToLower(appEnv) == "prod"

	if secret == "" {
		if isProduction {
			return "", fmt.Errorf("JWT_SECRET environment variable is required in production (APP_ENV=%s)", appEnv)
		}
		return defaultDevSecret, nil
	}

	if isProduction && len(secret) < minSecretLenForProd {
		return "", fmt.Errorf("JWT_SECRET must be at least %d characters in production (got %d)", minSecretLenForProd, len(secret))
	}

	return secret, nil
}

// IsSecretWeak returns true if the secret is shorter than the recommended minimum.
func IsSecretWeak(secret string) bool {
	return len(secret) < minSecretLenForProd
}
