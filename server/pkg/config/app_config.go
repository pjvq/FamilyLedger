package config

import (
	"fmt"
	"os"
	"strconv"
)

// AppConfig holds application configuration from environment variables.
type AppConfig struct {
	DBHost     string
	DBPort     int
	DBUser     string
	DBPassword string
	DBName     string
	DBSSLMode  string
	GRPCPort   string
	WSPort     string
}

// LoadAppConfig reads application configuration from environment variables.
// Returns an error if required values are missing or invalid.
func LoadAppConfig() (*AppConfig, error) {
	cfg := &AppConfig{
		DBHost:     getEnvDefault("DB_HOST", ""),
		DBUser:     getEnvDefault("DB_USER", "familyledger"),
		DBPassword: getEnvDefault("DB_PASSWORD", "familyledger"),
		DBName:     getEnvDefault("DB_NAME", "familyledger"),
		DBSSLMode:  getEnvDefault("DB_SSLMODE", "disable"),
		GRPCPort:   getEnvDefault("GRPC_PORT", "50051"),
		WSPort:     getEnvDefault("WS_PORT", "8080"),
	}

	// DB_HOST is required (no sensible default for production)
	if cfg.DBHost == "" {
		return nil, fmt.Errorf("DB_HOST environment variable is required")
	}

	// Parse DB_PORT
	dbPortStr := getEnvDefault("DB_PORT", "5432")
	port, err := strconv.Atoi(dbPortStr)
	if err != nil {
		return nil, fmt.Errorf("DB_PORT must be a valid integer: %q", dbPortStr)
	}
	if port < 1 || port > 65535 {
		return nil, fmt.Errorf("DB_PORT must be between 1 and 65535: %d", port)
	}
	cfg.DBPort = port

	// Validate GRPC_PORT is a valid port number
	if err := validatePort("GRPC_PORT", cfg.GRPCPort); err != nil {
		return nil, err
	}

	// Validate WS_PORT is a valid port number
	if err := validatePort("WS_PORT", cfg.WSPort); err != nil {
		return nil, err
	}

	return cfg, nil
}

// LoadAppConfigFromValues is a testable version that reads from a map instead of os environment.
func LoadAppConfigFromValues(env map[string]string) (*AppConfig, error) {
	get := func(key, fallback string) string {
		if v, ok := env[key]; ok {
			return v
		}
		return fallback
	}

	cfg := &AppConfig{
		DBHost:     get("DB_HOST", ""),
		DBUser:     get("DB_USER", "familyledger"),
		DBPassword: get("DB_PASSWORD", "familyledger"),
		DBName:     get("DB_NAME", "familyledger"),
		DBSSLMode:  get("DB_SSLMODE", "disable"),
		GRPCPort:   get("GRPC_PORT", "50051"),
		WSPort:     get("WS_PORT", "8080"),
	}

	// DB_HOST is required
	if cfg.DBHost == "" {
		return nil, fmt.Errorf("DB_HOST environment variable is required")
	}

	// Parse DB_PORT
	dbPortStr := get("DB_PORT", "5432")
	port, err := strconv.Atoi(dbPortStr)
	if err != nil {
		return nil, fmt.Errorf("DB_PORT must be a valid integer: %q", dbPortStr)
	}
	if port < 1 || port > 65535 {
		return nil, fmt.Errorf("DB_PORT must be between 1 and 65535: %d", port)
	}
	cfg.DBPort = port

	// Validate GRPC_PORT
	if err := validatePort("GRPC_PORT", cfg.GRPCPort); err != nil {
		return nil, err
	}

	// Validate WS_PORT
	if err := validatePort("WS_PORT", cfg.WSPort); err != nil {
		return nil, err
	}

	return cfg, nil
}

func validatePort(name, value string) error {
	port, err := strconv.Atoi(value)
	if err != nil {
		return fmt.Errorf("%s must be a valid integer: %q", name, value)
	}
	if port < 1 || port > 65535 {
		return fmt.Errorf("%s must be between 1 and 65535: %d", name, port)
	}
	return nil
}

func getEnvDefault(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok {
		return value
	}
	return fallback
}
