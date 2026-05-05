package sync

import (
	"context"
	"encoding/json"
	"fmt"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	pgxmock "github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
)

// ── applyAccountCreate ──────────────────────────────────────────────────────

func TestApplyAccountCreate_Success(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectExec("INSERT INTO accounts").
		WithArgs(eid, uid, "储蓄卡", "savings", int64(100000), "CNY", "bank", pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	p, _ := json.Marshal(accountPayload{Name: "储蓄卡", Type: "savings", Balance: 100000, Icon: "bank"})
	err := svc.applyAccountCreate(context.Background(), tx, uid, eid, string(p))
	assert.NoError(t, err)
}

func TestApplyAccountCreate_InvalidJSON(t *testing.T) {
	svc, _, tx := newSvc(t)
	err := svc.applyAccountCreate(context.Background(), tx, uid, uuid.New(), "bad")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "invalid account create payload")
}

func TestApplyAccountCreate_EmptyName(t *testing.T) {
	svc, _, tx := newSvc(t)
	p, _ := json.Marshal(accountPayload{})
	err := svc.applyAccountCreate(context.Background(), tx, uid, uuid.New(), string(p))
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "name is required")
}

func TestApplyAccountCreate_Defaults(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	// Currency="" → "CNY", Type="" → "cash"
	mock.ExpectExec("INSERT INTO accounts").
		WithArgs(eid, uid, "acct", "cash", int64(0), "CNY", "", pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	p, _ := json.Marshal(accountPayload{Name: "acct"})
	err := svc.applyAccountCreate(context.Background(), tx, uid, eid, string(p))
	assert.NoError(t, err)
}

func TestApplyAccountCreate_WithFamilyID(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	famID := uuid.New()
	mock.ExpectExec("INSERT INTO accounts").
		WithArgs(eid, uid, "家庭账户", "cash", int64(0), "CNY", "", pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	p, _ := json.Marshal(accountPayload{Name: "家庭账户", FamilyID: famID.String()})
	err := svc.applyAccountCreate(context.Background(), tx, uid, eid, string(p))
	assert.NoError(t, err)
}

func TestApplyAccountCreate_DBError(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectExec("INSERT INTO accounts").
		WithArgs(eid, uid, "x", "cash", int64(0), "CNY", "", pgxmock.AnyArg()).
		WillReturnError(fmt.Errorf("dup"))

	p, _ := json.Marshal(accountPayload{Name: "x"})
	err := svc.applyAccountCreate(context.Background(), tx, uid, eid, string(p))
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "failed to insert account")
}

// ── applyAccountUpdate ──────────────────────────────────────────────────────

func TestApplyAccountUpdate_Success(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id FROM accounts").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}).AddRow(uid))
	mock.ExpectExec("UPDATE accounts SET").
		WithArgs("新名字", "savings", eid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	p, _ := json.Marshal(accountPayload{Name: "新名字", Type: "savings"})
	err := svc.applyAccountUpdate(context.Background(), tx, uid, eid, string(p))
	assert.NoError(t, err)
}

func TestApplyAccountUpdate_InvalidJSON(t *testing.T) {
	svc, _, tx := newSvc(t)
	err := svc.applyAccountUpdate(context.Background(), tx, uid, uuid.New(), "bad")
	assert.Error(t, err)
}

func TestApplyAccountUpdate_NotFound(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id FROM accounts").
		WithArgs(eid).
		WillReturnError(pgx.ErrNoRows)

	p, _ := json.Marshal(accountPayload{Name: "x"})
	err := svc.applyAccountUpdate(context.Background(), tx, uid, eid, string(p))
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
}

func TestApplyAccountUpdate_WrongUser(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id FROM accounts").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}).AddRow(uuid.New()))

	p, _ := json.Marshal(accountPayload{Name: "x"})
	err := svc.applyAccountUpdate(context.Background(), tx, uid, eid, string(p))
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "does not belong")
}

func TestApplyAccountUpdate_NoFields(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id FROM accounts").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}).AddRow(uid))
	mock.ExpectExec("UPDATE accounts SET updated_at").
		WithArgs(eid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	p, _ := json.Marshal(accountPayload{})
	err := svc.applyAccountUpdate(context.Background(), tx, uid, eid, string(p))
	assert.NoError(t, err)
}

func TestApplyAccountUpdate_AllFields(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	isActive := true
	mock.ExpectQuery("SELECT user_id FROM accounts").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}).AddRow(uid))
	mock.ExpectExec("UPDATE accounts SET").
		WithArgs("n", "credit", "USD", "ic", true, eid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	p, _ := json.Marshal(accountPayload{Name: "n", Type: "credit", Currency: "USD", Icon: "ic", IsActive: &isActive})
	err := svc.applyAccountUpdate(context.Background(), tx, uid, eid, string(p))
	assert.NoError(t, err)
}

