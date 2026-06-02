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

	// 1. load source (exists, user-owned, not preset)
	mock.ExpectQuery("SELECT user_id, is_preset FROM categories WHERE id =").
		WithArgs(src).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "is_preset"}).AddRow(&uid, false))
	// 2. verify target exists
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(tgt).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))
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
	mock.ExpectQuery("SELECT user_id, is_preset FROM categories WHERE id =").
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

	mock.ExpectQuery("SELECT user_id, is_preset FROM categories WHERE id =").
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

	mock.ExpectQuery("SELECT user_id, is_preset FROM categories WHERE id =").
		WithArgs(src).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "is_preset"}).AddRow(&otherUser, false))

	err := svc.applyCategoryMergeOp(context.Background(), tx, uid, uuid.New(), "create", mergePayload(src.String(), tgt.String()))
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "does not belong to user")
}

func TestApplyCategoryMergeOp_TargetMissing(t *testing.T) {
	svc, mock, tx := newSvc(t)
	src := uuid.New()
	tgt := uuid.New()

	mock.ExpectQuery("SELECT user_id, is_preset FROM categories WHERE id =").
		WithArgs(src).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "is_preset"}).AddRow(&uid, false))
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(tgt).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(false))

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

func TestApplyCategoryMergeOp_SameSourceTarget(t *testing.T) {
	svc, _, tx := newSvc(t)
	id := uuid.New().String()
	err := svc.applyCategoryMergeOp(context.Background(), tx, uid, uuid.New(), "create", mergePayload(id, id))
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "must differ")
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

	mock.ExpectQuery("SELECT user_id, is_preset FROM categories WHERE id =").
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

	mock.ExpectQuery("SELECT user_id, is_preset FROM categories WHERE id =").
		WithArgs(src).
		WillReturnError(errors.New("db down"))

	err := svc.applyCategoryMergeOp(context.Background(), tx, uid, uuid.New(), "create", mergePayload(src.String(), tgt.String()))
	assert.Error(t, err)
}
