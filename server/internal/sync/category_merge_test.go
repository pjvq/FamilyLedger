package sync

import (
	"context"
	"encoding/json"
	"errors"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	pgxmock "github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
)

// helper: marshal a merge payload
func mergePayload(src, tgt string) string {
	b, _ := json.Marshal(categoryMergePayload{
		SourceCategoryID: src,
		TargetCategoryID: tgt,
	})
	return string(b)
}

func TestApplyCategoryMergeOp_Success(t *testing.T) {
	svc, mock, tx := newSvc(t)
	src := uuid.New()
	tgt := uuid.New()
	eid := uuid.New() // merge_log id (opaque)

	// 1. lock + load source (exists, user-owned, not preset)
	mock.ExpectQuery("SELECT user_id, is_preset FROM categories WHERE id =.*FOR UPDATE").
		WithArgs(src).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "is_preset"}).AddRow(&uid, false))
	// 2. lock + verify target exists and belongs to same user
	mock.ExpectQuery("SELECT user_id FROM categories WHERE id =.*FOR UPDATE").
		WithArgs(tgt).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}).AddRow(&uid))
	// 3. repoint transactions
	mock.ExpectExec("UPDATE transactions SET category_id =").
		WithArgs(tgt, src).
		WillReturnResult(pgxmock.NewResult("UPDATE", 3))
	// 4. re-parent sub-categories
	mock.ExpectExec("UPDATE categories SET parent_id =").
		WithArgs(tgt, src).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	// 5. soft-delete source only
	mock.ExpectExec("UPDATE categories SET deleted_at = NOW\\(\\) WHERE id =").
		WithArgs(src).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	err := svc.applyCategoryMergeOp(context.Background(), tx, uid, eid, "create", mergePayload(src.String(), tgt.String()))
	assert.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestApplyCategoryMergeOp_Idempotent_SourceGone(t *testing.T) {
	svc, mock, tx := newSvc(t)
	src := uuid.New()
	tgt := uuid.New()

	// source already deleted/gone -> no rows -> idempotent no-op
	mock.ExpectQuery("SELECT user_id, is_preset FROM categories WHERE id =.*FOR UPDATE").
		WithArgs(src).
		WillReturnError(pgx.ErrNoRows)

	err := svc.applyCategoryMergeOp(context.Background(), tx, uid, uuid.New(), "update", mergePayload(src.String(), tgt.String()))
	assert.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestApplyCategoryMergeOp_RefusePreset(t *testing.T) {
	svc, mock, tx := newSvc(t)
	src := uuid.New()
	tgt := uuid.New()

	mock.ExpectQuery("SELECT user_id, is_preset FROM categories WHERE id =.*FOR UPDATE").
		WithArgs(src).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "is_preset"}).AddRow(&uid, true))

	err := svc.applyCategoryMergeOp(context.Background(), tx, uid, uuid.New(), "create", mergePayload(src.String(), tgt.String()))
	assert.NoError(t, err) // preset is skipped (no-op), not an error
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestApplyCategoryMergeOp_WrongUser(t *testing.T) {
	svc, mock, tx := newSvc(t)
	src := uuid.New()
	tgt := uuid.New()
	otherUser := uuid.New()

	mock.ExpectQuery("SELECT user_id, is_preset FROM categories WHERE id =.*FOR UPDATE").
		WithArgs(src).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "is_preset"}).AddRow(&otherUser, false))
	// source owner is a stranger (not in caller's family) -> family check returns false
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(uid, otherUser).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(false))

	err := svc.applyCategoryMergeOp(context.Background(), tx, uid, uuid.New(), "create", mergePayload(src.String(), tgt.String()))
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "does not belong to user or their family")
}

func TestApplyCategoryMergeOp_TargetMissing(t *testing.T) {
	svc, mock, tx := newSvc(t)
	src := uuid.New()
	tgt := uuid.New()

	mock.ExpectQuery("SELECT user_id, is_preset FROM categories WHERE id =.*FOR UPDATE").
		WithArgs(src).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "is_preset"}).AddRow(&uid, false))
	// target query returns no rows (deleted/missing)
	mock.ExpectQuery("SELECT user_id FROM categories WHERE id =.*FOR UPDATE").
		WithArgs(tgt).
		WillReturnError(pgx.ErrNoRows)

	err := svc.applyCategoryMergeOp(context.Background(), tx, uid, uuid.New(), "create", mergePayload(src.String(), tgt.String()))
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "target category")
}

