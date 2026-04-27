package benchmark

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/google/uuid"
	pgxmock "github.com/pashagolub/pgxmock/v4"

	"github.com/familyledger/server/internal/dashboard"
	"github.com/familyledger/server/internal/transaction"
	"github.com/familyledger/server/pkg/middleware"
	dashpb "github.com/familyledger/server/proto/dashboard"
	txnpb "github.com/familyledger/server/proto/transaction"
)

const testUserID = "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"

func authedCtx() context.Context {
	return context.WithValue(context.Background(), middleware.UserIDKey, testUserID)
}

// setupListMock prepares pgxmock expectations for ListTransactions (personal mode, first page).
func setupListMock(mock pgxmock.PgxPoolIface, totalCount int, pageSize int) {
	userUUID := uuid.MustParse(testUserID)
	accountID := uuid.New()
	categoryID := uuid.New()
	now := time.Now()

	// COUNT query — personal mode
	mock.ExpectQuery(`SELECT COUNT\(\*\) FROM transactions t`).
		WithArgs(userUUID, pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"count"}).AddRow(int32(totalCount)))

	// SELECT query — returns up to pageSize+1 rows
	cols := []string{"id", "user_id", "account_id", "category_id", "amount", "currency",
		"amount_cny", "exchange_rate", "type", "note", "txn_date", "created_at", "updated_at", "tags", "image_urls"}
	rows := pgxmock.NewRows(cols)
	returnRows := pageSize + 1
	if returnRows > totalCount {
		returnRows = totalCount
	}
	for j := 0; j < returnRows; j++ {
		rows.AddRow(
			uuid.New(), userUUID, accountID, categoryID,
			int64(1000+j), "CNY", int64(1000+j), float64(1.0),
			"expense", fmt.Sprintf("note-%d", j),
			now.Add(-time.Duration(j)*time.Hour), now, now,
			[]string{"tag1"}, []string{},
		)
	}
	mock.ExpectQuery(`SELECT t\.id, t\.user_id, t\.account_id`).
		WithArgs(userUUID, pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(rows)
}

func BenchmarkListTransactions_100(b *testing.B) {
	ctx := authedCtx()
	req := &txnpb.ListTransactionsRequest{PageSize: 20}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		b.StopTimer()
		mock, err := pgxmock.NewPool()
		if err != nil {
			b.Fatalf("failed to create mock: %v", err)
		}
		svc := transaction.NewService(mock)
		setupListMock(mock, 100, 20)

		b.StartTimer()
		_, err = svc.ListTransactions(ctx, req)
		if err != nil {
			b.Fatalf("ListTransactions failed: %v", err)
		}
		b.StopTimer()
		mock.Close()
	}
}

func BenchmarkListTransactions_1000(b *testing.B) {
	ctx := authedCtx()
	req := &txnpb.ListTransactionsRequest{PageSize: 20}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		b.StopTimer()
		mock, err := pgxmock.NewPool()
		if err != nil {
			b.Fatalf("failed to create mock: %v", err)
		}
		svc := transaction.NewService(mock)
		setupListMock(mock, 1000, 20)

		b.StartTimer()
		_, err = svc.ListTransactions(ctx, req)
		if err != nil {
			b.Fatalf("ListTransactions failed: %v", err)
		}
		b.StopTimer()
		mock.Close()
	}
}

func BenchmarkDashboard_Aggregation(b *testing.B) {
	ctx := authedCtx()
	req := &dashpb.GetNetWorthRequest{}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		b.StopTimer()
		mock, err := pgxmock.NewPool()
		if err != nil {
			b.Fatalf("failed to create mock: %v", err)
		}
		svc := dashboard.NewService(mock)

		// GetNetWorth queries: cash_and_bank, investment, fixed_asset, loan
		// Personal mode: uses testUserID (string) as arg
		mock.ExpectQuery(`SELECT COALESCE\(SUM\(balance\), 0\)`).
			WithArgs(testUserID).
			WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(500000)))
		mock.ExpectQuery(`SELECT COALESCE\(SUM`).
			WithArgs(testUserID).
			WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(200000)))
		mock.ExpectQuery(`SELECT COALESCE\(SUM\(current_value\)`).
			WithArgs(testUserID).
			WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(1000000)))
		mock.ExpectQuery(`SELECT COALESCE\(SUM\(remaining_principal\)`).
			WithArgs(testUserID).
			WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(300000)))

		// estimateLastMonthNetWorth queries
		mock.ExpectQuery(`SELECT COALESCE\(SUM\(balance\), 0\)`).
			WithArgs(testUserID).
			WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(480000)))
		mock.ExpectQuery(`SELECT COALESCE\(SUM\(CASE`).
			WithArgs(testUserID, pgxmock.AnyArg(), pgxmock.AnyArg()).
			WillReturnRows(pgxmock.NewRows([]string{"income", "expense"}).AddRow(int64(30000), int64(10000)))
		mock.ExpectQuery(`SELECT COALESCE\(SUM`).
			WithArgs(testUserID).
			WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(190000)))
		mock.ExpectQuery(`SELECT COALESCE\(SUM\(latest_val`).
			WithArgs(testUserID).
			WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(950000)))
		mock.ExpectQuery(`SELECT COALESCE\(SUM\(remaining_principal\)`).
			WithArgs(testUserID).
			WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(310000)))

		b.StartTimer()
		_, err = svc.GetNetWorth(ctx, req)
		if err != nil {
			b.Fatalf("GetNetWorth failed: %v", err)
		}
		b.StopTimer()
		mock.Close()
	}
}