// ── applyAccountDelete ──────────────────────────────────────────────────────

func TestApplyAccountDelete_Success(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id FROM accounts").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}).AddRow(uid))
	mock.ExpectExec("UPDATE accounts SET deleted_at").
		WithArgs(eid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	err := svc.applyAccountDelete(context.Background(), tx, uid, eid)
	assert.NoError(t, err)
}

func TestApplyAccountDelete_NotFound(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id FROM accounts").
		WithArgs(eid).
		WillReturnError(pgx.ErrNoRows)
	err := svc.applyAccountDelete(context.Background(), tx, uid, eid)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "already deleted")
}

func TestApplyAccountDelete_WrongUser(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id FROM accounts").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}).AddRow(uuid.New()))
	err := svc.applyAccountDelete(context.Background(), tx, uid, eid)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "does not belong")
}

func TestApplyAccountDelete_DBError(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id FROM accounts").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}).AddRow(uid))
	mock.ExpectExec("UPDATE accounts SET deleted_at").
		WithArgs(eid).
		WillReturnError(fmt.Errorf("err"))
	err := svc.applyAccountDelete(context.Background(), tx, uid, eid)
	assert.Error(t, err)
}

// ── applyAccountOp routing ──────────────────────────────────────────────────

func TestApplyAccountOp_Create(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectExec("INSERT INTO accounts").
		WithArgs(eid, uid, "test", "cash", int64(0), "CNY", "", pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	p, _ := json.Marshal(accountPayload{Name: "test"})
	err := svc.applyAccountOp(context.Background(), tx, uid, eid, "create", string(p))
	assert.NoError(t, err)
}

func TestApplyAccountOp_Update(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id FROM accounts").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}).AddRow(uid))
	mock.ExpectExec("UPDATE accounts SET updated_at").
		WithArgs(eid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	err := svc.applyAccountOp(context.Background(), tx, uid, eid, "update", "{}")
	assert.NoError(t, err)
}

func TestApplyAccountOp_Delete(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id FROM accounts").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}).AddRow(uid))
	mock.ExpectExec("UPDATE accounts SET deleted_at").
		WithArgs(eid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	err := svc.applyAccountOp(context.Background(), tx, uid, eid, "delete", "")
	assert.NoError(t, err)
}

func TestApplyAccountOp_Unknown(t *testing.T) {
	svc, _, tx := newSvc(t)
	err := svc.applyAccountOp(context.Background(), tx, uid, uuid.New(), "merge", "")
	assert.NoError(t, err) // logs, returns nil
}

// ── applyCategoryCreate ─────────────────────────────────────────────────────

func TestApplyCategoryCreate_Success(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectExec("INSERT INTO categories").
		WithArgs(eid, "餐饮", "🍔", "food", "expense", 1, uid, pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	p, _ := json.Marshal(categoryPayload{Name: "餐饮", Icon: "🍔", IconKey: "food", Type: "expense", SortOrder: 1})
	err := svc.applyCategoryCreate(context.Background(), tx, uid, eid, string(p))
	assert.NoError(t, err)
}

func TestApplyCategoryCreate_InvalidJSON(t *testing.T) {
	svc, _, tx := newSvc(t)
	err := svc.applyCategoryCreate(context.Background(), tx, uid, uuid.New(), "bad")
	assert.Error(t, err)
}

func TestApplyCategoryCreate_EmptyName(t *testing.T) {
	svc, _, tx := newSvc(t)
	p, _ := json.Marshal(categoryPayload{})
	err := svc.applyCategoryCreate(context.Background(), tx, uid, uuid.New(), string(p))
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "name is required")
}

func TestApplyCategoryCreate_DefaultType(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectExec("INSERT INTO categories").
		WithArgs(eid, "test", "", "", "expense", 0, uid, pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	p, _ := json.Marshal(categoryPayload{Name: "test"})
	err := svc.applyCategoryCreate(context.Background(), tx, uid, eid, string(p))
	assert.NoError(t, err)
}

func TestApplyCategoryCreate_WithParentID(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	parentID := uuid.New().String()
	mock.ExpectExec("INSERT INTO categories").
		WithArgs(eid, "sub", "", "", "income", 0, uid, pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	p, _ := json.Marshal(categoryPayload{Name: "sub", Type: "income", ParentID: &parentID})
	err := svc.applyCategoryCreate(context.Background(), tx, uid, eid, string(p))
	assert.NoError(t, err)
}

func TestApplyCategoryCreate_InvalidParentID(t *testing.T) {
	svc, _, tx := newSvc(t)
	badID := "not-uuid"
	p, _ := json.Marshal(categoryPayload{Name: "x", ParentID: &badID})
	err := svc.applyCategoryCreate(context.Background(), tx, uid, uuid.New(), string(p))
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "invalid parent_id")
}

func TestApplyCategoryCreate_DBError(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectExec("INSERT INTO categories").
		WithArgs(eid, "x", "", "", "expense", 0, uid, pgxmock.AnyArg()).
		WillReturnError(fmt.Errorf("dup"))

	p, _ := json.Marshal(categoryPayload{Name: "x"})
	err := svc.applyCategoryCreate(context.Background(), tx, uid, eid, string(p))
	assert.Error(t, err)
}

// ── applyCategoryUpdate ─────────────────────────────────────────────────────

func TestApplyCategoryUpdate_Success(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	catUID := uid
	mock.ExpectQuery("SELECT user_id, is_preset FROM categories").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "is_preset"}).AddRow(&catUID, false))
	mock.ExpectExec("UPDATE categories SET").
		WithArgs("新名字", "🎯", eid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	p, _ := json.Marshal(categoryPayload{Name: "新名字", Icon: "🎯"})
	err := svc.applyCategoryUpdate(context.Background(), tx, uid, eid, string(p))
	assert.NoError(t, err)
}

func TestApplyCategoryUpdate_InvalidJSON(t *testing.T) {
	svc, _, tx := newSvc(t)
	err := svc.applyCategoryUpdate(context.Background(), tx, uid, uuid.New(), "bad")
	assert.Error(t, err)
}

func TestApplyCategoryUpdate_NotFound(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id, is_preset FROM categories").
		WithArgs(eid).
		WillReturnError(pgx.ErrNoRows)

	p, _ := json.Marshal(categoryPayload{Name: "x"})
	err := svc.applyCategoryUpdate(context.Background(), tx, uid, eid, string(p))
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
}

func TestApplyCategoryUpdate_PresetSkipped(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id, is_preset FROM categories").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "is_preset"}).AddRow(nil, true))

	p, _ := json.Marshal(categoryPayload{Name: "x"})
	err := svc.applyCategoryUpdate(context.Background(), tx, uid, eid, string(p))
	assert.NoError(t, err) // preset → skip silently
}

func TestApplyCategoryUpdate_WrongUser(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	otherUID := uuid.New()
	mock.ExpectQuery("SELECT user_id, is_preset FROM categories").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "is_preset"}).AddRow(&otherUID, false))

	p, _ := json.Marshal(categoryPayload{Name: "x"})
	err := svc.applyCategoryUpdate(context.Background(), tx, uid, eid, string(p))
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "does not belong")
}

