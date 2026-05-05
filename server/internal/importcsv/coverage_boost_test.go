package importcsv

import (
	"fmt"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	pb "github.com/familyledger/server/proto/importpb"
)

// ════════════════════════════════════════════════════════════════════════════
// ConfirmImport — full success path and edge cases
// ════════════════════════════════════════════════════════════════════════════

func TestBoost_ConfirmImport_SuccessWithDefaultAccount(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	sessionID := uuid.New()
	userID := uuid.MustParse(testUserID)
	accountID := uuid.New()
	categoryID := uuid.New()
	csvData := []byte("date,amount,type,category,note\n2026-01-15,100.50,expense,餐饮,午餐\n")
	expiresAt := time.Now().Add(30 * time.Minute)

	// Load session
	mock.ExpectQuery("SELECT .+ FROM import_sessions WHERE id").
		WithArgs(sessionID).
		WillReturnRows(pgxmock.NewRows([]string{"csv_data", "headers", "expires_at"}).
			AddRow(csvData, []string{"date", "amount", "type", "category", "note"}, expiresAt))

	// No default_account_id provided, look up user's default account
	mock.ExpectQuery("SELECT id FROM accounts WHERE user_id").
		WithArgs(userID).
		WillReturnRows(pgxmock.NewRows([]string{"id"}).AddRow(accountID))

	mock.ExpectBegin()

	// Category lookup: exact match
	mock.ExpectQuery("SELECT id FROM categories WHERE name = \\$1").
		WithArgs("餐饮").
		WillReturnRows(pgxmock.NewRows([]string{"id"}).AddRow(categoryID))

	// Insert transaction
	mock.ExpectExec("INSERT INTO transactions").
		WithArgs(userID, accountID, categoryID, int64(10050), "expense", "午餐", pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	// Update account balance
	mock.ExpectExec("UPDATE accounts SET balance").
		WithArgs(int64(-10050), accountID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	mock.ExpectCommit()

	// Cleanup session
	mock.ExpectExec("DELETE FROM import_sessions WHERE id").
		WithArgs(sessionID).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))

	resp, err := svc.ConfirmImport(authedCtx(), &pb.ConfirmImportRequest{
		SessionId: sessionID.String(),
		UserId:    testUserID,
		Mappings: []*pb.FieldMapping{
			{CsvColumn: "date", TargetField: "date"},
			{CsvColumn: "amount", TargetField: "amount"},
			{CsvColumn: "type", TargetField: "type"},
			{CsvColumn: "category", TargetField: "category"},
			{CsvColumn: "note", TargetField: "note"},
		},
	})
	require.NoError(t, err)
	assert.Equal(t, int32(1), resp.ImportedCount)
	assert.Equal(t, int32(0), resp.SkippedCount)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoost_ConfirmImport_WithProvidedAccountID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	sessionID := uuid.New()
	userID := uuid.MustParse(testUserID)
	accountID := uuid.New()
	categoryID := uuid.New()
	csvData := []byte("date,amount\n2026-02-01,50\n")
	expiresAt := time.Now().Add(30 * time.Minute)

	mock.ExpectQuery("SELECT .+ FROM import_sessions WHERE id").
		WithArgs(sessionID).
		WillReturnRows(pgxmock.NewRows([]string{"csv_data", "headers", "expires_at"}).
			AddRow(csvData, []string{"date", "amount"}, expiresAt))

	mock.ExpectBegin()

	// No category field → default expense category
	mock.ExpectQuery("SELECT id FROM categories WHERE type = \\$1").
		WithArgs("expense").
		WillReturnRows(pgxmock.NewRows([]string{"id"}).AddRow(categoryID))

	mock.ExpectExec("INSERT INTO transactions").
		WithArgs(userID, accountID, categoryID, int64(5000), "expense", "", pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	mock.ExpectExec("UPDATE accounts SET balance").
		WithArgs(int64(-5000), accountID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	mock.ExpectCommit()

	mock.ExpectExec("DELETE FROM import_sessions WHERE id").
		WithArgs(sessionID).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))

	resp, err := svc.ConfirmImport(authedCtx(), &pb.ConfirmImportRequest{
		SessionId:        sessionID.String(),
		UserId:           testUserID,
		DefaultAccountId: accountID.String(),
		Mappings: []*pb.FieldMapping{
			{CsvColumn: "date", TargetField: "date"},
			{CsvColumn: "amount", TargetField: "amount"},
		},
	})
	require.NoError(t, err)
	assert.Equal(t, int32(1), resp.ImportedCount)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoost_ConfirmImport_IncomeType(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	sessionID := uuid.New()
	userID := uuid.MustParse(testUserID)
	accountID := uuid.New()
	categoryID := uuid.New()
	csvData := []byte("date,amount,type\n2026-03-01,200,income\n")
	expiresAt := time.Now().Add(30 * time.Minute)

	mock.ExpectQuery("SELECT .+ FROM import_sessions WHERE id").
		WithArgs(sessionID).
		WillReturnRows(pgxmock.NewRows([]string{"csv_data", "headers", "expires_at"}).
			AddRow(csvData, []string{"date", "amount", "type"}, expiresAt))

	mock.ExpectBegin()

	// income type → income category
	mock.ExpectQuery("SELECT id FROM categories WHERE type = \\$1").
		WithArgs("income").
		WillReturnRows(pgxmock.NewRows([]string{"id"}).AddRow(categoryID))

	mock.ExpectExec("INSERT INTO transactions").
		WithArgs(userID, accountID, categoryID, int64(20000), "income", "", pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	// Income: positive balance delta
	mock.ExpectExec("UPDATE accounts SET balance").
		WithArgs(int64(20000), accountID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	mock.ExpectCommit()

	mock.ExpectExec("DELETE FROM import_sessions WHERE id").
		WithArgs(sessionID).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))

	resp, err := svc.ConfirmImport(authedCtx(), &pb.ConfirmImportRequest{
		SessionId:        sessionID.String(),
		UserId:           testUserID,
		DefaultAccountId: accountID.String(),
		Mappings: []*pb.FieldMapping{
			{CsvColumn: "date", TargetField: "date"},
			{CsvColumn: "amount", TargetField: "amount"},
			{CsvColumn: "type", TargetField: "type"},
		},
	})
	require.NoError(t, err)
	assert.Equal(t, int32(1), resp.ImportedCount)
}

func TestBoost_ConfirmImport_CategoryFuzzyMatch(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	sessionID := uuid.New()
	userID := uuid.MustParse(testUserID)
	accountID := uuid.New()
	categoryID := uuid.New()
	csvData := []byte("amount,category\n100,食品\n")
	expiresAt := time.Now().Add(30 * time.Minute)

	mock.ExpectQuery("SELECT .+ FROM import_sessions WHERE id").
		WithArgs(sessionID).
		WillReturnRows(pgxmock.NewRows([]string{"csv_data", "headers", "expires_at"}).
			AddRow(csvData, []string{"amount", "category"}, expiresAt))

	mock.ExpectBegin()

	// Exact match fails
	mock.ExpectQuery("SELECT id FROM categories WHERE name = \\$1").
		WithArgs("食品").
		WillReturnError(pgx.ErrNoRows)
	// Fuzzy match succeeds
	mock.ExpectQuery("SELECT id FROM categories WHERE name ILIKE").
		WithArgs("%食品%").
		WillReturnRows(pgxmock.NewRows([]string{"id"}).AddRow(categoryID))

	mock.ExpectExec("INSERT INTO transactions").
		WithArgs(userID, accountID, categoryID, int64(10000), "expense", "", pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	mock.ExpectExec("UPDATE accounts SET balance").
		WithArgs(int64(-10000), accountID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	mock.ExpectCommit()

	mock.ExpectExec("DELETE FROM import_sessions WHERE id").
		WithArgs(sessionID).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))

	resp, err := svc.ConfirmImport(authedCtx(), &pb.ConfirmImportRequest{
		SessionId:        sessionID.String(),
		UserId:           testUserID,
		DefaultAccountId: accountID.String(),
		Mappings: []*pb.FieldMapping{
			{CsvColumn: "amount", TargetField: "amount"},
			{CsvColumn: "category", TargetField: "category"},
		},
	})
	require.NoError(t, err)
	assert.Equal(t, int32(1), resp.ImportedCount)
}

func TestBoost_ConfirmImport_CategoryFallbackToType(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	sessionID := uuid.New()
	userID := uuid.MustParse(testUserID)
	accountID := uuid.New()
	categoryID := uuid.New()
	csvData := []byte("amount,category\n100,不存在的分类\n")
	expiresAt := time.Now().Add(30 * time.Minute)

	mock.ExpectQuery("SELECT .+ FROM import_sessions WHERE id").
		WithArgs(sessionID).
		WillReturnRows(pgxmock.NewRows([]string{"csv_data", "headers", "expires_at"}).
			AddRow(csvData, []string{"amount", "category"}, expiresAt))

	mock.ExpectBegin()

	// Exact fails
	mock.ExpectQuery("SELECT id FROM categories WHERE name = \\$1").
		WithArgs("不存在的分类").
		WillReturnError(pgx.ErrNoRows)
	// Fuzzy fails
	mock.ExpectQuery("SELECT id FROM categories WHERE name ILIKE").
		WithArgs("%不存在的分类%").
		WillReturnError(pgx.ErrNoRows)
	// Fallback to type
	mock.ExpectQuery("SELECT id FROM categories WHERE type = \\$1").
		WithArgs("expense").
		WillReturnRows(pgxmock.NewRows([]string{"id"}).AddRow(categoryID))

	mock.ExpectExec("INSERT INTO transactions").
		WithArgs(userID, accountID, categoryID, int64(10000), "expense", "", pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	mock.ExpectExec("UPDATE accounts SET balance").
		WithArgs(int64(-10000), accountID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	mock.ExpectCommit()

	mock.ExpectExec("DELETE FROM import_sessions WHERE id").
		WithArgs(sessionID).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))

	resp, err := svc.ConfirmImport(authedCtx(), &pb.ConfirmImportRequest{
		SessionId:        sessionID.String(),
		UserId:           testUserID,
		DefaultAccountId: accountID.String(),
		Mappings: []*pb.FieldMapping{
			{CsvColumn: "amount", TargetField: "amount"},
			{CsvColumn: "category", TargetField: "category"},
		},
	})
	require.NoError(t, err)
	assert.Equal(t, int32(1), resp.ImportedCount)
}

func TestBoost_ConfirmImport_NoCategoryFound(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	sessionID := uuid.New()
	accountID := uuid.New()
	csvData := []byte("amount,category\n100,不存在\n")
	expiresAt := time.Now().Add(30 * time.Minute)

	mock.ExpectQuery("SELECT .+ FROM import_sessions WHERE id").
		WithArgs(sessionID).
		WillReturnRows(pgxmock.NewRows([]string{"csv_data", "headers", "expires_at"}).
			AddRow(csvData, []string{"amount", "category"}, expiresAt))

	mock.ExpectBegin()

	// All category lookups fail
	mock.ExpectQuery("SELECT id FROM categories WHERE name = \\$1").
		WithArgs("不存在").
		WillReturnError(pgx.ErrNoRows)
	mock.ExpectQuery("SELECT id FROM categories WHERE name ILIKE").
		WithArgs("%不存在%").
		WillReturnError(pgx.ErrNoRows)
	mock.ExpectQuery("SELECT id FROM categories WHERE type = \\$1").
		WithArgs("expense").
		WillReturnError(pgx.ErrNoRows)

	// Row is skipped, commit empty transaction
	mock.ExpectCommit()

	mock.ExpectExec("DELETE FROM import_sessions WHERE id").
		WithArgs(sessionID).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))

	resp, err := svc.ConfirmImport(authedCtx(), &pb.ConfirmImportRequest{
		SessionId:        sessionID.String(),
		UserId:           testUserID,
		DefaultAccountId: accountID.String(),
		Mappings: []*pb.FieldMapping{
			{CsvColumn: "amount", TargetField: "amount"},
			{CsvColumn: "category", TargetField: "category"},
		},
	})
	require.NoError(t, err)
	assert.Equal(t, int32(0), resp.ImportedCount)
	assert.Equal(t, int32(1), resp.SkippedCount)
	assert.NotEmpty(t, resp.Errors)
}

