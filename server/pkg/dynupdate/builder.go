// Package dynupdate provides a type-safe builder for dynamic SQL UPDATE statements.
//
// It eliminates the repeated setClauses/args/argIdx boilerplate pattern
// found across sync entity operations.
package dynupdate

import (
	"fmt"
	"regexp"
	"strings"
)

// identifierRe matches safe SQL identifiers: letters, digits, underscores only.
var identifierRe = regexp.MustCompile(`^[a-zA-Z_][a-zA-Z0-9_]*$`)

// isValidIdentifier checks that a name is a safe SQL identifier.
func isValidIdentifier(name string) bool {
	return len(name) > 0 && len(name) <= 63 && identifierRe.MatchString(name)
}

// Builder constructs a dynamic UPDATE statement by accumulating SET clauses.
// Zero value is ready to use. Build() is terminal — must not be called twice.
type Builder struct {
	setClauses []string
	args       []interface{}
	built      bool
}

// Set adds a column assignment if the condition is true.
// This is the primary method — call it for each optional field.
// Panics if column is not a valid SQL identifier.
func (b *Builder) Set(column string, value interface{}, condition bool) {
	if !condition {
		return
	}
	if !isValidIdentifier(column) {
		panic(fmt.Sprintf("dynupdate: invalid column name: %q", column))
	}
	b.args = append(b.args, value)
	b.setClauses = append(b.setClauses, fmt.Sprintf("%s = $%d", column, len(b.args)))
}

// SetString adds a column assignment if value is non-empty.
func (b *Builder) SetString(column, value string) {
	b.Set(column, value, value != "")
}

// SetInt64NonZero adds a column assignment if value is non-zero.
// NOTE: If you need to set a field TO zero, use Set() directly with condition=true.
func (b *Builder) SetInt64NonZero(column string, value int64) {
	b.Set(column, value, value != 0)
}

// SetIntNonZero adds a column assignment if value is non-zero.
func (b *Builder) SetIntNonZero(column string, value int) {
	b.Set(column, value, value != 0)
}

// SetFloat64NonZero adds a column assignment if value is non-zero.
func (b *Builder) SetFloat64NonZero(column string, value float64) {
	b.Set(column, value, value != 0)
}

// HasUpdates returns true if at least one SET clause was added.
func (b *Builder) HasUpdates() bool {
	return len(b.setClauses) > 0
}

// Build returns the full UPDATE statement and the argument slice.
// Terminal operation — panics if called more than once on the same Builder.
//
// Example output:
//
//	"UPDATE loans SET name = $1, annual_rate = $2, updated_at = NOW() WHERE id = $3 AND deleted_at IS NULL"
//	args: ["My Loan", 3.5, entityID]
func (b *Builder) Build(table string, entityID interface{}) (string, []interface{}) {
	if b.built {
		panic("dynupdate: Build() called more than once")
	}
	b.built = true

	if !isValidIdentifier(table) {
		panic(fmt.Sprintf("dynupdate: invalid table name: %q", table))
	}

	// Copy to avoid mutating caller's view
	clauses := make([]string, len(b.setClauses), len(b.setClauses)+1)
	copy(clauses, b.setClauses)
	clauses = append(clauses, "updated_at = NOW()")

	args := make([]interface{}, len(b.args), len(b.args)+1)
	copy(args, b.args)
	args = append(args, entityID)
	idIdx := len(args)

	query := fmt.Sprintf("UPDATE %s SET %s WHERE id = $%d AND deleted_at IS NULL",
		table,
		strings.Join(clauses, ", "),
		idIdx,
	)
	return query, args
}

// BuildOrNoOp returns the UPDATE statement: uses Build if there are updates,
// otherwise returns a no-op that just touches updated_at.
func (b *Builder) BuildOrNoOp(table string, entityID interface{}) (string, []interface{}) {
	if !b.HasUpdates() {
		b.built = true // mark consumed
		return BuildNoOp(table, entityID)
	}
	return b.Build(table, entityID)
}

// BuildNoOp returns a simple "touch updated_at" statement when no fields changed.
// Panics if table is not a valid SQL identifier.
func BuildNoOp(table string, entityID interface{}) (string, []interface{}) {
	if !isValidIdentifier(table) {
		panic(fmt.Sprintf("dynupdate: invalid table name: %q", table))
	}
	return fmt.Sprintf("UPDATE %s SET updated_at = NOW() WHERE id = $1", table), []interface{}{entityID}
}