func TestApplyCategoryUpdate_NoFields(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	catUID := uid
	mock.ExpectQuery("SELECT user_id, is_preset FROM categories").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "is_preset"}).AddRow(&catUID, false))
	// No fields → returns nil without UPDATE
	p, _ := json.Marshal(categoryPayload{})
	err := svc.applyCategoryUpdate(context.Background(), tx, uid, eid, string(p))
	assert.NoError(t, err)
}

func TestApplyCategoryUpdate_AllFields(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	catUID := uid
	mock.ExpectQuery("SELECT user_id, is_preset FROM categories").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "is_preset"}).AddRow(&catUID, false))
	mock.ExpectExec("UPDATE categories SET").
		WithArgs("n", "ic", "ik", 5, eid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	p, _ := json.Marshal(categoryPayload{Name: "n", Icon: "ic", IconKey: "ik", SortOrder: 5})
	err := svc.applyCategoryUpdate(context.Background(), tx, uid, eid, string(p))
	assert.NoError(t, err)
}

// ── applyCategoryDelete ─────────────────────────────────────────────────────

func TestApplyCategoryDelete_Success(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	catUID := uid
	mock.ExpectQuery("SELECT user_id, is_preset FROM categories").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "is_preset"}).AddRow(&catUID, false))
	mock.ExpectExec("UPDATE categories SET deleted_at").
		WithArgs(eid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	err := svc.applyCategoryDelete(context.Background(), tx, uid, eid)
	assert.NoError(t, err)
}