func TestBoost_ConfirmImport_InvalidSessionID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.ConfirmImport(authedCtx(), &pb.ConfirmImportRequest{
		SessionId: "not-a-uuid",
		UserId:    testUserID,
		Mappings:  []*pb.FieldMapping{{CsvColumn: "a", TargetField: "b"}},
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoost_ConfirmImport_InvalidUserID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.ConfirmImport(authedCtx(), &pb.ConfirmImportRequest{
		SessionId: uuid.New().String(),
		UserId:    "not-a-uuid",
		Mappings:  []*pb.FieldMapping{{CsvColumn: "a", TargetField: "b"}},
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoost_ConfirmImport_InvalidDefaultAccountID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	sessionID := uuid.New()
	csvData := []byte("amount\n100\n")
	expiresAt := time.Now().Add(30 * time.Minute)

	mock.ExpectQuery("SELECT .+ FROM import_sessions WHERE id").
		WithArgs(sessionID).
		WillReturnRows(pgxmock.NewRows([]string{"csv_data", "headers", "expires_at"}).
			AddRow(csvData, []string{"amount"}, expiresAt))

	_, err = svc.ConfirmImport(authedCtx(), &pb.ConfirmImportRequest{
		SessionId:        sessionID.String(),
		UserId:           testUserID,
		DefaultAccountId: "not-a-uuid",
		Mappings:         []*pb.FieldMapping{{CsvColumn: "amount", TargetField: "amount"}},
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoost_ConfirmImport_NoDefaultAccount(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	sessionID := uuid.New()
	userID := uuid.MustParse(testUserID)
	csvData := []byte("amount\n100\n")
	expiresAt := time.Now().Add(30 * time.Minute)

	mock.ExpectQuery("SELECT .+ FROM import_sessions WHERE id").
		WithArgs(sessionID).
		WillReturnRows(pgxmock.NewRows([]string{"csv_data", "headers", "expires_at"}).
			AddRow(csvData, []string{"amount"}, expiresAt))

	// No default account found
	mock.ExpectQuery("SELECT id FROM accounts WHERE user_id").
		WithArgs(userID).
		WillReturnError(pgx.ErrNoRows)

	_, err = svc.ConfirmImport(authedCtx(), &pb.ConfirmImportRequest{
		SessionId: sessionID.String(),
		UserId:    testUserID,
		Mappings:  []*pb.FieldMapping{{CsvColumn: "amount", TargetField: "amount"}},
	})
	assert.Equal(t, codes.FailedPrecondition, status.Code(err))
}

func TestBoost_ConfirmImport_InvalidCsvColumn(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	sessionID := uuid.New()
	accountID := uuid.New()
	csvData := []byte("amount\n100\n")
	expiresAt := time.Now().Add(30 * time.Minute)

	mock.ExpectQuery("SELECT .+ FROM import_sessions WHERE id").
		WithArgs(sessionID).
		WillReturnRows(pgxmock.NewRows([]string{"csv_data", "headers", "expires_at"}).
			AddRow(csvData, []string{"amount"}, expiresAt))

	_, err = svc.ConfirmImport(authedCtx(), &pb.ConfirmImportRequest{
		SessionId:        sessionID.String(),
		UserId:           testUserID,
		DefaultAccountId: accountID.String(),
		Mappings:         []*pb.FieldMapping{{CsvColumn: "nonexistent", TargetField: "amount"}},
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoost_ConfirmImport_MultipleRows(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	sessionID := uuid.New()
	userID := uuid.MustParse(testUserID)
	accountID := uuid.New()
	categoryID := uuid.New()
	csvData := []byte("amount\n100\n200\n300\n")
	expiresAt := time.Now().Add(30 * time.Minute)

	mock.ExpectQuery("SELECT .+ FROM import_sessions WHERE id").
		WithArgs(sessionID).
		WillReturnRows(pgxmock.NewRows([]string{"csv_data", "headers", "expires_at"}).
			AddRow(csvData, []string{"amount"}, expiresAt))

	mock.ExpectBegin()

	for _, amt := range []int64{10000, 20000, 30000} {
		mock.ExpectQuery("SELECT id FROM categories WHERE type = \\$1").
			WithArgs("expense").
			WillReturnRows(pgxmock.NewRows([]string{"id"}).AddRow(categoryID))
		mock.ExpectExec("INSERT INTO transactions").
			WithArgs(userID, accountID, categoryID, amt, "expense", "", pgxmock.AnyArg()).
			WillReturnResult(pgxmock.NewResult("INSERT", 1))
		mock.ExpectExec("UPDATE accounts SET balance").
			WithArgs(-amt, accountID).
			WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	}

	mock.ExpectCommit()

	mock.ExpectExec("DELETE FROM import_sessions WHERE id").
		WithArgs(sessionID).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))

	resp, err := svc.ConfirmImport(authedCtx(), &pb.ConfirmImportRequest{
		SessionId:        sessionID.String(),
		UserId:           testUserID,
		DefaultAccountId: accountID.String(),
		Mappings: []*pb.FieldMapping{
			{CsvColumn: "amount", TargetField: "amount"},
		},
	})
	require.NoError(t, err)
	assert.Equal(t, int32(3), resp.ImportedCount)
	assert.Equal(t, int32(0), resp.SkippedCount)
}

func TestBoost_ConfirmImport_InsertError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	sessionID := uuid.New()
	accountID := uuid.New()
	categoryID := uuid.New()
	csvData := []byte("amount\n100\n")
	expiresAt := time.Now().Add(30 * time.Minute)

	mock.ExpectQuery("SELECT .+ FROM import_sessions WHERE id").
		WithArgs(sessionID).
		WillReturnRows(pgxmock.NewRows([]string{"csv_data", "headers", "expires_at"}).
			AddRow(csvData, []string{"amount"}, expiresAt))

	mock.ExpectBegin()

	mock.ExpectQuery("SELECT id FROM categories WHERE type = \\$1").
		WithArgs("expense").
		WillReturnRows(pgxmock.NewRows([]string{"id"}).AddRow(categoryID))

	mock.ExpectExec("INSERT INTO transactions").
		WithArgs(pgxmock.AnyArg(), accountID, categoryID, int64(10000), "expense", "", pgxmock.AnyArg()).
		WillReturnError(fmt.Errorf("insert failed"))

	mock.ExpectCommit()

	mock.ExpectExec("DELETE FROM import_sessions WHERE id").
		WithArgs(sessionID).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))

	resp, err := svc.ConfirmImport(authedCtx(), &pb.ConfirmImportRequest{
		SessionId:        sessionID.String(),
		UserId:           testUserID,
		DefaultAccountId: accountID.String(),
		Mappings:         []*pb.FieldMapping{{CsvColumn: "amount", TargetField: "amount"}},
	})
	require.NoError(t, err)
	assert.Equal(t, int32(0), resp.ImportedCount)
	assert.Equal(t, int32(1), resp.SkippedCount)
}

func TestBoost_ConfirmImport_BeginTxError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	sessionID := uuid.New()
	accountID := uuid.New()
	csvData := []byte("amount\n100\n")
	expiresAt := time.Now().Add(30 * time.Minute)

	mock.ExpectQuery("SELECT .+ FROM import_sessions WHERE id").
		WithArgs(sessionID).
		WillReturnRows(pgxmock.NewRows([]string{"csv_data", "headers", "expires_at"}).
			AddRow(csvData, []string{"amount"}, expiresAt))

	mock.ExpectBegin().WillReturnError(fmt.Errorf("begin error"))

	_, err = svc.ConfirmImport(authedCtx(), &pb.ConfirmImportRequest{
		SessionId:        sessionID.String(),
		UserId:           testUserID,
		DefaultAccountId: accountID.String(),
		Mappings:         []*pb.FieldMapping{{CsvColumn: "amount", TargetField: "amount"}},
	})
	assert.Equal(t, codes.Internal, status.Code(err))
}
