package export

import (
	"context"
	"encoding/json"
	"fmt"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"github.com/familyledger/server/pkg/middleware"
	pb "github.com/familyledger/server/proto/export"
)

const boostTestUserID = "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"
const boostTestFamilyID = "f1234567-9c0b-4ef8-bb6d-6bb9bd380a22"

func boostAuthedCtx() context.Context {
	return context.WithValue(context.Background(), middleware.UserIDKey, boostTestUserID)
}

// ══════════════════════════════════════════════════════════════════════════════
// queryTableRows tests
// ══════════════════════════════════════════════════════════════════════════════

func TestQueryTableRows_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	cols := []string{"id", "name", "amount"}
	mockRows := pgxmock.NewRows(cols).
		AddRow("row-1", "Account A", int64(1000)).
		AddRow("row-2", "Account B", int64(2000))

	mock.ExpectQuery("SELECT .+ FROM accounts").
		WithArgs(boostTestUserID).
		WillReturnRows(mockRows)

	ctx := boostAuthedCtx()
	result, err := svc.queryTableRows(ctx, "SELECT id, name, amount FROM accounts WHERE user_id = $1", boostTestUserID)
	require.NoError(t, err)
	assert.Len(t, result, 2)
	assert.Equal(t, "row-1", result[0]["id"])
	assert.Equal(t, "Account A", result[0]["name"])
	assert.Equal(t, int64(1000), result[0]["amount"])
	assert.Equal(t, "row-2", result[1]["id"])
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestQueryTableRows_Empty(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	cols := []string{"id", "name"}
	mockRows := pgxmock.NewRows(cols) // no rows

	mock.ExpectQuery("SELECT .+ FROM accounts").
		WithArgs(boostTestUserID).
		WillReturnRows(mockRows)

	ctx := boostAuthedCtx()
	result, err := svc.queryTableRows(ctx, "SELECT id, name FROM accounts WHERE user_id = $1", boostTestUserID)
	require.NoError(t, err)
	assert.Len(t, result, 0)
	assert.NotNil(t, result) // should return empty slice, not nil
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestQueryTableRows_QueryError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectQuery("SELECT .+ FROM accounts").
		WithArgs(boostTestUserID).
		WillReturnError(fmt.Errorf("connection refused"))

	ctx := boostAuthedCtx()
	result, err := svc.queryTableRows(ctx, "SELECT id, name FROM accounts WHERE user_id = $1", boostTestUserID)
	assert.Error(t, err)
	assert.Nil(t, result)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestQueryTableRows_ValuesError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	cols := []string{"id", "name"}
	mockRows := pgxmock.NewRows(cols).
		AddRow("row-1", "ok").
		AddRow("row-2", "fail").
		RowError(1, fmt.Errorf("values error on second row"))

	mock.ExpectQuery("SELECT .+ FROM accounts").
		WithArgs(boostTestUserID).
		WillReturnRows(mockRows)

	ctx := boostAuthedCtx()
	result, err := svc.queryTableRows(ctx, "SELECT id, name FROM accounts WHERE user_id = $1", boostTestUserID)
	// Second row triggers error via Values()
	assert.Error(t, err)
	assert.Nil(t, result)
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ══════════════════════════════════════════════════════════════════════════════
// FullBackup tests
// ══════════════════════════════════════════════════════════════════════════════

func TestFullBackup_PersonalMode_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	// Accounts query
	mock.ExpectQuery("SELECT .+ FROM accounts WHERE user_id").
		WithArgs(boostTestUserID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "name", "type", "balance", "currency", "is_active", "created_at", "updated_at"}).
			AddRow("acc-1", boostTestUserID, nil, "Cash", "cash", int64(10000), "CNY", true, time.Now(), time.Now()))

	// Transactions query (personal)
	mock.ExpectQuery("SELECT .+ FROM transactions WHERE user_id").
		WithArgs(boostTestUserID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "account_id", "type", "amount_cny", "currency", "amount", "category_id", "note", "txn_date", "created_at"}).
			AddRow("txn-1", boostTestUserID, "acc-1", "expense", int64(3500), "CNY", int64(3500), "cat-1", "lunch", time.Now(), time.Now()))

	// Budgets query
	mock.ExpectQuery("SELECT .+ FROM budgets WHERE user_id").
		WithArgs(boostTestUserID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "year", "month", "total_amount", "created_at", "updated_at"}))

	// Loans query
	mock.ExpectQuery("SELECT .+ FROM loans WHERE user_id").
		WithArgs(boostTestUserID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "name", "principal", "annual_rate", "total_months", "start_date", "repayment_method", "remaining_principal", "created_at", "updated_at"}))

	// Investments query
	mock.ExpectQuery("SELECT .+ FROM investments WHERE user_id").
		WithArgs(boostTestUserID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "symbol", "name", "market_type", "quantity", "cost_basis", "created_at", "updated_at"}))

	// Fixed Assets query
	mock.ExpectQuery("SELECT .+ FROM fixed_assets WHERE user_id").
		WithArgs(boostTestUserID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "name", "purchase_price", "current_value", "purchase_date", "created_at", "updated_at"}))

	// Categories query
	mock.ExpectQuery("SELECT .+ FROM categories").
		WithArgs(boostTestUserID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "name", "type", "icon", "icon_key", "parent_id"}).
			AddRow("cat-1", "餐饮", "expense", "🍔", "food", nil))

	// Custom Reminders query
	mock.ExpectQuery("SELECT .+ FROM custom_reminders WHERE user_id").
		WithArgs(boostTestUserID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "title", "description", "remind_at", "repeat_rule", "repeat_end_at", "is_active", "created_at", "updated_at"}))

	resp, err := svc.FullBackup(boostAuthedCtx(), &pb.FullBackupRequest{})
	require.NoError(t, err)
	assert.Equal(t, "json", resp.Format)
	assert.True(t, len(resp.Data) > 0)

	// Verify JSON structure
	var backup BackupData
	err = json.Unmarshal(resp.Data, &backup)
	require.NoError(t, err)
	assert.Equal(t, boostTestUserID, backup.UserID)
	assert.Empty(t, backup.FamilyID)
	assert.Len(t, backup.Accounts, 1)
	assert.Len(t, backup.Transactions, 1)
	assert.Len(t, backup.Categories, 1)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFullBackup_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.FullBackup(context.Background(), &pb.FullBackupRequest{})
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestFullBackup_FamilyMode_PermissionDenied(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	// Permission check fails: not a member
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnError(pgx.ErrNoRows)

	_, err = svc.FullBackup(boostAuthedCtx(), &pb.FullBackupRequest{FamilyId: boostTestFamilyID})
	require.Error(t, err)
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFullBackup_FamilyMode_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	// Permission check passes
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).AddRow("owner", []byte(`{}`)))

	// Accounts query (family)
	mock.ExpectQuery("SELECT .+ FROM accounts WHERE family_id").
		WithArgs(boostTestFamilyID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "name", "type", "balance", "currency", "is_active", "created_at", "updated_at"}).
			AddRow("acc-f1", boostTestUserID, boostTestFamilyID, "Family Cash", "cash", int64(50000), "CNY", true, time.Now(), time.Now()))

	// Transactions query (family - join accounts)
	mock.ExpectQuery("SELECT .+ FROM transactions t").
		WithArgs(boostTestFamilyID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "account_id", "type", "amount_cny", "currency", "amount", "category_id", "note", "txn_date", "created_at"}).
			AddRow("txn-f1", boostTestUserID, "acc-f1", "expense", int64(5000), "CNY", int64(5000), "cat-1", "family lunch", time.Now(), time.Now()))

	// Budgets query (family)
	mock.ExpectQuery("SELECT .+ FROM budgets WHERE family_id").
		WithArgs(boostTestFamilyID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "year", "month", "total_amount", "created_at", "updated_at"}))

	// Loans query (family)
	mock.ExpectQuery("SELECT .+ FROM loans WHERE family_id").
		WithArgs(boostTestFamilyID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "name", "principal", "annual_rate", "total_months", "start_date", "repayment_method", "remaining_principal", "created_at", "updated_at"}))

	// Investments query (family)
	mock.ExpectQuery("SELECT .+ FROM investments WHERE family_id").
		WithArgs(boostTestFamilyID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "symbol", "name", "market_type", "quantity", "cost_basis", "created_at", "updated_at"}))

	// Fixed Assets query (family)
	mock.ExpectQuery("SELECT .+ FROM fixed_assets WHERE family_id").
		WithArgs(boostTestFamilyID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "name", "purchase_price", "current_value", "purchase_date", "created_at", "updated_at"}))

	// Categories query (always by user_id)
	mock.ExpectQuery("SELECT .+ FROM categories").
		WithArgs(boostTestUserID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "name", "type", "icon", "icon_key", "parent_id"}))

	// Custom Reminders query (family)
	mock.ExpectQuery("SELECT .+ FROM custom_reminders WHERE family_id").
		WithArgs(boostTestFamilyID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "title", "description", "remind_at", "repeat_rule", "repeat_end_at", "is_active", "created_at", "updated_at"}))

	resp, err := svc.FullBackup(boostAuthedCtx(), &pb.FullBackupRequest{FamilyId: boostTestFamilyID})
	require.NoError(t, err)
	assert.Equal(t, "json", resp.Format)

	var backup BackupData
	err = json.Unmarshal(resp.Data, &backup)
	require.NoError(t, err)
	assert.Equal(t, boostTestFamilyID, backup.FamilyID)
	assert.Len(t, backup.Accounts, 1)
	assert.Len(t, backup.Transactions, 1)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFullBackup_AccountsQueryError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	// Accounts query fails
	mock.ExpectQuery("SELECT .+ FROM accounts WHERE user_id").
		WithArgs(boostTestUserID).
		WillReturnError(fmt.Errorf("db connection error"))

	_, err = svc.FullBackup(boostAuthedCtx(), &pb.FullBackupRequest{})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFullBackup_TransactionsQueryError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	// Accounts ok
	mock.ExpectQuery("SELECT .+ FROM accounts WHERE user_id").
		WithArgs(boostTestUserID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "name", "type", "balance", "currency", "is_active", "created_at", "updated_at"}))

	// Transactions fail
	mock.ExpectQuery("SELECT .+ FROM transactions WHERE user_id").
		WithArgs(boostTestUserID).
		WillReturnError(fmt.Errorf("query timeout"))

	_, err = svc.FullBackup(boostAuthedCtx(), &pb.FullBackupRequest{})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFullBackup_CustomRemindersError_NonFatal(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	// All succeed except custom_reminders
	mock.ExpectQuery("SELECT .+ FROM accounts WHERE user_id").
		WithArgs(boostTestUserID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "name", "type", "balance", "currency", "is_active", "created_at", "updated_at"}))

	mock.ExpectQuery("SELECT .+ FROM transactions WHERE user_id").
		WithArgs(boostTestUserID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "account_id", "type", "amount_cny", "currency", "amount", "category_id", "note", "txn_date", "created_at"}))

	mock.ExpectQuery("SELECT .+ FROM budgets WHERE user_id").
		WithArgs(boostTestUserID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "year", "month", "total_amount", "created_at", "updated_at"}))

	mock.ExpectQuery("SELECT .+ FROM loans WHERE user_id").
		WithArgs(boostTestUserID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "name", "principal", "annual_rate", "total_months", "start_date", "repayment_method", "remaining_principal", "created_at", "updated_at"}))

	mock.ExpectQuery("SELECT .+ FROM investments WHERE user_id").
		WithArgs(boostTestUserID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "symbol", "name", "market_type", "quantity", "cost_basis", "created_at", "updated_at"}))

	mock.ExpectQuery("SELECT .+ FROM fixed_assets WHERE user_id").
		WithArgs(boostTestUserID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "name", "purchase_price", "current_value", "purchase_date", "created_at", "updated_at"}))

	mock.ExpectQuery("SELECT .+ FROM categories").
		WithArgs(boostTestUserID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "name", "type", "icon", "icon_key", "parent_id"}))

	// Custom reminders error - should be non-fatal
	mock.ExpectQuery("SELECT .+ FROM custom_reminders WHERE user_id").
		WithArgs(boostTestUserID).
		WillReturnError(fmt.Errorf("table does not exist"))

	resp, err := svc.FullBackup(boostAuthedCtx(), &pb.FullBackupRequest{})
	require.NoError(t, err) // non-fatal error
	assert.Equal(t, "json", resp.Format)

	var backup BackupData
	err = json.Unmarshal(resp.Data, &backup)
	require.NoError(t, err)
	assert.NotNil(t, backup.Reminders) // should be empty slice, not nil
	assert.Len(t, backup.Reminders, 0)
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ══════════════════════════════════════════════════════════════════════════════
// queryTransactions additional coverage
// ══════════════════════════════════════════════════════════════════════════════

