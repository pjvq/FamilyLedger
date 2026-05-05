package category

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestUUID_Deterministic(t *testing.T) {
	id1 := UUID("expense", "餐饮")
	id2 := UUID("expense", "餐饮")
	assert.Equal(t, id1, id2, "same input should produce same UUID")
}

func TestUUID_DifferentInputs(t *testing.T) {
	id1 := UUID("expense", "餐饮")
	id2 := UUID("income", "工资")
	assert.NotEqual(t, id1, id2)
}

func TestUUID_TypeMatters(t *testing.T) {
	id1 := UUID("expense", "test")
	id2 := UUID("income", "test")
	assert.NotEqual(t, id1, id2, "different type should produce different UUID")
}
