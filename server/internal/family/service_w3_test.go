package family

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// ═══════════════════════════════════════════════════════════════════════════════
// W3: Family Business Logic Tests
// Covers: invite code format (8-char, uppercase alphanumeric), TTL
// ═══════════════════════════════════════════════════════════════════════════════

func TestW3_GenerateInviteCode_Format(t *testing.T) {
	// Test the code generation function directly
	// Produces 100 codes and validates format
	seen := make(map[string]bool)

	for i := 0; i < 100; i++ {
		code, err := generateInviteCode()
		require.NoError(t, err)

		// Must be exactly 8 characters
		assert.Len(t, code, 8, "invite code must be 8 characters")

		// Must only contain uppercase letters and digits
		for _, ch := range code {
			assert.True(t,
				(ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9'),
				"invite code must be uppercase alphanumeric, got: %c", ch,
			)
		}

		// Should have reasonable uniqueness (no collisions in 100 runs)
		assert.False(t, seen[code], "invite code collision detected: %s", code)
		seen[code] = true
	}
}

// suppress unused import warning
var _ context.Context
