package sync

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/google/uuid"
	pgxmock "github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestApplyLoanOp_Create(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	hub := newTestHub()
	svc := NewService(mock, hub)
	userUID := uuid.MustParse(testUserID)
	entityID := uuid.New()

	payload := loanPayload{
		Name:             "房贷",
		LoanType:         "commercial",
		Principal:        1000000,
		RemainingPrincipal: 900000,
		AnnualRate:       4.5,
		TotalMonths:      360,
		PaidMonths:       12,
		RepaymentMethod:  "equal_payment",
		PaymentDay:       15,
		StartDate:        "2025-01-01",
	}
	payloadJSON, _ := json.Marshal(payload)

	mock.ExpectBegin()
	tx, err := mock.Begin(context.Background())
	require.NoError(t, err)

	mock.ExpectExec("INSERT INTO loans").
		WithArgs(entityID, userUID, "房贷", "commercial", int64(1000000), int64(900000),
			4.5, 360, 12, "equal_payment", 15, pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	err = svc.applyLoanCreate(context.Background(), tx, userUID, entityID, string(payloadJSON))
	require.NoError(t, err)
}

func TestApplyLoanOp_Delete(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	hub := newTestHub()
	svc := NewService(mock, hub)
	userUID := uuid.MustParse(testUserID)
	entityID := uuid.New()

	mock.ExpectBegin()
	tx, err := mock.Begin(context.Background())
	require.NoError(t, err)

	mock.ExpectExec("UPDATE loans SET deleted_at").
		WithArgs(entityID, userUID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	err = svc.applyGenericSoftDelete(context.Background(), tx, userUID, entityID, "loans")
	require.NoError(t, err)
}

func TestApplyInvestmentOp_Create(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	hub := newTestHub()
	svc := NewService(mock, hub)
	userUID := uuid.MustParse(testUserID)
	entityID := uuid.New()

	payload := investmentPayload{
		Symbol:     "600519",
		Name:       "贵州茅台",
		MarketType: "a_share",
		Quantity:   100.0,
		CostBasis:  1800000,
	}
	payloadJSON, _ := json.Marshal(payload)

	mock.ExpectBegin()
	tx, err := mock.Begin(context.Background())
	require.NoError(t, err)

	mock.ExpectExec("INSERT INTO investments").
		WithArgs(entityID, userUID, "600519", "贵州茅台", "a_share", 100.0, int64(1800000)).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	err = svc.applyInvestmentCreate(context.Background(), tx, userUID, entityID, string(payloadJSON))
	require.NoError(t, err)
}

func TestApplyInvestmentOp_Delete(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	hub := newTestHub()
	svc := NewService(mock, hub)
	userUID := uuid.MustParse(testUserID)
	entityID := uuid.New()

	mock.ExpectBegin()
	tx, err := mock.Begin(context.Background())
	require.NoError(t, err)

	mock.ExpectExec("UPDATE investments SET deleted_at").
		WithArgs(entityID, userUID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	err = svc.applyGenericSoftDelete(context.Background(), tx, userUID, entityID, "investments")
	require.NoError(t, err)
}

func TestApplyBudgetOp_Create(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	hub := newTestHub()
	svc := NewService(mock, hub)
	userUID := uuid.MustParse(testUserID)
	entityID := uuid.New()

	payload := budgetPayload{
		Year:        2026,
		Month:       4,
		TotalAmount: 500000,
	}
	payloadJSON, _ := json.Marshal(payload)

	mock.ExpectBegin()
	tx, err := mock.Begin(context.Background())
	require.NoError(t, err)

	mock.ExpectExec("INSERT INTO budgets").
		WithArgs(entityID, userUID, pgxmock.AnyArg(), int32(2026), int32(4), int64(500000)).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	err = svc.applyBudgetCreate(context.Background(), tx, userUID, entityID, string(payloadJSON))
	require.NoError(t, err)
}

func TestApplyOperation_UnknownEntityType(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	hub := newTestHub()
	svc := NewService(mock, hub)
	userUID := uuid.MustParse(testUserID)
	entityID := uuid.New()

	mock.ExpectBegin()
	tx, err := mock.Begin(context.Background())
	require.NoError(t, err)

	// Unknown entity type should not error (returns nil, logs warning)
	err = svc.applyOperation(context.Background(), tx, userUID, "unknown_type", entityID, "create", "{}")
	assert.NoError(t, err)
}
