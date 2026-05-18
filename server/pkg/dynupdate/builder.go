// Package dynupdate provides a type-safe builder for dynamic SQL UPDATE statements.
//
// It eliminates the repeated setClauses/args/argIdx boilerplate pattern
// found across sync entity operations.
package dynupdate

import (
	"fmt"
	"strings"
)

// Builder constructs a dynamic UPDATE statement by accumulating SET clauses.
// Zero value is ready to use.
type Builder struct {
	setClauses []string
	args       []interface{}
}

// Set adds a column assignment if the condition is true.
// This is the primary method — call it for each optional field.
func (b *Builder) Set(column string, value interface{}, condition bool) {
	if !condition {
		return
	}
	b.args = append(b.args, value)
	b.setClauses = append(b.setClauses, fmt.Sprintf("%s = $%d", column, len(b.args)))
}

// SetString adds a column assignment if value is non-empty.
func (b *Builder) SetString(column, value string) {
	b.Set(column, value, value != "")
}

// SetInt64 adds a column assignment if value > 0.
func (b *Builder) SetInt64(column string, value int64) {
	b.Set(column, value, value > 0)
}

// SetInt adds a column assignment if value > 0.
func (b *Builder) SetInt(column string, value int) {
	b.Set(column, value, value > 0)
}

// SetFloat64 adds a column assignment if value > 0.
func (b *Builder) SetFloat64(column string, value float64) {
	b.Set(column, value, value > 0)
}

// HasUpdates returns true if at least one SET clause was added.
func (b *Builder) HasUpdates() bool {
	return len(b.setClauses) > 0
}

// Build returns the full UPDATE statement and the argument slice.
// The WHERE clause uses the next parameter index for the entity ID.
//
// Example output:
//
//	"UPDATE loans SET name = $1, annual_rate = $2, updated_at = NOW() WHERE id = $3 AND deleted_at IS NULL"
//	args: ["My Loan", 3.5, entityID]
func (b *Builder) Build(table string, entityID interface{}) (string, []interface{}) {
	b.setClauses = append(b.setClauses, "updated_at = NOW()")
	b.args = append(b.args, entityID)
	idIdx := len(b.args)

	query := fmt.Sprintf("UPDATE %s SET %s WHERE id = $%d AND deleted_at IS NULL",
		table,
		strings.Join(b.setClauses, ", "),
		idIdx,
	)
	return query, b.args
}

// BuildNoOp returns a simple "touch updated_at" statement when no fields changed.
func BuildNoOp(table string, entityID interface{}) (string, []interface{}) {
	return fmt.Sprintf("UPDATE %s SET updated_at = NOW() WHERE id = $1", table), []interface{}{entityID}
}