func TestApplyCategoryDelete_AlreadyDeleted(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id, is_preset FROM categories").
		WithArgs(eid).
		WillReturnError(pgx.ErrNoRows)
	err := svc.applyCategoryDelete(context.Background(), tx, uid, eid)
	assert.NoError(t, err) // idempotent
}

func TestApplyCategoryDelete_PresetSkipped(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id, is_preset FROM categories").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "is_preset"}).AddRow(nil, true))
	err := svc.applyCategoryDelete(context.Background(), tx, uid, eid)
	assert.NoError(t, err) // preset → skip
}

func TestApplyCategoryDelete_WrongUser(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	otherUID := uuid.New()
	mock.ExpectQuery("SELECT user_id, is_preset FROM categories").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "is_preset"}).AddRow(&otherUID, false))
	err := svc.applyCategoryDelete(context.Background(), tx, uid, eid)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "does not belong")
}

func TestApplyCategoryDelete_DBError(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	catUID := uid
	mock.ExpectQuery("SELECT user_id, is_preset FROM categories").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "is_preset"}).AddRow(&catUID, false))
	mock.ExpectExec("UPDATE categories SET deleted_at").
		WithArgs(eid).
		WillReturnError(fmt.Errorf("err"))
	err := svc.applyCategoryDelete(context.Background(), tx, uid, eid)
	assert.Error(t, err)
}

// ── applyCategoryOp routing ─────────────────────────────────────────────────

func TestApplyCategoryOp_Create(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectExec("INSERT INTO categories").
		WithArgs(eid, "x", "", "", "expense", 0, uid, pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	p, _ := json.Marshal(categoryPayload{Name: "x"})
	err := svc.applyCategoryOp(context.Background(), tx, uid, eid, "create", string(p))
	assert.NoError(t, err)
}

func TestApplyCategoryOp_Update(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	catUID := uid
	mock.ExpectQuery("SELECT user_id, is_preset FROM categories").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "is_preset"}).AddRow(&catUID, false))
	p, _ := json.Marshal(categoryPayload{})
	err := svc.applyCategoryOp(context.Background(), tx, uid, eid, "update", string(p))
	assert.NoError(t, err)
}

func TestApplyCategoryOp_Delete(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id, is_preset FROM categories").
		WithArgs(eid).
		WillReturnError(pgx.ErrNoRows)
	err := svc.applyCategoryOp(context.Background(), tx, uid, eid, "delete", "")
	assert.NoError(t, err)
}

func TestApplyCategoryOp_Unknown(t *testing.T) {
	svc, _, tx := newSvc(t)
	err := svc.applyCategoryOp(context.Background(), tx, uid, uuid.New(), "merge", "")
	assert.NoError(t, err)
}

// ── applyTransactionUpdate ──────────────────────────────────────────────────

