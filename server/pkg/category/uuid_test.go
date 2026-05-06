package category

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestUUID_Deterministic(t *testing.T) {
	id1 := UUID("user-123", "expense", "餐饮")
	id2 := UUID("user-123", "expense", "餐饮")
	assert.Equal(t, id1, id2, "same input should produce same UUID")
}

func TestUUID_DifferentUsers(t *testing.T) {
	id1 := UUID("user-aaa", "expense", "餐饮")
	id2 := UUID("user-bbb", "expense", "餐饮")
	assert.NotEqual(t, id1, id2, "different users should produce different UUIDs for same category")
}

func TestUUID_DifferentInputs(t *testing.T) {
	id1 := UUID("user-123", "expense", "餐饮")
	id2 := UUID("user-123", "income", "工资")
	assert.NotEqual(t, id1, id2)
}

func TestUUID_TypeMatters(t *testing.T) {
	id1 := UUID("user-123", "expense", "test")
	id2 := UUID("user-123", "income", "test")
	assert.NotEqual(t, id1, id2, "different type should produce different UUID")
}

func TestUUID_FamilyShared(t *testing.T) {
	// Family members use familyId as ownerID, so same category = same UUID
	id1 := UUID("family-xyz", "expense", "餐饮")
	id2 := UUID("family-xyz", "expense", "餐饮")
	assert.Equal(t, id1, id2, "same family should produce same UUID")
}
