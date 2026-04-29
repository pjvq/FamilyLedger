package migration

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const migrationsDir = "../../migrations"
const expectedMigrationCount = 39

// validSQLStartRegex matches common SQL statement starters.
var validSQLStartRegex = regexp.MustCompile(`(?i)^\s*(CREATE|ALTER|DROP|INSERT|UPDATE|DELETE|SET|DO|BEGIN|COMMIT|WITH|--|\s*$)`)

// migrationFileRegex matches migration filenames like "001_create_users.up.sql"
var migrationFileRegex = regexp.MustCompile(`^(\d{3})_[a-z0-9_]+\.(up|down)\.sql$`)

func TestMigration_AllFilesExist(t *testing.T) {
	entries, err := os.ReadDir(migrationsDir)
	require.NoError(t, err, "failed to read migrations directory")

	upFiles := 0
	downFiles := 0
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		if strings.HasSuffix(entry.Name(), ".up.sql") {
			upFiles++
		}
		if strings.HasSuffix(entry.Name(), ".down.sql") {
			downFiles++
		}
	}

	assert.Equal(t, expectedMigrationCount, upFiles, "expected %d .up.sql files", expectedMigrationCount)
	assert.Equal(t, expectedMigrationCount, downFiles, "expected %d .down.sql files", expectedMigrationCount)
}

func TestMigration_FileNamingConvention(t *testing.T) {
	entries, err := os.ReadDir(migrationsDir)
	require.NoError(t, err)

	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		name := entry.Name()
		if !strings.HasSuffix(name, ".sql") {
			continue
		}
		assert.True(t, migrationFileRegex.MatchString(name),
			"migration file %q does not match expected naming pattern NNN_description.(up|down).sql", name)
	}
}

func TestMigration_SequentialNumbering(t *testing.T) {
	entries, err := os.ReadDir(migrationsDir)
	require.NoError(t, err)

	// Collect all unique migration numbers from .up.sql files
	numbers := make([]int, 0)
	seen := make(map[int]bool)

	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".up.sql") {
			continue
		}
		matches := migrationFileRegex.FindStringSubmatch(entry.Name())
		if len(matches) < 2 {
			t.Fatalf("unexpected file format: %s", entry.Name())
		}
		num, err := strconv.Atoi(matches[1])
		require.NoError(t, err)

		assert.False(t, seen[num], "duplicate migration number: %d", num)
		seen[num] = true
		numbers = append(numbers, num)
	}

	sort.Ints(numbers)

	// Verify sequential from 1 to N with no gaps
	for i, num := range numbers {
		expected := i + 1
		assert.Equal(t, expected, num,
			"migration numbering gap: expected %03d, got %03d", expected, num)
	}
}

func TestMigration_UpFilesHavePairs(t *testing.T) {
	entries, err := os.ReadDir(migrationsDir)
	require.NoError(t, err)

	upFiles := make(map[string]bool)
	downFiles := make(map[string]bool)

	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		name := entry.Name()
		if strings.HasSuffix(name, ".up.sql") {
			base := strings.TrimSuffix(name, ".up.sql")
			upFiles[base] = true
		}
		if strings.HasSuffix(name, ".down.sql") {
			base := strings.TrimSuffix(name, ".down.sql")
			downFiles[base] = true
		}
	}

	for base := range upFiles {
		assert.True(t, downFiles[base], "missing .down.sql for migration: %s", base)
	}
	for base := range downFiles {
		assert.True(t, upFiles[base], "missing .up.sql for migration: %s", base)
	}
}

func TestMigration_UpFilesNotEmpty(t *testing.T) {
	entries, err := os.ReadDir(migrationsDir)
	require.NoError(t, err)

	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".up.sql") {
			continue
		}
		path := filepath.Join(migrationsDir, entry.Name())
		data, err := os.ReadFile(path)
		require.NoError(t, err, "failed to read %s", entry.Name())

		content := strings.TrimSpace(string(data))
		assert.NotEmpty(t, content, "migration %s is empty", entry.Name())
	}
}

func TestMigration_UpFilesStartWithValidSQL(t *testing.T) {
	entries, err := os.ReadDir(migrationsDir)
	require.NoError(t, err)

	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".up.sql") {
			continue
		}
		path := filepath.Join(migrationsDir, entry.Name())
		data, err := os.ReadFile(path)
		require.NoError(t, err, "failed to read %s", entry.Name())

		content := strings.TrimSpace(string(data))
		if content == "" {
			continue // already caught by NotEmpty test
		}

		// Get first non-empty, non-comment line
		firstMeaningfulLine := ""
		for _, line := range strings.Split(content, "\n") {
			trimmed := strings.TrimSpace(line)
			if trimmed == "" || strings.HasPrefix(trimmed, "--") {
				continue
			}
			firstMeaningfulLine = trimmed
			break
		}

		if firstMeaningfulLine != "" {
			assert.True(t, validSQLStartRegex.MatchString(firstMeaningfulLine),
				"migration %s: first SQL line doesn't start with a recognized keyword: %q",
				entry.Name(), firstMeaningfulLine[:min(80, len(firstMeaningfulLine))])
		}
	}
}

func TestMigration_DownFilesNotEmpty(t *testing.T) {
	entries, err := os.ReadDir(migrationsDir)
	require.NoError(t, err)

	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".down.sql") {
			continue
		}
		path := filepath.Join(migrationsDir, entry.Name())
		data, err := os.ReadFile(path)
		require.NoError(t, err, "failed to read %s", entry.Name())

		content := strings.TrimSpace(string(data))
		assert.NotEmpty(t, content, "migration %s is empty", entry.Name())
	}
}

func TestMigration_FileSizesReasonable(t *testing.T) {
	entries, err := os.ReadDir(migrationsDir)
	require.NoError(t, err)

	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".sql") {
			continue
		}
		info, err := entry.Info()
		require.NoError(t, err)

		// Migration files shouldn't be too large (likely means binary data was committed)
		assert.Less(t, info.Size(), int64(1024*1024),
			"migration %s is suspiciously large (%d bytes)", entry.Name(), info.Size())
	}
}

func TestMigration_TotalCount(t *testing.T) {
	entries, err := os.ReadDir(migrationsDir)
	require.NoError(t, err)

	sqlFiles := 0
	for _, entry := range entries {
		if !entry.IsDir() && strings.HasSuffix(entry.Name(), ".sql") {
			sqlFiles++
		}
	}

	// 39 up + 39 down = 76 total
	assert.Equal(t, expectedMigrationCount*2, sqlFiles,
		fmt.Sprintf("expected %d SQL files (39 up + 39 down)", expectedMigrationCount*2))
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