func TestApplyTransactionUpdate_Success(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	accID := uuid.New()
	// Fetch existing
	mock.ExpectQuery("SELECT user_id, account_id, amount_cny, type, currency, exchange_rate").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "account_id", "amount_cny", "type", "currency", "exchange_rate"}).
			AddRow(uid, accID, int64(10000), "expense", "CNY", 1.0))
	// UPDATE transaction (amount + amount_cny + category)
	catID := uuid.New()
	mock.ExpectExec("UPDATE transactions SET").
		WithArgs(int64(20000), int64(20000), catID, eid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	// UPDATE account balance
	mock.ExpectExec("UPDATE accounts SET balance").
		WithArgs(int64(-10000), accID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	p, _ := json.Marshal(transactionPayload{Amount: 20000, CategoryID: catID.String()})
	err := svc.applyTransactionUpdate(context.Background(), tx, uid, eid, string(p))
	assert.NoError(t, err)
}

func TestApplyTransactionUpdate_InvalidJSON(t *testing.T) {
	svc, _, tx := newSvc(t)
	err := svc.applyTransactionUpdate(context.Background(), tx, uid, uuid.New(), "bad")
	assert.Error(t, err)
}

func TestApplyTransactionUpdate_NotFound(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id, account_id, amount_cny, type, currency, exchange_rate").
		WithArgs(eid).
		WillReturnError(pgx.ErrNoRows)

	err := svc.applyTransactionUpdate(context.Background(), tx, uid, eid, "{}")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
}

func TestApplyTransactionUpdate_WrongUser(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id, account_id, amount_cny, type, currency, exchange_rate").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "account_id", "amount_cny", "type", "currency", "exchange_rate"}).
			AddRow(uuid.New(), uuid.New(), int64(100), "expense", "CNY", 1.0))

	err := svc.applyTransactionUpdate(context.Background(), tx, uid, eid, "{}")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "does not belong")
}

func TestApplyTransactionUpdate_TypeChange(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	accID := uuid.New()
	// old: expense 10000
	mock.ExpectQuery("SELECT user_id, account_id, amount_cny, type, currency, exchange_rate").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "account_id", "amount_cny", "type", "currency", "exchange_rate"}).
			AddRow(uid, accID, int64(10000), "expense", "CNY", 1.0))
	// change to income
	mock.ExpectExec("UPDATE transactions SET").
		WithArgs("income", eid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	// balance adjust: old delta = -10000, new delta = +10000, adjust = +20000
	mock.ExpectExec("UPDATE accounts SET balance").
		WithArgs(int64(20000), accID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	p, _ := json.Marshal(transactionPayload{Type: "income"})
	err := svc.applyTransactionUpdate(context.Background(), tx, uid, eid, string(p))
	assert.NoError(t, err)
}

func TestApplyTransactionUpdate_Note(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	accID := uuid.New()
	mock.ExpectQuery("SELECT user_id, account_id, amount_cny, type, currency, exchange_rate").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "account_id", "amount_cny", "type", "currency", "exchange_rate"}).
			AddRow(uid, accID, int64(100), "expense", "CNY", 1.0))
	mock.ExpectExec("UPDATE transactions SET").
		WithArgs("new note", eid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	// balance unchanged → no balance update

	p, _ := json.Marshal(transactionPayload{Note: "new note"})
	err := svc.applyTransactionUpdate(context.Background(), tx, uid, eid, string(p))
	assert.NoError(t, err)
}

func TestApplyTransactionUpdate_TxnDate(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	accID := uuid.New()
	mock.ExpectQuery("SELECT user_id, account_id, amount_cny, type, currency, exchange_rate").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "account_id", "amount_cny", "type", "currency", "exchange_rate"}).
			AddRow(uid, accID, int64(100), "expense", "CNY", 1.0))
	mock.ExpectExec("UPDATE transactions SET").
		WithArgs(pgxmock.AnyArg(), eid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	p, _ := json.Marshal(transactionPayload{TxnDate: "2026-05-01T00:00:00.000"})
	err := svc.applyTransactionUpdate(context.Background(), tx, uid, eid, string(p))
	assert.NoError(t, err)
}

func TestApplyTransactionUpdate_InvalidCategoryID(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id, account_id, amount_cny, type, currency, exchange_rate").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "account_id", "amount_cny", "type", "currency", "exchange_rate"}).
			AddRow(uid, uuid.New(), int64(100), "expense", "CNY", 1.0))

	p, _ := json.Marshal(transactionPayload{CategoryID: "not-uuid"})
	err := svc.applyTransactionUpdate(context.Background(), tx, uid, eid, string(p))
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "invalid category_id")
}