func TestApplyCategoryMergeOp_InvalidPayload(t *testing.T) {
	svc, _, tx := newSvc(t)
	err := svc.applyCategoryMergeOp(context.Background(), tx, uid, uuid.New(), "create", "{not json")
	assert.Error(t, err)
}

func TestApplyCategoryMergeOp_MissingIDs(t *testing.T) {
	svc, _, tx := newSvc(t)
	err := svc.applyCategoryMergeOp(context.Background(), tx, uid, uuid.New(), "create", `{"source_category_id":"","target_category_id":""}`)
	assert.Error(t, err)
}

func TestApplyCategoryMergeOp_SameSourceTarget_IsNoOp(t *testing.T) {
	svc, _, tx := newSvc(t)
	id := uuid.New().String()
	// Self-merge is now a no-op (idempotent), matching client behavior.
	err := svc.applyCategoryMergeOp(context.Background(), tx, uid, uuid.New(), "create", mergePayload(id, id))
	assert.NoError(t, err)
}

func TestApplyCategoryMergeOp_DeleteOpIsNoOp(t *testing.T) {
	svc, _, tx := newSvc(t)
	src := uuid.New().String()
	tgt := uuid.New().String()
	// delete op_type must short-circuit before any DB call
	err := svc.applyCategoryMergeOp(context.Background(), tx, uid, uuid.New(), "delete", mergePayload(src, tgt))
	assert.NoError(t, err)
}

func TestApplyCategoryMergeOp_InvalidUUIDs(t *testing.T) {
	svc, _, tx := newSvc(t)
	err := svc.applyCategoryMergeOp(context.Background(), tx, uid, uuid.New(), "create", `{"source_category_id":"not-a-uuid","target_category_id":"also-bad"}`)
	assert.Error(t, err)
}

// applyOperation routes category_merge to the merge handler.
func TestApplyOperation_RoutesCategoryMerge(t *testing.T) {
	svc, mock, tx := newSvc(t)
	src := uuid.New()
	tgt := uuid.New()

	mock.ExpectQuery("SELECT user_id, is_preset FROM categories WHERE id =.*FOR UPDATE").
		WithArgs(src).
		WillReturnError(pgx.ErrNoRows) // idempotent no-op path keeps the test simple

	err := svc.applyOperation(context.Background(), tx, uid, "category_merge", uuid.New(), "create", mergePayload(src.String(), tgt.String()))
	assert.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestApplyCategoryMergeOp_LoadError(t *testing.T) {
	svc, mock, tx := newSvc(t)
	src := uuid.New()
	tgt := uuid.New()

	mock.ExpectQuery("SELECT user_id, is_preset FROM categories WHERE id =.*FOR UPDATE").
		WithArgs(src).
		WillReturnError(errors.New("db down"))

	err := svc.applyCategoryMergeOp(context.Background(), tx, uid, uuid.New(), "create", mergePayload(src.String(), tgt.String()))
	assert.Error(t, err)
}

// CRITICAL #1 regression test: target belongs to a stranger (not same family).
func TestApplyCategoryMergeOp_TargetBelongsToOtherUser(t *testing.T) {
	svc, mock, tx := newSvc(t)
	src := uuid.New()
	tgt := uuid.New()
	otherUser := uuid.New()

	// source is owned by uid (current user) — OK, no family query needed
	mock.ExpectQuery("SELECT user_id, is_preset FROM categories WHERE id =.*FOR UPDATE").
		WithArgs(src).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "is_preset"}).AddRow(&uid, false))
	// target belongs to a DIFFERENT user
	mock.ExpectQuery("SELECT user_id FROM categories WHERE id =.*FOR UPDATE").
		WithArgs(tgt).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}).AddRow(&otherUser))
	// that user is NOT in caller's family -> rejected
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(uid, otherUser).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(false))

	err := svc.applyCategoryMergeOp(context.Background(), tx, uid, uuid.New(), "create", mergePayload(src.String(), tgt.String()))
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "target category")
	assert.Contains(t, err.Error(), "does not belong to user or their family")
	assert.NoError(t, mock.ExpectationsWereMet())
}

