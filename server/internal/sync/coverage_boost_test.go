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
	"github.com/stretchr/testify/require"
)

// ── helpers ─────────────────────────────────────────────────────────────────

func newSvc(t *testing.T) (*Service, pgxmock.PgxPoolIface, pgx.Tx) {
	t.Helper()
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	t.Cleanup(func() { mock.Close() })
	svc := NewService(mock, newTestHub())
	mock.ExpectBegin()
	tx, err := mock.Begin(context.Background())
	require.NoError(t, err)
	return svc, mock, tx
}

var uid = uuid.MustParse(testUserID)

// ── verifyOwnership ─────────────────────────────────────────────────────────

func TestVerifyOwnership_Success(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id FROM loans").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}).AddRow(uid))
	err := svc.verifyOwnership(context.Background(), tx, uid, eid, "loans")
	assert.NoError(t, err)
}

func TestVerifyOwnership_NotFound(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id FROM loans").
		WithArgs(eid).
		WillReturnError(pgx.ErrNoRows)
	err := svc.verifyOwnership(context.Background(), tx, uid, eid, "loans")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
}

func TestVerifyOwnership_WrongUser(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	otherUID := uuid.New()
	mock.ExpectQuery("SELECT user_id FROM loans").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}).AddRow(otherUID))
	err := svc.verifyOwnership(context.Background(), tx, uid, eid, "loans")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "does not belong")
}

func TestVerifyOwnership_DBError(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id FROM loans").
		WithArgs(eid).
		WillReturnError(fmt.Errorf("db down"))
	err := svc.verifyOwnership(context.Background(), tx, uid, eid, "loans")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "failed to fetch")
}

// ── applyLoanUpdate ─────────────────────────────────────────────────────────

func TestApplyLoanUpdate_Success(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id FROM loans").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}).AddRow(uid))
	mock.ExpectExec("UPDATE loans SET").
		WithArgs("新房贷", int64(800000), eid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	p, _ := json.Marshal(loanPayload{Name: "新房贷", RemainingPrincipal: 800000})
	err := svc.applyLoanUpdate(context.Background(), tx, uid, eid, string(p))
	assert.NoError(t, err)
}

func TestApplyLoanUpdate_InvalidJSON(t *testing.T) {
	svc, _, tx := newSvc(t)
	err := svc.applyLoanUpdate(context.Background(), tx, uid, uuid.New(), "bad")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "invalid loan update payload")
}

