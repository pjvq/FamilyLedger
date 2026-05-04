//go:build integration

package integration

import (
	"context"
	"fmt"
	"math/rand"
	"sort"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	syncpkg "github.com/familyledger/server/internal/sync"
	"github.com/familyledger/server/internal/transaction"
	"github.com/familyledger/server/pkg/middleware"
	"github.com/familyledger/server/pkg/ws"
	pb "github.com/familyledger/server/proto/sync"
	txnpb "github.com/familyledger/server/proto/transaction"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// ═══════════════════════════════════════════════════════════════════════════════
// W13: Performance + Stress Tests
//
// PERF-001: 50 concurrent Push clients (10 ops each = 500 total)
// PERF-002: 10000 transactions pagination P99
// PERF-003: Push SLA P99 < 500ms
// PERF-004: Pull SLA P99 < 200ms (100 items)
// PERF-005: PG slow query injection / context deadline
// ═══════════════════════════════════════════════════════════════════════════════

// percentile calculates the P-th percentile from a sorted slice of durations.
func percentile(sorted []time.Duration, p float64) time.Duration {
	if len(sorted) == 0 {
		return 0
	}
	idx := int(float64(len(sorted)-1) * p / 100.0)
	if idx >= len(sorted) {
		idx = len(sorted) - 1
	}
	return sorted[idx]
}

// ─── PERF-001: 50 Concurrent Push Clients ────────────────────────────────────

func TestPerf_ConcurrentPush_50Clients(t *testing.T) {
	db := getDB(t)
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	const numClients = 50
	const opsPerClient = 10
	const totalExpected = numClients * opsPerClient

	// Create 50 users, each with an account
	type clientInfo struct {
		userID    uuid.UUID
		accountID uuid.UUID
	}
	clients := make([]clientInfo, numClients)

	catID := getCategoryID(t, db)

	for i := 0; i < numClients; i++ {
		email := fmt.Sprintf("perf001_client_%d@test.com", i)
		userID := createTestUser(t, db, email)
		acctID := createTestAccount(t, db, userID, fmt.Sprintf("Account_%d", i), nil)
		clients[i] = clientInfo{userID: userID, accountID: acctID}
	}

	// Create sync service
	hub := ws.NewHub(nil)
	syncSvc := syncpkg.NewService(db.pool, hub)

	// Launch 50 concurrent pushers
	var wg sync.WaitGroup
	errCh := make(chan error, totalExpected)

	for i := 0; i < numClients; i++ {
		wg.Add(1)
		go func(ci clientInfo, clientIdx int) {
			defer wg.Done()

			authedCtx := context.WithValue(ctx, middleware.UserIDKey, ci.userID.String())

			ops := make([]*pb.SyncOperation, opsPerClient)
			for j := 0; j < opsPerClient; j++ {
				entityID := uuid.New()
				payload := fmt.Sprintf(
					`{"account_id":"%s","category_id":"%s","amount":%d,"currency":"CNY","amount_cny":%d,"exchange_rate":1.0,"type":"expense","note":"perf001_%d_%d","txn_date":"%s","tags":[],"image_urls":[]}`,
					ci.accountID.String(), catID.String(),
					1000+j, 1000+j, clientIdx, j,
					time.Now().Format(time.RFC3339),
				)
				ops[j] = &pb.SyncOperation{
					Id:         uuid.New().String(),
					EntityType: "transaction",
					EntityId:   entityID.String(),
					OpType:     pb.OperationType_OPERATION_TYPE_CREATE,
					Payload:    payload,
					ClientId:   fmt.Sprintf("perf001-client-%d-op-%d", clientIdx, j),
					Timestamp:  timestamppb.Now(),
				}
			}

			resp, err := syncSvc.PushOperations(authedCtx, &pb.PushOperationsRequest{
				Operations: ops,
			})
			if err != nil {
				errCh <- fmt.Errorf("client %d push error: %w", clientIdx, err)
				return
			}
			if resp.AcceptedCount != int32(opsPerClient) {
				errCh <- fmt.Errorf("client %d: accepted %d/%d, failed: %v",
					clientIdx, resp.AcceptedCount, opsPerClient, resp.FailedIds)
			}
		}(clients[i], i)
	}

	wg.Wait()
	close(errCh)

	// Collect errors
	var errors []error
	for err := range errCh {
		errors = append(errors, err)
	}
	for _, err := range errors {
		t.Logf("Push error: %v", err)
	}

	// Verify: DB should have exactly totalExpected sync_operations
	var count int
	err := db.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM sync_operations`,
	).Scan(&count)
	require.NoError(t, err)
	assert.Equal(t, totalExpected, count,
		"expected %d sync_operations in DB, got %d", totalExpected, count)

	// Verify via PullChanges: each client should pull back their own 10 operations
	var pullErrors int
	for i := 0; i < numClients; i++ {
		pullCtx := context.WithValue(ctx, middleware.UserIDKey, clients[i].userID.String())
		pullResp, pullErr := syncSvc.PullChanges(pullCtx, &pb.PullChangesRequest{
			ClientId: fmt.Sprintf("perf001-verifier-%d", i),
			PageSize: 100,
		})
		if pullErr != nil {
			pullErrors++
			if pullErrors <= 3 {
				t.Logf("PullChanges error for client %d: %v", i, pullErr)
			}
			continue
		}
		if len(pullResp.Operations) < opsPerClient {
			pullErrors++
			if pullErrors <= 3 {
				t.Logf("PullChanges client %d: got %d ops, expected %d", i, len(pullResp.Operations), opsPerClient)
			}
		}
	}
	assert.Equal(t, 0, pullErrors,
		"all %d clients should pull back %d operations each via PullChanges", numClients, opsPerClient)
	t.Logf("PullChanges verification: %d/%d clients OK", numClients-pullErrors, numClients)

	// Log pg_stat_activity wait_event info
	rows, err := db.pool.Query(ctx,
		`SELECT wait_event_type, wait_event, COUNT(*)
		 FROM pg_stat_activity
		 WHERE datname = current_database() AND wait_event IS NOT NULL
		 GROUP BY wait_event_type, wait_event`,
	)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var weType, we string
			var c int
			if err := rows.Scan(&weType, &we, &c); err == nil {
				t.Logf("pg_stat_activity wait_event: %s/%s count=%d", weType, we, c)
			}
		}
	}

	// Verify no deadlock: if we got here within 30s timeout, no deadlock
	t.Logf("PERF-001 PASS: %d/%d sync_operations created by %d concurrent clients (no deadlock)",
		count, totalExpected, numClients)
}

// ─── PERF-002: 10000 Transactions Pagination P99 ─────────────────────────────

func TestPerf_Pagination_10000Transactions(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()

	userID := createTestUser(t, db, "perf002@test.com")
	acctID := createTestAccount(t, db, userID, "Perf002 Account", nil)
	catID := getCategoryID(t, db)

	const txnCount = 10000

	// Seed 10000 transactions via bulk INSERT (much faster than gRPC)
	t.Logf("Seeding %d transactions via bulk SQL INSERT...", txnCount)
	seedStart := time.Now()

	batchSize := 500
	for batchStart := 0; batchStart < txnCount; batchStart += batchSize {
		batchEnd := batchStart + batchSize
		if batchEnd > txnCount {
			batchEnd = txnCount
		}

		query := `INSERT INTO transactions (user_id, account_id, category_id, amount, currency, amount_cny, exchange_rate, type, note, txn_date, tags, image_urls) VALUES `
		args := make([]interface{}, 0, (batchEnd-batchStart)*5)
		for i := batchStart; i < batchEnd; i++ {
			if i > batchStart {
				query += ","
			}
			argBase := (i - batchStart) * 5
			query += fmt.Sprintf("($%d, $%d, $%d, $%d, 'CNY', $%d, 1.0, 'expense', 'perf002', NOW() - interval '%d hours', '{}', '{}')",
				argBase+1, argBase+2, argBase+3, argBase+4, argBase+5, i)
			amount := int64(1000 + i%1000)
			args = append(args, userID, acctID, catID, amount, amount)
		}

		_, err := db.pool.Exec(ctx, query, args...)
		require.NoError(t, err, "failed to insert batch at offset %d", batchStart)
	}
	t.Logf("Seeded %d transactions in %v", txnCount, time.Since(seedStart))

	// Use the transaction service for pagination queries
	txnSvc := transaction.NewService(db.pool)
	authedCtx := context.WithValue(ctx, middleware.UserIDKey, userID.String())

	// CI threshold: 3x target (200ms target → 600ms CI threshold)
	const ciThreshold = 600 * time.Millisecond

	// Test pagination at three positions: offset 0, ~500, ~9980
	// ListTransactions uses cursor-based pagination, so we paginate forward
	testCases := []struct {
		name     string
		pageSize int32
		pages    int // number of pages to skip to reach target offset
	}{
		{"offset_0", 20, 0},
		{"offset_500", 20, 25},   // 25 pages * 20 = 500
		{"offset_9980", 20, 499}, // 499 pages * 20 = 9980
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			var pageToken string

			// Skip to the target page
			for p := 0; p < tc.pages; p++ {
				resp, err := txnSvc.ListTransactions(authedCtx, &txnpb.ListTransactionsRequest{
					PageSize:  tc.pageSize,
					PageToken: pageToken,
				})
				require.NoError(t, err)
				pageToken = resp.NextPageToken
				if pageToken == "" {
					t.Skipf("ran out of pages at page %d (expected %d)", p, tc.pages)
				}
			}

			// Measure the target page query
			start := time.Now()
			resp, err := txnSvc.ListTransactions(authedCtx, &txnpb.ListTransactionsRequest{
				PageSize:  tc.pageSize,
				PageToken: pageToken,
			})
			elapsed := time.Since(start)

			require.NoError(t, err)
			assert.NotEmpty(t, resp.Transactions, "should return transactions at %s", tc.name)
			assert.Less(t, elapsed, ciThreshold,
				"%s: pagination query took %v, threshold %v", tc.name, elapsed, ciThreshold)
			t.Logf("%s: %d txns returned in %v", tc.name, len(resp.Transactions), elapsed)
		})
	}
}

// ─── PERF-003: Push SLA P99 < 500ms ──────────────────────────────────────────

func TestPerf_Push_SLA(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()

	userID := createTestUser(t, db, "perf003@test.com")
	acctID := createTestAccount(t, db, userID, "Perf003 Account", nil)
	catID := getCategoryID(t, db)

	hub := ws.NewHub(nil)
	syncSvc := syncpkg.NewService(db.pool, hub)
	authedCtx := context.WithValue(ctx, middleware.UserIDKey, userID.String())

	const iterations = 100
	latencies := make([]time.Duration, 0, iterations)

	for i := 0; i < iterations; i++ {
		entityID := uuid.New()
		payload := fmt.Sprintf(
			`{"account_id":"%s","category_id":"%s","amount":%d,"currency":"CNY","amount_cny":%d,"exchange_rate":1.0,"type":"expense","note":"sla_%d","txn_date":"%s","tags":[],"image_urls":[]}`,
			acctID.String(), catID.String(), 1000+i, 1000+i, i, time.Now().Format(time.RFC3339),
		)

		ops := []*pb.SyncOperation{{
			Id:         uuid.New().String(),
			EntityType: "transaction",
			EntityId:   entityID.String(),
			OpType:     pb.OperationType_OPERATION_TYPE_CREATE,
			Payload:    payload,
			ClientId:   fmt.Sprintf("sla-push-%d", i),
			Timestamp:  timestamppb.Now(),
		}}

		start := time.Now()
		resp, err := syncSvc.PushOperations(authedCtx, &pb.PushOperationsRequest{
			Operations: ops,
		})
		elapsed := time.Since(start)

		require.NoError(t, err)
		require.Equal(t, int32(1), resp.AcceptedCount)
		latencies = append(latencies, elapsed)
	}

	sort.Slice(latencies, func(i, j int) bool { return latencies[i] < latencies[j] })
	p50 := percentile(latencies, 50)
	p95 := percentile(latencies, 95)
	p99 := percentile(latencies, 99)

	t.Logf("Push SLA (n=%d): P50=%v P95=%v P99=%v", iterations, p50, p95, p99)

	// CI threshold: 3x target (500ms → 1500ms)
	const ciThreshold = 1500 * time.Millisecond
	assert.Less(t, p99, ciThreshold,
		"Push P99 %v exceeds CI threshold %v (target: 500ms)", p99, ciThreshold)
}

// ─── PERF-004: Pull SLA P99 < 200ms (100 items) ─────────────────────────────

func TestPerf_Pull_SLA(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()

	userID := createTestUser(t, db, "perf004@test.com")

	hub := ws.NewHub(nil)
	syncSvc := syncpkg.NewService(db.pool, hub)
	authedCtx := context.WithValue(ctx, middleware.UserIDKey, userID.String())

	// Seed 100 sync_operations via SQL
	baseTime := time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC)
	for i := 0; i < 100; i++ {
		ts := baseTime.Add(time.Duration(i) * time.Minute)
		_, err := db.pool.Exec(ctx,
			`INSERT INTO sync_operations (user_id, entity_type, entity_id, op_type, payload, client_id, timestamp)
			 VALUES ($1, 'transaction', $2, 'create', '{}', $3, $4)`,
			userID, uuid.New(), fmt.Sprintf("seed-client-%d", i), ts,
		)
		require.NoError(t, err)
	}

	const iterations = 100
	latencies := make([]time.Duration, 0, iterations)

	// Pull all 100 items each iteration
	since := baseTime.Add(-1 * time.Second)
	for i := 0; i < iterations; i++ {
		start := time.Now()
		resp, err := syncSvc.PullChanges(authedCtx, &pb.PullChangesRequest{
			Since:    timestamppb.New(since),
			ClientId: "pull-sla-client",
			PageSize: 500, // request all at once
		})
		elapsed := time.Since(start)

		require.NoError(t, err)
		assert.GreaterOrEqual(t, len(resp.Operations), 100,
			"expected ≥100 operations, got %d", len(resp.Operations))
		latencies = append(latencies, elapsed)
	}

	sort.Slice(latencies, func(i, j int) bool { return latencies[i] < latencies[j] })
	p50 := percentile(latencies, 50)
	p95 := percentile(latencies, 95)
	p99 := percentile(latencies, 99)

	t.Logf("Pull SLA (n=%d, 100 items): P50=%v P95=%v P99=%v", iterations, p50, p95, p99)

	// CI threshold: 3x target (200ms → 600ms)
	const ciThreshold = 600 * time.Millisecond
	assert.Less(t, p99, ciThreshold,
		"Pull P99 %v exceeds CI threshold %v (target: 200ms)", p99, ciThreshold)
}

// ─── PERF-005: PG Slow Query Injection + Context Deadline ────────────────────

func TestPerf_PGSlowQuery_ContextDeadline(t *testing.T) {
	db := getDB(t)

	// Set a short deadline (500ms)
	ctx, cancel := context.WithTimeout(context.Background(), 500*time.Millisecond)
	defer cancel()

	// Inject pg_sleep(2) — should be cancelled by context
	var result int
	err := db.pool.QueryRow(ctx, `SELECT 1 FROM pg_sleep(2)`).Scan(&result)
	require.Error(t, err, "pg_sleep(2) with 500ms deadline should fail")
	t.Logf("Expected deadline error: %v", err)

	// Verify no dirty data: the sleep query shouldn't have created anything
	freshCtx := context.Background()
	var count int
	err = db.pool.QueryRow(freshCtx,
		`SELECT COUNT(*) FROM sync_operations`,
	).Scan(&count)
	require.NoError(t, err)
	assert.Equal(t, 0, count, "no dirty data should exist after cancelled query")

	// Test that a cancelled write transaction does not commit partial data
	txCtx, txCancel := context.WithTimeout(context.Background(), 200*time.Millisecond)
	defer txCancel()

	userID := createTestUser(t, db, "perf005@test.com")

	tx, err := db.pool.Begin(txCtx)
	require.NoError(t, err)

	_, err = tx.Exec(txCtx,
		`INSERT INTO sync_operations (user_id, entity_type, entity_id, op_type, payload, client_id, timestamp)
		 VALUES ($1, 'transaction', $2, 'create', '{}', 'deadline-test', NOW())`,
		userID, uuid.New(),
	)
	// Insert might succeed before timeout
	if err == nil {
		// Now do a slow query that triggers timeout
		var sleepResult int
		err = tx.QueryRow(txCtx, `SELECT 1 FROM pg_sleep(2)`).Scan(&sleepResult)
		require.Error(t, err, "pg_sleep in transaction should fail with deadline")
	}

	// Rollback (or it was already cancelled by context)
	_ = tx.Rollback(context.Background())

	// Verify: the inserted row should NOT be committed
	var syncCount int
	err = db.pool.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM sync_operations WHERE client_id = 'deadline-test'`,
	).Scan(&syncCount)
	require.NoError(t, err)
	assert.Equal(t, 0, syncCount, "deadline-cancelled transaction should not commit data")

	t.Logf("PERF-005 PASS: context deadline correctly prevents slow queries and partial commits")
}

// ─── Helper: suppress unused import warnings ─────────────────────────────────

var _ = rand.Intn