func TestApplyTransactionUpdate_InvalidTxnDate(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id, account_id, amount_cny, type, currency, exchange_rate").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "account_id", "amount_cny", "type", "currency", "exchange_rate"}).
			AddRow(uid, uuid.New(), int64(100), "expense", "CNY", 1.0))

	p, _ := json.Marshal(transactionPayload{TxnDate: "bad-date"})
	err := svc.applyTransactionUpdate(context.Background(), tx, uid, eid, string(p))
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "invalid txn_date")
}

// ── applyTransactionDelete ──────────────────────────────────────────────────

func TestApplyTransactionDelete_Success(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	accID := uuid.New()
	mock.ExpectQuery("SELECT user_id, account_id, amount_cny, type").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "account_id", "amount_cny", "type"}).
			AddRow(uid, accID, int64(5000), "expense"))
	mock.ExpectExec("UPDATE transactions SET deleted_at").
		WithArgs(eid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectExec("UPDATE accounts SET balance").
		WithArgs(int64(5000), accID). // revert expense
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	err := svc.applyTransactionDelete(context.Background(), tx, uid, eid)
	assert.NoError(t, err)
}

func TestApplyTransactionDelete_IncomeRevert(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	accID := uuid.New()
	mock.ExpectQuery("SELECT user_id, account_id, amount_cny, type").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "account_id", "amount_cny", "type"}).
			AddRow(uid, accID, int64(10000), "income"))
	mock.ExpectExec("UPDATE transactions SET deleted_at").
		WithArgs(eid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectExec("UPDATE accounts SET balance").
		WithArgs(int64(-10000), accID). // revert income
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	err := svc.applyTransactionDelete(context.Background(), tx, uid, eid)
	assert.NoError(t, err)
}

func TestApplyTransactionDelete_AlreadyDeleted(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id, account_id, amount_cny, type").
		WithArgs(eid).
		WillReturnError(pgx.ErrNoRows)
	err := svc.applyTransactionDelete(context.Background(), tx, uid, eid)
	assert.NoError(t, err) // idempotent
}

func TestApplyTransactionDelete_WrongUser(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id, account_id, amount_cny, type").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "account_id", "amount_cny", "type"}).
			AddRow(uuid.New(), uuid.New(), int64(100), "expense"))
	err := svc.applyTransactionDelete(context.Background(), tx, uid, eid)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "does not belong")
}

// ── applyTransactionOp routing ──────────────────────────────────────────────

func TestApplyTransactionOp_Update(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	accID := uuid.New()
	mock.ExpectQuery("SELECT user_id, account_id, amount_cny, type, currency, exchange_rate").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "account_id", "amount_cny", "type", "currency", "exchange_rate"}).
			AddRow(uid, accID, int64(100), "expense", "CNY", 1.0))
	mock.ExpectExec("UPDATE transactions SET").
		WithArgs("note", eid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	p, _ := json.Marshal(transactionPayload{Note: "note"})
	err := svc.applyTransactionOp(context.Background(), tx, uid, eid, "update", string(p))
	assert.NoError(t, err)
}

func TestApplyTransactionOp_Delete(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id, account_id, amount_cny, type").
		WithArgs(eid).
		WillReturnError(pgx.ErrNoRows)
	err := svc.applyTransactionOp(context.Background(), tx, uid, eid, "delete", "")
	assert.NoError(t, err)
}

func TestApplyTransactionOp_Unknown(t *testing.T) {
	svc, _, tx := newSvc(t)
	err := svc.applyTransactionOp(context.Background(), tx, uid, uuid.New(), "merge", "")
	assert.NoError(t, err)
}

// ── applyTransactionCreate edge cases ───────────────────────────────────────

func TestApplyTransactionCreate_InvalidJSON(t *testing.T) {
	svc, _, tx := newSvc(t)
	err := svc.applyTransactionCreate(context.Background(), tx, uid, uuid.New(), "bad")
	assert.Error(t, err)
}

