// Package db provides a minimal interface for database access,
// allowing production code to use *pgxpool.Pool and tests to use pgxmock.
package db

import (
	"context"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

// Pool abstracts the subset of pgxpool.Pool methods used by services.
// *pgxpool.Pool satisfies this interface, as does pgxmock.PgxPoolIface.
type Pool interface {
	Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
	Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
	Begin(ctx context.Context) (pgx.Tx, error)
}
