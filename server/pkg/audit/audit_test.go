package audit

import (
	"context"
	"testing"

	"github.com/google/uuid"
	pgxmock "github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestLogAudit_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	familyID := uuid.New().String()
	userID := uuid.New().String()
	entityID := uuid.New().String()

	mock.ExpectExec("INSERT INTO audit_logs").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), "create", "transaction", pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	LogAudit(context.Background(), mock, familyID, userID, "create", "transaction", entityID, map[string]interface{}{"amount": 100})
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestLogAudit_EmptyFamilyID_Noop(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	// No family ID — should be a no-op
	LogAudit(context.Background(), mock, "", uuid.New().String(), "create", "transaction", uuid.New().String(), nil)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestLogAudit_NilChanges(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	familyID := uuid.New().String()
	userID := uuid.New().String()
	entityID := uuid.New().String()

	mock.ExpectExec("INSERT INTO audit_logs").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), "delete", "account", pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	LogAudit(context.Background(), mock, familyID, userID, "delete", "account", entityID, nil)
	assert.NoError(t, mock.ExpectationsWereMet())
}