func TestQueryTransactions_WithDateFilters(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	cols := []string{"txn_date", "type", "category_name", "amount_cny", "account_name", "note"}
	d, _ := time.Parse("2006-01-02", "2026-03-15")
	mockRows := pgxmock.NewRows(cols).
		AddRow(d, "expense", "餐饮", int64(5000), "现金", "dinner")

	mock.ExpectQuery("SELECT .+ FROM transactions").
		WithArgs(boostTestUserID, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(mockRows)

	resp, err := svc.ExportTransactions(boostAuthedCtx(), &pb.ExportRequest{
		Format:    "csv",
		StartDate: "2026-03-01",
		EndDate:   "2026-03-31",
	})
	require.NoError(t, err)
	assert.Contains(t, string(resp.Data), "2026-03-15")
	assert.Contains(t, string(resp.Data), "50.00")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestQueryTransactions_WithCategoryFilter(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	cols := []string{"txn_date", "type", "category_name", "amount_cny", "account_name", "note"}
	d, _ := time.Parse("2006-01-02", "2026-04-10")
	mockRows := pgxmock.NewRows(cols).
		AddRow(d, "income", "工资", int64(800000), "银行", "salary")

	mock.ExpectQuery("SELECT .+ FROM transactions").
		WithArgs(boostTestUserID, pgxmock.AnyArg()).
		WillReturnRows(mockRows)

	resp, err := svc.ExportTransactions(boostAuthedCtx(), &pb.ExportRequest{
		Format:      "csv",
		CategoryIds: []string{"cat-salary"},
	})
	require.NoError(t, err)
	assert.Contains(t, string(resp.Data), "8000.00")
	assert.Contains(t, string(resp.Data), "收入")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestQueryTransactions_DBError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectQuery("SELECT .+ FROM transactions").
		WithArgs(boostTestUserID).
		WillReturnError(fmt.Errorf("database error"))

	_, err = svc.ExportTransactions(boostAuthedCtx(), &pb.ExportRequest{Format: "csv"})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestQueryTransactions_ScanError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	cols := []string{"txn_date", "type", "category_name", "amount_cny", "account_name", "note"}
	mockRows := pgxmock.NewRows(cols).
		AddRow("invalid-date", "expense", "餐饮", int64(100), "现金", "test") // wrong type for txn_date

	mock.ExpectQuery("SELECT .+ FROM transactions").
		WithArgs(boostTestUserID).
		WillReturnRows(mockRows)

	_, err = svc.ExportTransactions(boostAuthedCtx(), &pb.ExportRequest{Format: "csv"})
	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ══════════════════════════════════════════════════════════════════════════════
// exportCSV additional coverage (CSV flush error path)
// ══════════════════════════════════════════════════════════════════════════════

func TestExportCSV_LargeDataset(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	cols := []string{"txn_date", "type", "category_name", "amount_cny", "account_name", "note"}
	mockRows := pgxmock.NewRows(cols)
	for i := 0; i < 100; i++ {
		d, _ := time.Parse("2006-01-02", "2026-01-15")
		mockRows.AddRow(d, "expense", fmt.Sprintf("cat-%d", i), int64(i*100+50), fmt.Sprintf("acc-%d", i), fmt.Sprintf("note-%d", i))
	}

	mock.ExpectQuery("SELECT .+ FROM transactions").
		WithArgs(boostTestUserID).
		WillReturnRows(mockRows)

	resp, err := svc.ExportTransactions(boostAuthedCtx(), &pb.ExportRequest{Format: "csv"})
	require.NoError(t, err)
	assert.Contains(t, string(resp.Data), "cat-0")
	assert.Contains(t, string(resp.Data), "cat-99")
	assert.Contains(t, resp.ContentType, "csv")
	assert.NoError(t, mock.ExpectationsWereMet())
}