func TestApplyLoanUpdate_NoFields(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id FROM loans").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}).AddRow(uid))
	mock.ExpectExec("UPDATE loans SET updated_at").
		WithArgs(eid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	p, _ := json.Marshal(loanPayload{})
	err := svc.applyLoanUpdate(context.Background(), tx, uid, eid, string(p))
	assert.NoError(t, err)
}

func TestApplyLoanUpdate_AllFields(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id FROM loans").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}).AddRow(uid))
	mock.ExpectExec("UPDATE loans SET").
		WithArgs("名字", int64(500), 6, 3.5, eid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	p, _ := json.Marshal(loanPayload{Name: "名字", RemainingPrincipal: 500, PaidMonths: 6, AnnualRate: 3.5})
	err := svc.applyLoanUpdate(context.Background(), tx, uid, eid, string(p))
	assert.NoError(t, err)
}

// ── applyLoanOp routing ─────────────────────────────────────────────────────

func TestApplyLoanOp_Update(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id FROM loans").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}).AddRow(uid))
	mock.ExpectExec("UPDATE loans SET updated_at").
		WithArgs(eid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	err := svc.applyLoanOp(context.Background(), tx, uid, eid, "update", "{}")
	assert.NoError(t, err)
}

func TestApplyLoanOp_UnknownOp(t *testing.T) {
	svc, _, tx := newSvc(t)
	err := svc.applyLoanOp(context.Background(), tx, uid, uuid.New(), "merge", "{}")
	assert.NoError(t, err) // logs and returns nil
}

// ── applyLoanCreate edge cases ──────────────────────────────────────────────

func TestApplyLoanCreate_InvalidJSON(t *testing.T) {
	svc, _, tx := newSvc(t)
	err := svc.applyLoanCreate(context.Background(), tx, uid, uuid.New(), "bad")
	assert.Error(t, err)
}

func TestApplyLoanCreate_EmptyName(t *testing.T) {
	svc, _, tx := newSvc(t)
	p, _ := json.Marshal(loanPayload{})
	err := svc.applyLoanCreate(context.Background(), tx, uid, uuid.New(), string(p))
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "name is required")
}

func TestApplyLoanCreate_Defaults(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	// PaymentDay=0 → default 1, LoanType="" → "commercial", RepaymentMethod="" → "equal_payment"
	mock.ExpectExec("INSERT INTO loans").
		WithArgs(eid, uid, "test", "commercial", int64(0), int64(0),
			0.0, 0, 0, "equal_payment", 1, pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	p, _ := json.Marshal(loanPayload{Name: "test"})
	err := svc.applyLoanCreate(context.Background(), tx, uid, eid, string(p))
	assert.NoError(t, err)
}

func TestApplyLoanCreate_WithAccountAndGroup(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	accID := uuid.New()
	grpID := uuid.New()
	mock.ExpectExec("INSERT INTO loans").
		WithArgs(eid, uid, "loan", "commercial", int64(100), int64(90),
			4.0, 12, 1, "equal_payment", 15, pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	p, _ := json.Marshal(loanPayload{
		Name: "loan", Principal: 100, RemainingPrincipal: 90,
		AnnualRate: 4.0, TotalMonths: 12, PaidMonths: 1,
		PaymentDay: 15, AccountID: accID.String(), GroupID: grpID.String(),
	})
	err := svc.applyLoanCreate(context.Background(), tx, uid, eid, string(p))
	assert.NoError(t, err)
}

func TestApplyLoanCreate_DBError(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectExec("INSERT INTO loans").
		WithArgs(eid, uid, "x", "commercial", int64(0), int64(0),
			0.0, 0, 0, "equal_payment", 1, pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnError(fmt.Errorf("constraint"))

	p, _ := json.Marshal(loanPayload{Name: "x"})
	err := svc.applyLoanCreate(context.Background(), tx, uid, eid, string(p))
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "failed to insert loan")
}

// ── applyLoanGroupCreate ────────────────────────────────────────────────────

func TestApplyLoanGroupCreate_Success(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectExec("INSERT INTO loan_groups").
		WithArgs(eid, uid, "组合贷", "commercial_only", int64(2000000), 15, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	p, _ := json.Marshal(loanGroupPayload{Name: "组合贷", TotalPrincipal: 2000000, PaymentDay: 15, StartDate: "2025-06-01"})
	err := svc.applyLoanGroupCreate(context.Background(), tx, uid, eid, string(p))
	assert.NoError(t, err)
}

func TestApplyLoanGroupCreate_InvalidJSON(t *testing.T) {
	svc, _, tx := newSvc(t)
	err := svc.applyLoanGroupCreate(context.Background(), tx, uid, uuid.New(), "bad")
	assert.Error(t, err)
}

func TestApplyLoanGroupCreate_EmptyName(t *testing.T) {
	svc, _, tx := newSvc(t)
	p, _ := json.Marshal(loanGroupPayload{})
	err := svc.applyLoanGroupCreate(context.Background(), tx, uid, uuid.New(), string(p))
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "name is required")
}

func TestApplyLoanGroupCreate_Defaults(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	// PaymentDay=0 → 1, GroupType="" → "commercial_only"
	mock.ExpectExec("INSERT INTO loan_groups").
		WithArgs(eid, uid, "grp", "commercial_only", int64(0), 1, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	p, _ := json.Marshal(loanGroupPayload{Name: "grp"})
	err := svc.applyLoanGroupCreate(context.Background(), tx, uid, eid, string(p))
	assert.NoError(t, err)
}

func TestApplyLoanGroupCreate_DBError(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectExec("INSERT INTO loan_groups").
		WithArgs(eid, uid, "x", "commercial_only", int64(0), 1, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnError(fmt.Errorf("dup"))

	p, _ := json.Marshal(loanGroupPayload{Name: "x"})
	err := svc.applyLoanGroupCreate(context.Background(), tx, uid, eid, string(p))
	assert.Error(t, err)
}

// ── applyLoanGroupUpdate ────────────────────────────────────────────────────

func TestApplyLoanGroupUpdate_Success(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id FROM loan_groups").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}).AddRow(uid))
	mock.ExpectExec("UPDATE loan_groups SET").
		WithArgs("新名字", int64(3000000), eid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	p, _ := json.Marshal(loanGroupPayload{Name: "新名字", TotalPrincipal: 3000000})
	err := svc.applyLoanGroupUpdate(context.Background(), tx, uid, eid, string(p))
	assert.NoError(t, err)
}

func TestApplyLoanGroupUpdate_InvalidJSON(t *testing.T) {
	svc, _, tx := newSvc(t)
	err := svc.applyLoanGroupUpdate(context.Background(), tx, uid, uuid.New(), "bad")
	assert.Error(t, err)
}

func TestApplyLoanGroupUpdate_NoFields(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id FROM loan_groups").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}).AddRow(uid))
	mock.ExpectExec("UPDATE loan_groups SET updated_at").
		WithArgs(eid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	p, _ := json.Marshal(loanGroupPayload{})
	err := svc.applyLoanGroupUpdate(context.Background(), tx, uid, eid, string(p))
	assert.NoError(t, err)
}

// ── applyLoanGroupOp routing ────────────────────────────────────────────────

func TestApplyLoanGroupOp_Create(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectExec("INSERT INTO loan_groups").
		WithArgs(eid, uid, "grp", "commercial_only", int64(0), 1, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	p, _ := json.Marshal(loanGroupPayload{Name: "grp"})
	err := svc.applyLoanGroupOp(context.Background(), tx, uid, eid, "create", string(p))
	assert.NoError(t, err)
}

func TestApplyLoanGroupOp_Update(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id FROM loan_groups").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}).AddRow(uid))
	mock.ExpectExec("UPDATE loan_groups SET updated_at").
		WithArgs(eid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	err := svc.applyLoanGroupOp(context.Background(), tx, uid, eid, "update", "{}")
	assert.NoError(t, err)
}

func TestApplyLoanGroupOp_Delete(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectExec("UPDATE loan_groups SET deleted_at").
		WithArgs(eid, uid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	err := svc.applyLoanGroupOp(context.Background(), tx, uid, eid, "delete", "")
	assert.NoError(t, err)
}

func TestApplyLoanGroupOp_Unknown(t *testing.T) {
	svc, _, tx := newSvc(t)
	err := svc.applyLoanGroupOp(context.Background(), tx, uid, uuid.New(), "merge", "")
	assert.NoError(t, err)
}

// ── applyInvestmentUpdate ───────────────────────────────────────────────────

func TestApplyInvestmentUpdate_Success(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id FROM investments").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}).AddRow(uid))
	mock.ExpectExec("UPDATE investments SET").
		WithArgs("新名字", 200.0, int64(360000), eid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	p, _ := json.Marshal(investmentPayload{Name: "新名字", Quantity: 200, CostBasis: 360000})
	err := svc.applyInvestmentUpdate(context.Background(), tx, uid, eid, string(p))
	assert.NoError(t, err)
}

func TestApplyInvestmentUpdate_InvalidJSON(t *testing.T) {
	svc, _, tx := newSvc(t)
	err := svc.applyInvestmentUpdate(context.Background(), tx, uid, uuid.New(), "bad")
	assert.Error(t, err)
}

func TestApplyInvestmentUpdate_NoFields(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id FROM investments").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}).AddRow(uid))
	mock.ExpectExec("UPDATE investments SET updated_at").
		WithArgs(eid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	err := svc.applyInvestmentUpdate(context.Background(), tx, uid, eid, "{}")
	assert.NoError(t, err)
}

// ── applyInvestmentOp routing ───────────────────────────────────────────────

func TestApplyInvestmentOp_Update(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id FROM investments").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}).AddRow(uid))
	mock.ExpectExec("UPDATE investments SET updated_at").
		WithArgs(eid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	err := svc.applyInvestmentOp(context.Background(), tx, uid, eid, "update", "{}")
	assert.NoError(t, err)
}

func TestApplyInvestmentOp_Unknown(t *testing.T) {
	svc, _, tx := newSvc(t)
	err := svc.applyInvestmentOp(context.Background(), tx, uid, uuid.New(), "merge", "")
	assert.NoError(t, err)
}

// ── applyFixedAssetCreate ───────────────────────────────────────────────────

func TestApplyFixedAssetCreate_Success(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectExec("INSERT INTO fixed_assets").
		WithArgs(eid, uid, "房产", "real_estate", int64(5000000), int64(6000000), pgxmock.AnyArg(), "一套房").
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	p, _ := json.Marshal(fixedAssetPayload{
		Name: "房产", AssetType: "real_estate", PurchasePrice: 5000000,
		CurrentValue: 6000000, PurchaseDate: "2020-01-01", Description: "一套房",
	})
	err := svc.applyFixedAssetCreate(context.Background(), tx, uid, eid, string(p))
	assert.NoError(t, err)
}

func TestApplyFixedAssetCreate_InvalidJSON(t *testing.T) {
	svc, _, tx := newSvc(t)
	err := svc.applyFixedAssetCreate(context.Background(), tx, uid, uuid.New(), "bad")
	assert.Error(t, err)
}

func TestApplyFixedAssetCreate_EmptyName(t *testing.T) {
	svc, _, tx := newSvc(t)
	p, _ := json.Marshal(fixedAssetPayload{})
	err := svc.applyFixedAssetCreate(context.Background(), tx, uid, uuid.New(), string(p))
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "name is required")
}

func TestApplyFixedAssetCreate_Defaults(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectExec("INSERT INTO fixed_assets").
		WithArgs(eid, uid, "car", "other", int64(0), int64(0), pgxmock.AnyArg(), "").
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	p, _ := json.Marshal(fixedAssetPayload{Name: "car"})
	err := svc.applyFixedAssetCreate(context.Background(), tx, uid, eid, string(p))
	assert.NoError(t, err)
}

func TestApplyFixedAssetCreate_DBError(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectExec("INSERT INTO fixed_assets").
		WithArgs(eid, uid, "x", "other", int64(0), int64(0), pgxmock.AnyArg(), "").
		WillReturnError(fmt.Errorf("err"))

	p, _ := json.Marshal(fixedAssetPayload{Name: "x"})
	err := svc.applyFixedAssetCreate(context.Background(), tx, uid, eid, string(p))
	assert.Error(t, err)
}

// ── applyFixedAssetUpdate ───────────────────────────────────────────────────

func TestApplyFixedAssetUpdate_Success(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id FROM fixed_assets").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}).AddRow(uid))
	mock.ExpectExec("UPDATE fixed_assets SET").
		WithArgs("新名字", int64(7000000), eid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	p, _ := json.Marshal(fixedAssetPayload{Name: "新名字", CurrentValue: 7000000})
	err := svc.applyFixedAssetUpdate(context.Background(), tx, uid, eid, string(p))
	assert.NoError(t, err)
}

func TestApplyFixedAssetUpdate_InvalidJSON(t *testing.T) {
	svc, _, tx := newSvc(t)
	err := svc.applyFixedAssetUpdate(context.Background(), tx, uid, uuid.New(), "bad")
	assert.Error(t, err)
}

func TestApplyFixedAssetUpdate_NoFields(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id FROM fixed_assets").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}).AddRow(uid))
	mock.ExpectExec("UPDATE fixed_assets SET updated_at").
		WithArgs(eid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	err := svc.applyFixedAssetUpdate(context.Background(), tx, uid, eid, "{}")
	assert.NoError(t, err)
}

// ── applyFixedAssetOp routing ───────────────────────────────────────────────

func TestApplyFixedAssetOp_Create(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectExec("INSERT INTO fixed_assets").
		WithArgs(eid, uid, "car", "other", int64(0), int64(0), pgxmock.AnyArg(), "").
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	p, _ := json.Marshal(fixedAssetPayload{Name: "car"})
	err := svc.applyFixedAssetOp(context.Background(), tx, uid, eid, "create", string(p))
	assert.NoError(t, err)
}

func TestApplyFixedAssetOp_Update(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectQuery("SELECT user_id FROM fixed_assets").
		WithArgs(eid).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}).AddRow(uid))
	mock.ExpectExec("UPDATE fixed_assets SET updated_at").
		WithArgs(eid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	err := svc.applyFixedAssetOp(context.Background(), tx, uid, eid, "update", "{}")
	assert.NoError(t, err)
}

func TestApplyFixedAssetOp_Delete(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectExec("UPDATE fixed_assets SET deleted_at").
		WithArgs(eid, uid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	err := svc.applyFixedAssetOp(context.Background(), tx, uid, eid, "delete", "")
	assert.NoError(t, err)
}

func TestApplyFixedAssetOp_Unknown(t *testing.T) {
	svc, _, tx := newSvc(t)
	err := svc.applyFixedAssetOp(context.Background(), tx, uid, uuid.New(), "merge", "")
	assert.NoError(t, err)
}

// ── applyBudgetUpdate ───────────────────────────────────────────────────────

func TestApplyBudgetUpdate_Success(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectExec("UPDATE budgets SET total_amount").
		WithArgs(int64(600000), eid, uid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	p, _ := json.Marshal(budgetPayload{TotalAmount: 600000})
	err := svc.applyBudgetUpdate(context.Background(), tx, uid, eid, string(p))
	assert.NoError(t, err)
}

func TestApplyBudgetUpdate_InvalidJSON(t *testing.T) {
	svc, _, tx := newSvc(t)
	err := svc.applyBudgetUpdate(context.Background(), tx, uid, uuid.New(), "bad")
	assert.Error(t, err)
}

func TestApplyBudgetUpdate_ZeroAmount(t *testing.T) {
	svc, _, tx := newSvc(t)
	p, _ := json.Marshal(budgetPayload{TotalAmount: 0})
	err := svc.applyBudgetUpdate(context.Background(), tx, uid, uuid.New(), string(p))
	assert.NoError(t, err) // nothing to update
}

func TestApplyBudgetUpdate_DBError(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectExec("UPDATE budgets SET total_amount").
		WithArgs(int64(100), eid, uid).
		WillReturnError(fmt.Errorf("err"))

	p, _ := json.Marshal(budgetPayload{TotalAmount: 100})
	err := svc.applyBudgetUpdate(context.Background(), tx, uid, eid, string(p))
	assert.Error(t, err)
}

// ── applyBudgetOp routing ───────────────────────────────────────────────────

func TestApplyBudgetOp_CreateRouting(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectExec("INSERT INTO budgets").
		WithArgs(eid, uid, pgxmock.AnyArg(), int32(2026), int32(5), int64(100000)).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	p, _ := json.Marshal(budgetPayload{Year: 2026, Month: 5, TotalAmount: 100000})
	err := svc.applyBudgetOp(context.Background(), tx, uid, eid, "create", string(p))
	assert.NoError(t, err)
}

func TestApplyBudgetOp_Update(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectExec("UPDATE budgets SET total_amount").
		WithArgs(int64(200000), eid, uid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	p, _ := json.Marshal(budgetPayload{TotalAmount: 200000})
	err := svc.applyBudgetOp(context.Background(), tx, uid, eid, "update", string(p))
	assert.NoError(t, err)
}

func TestApplyBudgetOp_Delete(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectExec("DELETE FROM budgets WHERE").
		WithArgs(eid, uid).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))
	err := svc.applyBudgetOp(context.Background(), tx, uid, eid, "delete", "")
	assert.NoError(t, err)
}

func TestApplyBudgetOp_DeleteError(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectExec("DELETE FROM budgets WHERE").
		WithArgs(eid, uid).
		WillReturnError(fmt.Errorf("err"))
	err := svc.applyBudgetOp(context.Background(), tx, uid, eid, "delete", "")
	assert.Error(t, err)
}

func TestApplyBudgetOp_Unknown(t *testing.T) {
	svc, _, tx := newSvc(t)
	err := svc.applyBudgetOp(context.Background(), tx, uid, uuid.New(), "merge", "")
	assert.NoError(t, err)
}

// ── applyBudgetCreate edge cases ────────────────────────────────────────────

func TestApplyBudgetCreate_InvalidJSON(t *testing.T) {
	svc, _, tx := newSvc(t)
	err := svc.applyBudgetCreate(context.Background(), tx, uid, uuid.New(), "bad")
	assert.Error(t, err)
}

func TestApplyBudgetCreate_MissingFields(t *testing.T) {
	svc, _, tx := newSvc(t)
	p, _ := json.Marshal(budgetPayload{Year: 2026})
	err := svc.applyBudgetCreate(context.Background(), tx, uid, uuid.New(), string(p))
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "required")
}

func TestApplyBudgetCreate_WithFamilyID(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	famID := uuid.New()
	mock.ExpectExec("INSERT INTO budgets").
		WithArgs(eid, uid, pgxmock.AnyArg(), int32(2026), int32(6), int64(300000)).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	p, _ := json.Marshal(budgetPayload{Year: 2026, Month: 6, TotalAmount: 300000, FamilyID: famID.String()})
	err := svc.applyBudgetCreate(context.Background(), tx, uid, eid, string(p))
	assert.NoError(t, err)
}

func TestApplyBudgetCreate_DBError(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectExec("INSERT INTO budgets").
		WithArgs(eid, uid, pgxmock.AnyArg(), int32(2026), int32(7), int64(100)).
		WillReturnError(fmt.Errorf("dup"))

	p, _ := json.Marshal(budgetPayload{Year: 2026, Month: 7, TotalAmount: 100})
	err := svc.applyBudgetCreate(context.Background(), tx, uid, eid, string(p))
	assert.Error(t, err)
}

// ── applyInvestmentCreate edge cases ────────────────────────────────────────

func TestApplyInvestmentCreate_InvalidJSON(t *testing.T) {
	svc, _, tx := newSvc(t)
	err := svc.applyInvestmentCreate(context.Background(), tx, uid, uuid.New(), "bad")
	assert.Error(t, err)
}

func TestApplyInvestmentCreate_MissingFields(t *testing.T) {
	svc, _, tx := newSvc(t)
	p, _ := json.Marshal(investmentPayload{Symbol: "600519"})
	err := svc.applyInvestmentCreate(context.Background(), tx, uid, uuid.New(), string(p))
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "required")
}

func TestApplyInvestmentCreate_DefaultMarketType(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectExec("INSERT INTO investments").
		WithArgs(eid, uid, "BTC", "Bitcoin", "a_share", 0.0, int64(0)).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	p, _ := json.Marshal(investmentPayload{Symbol: "BTC", Name: "Bitcoin"})
	err := svc.applyInvestmentCreate(context.Background(), tx, uid, eid, string(p))
	assert.NoError(t, err)
}

func TestApplyInvestmentCreate_DBError(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectExec("INSERT INTO investments").
		WithArgs(eid, uid, "X", "Y", "a_share", 0.0, int64(0)).
		WillReturnError(fmt.Errorf("err"))

	p, _ := json.Marshal(investmentPayload{Symbol: "X", Name: "Y"})
	err := svc.applyInvestmentCreate(context.Background(), tx, uid, eid, string(p))
	assert.Error(t, err)
}

// ── applyGenericSoftDelete edge cases ───────────────────────────────────────

func TestApplyGenericSoftDelete_ZeroRows(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectExec("UPDATE investments SET deleted_at").
		WithArgs(eid, uid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 0))
	// Should not error, just logs
	err := svc.applyGenericSoftDelete(context.Background(), tx, uid, eid, "investments")
	assert.NoError(t, err)
}

func TestApplyGenericSoftDelete_DBError(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	mock.ExpectExec("UPDATE loans SET deleted_at").
		WithArgs(eid, uid).
		WillReturnError(fmt.Errorf("err"))
	err := svc.applyGenericSoftDelete(context.Background(), tx, uid, eid, "loans")
	assert.Error(t, err)
}

// ── nilIfEmpty ──────────────────────────────────────────────────────────────

func TestNilIfEmpty_Empty(t *testing.T) {
	assert.Nil(t, nilIfEmpty(""))
}

func TestNilIfEmpty_Invalid(t *testing.T) {
	assert.Nil(t, nilIfEmpty("not-a-uuid"))
}

func TestNilIfEmpty_Valid(t *testing.T) {
	id := uuid.New()
	result := nilIfEmpty(id.String())
	assert.Equal(t, id, result)
}

// ── applyOperation routing (remaining branches) ─────────────────────────────

func TestApplyOperation_Account(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	p, _ := json.Marshal(accountPayload{Name: "test", Type: "cash"})
	mock.ExpectExec("INSERT INTO accounts").
		WithArgs(eid, uid, "test", "cash", int64(0), "CNY", "", pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	err := svc.applyOperation(context.Background(), tx, uid, "account", eid, "create", string(p))
	assert.NoError(t, err)
}

func TestApplyOperation_Category(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	p, _ := json.Marshal(categoryPayload{Name: "test", Type: "expense"})
	mock.ExpectExec("INSERT INTO categories").
		WithArgs(eid, "test", "", "", "expense", 0, uid, pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	err := svc.applyOperation(context.Background(), tx, uid, "category", eid, "create", string(p))
	assert.NoError(t, err)
}

func TestApplyOperation_Loan(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	p, _ := json.Marshal(loanPayload{Name: "test"})
	mock.ExpectExec("INSERT INTO loans").
		WithArgs(eid, uid, "test", "commercial", int64(0), int64(0),
			0.0, 0, 0, "equal_payment", 1, pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	err := svc.applyOperation(context.Background(), tx, uid, "loan", eid, "create", string(p))
	assert.NoError(t, err)
}

func TestApplyOperation_LoanGroup(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	p, _ := json.Marshal(loanGroupPayload{Name: "grp"})
	mock.ExpectExec("INSERT INTO loan_groups").
		WithArgs(eid, uid, "grp", "commercial_only", int64(0), 1, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	err := svc.applyOperation(context.Background(), tx, uid, "loan_group", eid, "create", string(p))
	assert.NoError(t, err)
}

func TestApplyOperation_Investment(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	p, _ := json.Marshal(investmentPayload{Symbol: "X", Name: "Y"})
	mock.ExpectExec("INSERT INTO investments").
		WithArgs(eid, uid, "X", "Y", "a_share", 0.0, int64(0)).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	err := svc.applyOperation(context.Background(), tx, uid, "investment", eid, "create", string(p))
	assert.NoError(t, err)
}

func TestApplyOperation_FixedAsset(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	p, _ := json.Marshal(fixedAssetPayload{Name: "car"})
	mock.ExpectExec("INSERT INTO fixed_assets").
		WithArgs(eid, uid, "car", "other", int64(0), int64(0), pgxmock.AnyArg(), "").
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	err := svc.applyOperation(context.Background(), tx, uid, "fixed_asset", eid, "create", string(p))
	assert.NoError(t, err)
}

func TestApplyOperation_Budget(t *testing.T) {
	svc, mock, tx := newSvc(t)
	eid := uuid.New()
	p, _ := json.Marshal(budgetPayload{Year: 2026, Month: 1, TotalAmount: 50000})
	mock.ExpectExec("INSERT INTO budgets").
		WithArgs(eid, uid, pgxmock.AnyArg(), int32(2026), int32(1), int64(50000)).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	err := svc.applyOperation(context.Background(), tx, uid, "budget", eid, "create", string(p))
	assert.NoError(t, err)
}