func TestApplyTransactionCreate_InvalidAccountID(t *testing.T) {
	svc, _, tx := newSvc(t)
	p, _ := json.Marshal(transactionPayload{AccountID: "not-uuid", CategoryID: uuid.New().String()})
	err := svc.applyTransactionCreate(context.Background(), tx, uid, uuid.New(), string(p))
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "invalid account_id")
}

func TestApplyTransactionCreate_InvalidCategoryID(t *testing.T) {
	svc, _, tx := newSvc(t)
	p, _ := json.Marshal(transactionPayload{AccountID: uuid.New().String(), CategoryID: "not-uuid"})
	err := svc.applyTransactionCreate(context.Background(), tx, uid, uuid.New(), string(p))
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "invalid category_id")
}

func TestApplyTransactionCreate_AccountNotFound(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	accID := uuid.New()
	catID := uuid.New()
	mock.ExpectQuery("SELECT user_id, family_id FROM accounts").
		WithArgs(accID).
		WillReturnError(pgx.ErrNoRows)

	p, _ := json.Marshal(transactionPayload{AccountID: accID.String(), CategoryID: catID.String()})
	err := svc.applyTransactionCreate(context.Background(), tx, uid, eid, string(p))
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "account not found")
}

func TestApplyTransactionCreate_AccountWrongUser(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	accID := uuid.New()
	catID := uuid.New()
	// Account owned by different user, no family
	mock.ExpectQuery("SELECT user_id, family_id FROM accounts").
		WithArgs(accID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(uuid.New(), nil))

	p, _ := json.Marshal(transactionPayload{AccountID: accID.String(), CategoryID: catID.String()})
	err := svc.applyTransactionCreate(context.Background(), tx, uid, eid, string(p))
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "does not belong")
}

func TestApplyTransactionCreate_FamilyAccount(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	accID := uuid.New()
	catID := uuid.New()
	famID := uuid.New()
	otherUID := uuid.New()
	// Account owned by someone else but has family_id
	mock.ExpectQuery("SELECT user_id, family_id FROM accounts").
		WithArgs(accID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(otherUID, &famID))
	// Check family membership
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(famID, uid).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))
	// Insert transaction
	mock.ExpectExec("INSERT INTO transactions").
		WithArgs(eid, uid, accID, catID, int64(5000), "CNY", int64(5000), 1.0, "expense",
			"", pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	// Update balance
	mock.ExpectExec("UPDATE accounts SET balance").
		WithArgs(int64(-5000), accID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	p, _ := json.Marshal(transactionPayload{AccountID: accID.String(), CategoryID: catID.String(), Amount: 5000})
	err := svc.applyTransactionCreate(context.Background(), tx, uid, eid, string(p))
	assert.NoError(t, err)
}

func TestApplyTransactionCreate_FamilyNotMember(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	accID := uuid.New()
	catID := uuid.New()
	famID := uuid.New()
	mock.ExpectQuery("SELECT user_id, family_id FROM accounts").
		WithArgs(accID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(uuid.New(), &famID))
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(famID, uid).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(false))

	p, _ := json.Marshal(transactionPayload{AccountID: accID.String(), CategoryID: catID.String()})
	err := svc.applyTransactionCreate(context.Background(), tx, uid, eid, string(p))
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "does not belong")
}

func TestApplyTransactionCreate_IncomeType(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	accID := uuid.New()
	catID := uuid.New()
	mock.ExpectQuery("SELECT user_id, family_id FROM accounts").
		WithArgs(accID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(uid, nil))
	mock.ExpectExec("INSERT INTO transactions").
		WithArgs(eid, uid, accID, catID, int64(8000), "CNY", int64(8000), 1.0, "income",
			"salary", pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	mock.ExpectExec("UPDATE accounts SET balance").
		WithArgs(int64(8000), accID). // income → positive
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	p, _ := json.Marshal(transactionPayload{
		AccountID: accID.String(), CategoryID: catID.String(),
		Amount: 8000, Type: "income", Note: "salary",
	})
	err := svc.applyTransactionCreate(context.Background(), tx, uid, eid, string(p))
	assert.NoError(t, err)
}
