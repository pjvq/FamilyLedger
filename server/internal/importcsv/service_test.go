package importcsv

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"github.com/familyledger/server/pkg/middleware"
	pb "github.com/familyledger/server/proto/importpb"
)

const testUserID = "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"

func authedCtx() context.Context {
	return context.WithValue(context.Background(), middleware.UserIDKey, testUserID)
}

// ─── ParseCSV ───────────────────────────────────────────────────────────────

func TestParseCSV_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	csvData := []byte("日期,金额,类型,分类,备注\n2026-01-01,100.50,expense,餐饮,午餐\n2026-01-02,50,income,工资,\n")

	mock.ExpectExec("INSERT INTO import_sessions").
		WithArgs(pgxmock.AnyArg(), testUserID, csvData, pgxmock.AnyArg(), int32(2), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	resp, err := svc.ParseCSV(authedCtx(), &pb.ParseCSVRequest{CsvData: csvData})
	require.NoError(t, err)
	assert.Equal(t, int32(2), resp.TotalRows)
	assert.Len(t, resp.Headers, 5)
	assert.Len(t, resp.PreviewRows, 2)
	assert.NotEmpty(t, resp.SessionId)
}

func TestParseCSV_EmptyData(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.ParseCSV(authedCtx(), &pb.ParseCSVRequest{CsvData: nil})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestParseCSV_GBKEncoding(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	// Simple ASCII CSV, encoding=gbk should still work
	csvData := []byte("date,amount\n2026-01-01,100\n")
	mock.ExpectExec("INSERT INTO import_sessions").
		WithArgs(pgxmock.AnyArg(), testUserID, csvData, pgxmock.AnyArg(), int32(1), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	resp, err := svc.ParseCSV(authedCtx(), &pb.ParseCSVRequest{CsvData: csvData, Encoding: "gbk"})
	require.NoError(t, err)
	assert.Equal(t, int32(1), resp.TotalRows)
}

// ─── ConfirmImport ──────────────────────────────────────────────────────────

func TestConfirmImport_EmptySessionID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.ConfirmImport(authedCtx(), &pb.ConfirmImportRequest{SessionId: ""})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestConfirmImport_EmptyUserID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.ConfirmImport(authedCtx(), &pb.ConfirmImportRequest{
		SessionId: uuid.New().String(),
		UserId:    "",
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestConfirmImport_NoMappings(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.ConfirmImport(authedCtx(), &pb.ConfirmImportRequest{
		SessionId: uuid.New().String(),
		UserId:    testUserID,
		Mappings:  nil,
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestConfirmImport_SessionNotFound(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	sessionID := uuid.New()
	mock.ExpectQuery("SELECT .+ FROM import_sessions").
		WithArgs(sessionID).
		WillReturnError(fmt.Errorf("no rows in result set"))

	_, err = svc.ConfirmImport(authedCtx(), &pb.ConfirmImportRequest{
		SessionId: sessionID.String(),
		UserId:    testUserID,
		Mappings:  []*pb.FieldMapping{{CsvColumn: "date", TargetField: "date"}},
	})
	assert.Equal(t, codes.NotFound, status.Code(err))
}

func TestConfirmImport_SessionExpired(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	sessionID := uuid.New()
	expiredTime := time.Now().Add(-1 * time.Hour) // expired 1 hour ago

	mock.ExpectQuery("SELECT .+ FROM import_sessions").
		WithArgs(sessionID).
		WillReturnRows(pgxmock.NewRows([]string{"csv_data", "headers", "expires_at"}).
			AddRow([]byte("date,amount\n2026-01-01,100\n"), []string{"date", "amount"}, expiredTime))

	_, err = svc.ConfirmImport(authedCtx(), &pb.ConfirmImportRequest{
		SessionId: sessionID.String(),
		UserId:    testUserID,
		Mappings:  []*pb.FieldMapping{{CsvColumn: "date", TargetField: "date"}},
	})
	assert.Equal(t, codes.FailedPrecondition, status.Code(err))
}

// ─── CleanupExpiredSessions ─────────────────────────────────────────────────

func TestCleanupExpiredSessions_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectExec("DELETE FROM import_sessions WHERE expires_at").
		WillReturnResult(pgxmock.NewResult("DELETE", 3))

	err = svc.CleanupExpiredSessions(context.Background())
	assert.NoError(t, err)
}

// ─── Pure logic: decodeCSVData ──────────────────────────────────────────────

func TestDecodeCSVData_UTF8(t *testing.T) {
	data := []byte("hello,world")
	out, err := decodeCSVData(data, "utf8")
	require.NoError(t, err)
	assert.Equal(t, data, out)
}

func TestDecodeCSVData_UTF8BOM(t *testing.T) {
	data := []byte{0xEF, 0xBB, 0xBF, 'h', 'e', 'l', 'l', 'o'}
	out, err := decodeCSVData(data, "utf-8")
	require.NoError(t, err)
	assert.Equal(t, []byte("hello"), out)
}

func TestDecodeCSVData_Unknown(t *testing.T) {
	data := []byte("test")
	out, err := decodeCSVData(data, "latin1")
	require.NoError(t, err)
	assert.Equal(t, data, out)
}

// ─── Pure logic: extractFields ──────────────────────────────────────────────

func TestExtractFields_Full(t *testing.T) {
	record := []string{"2026-01-15", "99.50", "expense", "餐饮", "午餐"}
	fieldMap := map[string]int{"date": 0, "amount": 1, "type": 2, "category": 3, "note": 4}

	txnDate, amount, txnType, cat, note, err := extractFields(record, fieldMap)
	require.NoError(t, err)
	assert.Equal(t, int64(9950), amount)
	assert.Equal(t, "expense", txnType)
	assert.Equal(t, "餐饮", cat)
	assert.Equal(t, "午餐", note)
	assert.Equal(t, 2026, txnDate.Year())
}

func TestExtractFields_Income(t *testing.T) {
	record := []string{"2026-01-15", "5000", "收入"}
	fieldMap := map[string]int{"date": 0, "amount": 1, "type": 2}

	_, _, txnType, _, _, err := extractFields(record, fieldMap)
	require.NoError(t, err)
	assert.Equal(t, "income", txnType)
}

func TestExtractFields_NegativeAmount(t *testing.T) {
	record := []string{"2026-01-15", "-100"}
	fieldMap := map[string]int{"date": 0, "amount": 1}

	_, amount, _, _, _, err := extractFields(record, fieldMap)
	require.NoError(t, err)
	assert.Equal(t, int64(10000), amount) // abs value
}

func TestExtractFields_AmountWithSymbols(t *testing.T) {
	record := []string{"2026-01-15", "¥1,234.56"}
	fieldMap := map[string]int{"date": 0, "amount": 1}

	_, amount, _, _, _, err := extractFields(record, fieldMap)
	require.NoError(t, err)
	assert.Equal(t, int64(123456), amount)
}

func TestExtractFields_NoAmountMapping(t *testing.T) {
	record := []string{"2026-01-15"}
	fieldMap := map[string]int{"date": 0}

	_, _, _, _, _, err := extractFields(record, fieldMap)
	assert.Error(t, err)
}

// ─── Pure logic: parseDate ──────────────────────────────────────────────────

func TestParseDate_Formats(t *testing.T) {
	tests := []struct {
		input string
		year  int
		month time.Month
		day   int
	}{
		{"2026-01-15", 2026, 1, 15},
		{"2026/01/15", 2026, 1, 15},
		{"2026.01.15", 2026, 1, 15},
		{"20260115", 2026, 1, 15},
	}
	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			d, err := parseDate(tt.input)
			require.NoError(t, err)
			assert.Equal(t, tt.year, d.Year())
			assert.Equal(t, tt.month, d.Month())
			assert.Equal(t, tt.day, d.Day())
		})
	}
}

func TestParseDate_Invalid(t *testing.T) {
	_, err := parseDate("not-a-date")
	assert.Error(t, err)
}
