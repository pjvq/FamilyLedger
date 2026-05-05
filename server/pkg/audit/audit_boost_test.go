package audit

import (
	"context"
	"fmt"
	"testing"

	"github.com/google/uuid"
	pgxmock "github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// ── LogAudit edge cases ─────────────────────────────────────────────────────

func TestLogAudit_InvalidFamilyID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	// Invalid family_id → logs error, no INSERT
	LogAudit(context.Background(), mock, "bad", uuid.New().String(), "create", "txn", uuid.New().String(), nil)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestLogAudit_InvalidUserID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	LogAudit(context.Background(), mock, uuid.New().String(), "bad", "create", "txn", uuid.New().String(), nil)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestLogAudit_InvalidEntityID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	LogAudit(context.Background(), mock, uuid.New().String(), uuid.New().String(), "create", "txn", "bad", nil)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestLogAudit_DBError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	famID := uuid.New().String()
	userID := uuid.New().String()
	entID := uuid.New().String()
	mock.ExpectExec("INSERT INTO audit_logs").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), "update", "account", pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnError(fmt.Errorf("db error"))
	LogAudit(context.Background(), mock, famID, userID, "update", "account", entID, map[string]interface{}{"k": "v"})
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ── LogAuditWithExecer ──────────────────────────────────────────────────────

type mockExecer struct {
	execCalled bool
	returnErr  error
}

func (m *mockExecer) Exec(ctx context.Context, sql string, args ...any) (interface{ RowsAffected() int64 }, error) {
	m.execCalled = true
	if m.returnErr != nil {
		return nil, m.returnErr
	}
	return &mockResult{}, nil
}

type mockResult struct{}

func (m *mockResult) RowsAffected() int64 { return 1 }

func TestLogAuditWithExecer_EmptyFamily(t *testing.T) {
	err := LogAuditWithExecer(context.Background(), &mockExecer{}, "", uuid.New().String(), "create", "txn", uuid.New().String(), nil)
	assert.NoError(t, err)
}

func TestLogAuditWithExecer_Success(t *testing.T) {
	ex := &mockExecer{}
	err := LogAuditWithExecer(context.Background(), ex, uuid.New().String(), uuid.New().String(), "create", "txn", uuid.New().String(), nil)
	assert.NoError(t, err)
	assert.True(t, ex.execCalled)
}

func TestLogAuditWithExecer_WithChanges(t *testing.T) {
	ex := &mockExecer{}
	changes := map[string]interface{}{"amount": map[string]int{"old": 100, "new": 200}}
	err := LogAuditWithExecer(context.Background(), ex, uuid.New().String(), uuid.New().String(), "update", "txn", uuid.New().String(), changes)
	assert.NoError(t, err)
}

func TestLogAuditWithExecer_InvalidFamilyID(t *testing.T) {
	err := LogAuditWithExecer(context.Background(), &mockExecer{}, "bad", uuid.New().String(), "create", "txn", uuid.New().String(), nil)
	assert.Error(t, err)
}

func TestLogAuditWithExecer_InvalidUserID(t *testing.T) {
	err := LogAuditWithExecer(context.Background(), &mockExecer{}, uuid.New().String(), "bad", "create", "txn", uuid.New().String(), nil)
	assert.Error(t, err)
}

func TestLogAuditWithExecer_InvalidEntityID(t *testing.T) {
	err := LogAuditWithExecer(context.Background(), &mockExecer{}, uuid.New().String(), uuid.New().String(), "create", "txn", "bad", nil)
	assert.Error(t, err)
}

func TestLogAuditWithExecer_DBError(t *testing.T) {
	ex := &mockExecer{returnErr: fmt.Errorf("db err")}
	err := LogAuditWithExecer(context.Background(), ex, uuid.New().String(), uuid.New().String(), "create", "txn", uuid.New().String(), nil)
	assert.Error(t, err)
}
