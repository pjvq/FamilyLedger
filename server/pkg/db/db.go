package db

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// Pool defaults — single source of truth.
const (
	DefaultMaxConns        int32         = 20
	DefaultMinConns        int32         = 2
	DefaultMaxConnLifetime time.Duration = 1 * time.Hour
	DefaultMaxConnIdleTime time.Duration = 30 * time.Minute
)

type Config struct {
	Host     string
	Port     int
	User     string
	Password string
	DBName   string
	SSLMode  string
	// Pool configuration (zero value = use defaults above)
	MaxConns        int32
	MinConns        int32
	MaxConnLifetime time.Duration
	MaxConnIdleTime time.Duration
}

func NewPool(ctx context.Context, cfg Config) (*pgxpool.Pool, error) {
	dsn := fmt.Sprintf(
		"postgres://%s:%s@%s:%d/%s?sslmode=%s",
		cfg.User, cfg.Password, cfg.Host, cfg.Port, cfg.DBName, cfg.SSLMode,
	)

	poolCfg, err := pgxpool.ParseConfig(dsn)
	if err != nil {
		return nil, fmt.Errorf("parse db config: %w", err)
	}

	// Apply pool settings with sensible defaults
	maxConns := DefaultMaxConns
	if cfg.MaxConns > 0 {
		maxConns = cfg.MaxConns
	}
	minConns := DefaultMinConns
	if cfg.MinConns > 0 {
		minConns = cfg.MinConns
	}

	// Validate: MinConns must not exceed MaxConns
	if minConns > maxConns {
		return nil, fmt.Errorf("db pool config: MinConns (%d) must not exceed MaxConns (%d)", minConns, maxConns)
	}

	poolCfg.MaxConns = maxConns
	poolCfg.MinConns = minConns

	poolCfg.MaxConnLifetime = DefaultMaxConnLifetime
	if cfg.MaxConnLifetime > 0 {
		poolCfg.MaxConnLifetime = cfg.MaxConnLifetime
	}
	poolCfg.MaxConnIdleTime = DefaultMaxConnIdleTime
	if cfg.MaxConnIdleTime > 0 {
		poolCfg.MaxConnIdleTime = cfg.MaxConnIdleTime
	}

	pool, err := pgxpool.NewWithConfig(ctx, poolCfg)
	if err != nil {
		return nil, fmt.Errorf("create db pool: %w", err)
	}

	if err := pool.Ping(ctx); err != nil {
		return nil, fmt.Errorf("ping db: %w", err)
	}

	return pool, nil
}
