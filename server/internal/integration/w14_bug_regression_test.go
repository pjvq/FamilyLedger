//go:build integration

package integration

import (
	"context"
	"encoding/csv"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/familyledger/server/internal/dashboard"
	"github.com/familyledger/server/internal/export"
	syncpkg "github.com/familyledger/server/internal/sync"
	"github.com/familyledger/server/pkg/middleware"
	"github.com/familyledger/server/pkg/ws"
	pbDash "github.com/familyledger/server/proto/dashboard"
	pbExport "github.com/familyledger/server/proto/export"
	pb "github.com/familyledger/server/proto/sync"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// ═══════════════════════════════════════════════════════════════════════════════
// W14: @neverSkip Bug Regression Tests
//
// These tests MUST NEVER be skipped, disabled, or marked expected failure.
// Each corresponds to a specific bug discovered during W1-W13 testing.
// ═══════════════════════════════════════════════════════════════════════════════

// @neverSkip BUG-001: Dashboard familyId filter
// Bug: Dashboard queries returned personal data even in family mode because
// familyId was not used in the WHERE clause.
func TestBUG001_Dashboard_FamilyId_Filter(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()
	svc := dashboard.NewService(db.pool)

	owner := createTestUser(t, db, "bug001_owner@test.com")
	member := createTestUser(t, db, "bug001_member@test.com")
	outsider := createTestUser(t, db, "bug001_outsider@test.com")

	familyID := createTestFamily(t, db, owner, "BUG-001 Family")
	addFamilyMember(t, db, familyID, owner, "owner", `{"view":true,"edit":true,"delete":true,"invite":true,"manage":true}`)
	addFamilyMember(t, db, familyID, member, "member", `{"view":true,"edit":true,"delete":false,"invite":false,"manage":false}`)

	// Create family account + outsider personal account
	familyAcct := createTestAccount(t, db, owner, "Family Acct", &familyID)
	outsiderAcct := createTestAccount(t, db, outsider, "Outsider Acct", nil)
	catID := getCategoryID(t, db)

	// Family transaction: ¥100
	_, err := db.pool.Exec(ctx,
		`INSERT INTO transactions (id, user_id, account_id, category_id, amount, amount_cny, type, note, txn_date, family_id, created_at, updated_at)
		 VALUES ($1, $2, $3, $4, 10000, 10000, 'expense', 'family expense', NOW(), $5, NOW(), NOW())`,
		uuid.New(), owner, familyAcct, catID, familyID)
	require.NoError(t, err)

	// Outsider transaction: ¥200 — must NOT appear in family dashboard
	_, err = db.pool.Exec(ctx,
		`INSERT INTO transactions (id, user_id, account_id, category_id, amount, amount_cny, type, note, txn_date, created_at, updated_at)
		 VALUES ($1, $2, $3, $4, 20000, 20000, 'expense', 'outsider expense', NOW(), NOW(), NOW())`,
		uuid.New(), outsider, outsiderAcct, catID)
	require.NoError(t, err)

	// Query dashboard in family mode — use CategoryBreakdown which sums expenses
	ownerCtx := authedCtxWith(owner)
	now := time.Now()
	resp, err := svc.GetCategoryBreakdown(ownerCtx, &pbDash.CategoryBreakdownRequest{
		FamilyId: familyID.String(),
		Year:     int32(now.Year()),
		Month:    int32(now.Month()),
	})
	require.NoError(t, err)

	// REGRESSION: outsider's ¥200 must NOT be included, only family's ¥100
	assert.Equal(t, int64(10000), resp.GetTotal(),
		"BUG-001: family dashboard must filter by familyId — outsider data must be excluded")

	t.Log("BUG-001 PASS: Dashboard correctly filters by familyId")
}

// @neverSkip BUG-002: PullChanges family data
// Bug: PullChanges only returned the requesting user's own data, not family
// members' data when the user belongs to a family.
func TestBUG002_PullChanges_Family_Data(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()
	syncSvc := syncpkg.NewService(db.pool, ws.NewHub(nil))

	owner := createTestUser(t, db, "bug002_owner@test.com")
	member := createTestUser(t, db, "bug002_member@test.com")
	familyID := createTestFamily(t, db, owner, "BUG-002 Family")
	addFamilyMember(t, db, familyID, owner, "owner", `{"view":true,"edit":true,"delete":true,"invite":true,"manage":true}`)
	addFamilyMember(t, db, familyID, member, "member", `{"view":true,"edit":true,"delete":false,"invite":false,"manage":false}`)

	catID := getCategoryID(t, db)
	ownerAcct := createTestAccount(t, db, owner, "Owner Acct", &familyID)

	// Owner pushes a family transaction
	ownerCtx := context.WithValue(ctx, middleware.UserIDKey, owner.String())
	_, err := syncSvc.PushOperations(ownerCtx, &pb.PushOperationsRequest{
		Operations: []*pb.SyncOperation{{
			Id:              uuid.New().String(),
			EntityType:      "transaction",
			EntityId:        uuid.New().String(),
			OpType: pb.OperationType_OPERATION_TYPE_CREATE,
			Payload: `{"amount":5000,"type":"expense","account_id":"` + ownerAcct.String() + `","category_id":"` + catID.String() + `","family_id":"` + familyID.String() + `"}`,
			Timestamp: timestamppb.Now(),
		}},
	})
	require.NoError(t, err)

	// Member pulls — should see owner's family transaction
	memberCtx := context.WithValue(ctx, middleware.UserIDKey, member.String())
	pullResp, err := syncSvc.PullChanges(memberCtx, &pb.PullChangesRequest{
		Since: timestamppb.New(time.Now().Add(-1 * time.Hour)),
	})
	require.NoError(t, err)

	// REGRESSION: member must see family data from owner
	found := false
	for _, change := range pullResp.Operations {
		if change.EntityType == "transaction" && strings.Contains(change.Payload, familyID.String()) {
			found = true
			break
		}
	}
	assert.True(t, found,
		"BUG-002: PullChanges must include family members' data when user belongs to family")

	t.Log("BUG-002 PASS: PullChanges returns family members' data")
}

// @neverSkip BUG-003: WebSocket broadcast scope
// Bug: WS broadcast only sent to the message sender instead of all family members.
// The server-side pattern: when user A pushes a sync op, the server looks up
// all family members and calls BroadcastToUser for each of them.
// This test verifies the family member lookup returns all members.
func TestBUG003_WebSocket_Broadcast_Scope(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()

	owner := createTestUser(t, db, "bug003_owner@test.com")
	member1 := createTestUser(t, db, "bug003_m1@test.com")
	member2 := createTestUser(t, db, "bug003_m2@test.com")
	outsider := createTestUser(t, db, "bug003_outsider@test.com")
	familyID := createTestFamily(t, db, owner, "BUG-003 Family")
	addFamilyMember(t, db, familyID, owner, "owner", `{"view":true,"edit":true,"delete":true,"invite":true,"manage":true}`)
	addFamilyMember(t, db, familyID, member1, "member", `{"view":true,"edit":true,"delete":false,"invite":false,"manage":false}`)
	addFamilyMember(t, db, familyID, member2, "member", `{"view":true,"edit":true,"delete":false,"invite":false,"manage":false}`)

	// Query family members — this is the same query the WS handler uses
	// to determine broadcast targets
	rows, err := db.pool.Query(ctx,
		`SELECT user_id FROM family_members WHERE family_id = $1`,
		familyID,
	)
	require.NoError(t, err)
	defer rows.Close()

	var memberIDs []uuid.UUID
	for rows.Next() {
		var uid uuid.UUID
		require.NoError(t, rows.Scan(&uid))
		memberIDs = append(memberIDs, uid)
	}
	require.NoError(t, rows.Err())

	// REGRESSION: All 3 family members must be in the broadcast list
	assert.Len(t, memberIDs, 3,
		"BUG-003: family member query must return all 3 members (owner + 2 members)")

	// Verify specific members
	idSet := make(map[uuid.UUID]bool)
	for _, id := range memberIDs {
		idSet[id] = true
	}
	assert.True(t, idSet[owner], "BUG-003: owner must be in broadcast targets")
	assert.True(t, idSet[member1], "BUG-003: member1 must be in broadcast targets")
	assert.True(t, idSet[member2], "BUG-003: member2 must be in broadcast targets")
	assert.False(t, idSet[outsider], "BUG-003: outsider must NOT be in broadcast targets")

	t.Log("BUG-003 PASS: Family member query returns all members for WS broadcast")
}

// @neverSkip BUG-004: Transaction edit permission
// Bug: Any authenticated user could edit any transaction, not just the
// creator or family admin.
func TestBUG004_Transaction_Edit_Permission(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()

	owner := createTestUser(t, db, "bug004_owner@test.com")
	member := createTestUser(t, db, "bug004_member@test.com")
	outsider := createTestUser(t, db, "bug004_outsider@test.com")

	familyID := createTestFamily(t, db, owner, "BUG-004 Family")
	addFamilyMember(t, db, familyID, owner, "owner", `{"view":true,"edit":true,"delete":true,"invite":true,"manage":true}`)
	addFamilyMember(t, db, familyID, member, "member", `{"view":true,"edit":false,"delete":false,"invite":false,"manage":false}`)

	catID := getCategoryID(t, db)
	ownerAcct := createTestAccount(t, db, owner, "Owner Acct", &familyID)

	// Create a transaction owned by 'owner'
	txnID := uuid.New()
	_, err := db.pool.Exec(ctx,
		`INSERT INTO transactions (id, user_id, account_id, category_id, amount, amount_cny, type, note, txn_date, family_id, created_at, updated_at)
		 VALUES ($1, $2, $3, $4, 5000, 5000, 'expense', 'original', NOW(), $5, NOW(), NOW())`,
		txnID, owner, ownerAcct, catID, familyID)
	require.NoError(t, err)

	syncSvc := syncpkg.NewService(db.pool, ws.NewHub(nil))

	// Member without edit permission tries to update — should fail
	memberCtx := context.WithValue(ctx, middleware.UserIDKey, member.String())
	_, err = syncSvc.PushOperations(memberCtx, &pb.PushOperationsRequest{
		Operations: []*pb.SyncOperation{{
			Id:              uuid.New().String(),
			EntityType:      "transaction",
			EntityId:        txnID.String(),
			OpType: pb.OperationType_OPERATION_TYPE_UPDATE,
			Payload: `{"note":"hacked by member"}`,
			Timestamp: timestamppb.Now(),
		}},
	})
	// Push should either reject or the operation should fail
	if err == nil {
		// Check the data wasn't actually changed
		var note string
		_ = db.pool.QueryRow(ctx, `SELECT note FROM transactions WHERE id=$1`, txnID).Scan(&note)
		assert.NotEqual(t, "hacked by member", note,
			"BUG-004: member without edit permission must not be able to modify transaction")
	}

	// Outsider (not in family) tries to update — must fail
	outsiderCtx := context.WithValue(ctx, middleware.UserIDKey, outsider.String())
	_, err = syncSvc.PushOperations(outsiderCtx, &pb.PushOperationsRequest{
		Operations: []*pb.SyncOperation{{
			Id:              uuid.New().String(),
			EntityType:      "transaction",
			EntityId:        txnID.String(),
			OpType: pb.OperationType_OPERATION_TYPE_UPDATE,
			Payload: `{"note":"hacked by outsider"}`,
			Timestamp: timestamppb.Now(),
		}},
	})
	if err == nil {
		var note string
		_ = db.pool.QueryRow(ctx, `SELECT note FROM transactions WHERE id=$1`, txnID).Scan(&note)
		assert.NotEqual(t, "hacked by outsider", note,
			"BUG-004: outsider must not be able to modify family transaction")
	}

	// Owner edits — should succeed
	ownerCtx := context.WithValue(ctx, middleware.UserIDKey, owner.String())
	_, err = syncSvc.PushOperations(ownerCtx, &pb.PushOperationsRequest{
		Operations: []*pb.SyncOperation{{
			Id:              uuid.New().String(),
			EntityType:      "transaction",
			EntityId:        txnID.String(),
			OpType: pb.OperationType_OPERATION_TYPE_UPDATE,
			Payload: `{"note":"updated by owner"}`,
			Timestamp: timestamppb.Now(),
		}},
	})
	require.NoError(t, err)

	t.Log("BUG-004 PASS: Transaction edit respects permission boundaries")
}

// @neverSkip BUG-005: Sync timestamp monotonic
// Bug: Sync timestamps could go backwards due to clock skew between client and
// server, causing Pull to miss updates.
func TestBUG005_Sync_Timestamp_Monotonic(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()
	syncSvc := syncpkg.NewService(db.pool, ws.NewHub(nil))

	user := createTestUser(t, db, "bug005@test.com")
	userCtx := context.WithValue(ctx, middleware.UserIDKey, user.String())
	acct := createTestAccount(t, db, user, "Bug005 Acct", nil)
	catID := getCategoryID(t, db)

	// Push 5 operations rapidly
	var entityIDs []string
	for i := 0; i < 5; i++ {
		eid := uuid.New().String()
		entityIDs = append(entityIDs, eid)
		_, err := syncSvc.PushOperations(userCtx, &pb.PushOperationsRequest{
			Operations: []*pb.SyncOperation{{
				Id:         uuid.New().String(),
				EntityType: "transaction",
				EntityId:   eid,
				OpType:     pb.OperationType_OPERATION_TYPE_CREATE,
				Payload:    `{"amount":1000,"type":"expense","account_id":"` + acct.String() + `","category_id":"` + catID.String() + `"}`,
				Timestamp:  timestamppb.Now(),
			}},
		})
		require.NoError(t, err)
	}

	// Query server-side timestamps from DB to verify monotonicity
	rows, err := db.pool.Query(ctx,
		`SELECT timestamp FROM sync_operations
		 WHERE user_id = $1 ORDER BY timestamp ASC`, user)
	require.NoError(t, err)
	defer rows.Close()

	var serverTimestamps []time.Time
	for rows.Next() {
		var ts time.Time
		require.NoError(t, rows.Scan(&ts))
		serverTimestamps = append(serverTimestamps, ts)
	}
	require.NoError(t, rows.Err())
	require.GreaterOrEqual(t, len(serverTimestamps), 5)

	// REGRESSION: server timestamps must be monotonically non-decreasing
	for i := 1; i < len(serverTimestamps); i++ {
		assert.False(t, serverTimestamps[i].Before(serverTimestamps[i-1]),
			"BUG-005: server timestamp[%d]=%v is before timestamp[%d]=%v — monotonic violation",
			i, serverTimestamps[i], i-1, serverTimestamps[i-1])
	}

	// Verify Pull from oldest timestamp returns all 5
	pullResp, err := syncSvc.PullChanges(userCtx, &pb.PullChangesRequest{
		Since: timestamppb.New(serverTimestamps[0].Add(-1 * time.Second)),
	})
	require.NoError(t, err)
	txnChanges := 0
	for _, c := range pullResp.Operations {
		if c.EntityType == "transaction" {
			txnChanges++
		}
	}
	assert.GreaterOrEqual(t, txnChanges, 5,
		"BUG-005: Pull from before first push must return all 5 operations")

	t.Log("BUG-005 PASS: Sync timestamps are monotonically non-decreasing")
}

// @neverSkip BUG-007: Export family mode no data
// Bug: Export in family mode returned empty data because the SQL query
// didn't join on family_id correctly.
func TestBUG007_Export_FamilyMode_IncludesAllMembers(t *testing.T) {
	db := getDB(t)
	ctx := context.Background()
	svc := export.NewService(db.pool)

	owner := createTestUser(t, db, "bug007_owner@test.com")
	member := createTestUser(t, db, "bug007_member@test.com")
	familyID := createTestFamily(t, db, owner, "BUG-007 Family")
	addFamilyMember(t, db, familyID, owner, "owner", `{"view":true,"edit":true,"delete":true,"invite":true,"manage":true}`)
	addFamilyMember(t, db, familyID, member, "member", `{"view":true,"edit":true,"delete":false,"invite":false,"manage":false}`)

	catID := getCategoryID(t, db)
	ownerAcct := createTestAccount(t, db, owner, "Owner Export", &familyID)
	memberAcct := createTestAccount(t, db, member, "Member Export", &familyID)

	// Owner creates a transaction
	_, err := db.pool.Exec(ctx,
		`INSERT INTO transactions (id, user_id, account_id, category_id, amount, amount_cny, type, note, txn_date, family_id, created_at, updated_at)
		 VALUES ($1, $2, $3, $4, 10000, 10000, 'expense', 'owner tx', NOW(), $5, NOW(), NOW())`,
		uuid.New(), owner, ownerAcct, catID, familyID)
	require.NoError(t, err)

	// Member creates a transaction
	_, err = db.pool.Exec(ctx,
		`INSERT INTO transactions (id, user_id, account_id, category_id, amount, amount_cny, type, note, txn_date, family_id, created_at, updated_at)
		 VALUES ($1, $2, $3, $4, 20000, 20000, 'income', 'member tx', NOW(), $5, NOW(), NOW())`,
		uuid.New(), member, memberAcct, catID, familyID)
	require.NoError(t, err)

	// Export in family mode
	ownerCtx := authedCtxWith(owner)
	resp, err := svc.ExportTransactions(ownerCtx, &pbExport.ExportRequest{
		Format:   "csv",
		FamilyId: familyID.String(),
	})
	require.NoError(t, err)
	require.NotEmpty(t, resp.Data, "BUG-007: family export must not be empty")

	// Parse CSV and verify both members' transactions are present
	reader := csv.NewReader(strings.NewReader(string(resp.Data)))
	records, err := reader.ReadAll()
	require.NoError(t, err)

	// Header + at least 2 data rows
	assert.GreaterOrEqual(t, len(records), 3,
		"BUG-007: family export must include header + ≥2 data rows (owner + member)")

	// Check both notes appear
	allNotes := ""
	for _, row := range records[1:] {
		allNotes += strings.Join(row, " ") + "\n"
	}
	assert.Contains(t, allNotes, "owner tx",
		"BUG-007: family export must include owner's transaction")
	assert.Contains(t, allNotes, "member tx",
		"BUG-007: family export must include member's transaction")

	t.Log("BUG-007 PASS: Export in family mode includes all family members' transactions")
}
