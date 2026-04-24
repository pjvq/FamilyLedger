package export

import (
	"context"
	"testing"
	"time"

	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"github.com/familyledger/server/pkg/middleware"
	pb "github.com/familyledger/server/proto/export"
)

const testUserID = "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"

func authedCtx() context.Context {
	return context.WithValue(context.Background(), middleware.UserIDKey, testUserID)
}

func expectTxnQuery(mock pgxmock.PgxPoolIface, rows ...transactionRow) {
	cols := []string{"txn_date", "type", "category_name", "amount_cny", "account_name", "note"}
	mockRows := pgxmock.NewRows(cols)
	for _, r := range rows {
		d, _ := time.Parse("2006-01-02", r.Date)
		txnType := "expense"
		if r.Type == "收入" {
			txnType = "income"
		}
		mockRows.AddRow(d, txnType, r.CategoryName, r.Amount, r.AccountName, r.Note)
	}
	mock.ExpectQuery("SELECT .+ FROM transactions").
		WithArgs(testUserID).
		WillReturnRows(mockRows)
}

var sampleRows = []transactionRow{
	{Date: "2026-01-15", Type: "支出", CategoryName: "餐饮", Amount: 3500, AccountName: "现金", Note: "午餐"},
	{Date: "2026-01-16", Type: "收入", CategoryName: "工资", Amount: 500000, AccountName: "工商银行", Note: "月薪"},
}

// ─── ExportTransactions CSV ─────────────────────────────────────────────────

func TestExportCSV_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	expectTxnQuery(mock, sampleRows...)

	resp, err := svc.ExportTransactions(authedCtx(), &pb.ExportRequest{Format: "csv"})
	require.NoError(t, err)
	assert.Contains(t, string(resp.Data), "日期")
	assert.Contains(t, string(resp.Data), "35.00")  // 3500 分 = 35.00 元
	assert.Contains(t, resp.Filename, ".csv")
	assert.Contains(t, resp.ContentType, "csv")
}

func TestExportCSV_Empty(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	expectTxnQuery(mock)

	resp, err := svc.ExportTransactions(authedCtx(), &pb.ExportRequest{Format: "csv"})
	require.NoError(t, err)
	assert.Contains(t, string(resp.Data), "日期") // header still present
}

func TestExportCSV_DefaultFormat(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	expectTxnQuery(mock, sampleRows...)

	resp, err := svc.ExportTransactions(authedCtx(), &pb.ExportRequest{}) // no format → csv
	require.NoError(t, err)
	assert.Contains(t, resp.ContentType, "csv")
}

// ─── ExportTransactions Excel ───────────────────────────────────────────────

func TestExportExcel_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	expectTxnQuery(mock, sampleRows...)

	resp, err := svc.ExportTransactions(authedCtx(), &pb.ExportRequest{Format: "excel"})
	require.NoError(t, err)
	assert.Contains(t, resp.Filename, ".xlsx")
	assert.True(t, len(resp.Data) > 0)
}

// ─── ExportTransactions PDF ─────────────────────────────────────────────────

func TestExportPDF_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	expectTxnQuery(mock, sampleRows...)

	resp, err := svc.ExportTransactions(authedCtx(), &pb.ExportRequest{Format: "pdf"})
	require.NoError(t, err)
	assert.Contains(t, resp.Filename, ".pdf")
	assert.Contains(t, resp.ContentType, "pdf")
	assert.True(t, len(resp.Data) > 0)
}

// ─── Validation ─────────────────────────────────────────────────────────────

func TestExport_InvalidFormat(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.ExportTransactions(authedCtx(), &pb.ExportRequest{Format: "xml"})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestExport_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.ExportTransactions(context.Background(), &pb.ExportRequest{})
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

// ─── Date filter validation ─────────────────────────────────────────────────

func TestExport_InvalidStartDate(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.ExportTransactions(authedCtx(), &pb.ExportRequest{StartDate: "not-a-date"})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestExport_InvalidEndDate(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.ExportTransactions(authedCtx(), &pb.ExportRequest{EndDate: "invalid"})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── Pure logic ─────────────────────────────────────────────────────────────

func TestAmountToYuan(t *testing.T) {
	assert.Equal(t, "0.00", amountToYuan(0))
	assert.Equal(t, "1.00", amountToYuan(100))
	assert.Equal(t, "99.99", amountToYuan(9999))
	assert.Equal(t, "12345.67", amountToYuan(1234567))
}

func TestTruncateStr(t *testing.T) {
	assert.Equal(t, "hello", truncateStr("hello", 10))
	assert.Equal(t, "hell…", truncateStr("hello world", 5))
	assert.Equal(t, "", truncateStr("", 5))
}

func TestCellName(t *testing.T) {
	assert.Equal(t, "A1", cellName(1, 1))
	assert.Equal(t, "B2", cellName(2, 2))
	assert.Equal(t, "F10", cellName(6, 10))
}
