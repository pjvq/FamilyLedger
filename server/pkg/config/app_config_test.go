package config

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestLoadAppConfigFromValues_ValidConfig(t *testing.T) {
	env := map[string]string{
		"DB_HOST":     "localhost",
		"DB_PORT":     "5432",
		"DB_USER":     "myuser",
		"DB_PASSWORD": "mypass",
		"DB_NAME":     "mydb",
		"DB_SSLMODE":  "require",
		"GRPC_PORT":   "50051",
		"WS_PORT":     "8080",
	}

	cfg, err := LoadAppConfigFromValues(env)
	require.NoError(t, err)
	assert.Equal(t, "localhost", cfg.DBHost)
	assert.Equal(t, 5432, cfg.DBPort)
	assert.Equal(t, "myuser", cfg.DBUser)
	assert.Equal(t, "mypass", cfg.DBPassword)
	assert.Equal(t, "mydb", cfg.DBName)
	assert.Equal(t, "require", cfg.DBSSLMode)
	assert.Equal(t, "50051", cfg.GRPCPort)
	assert.Equal(t, "8080", cfg.WSPort)
}

func TestLoadAppConfigFromValues_DefaultValues(t *testing.T) {
	env := map[string]string{
		"DB_HOST": "db.example.com",
	}

	cfg, err := LoadAppConfigFromValues(env)
	require.NoError(t, err)
	assert.Equal(t, "db.example.com", cfg.DBHost)
	assert.Equal(t, 5432, cfg.DBPort)
	assert.Equal(t, "familyledger", cfg.DBUser)
	assert.Equal(t, "familyledger", cfg.DBPassword)
	assert.Equal(t, "familyledger", cfg.DBName)
	assert.Equal(t, "disable", cfg.DBSSLMode)
	assert.Equal(t, "50051", cfg.GRPCPort)
	assert.Equal(t, "8080", cfg.WSPort)
}

func TestLoadAppConfigFromValues_MissingDBHost(t *testing.T) {
	env := map[string]string{
		"DB_PORT": "5432",
	}

	cfg, err := LoadAppConfigFromValues(env)
	require.Error(t, err)
	assert.Nil(t, cfg)
	assert.Contains(t, err.Error(), "DB_HOST")
	assert.Contains(t, err.Error(), "required")
}

func TestLoadAppConfigFromValues_EmptyDBHost(t *testing.T) {
	env := map[string]string{
		"DB_HOST": "",
	}

	cfg, err := LoadAppConfigFromValues(env)
	require.Error(t, err)
	assert.Nil(t, cfg)
	assert.Contains(t, err.Error(), "DB_HOST")
}

func TestLoadAppConfigFromValues_InvalidDBPort(t *testing.T) {
	tests := []struct {
		name    string
		port    string
		errMsg  string
	}{
		{"non-numeric", "abc", "valid integer"},
		{"negative", "-1", "between 1 and 65535"},
		{"zero", "0", "between 1 and 65535"},
		{"too large", "99999", "between 1 and 65535"},
		{"float", "5432.5", "valid integer"},
		{"empty string", "", "valid integer"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			env := map[string]string{
				"DB_HOST": "localhost",
				"DB_PORT": tt.port,
			}

			cfg, err := LoadAppConfigFromValues(env)
			require.Error(t, err)
			assert.Nil(t, cfg)
			assert.Contains(t, err.Error(), tt.errMsg)
		})
	}
}

func TestLoadAppConfigFromValues_InvalidGRPCPort(t *testing.T) {
	tests := []struct {
		name    string
		port    string
		errMsg  string
	}{
		{"non-numeric", "not-a-port", "valid integer"},
		{"negative", "-5", "between 1 and 65535"},
		{"zero", "0", "between 1 and 65535"},
		{"too large", "70000", "between 1 and 65535"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			env := map[string]string{
				"DB_HOST":   "localhost",
				"GRPC_PORT": tt.port,
			}

			cfg, err := LoadAppConfigFromValues(env)
			require.Error(t, err)
			assert.Nil(t, cfg)
			assert.Contains(t, err.Error(), "GRPC_PORT")
			assert.Contains(t, err.Error(), tt.errMsg)
		})
	}
}

func TestLoadAppConfigFromValues_InvalidWSPort(t *testing.T) {
	tests := []struct {
		name    string
		port    string
		errMsg  string
	}{
		{"non-numeric", "xyz", "valid integer"},
		{"negative", "-100", "between 1 and 65535"},
		{"too large", "100000", "between 1 and 65535"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			env := map[string]string{
				"DB_HOST": "localhost",
				"WS_PORT": tt.port,
			}

			cfg, err := LoadAppConfigFromValues(env)
			require.Error(t, err)
			assert.Nil(t, cfg)
			assert.Contains(t, err.Error(), "WS_PORT")
			assert.Contains(t, err.Error(), tt.errMsg)
		})
	}
}

func TestLoadAppConfigFromValues_ValidPortBoundaries(t *testing.T) {
	tests := []struct {
		name string
		port string
		want int
	}{
		{"minimum port", "1", 1},
		{"common port", "5432", 5432},
		{"maximum port", "65535", 65535},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			env := map[string]string{
				"DB_HOST": "localhost",
				"DB_PORT": tt.port,
			}

			cfg, err := LoadAppConfigFromValues(env)
			require.NoError(t, err)
			assert.Equal(t, tt.want, cfg.DBPort)
		})
	}
}

func TestLoadAppConfigFromValues_CustomGRPCAndWSPorts(t *testing.T) {
	env := map[string]string{
		"DB_HOST":   "localhost",
		"GRPC_PORT": "9090",
		"WS_PORT":   "3000",
	}

	cfg, err := LoadAppConfigFromValues(env)
	require.NoError(t, err)
	assert.Equal(t, "9090", cfg.GRPCPort)
	assert.Equal(t, "3000", cfg.WSPort)
}

func TestValidatePort_Valid(t *testing.T) {
	assert.NoError(t, validatePort("TEST_PORT", "8080"))
	assert.NoError(t, validatePort("TEST_PORT", "1"))
	assert.NoError(t, validatePort("TEST_PORT", "65535"))
}

func TestValidatePort_Invalid(t *testing.T) {
	assert.Error(t, validatePort("TEST_PORT", "abc"))
	assert.Error(t, validatePort("TEST_PORT", "0"))
	assert.Error(t, validatePort("TEST_PORT", "65536"))
	assert.Error(t, validatePort("TEST_PORT", "-1"))
}
