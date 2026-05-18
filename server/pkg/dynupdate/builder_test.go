package dynupdate

import (
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
)

func TestBuilder_NoFields(t *testing.T) {
	var b Builder
	assert.False(t, b.HasUpdates())
}

func TestBuilder_SetString(t *testing.T) {
	var b Builder
	b.SetString("name", "hello")
	b.SetString("empty", "")

	assert.True(t, b.HasUpdates())

	id := uuid.New()
	query, args := b.Build("loans", id)
	assert.Equal(t, "UPDATE loans SET name = $1, updated_at = NOW() WHERE id = $2 AND deleted_at IS NULL", query)
	assert.Equal(t, []interface{}{"hello", id}, args)
}

func TestBuilder_MixedTypes(t *testing.T) {
	var b Builder
	b.SetString("name", "test")
	b.SetInt64NonZero("amount", 1000)
	b.SetFloat64NonZero("rate", 3.5)
	b.SetIntNonZero("months", 0) // should not be added

	id := uuid.New()
	query, args := b.Build("investments", id)
	assert.Contains(t, query, "name = $1")
	assert.Contains(t, query, "amount = $2")
	assert.Contains(t, query, "rate = $3")
	assert.NotContains(t, query, "months")
	assert.Contains(t, query, "WHERE id = $4")
	assert.Len(t, args, 4)
}

func TestBuilder_ConditionalSet(t *testing.T) {
	var b Builder
	b.Set("status", "active", true)
	b.Set("hidden", "secret", false) // should not be added

	assert.True(t, b.HasUpdates())
	id := uuid.New()
	_, args := b.Build("accounts", id)
	assert.Len(t, args, 2) // "active" + id
}

func TestBuildNoOp(t *testing.T) {
	id := uuid.New()
	query, args := BuildNoOp("loans", id)
	assert.Equal(t, "UPDATE loans SET updated_at = NOW() WHERE id = $1", query)
	assert.Equal(t, []interface{}{id}, args)
}

func TestBuildOrNoOp_NoUpdates(t *testing.T) {
	var b Builder
	id := uuid.New()
	query, args := b.BuildOrNoOp("loans", id)
	assert.Equal(t, "UPDATE loans SET updated_at = NOW() WHERE id = $1", query)
	assert.Equal(t, []interface{}{id}, args)
}

func TestBuildOrNoOp_WithUpdates(t *testing.T) {
	var b Builder
	b.SetString("name", "hello")
	id := uuid.New()
	query, args := b.BuildOrNoOp("loans", id)
	assert.Contains(t, query, "name = $1")
	assert.Contains(t, query, "updated_at = NOW()")
	assert.Len(t, args, 2)
}

func TestBuilder_DoubleBuildPanics(t *testing.T) {
	var b Builder
	b.SetString("name", "test")
	id := uuid.New()
	b.Build("loans", id)
	assert.Panics(t, func() { b.Build("loans", id) })
}

func TestBuilder_InvalidTablePanics(t *testing.T) {
	var b Builder
	b.SetString("name", "test")
	assert.Panics(t, func() { b.Build("loans; DROP TABLE--", uuid.New()) })
}

func TestBuilder_InvalidColumnPanics(t *testing.T) {
	var b Builder
	assert.Panics(t, func() { b.Set("name; DROP", "x", true) })
}

func TestBuildNoOp_InvalidTablePanics(t *testing.T) {
	assert.Panics(t, func() { BuildNoOp("bad table", uuid.New()) })
}