// Target is a preset (user_id=nil) — should be allowed (presets are global targets).
func TestApplyCategoryMergeOp_TargetIsPreset_Allowed(t *testing.T) {
	svc, mock, tx := newSvc(t)
	src := uuid.New()
	tgt := uuid.New()

	// source owned by uid
	mock.ExpectQuery("SELECT user_id, is_preset FROM categories WHERE id =.*FOR UPDATE").
		WithArgs(src).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "is_preset"}).AddRow(&uid, false))
	// target is a preset (user_id = nil)
	mock.ExpectQuery("SELECT user_id FROM categories WHERE id =.*FOR UPDATE").
		WithArgs(tgt).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}).AddRow(nil))
	// 3 mutations proceed
	mock.ExpectExec("UPDATE transactions SET category_id =").
		WithArgs(tgt, src).
		WillReturnResult(pgxmock.NewResult("UPDATE", 0))
	mock.ExpectExec("UPDATE categories SET parent_id =").
		WithArgs(tgt, src).
		WillReturnResult(pgxmock.NewResult("UPDATE", 0))
	mock.ExpectExec("UPDATE categories SET deleted_at = NOW\\(\\) WHERE id =").
		WithArgs(src).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	err := svc.applyCategoryMergeOp(context.Background(), tx, uid, uuid.New(), "create", mergePayload(src.String(), tgt.String()))
	assert.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

// Same-family merge: source owned by family member A, target owned by member B,
// caller is in the same family. Both ownership checks pass via family membership.
func TestApplyCategoryMergeOp_SameFamily_Allowed(t *testing.T) {
	svc, mock, tx := newSvc(t)
	src := uuid.New()
	tgt := uuid.New()
	memberA := uuid.New() // owns source
	memberB := uuid.New() // owns target

	// source owned by memberA (not caller) -> family check passes
	mock.ExpectQuery("SELECT user_id, is_preset FROM categories WHERE id =.*FOR UPDATE").
		WithArgs(src).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "is_preset"}).AddRow(&memberA, false))
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(uid, memberA).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))
	// target owned by memberB (not caller) -> family check passes
	mock.ExpectQuery("SELECT user_id FROM categories WHERE id =.*FOR UPDATE").
		WithArgs(tgt).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}).AddRow(&memberB))
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(uid, memberB).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))
	// 3 mutations proceed
	mock.ExpectExec("UPDATE transactions SET category_id =").
		WithArgs(tgt, src).
		WillReturnResult(pgxmock.NewResult("UPDATE", 2))
	mock.ExpectExec("UPDATE categories SET parent_id =").
		WithArgs(tgt, src).
		WillReturnResult(pgxmock.NewResult("UPDATE", 0))
	mock.ExpectExec("UPDATE categories SET deleted_at = NOW\\(\\) WHERE id =").
		WithArgs(src).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	err := svc.applyCategoryMergeOp(context.Background(), tx, uid, uuid.New(), "create", mergePayload(src.String(), tgt.String()))
	assert.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

// applyCategoryUpdate: a family member can edit a family-scoped category
// created by another member.
func TestApplyCategoryUpdate_SameFamily_Allowed(t *testing.T) {
	svc, mock, tx := newSvc(t)
	cid := uuid.New()
	memberA := uuid.New() // created the category

	mock.ExpectQuery("SELECT user_id, is_preset FROM categories WHERE id =").
		WithArgs(cid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "is_preset"}).AddRow(&memberA, false))
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(uid, memberA).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))
	mock.ExpectExec("UPDATE categories SET").
		WithArgs("Renamed", cid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	payload, _ := json.Marshal(categoryPayload{Name: "Renamed"})
	err := svc.applyCategoryUpdate(context.Background(), tx, uid, cid, string(payload))
	assert.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

// applyCategoryUpdate: a stranger (not in family) cannot edit the category.
func TestApplyCategoryUpdate_Stranger_Rejected(t *testing.T) {
	svc, mock, tx := newSvc(t)
	cid := uuid.New()
	stranger := uuid.New()

	mock.ExpectQuery("SELECT user_id, is_preset FROM categories WHERE id =").
		WithArgs(cid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "is_preset"}).AddRow(&stranger, false))
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(uid, stranger).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(false))

	payload, _ := json.Marshal(categoryPayload{Name: "Hijack"})
	err := svc.applyCategoryUpdate(context.Background(), tx, uid, cid, string(payload))
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "does not belong to user or their family")
	assert.NoError(t, mock.ExpectationsWereMet())
}
