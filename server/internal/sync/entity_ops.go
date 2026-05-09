package sync

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

// ── Loan sync operations ────────────────────────────────────────────────────

type loanPayload struct {
	Name             string  `json:"name"`
	LoanType         string  `json:"loan_type"`
	Principal        int64   `json:"principal"`
	RemainingPrincipal int64 `json:"remaining_principal"`
	AnnualRate       float64 `json:"annual_rate"`
	TotalMonths      int     `json:"total_months"`
	PaidMonths       int     `json:"paid_months"`
	RepaymentMethod  string  `json:"repayment_method"`
	PaymentDay       int     `json:"payment_day"`
	StartDate        string  `json:"start_date"`
	AccountID        string  `json:"account_id"`
	GroupID          string  `json:"group_id"`
}

func (s *Service) applyLoanOp(ctx context.Context, tx pgx.Tx, userID uuid.UUID, entityID uuid.UUID, opType string, payload string) error {
	switch opType {
	case "create":
		return s.applyLoanCreate(ctx, tx, userID, entityID, payload)
	case "update":
		return s.applyLoanUpdate(ctx, tx, userID, entityID, payload)
	case "delete":
		return s.applyGenericSoftDelete(ctx, tx, userID, entityID, "loans")
	default:
		log.Printf("sync: unknown op_type %q for loan, skipping", opType)
		return nil
	}
}

func (s *Service) applyLoanCreate(ctx context.Context, tx pgx.Tx, userID uuid.UUID, entityID uuid.UUID, payload string) error {
	var p loanPayload
	if err := json.Unmarshal([]byte(payload), &p); err != nil {
		return fmt.Errorf("invalid loan create payload: %w", err)
	}

	if p.Name == "" {
		return fmt.Errorf("loan name is required")
	}
	if p.PaymentDay < 1 || p.PaymentDay > 28 {
		p.PaymentDay = 1
	}

	startDate := time.Now()
	if p.StartDate != "" {
		if parsed, err := time.Parse("2006-01-02", p.StartDate); err == nil {
			startDate = parsed
		}
	}

	var accountID *uuid.UUID
	if p.AccountID != "" {
		aid, err := uuid.Parse(p.AccountID)
		if err == nil {
			accountID = &aid
		}
	}

	var groupID *uuid.UUID
	if p.GroupID != "" {
		gid, err := uuid.Parse(p.GroupID)
		if err == nil {
			groupID = &gid
		}
	}

	loanType := p.LoanType
	if loanType == "" {
		loanType = "commercial"
	}
	repaymentMethod := p.RepaymentMethod
	if repaymentMethod == "" {
		repaymentMethod = "equal_payment"
	}

	_, err := tx.Exec(ctx,
		`INSERT INTO loans (id, user_id, name, loan_type, principal, remaining_principal, annual_rate,
		 total_months, paid_months, repayment_method, payment_day, start_date, account_id, group_id)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)`,
		entityID, userID, p.Name, loanType, p.Principal, p.RemainingPrincipal,
		p.AnnualRate, p.TotalMonths, p.PaidMonths, repaymentMethod, p.PaymentDay,
		startDate, accountID, groupID,
	)
	if err != nil {
		return fmt.Errorf("failed to insert loan: %w", err)
	}
	return nil
}

func (s *Service) applyLoanUpdate(ctx context.Context, tx pgx.Tx, userID uuid.UUID, entityID uuid.UUID, payload string) error {
	var p loanPayload
	if err := json.Unmarshal([]byte(payload), &p); err != nil {
		return fmt.Errorf("invalid loan update payload: %w", err)
	}

	// Verify ownership
	if err := s.verifyOwnership(ctx, tx, userID, entityID, "loans"); err != nil {
		return err
	}

	setClauses := []string{"updated_at = NOW()"}
	args := []interface{}{}
	argIdx := 1

	if p.Name != "" {
		args = append(args, p.Name)
		setClauses = append(setClauses, fmt.Sprintf("name = $%d", argIdx))
		argIdx++
	}
	if p.RemainingPrincipal > 0 {
		args = append(args, p.RemainingPrincipal)
		setClauses = append(setClauses, fmt.Sprintf("remaining_principal = $%d", argIdx))
		argIdx++
	}
	if p.PaidMonths > 0 {
		args = append(args, p.PaidMonths)
		setClauses = append(setClauses, fmt.Sprintf("paid_months = $%d", argIdx))
		argIdx++
	}
	if p.AnnualRate > 0 {
		args = append(args, p.AnnualRate)
		setClauses = append(setClauses, fmt.Sprintf("annual_rate = $%d", argIdx))
		argIdx++
	}

	if len(args) == 0 {
		_, err := tx.Exec(ctx, "UPDATE loans SET updated_at = NOW() WHERE id = $1", entityID)
		return err
	}

	args = append(args, entityID)
	query := fmt.Sprintf("UPDATE loans SET %s WHERE id = $%d AND deleted_at IS NULL",
		strings.Join(setClauses, ", "), argIdx)
	_, err := tx.Exec(ctx, query, args...)
	if err != nil {
		return fmt.Errorf("failed to update loan: %w", err)
	}
	return nil
}

// ── Loan Group sync operations ──────────────────────────────────────────────

type loanGroupPayload struct {
	Name           string `json:"name"`
	GroupType      string `json:"group_type"`
	TotalPrincipal int64  `json:"total_principal"`
	PaymentDay     int    `json:"payment_day"`
	StartDate      string `json:"start_date"`
	AccountID      string `json:"account_id"`
}

func (s *Service) applyLoanGroupOp(ctx context.Context, tx pgx.Tx, userID uuid.UUID, entityID uuid.UUID, opType string, payload string) error {
	switch opType {
	case "create":
		return s.applyLoanGroupCreate(ctx, tx, userID, entityID, payload)
	case "update":
		return s.applyLoanGroupUpdate(ctx, tx, userID, entityID, payload)
	case "delete":
		return s.applyGenericSoftDelete(ctx, tx, userID, entityID, "loan_groups")
	default:
		log.Printf("sync: unknown op_type %q for loan_group, skipping", opType)
		return nil
	}
}

func (s *Service) applyLoanGroupCreate(ctx context.Context, tx pgx.Tx, userID uuid.UUID, entityID uuid.UUID, payload string) error {
	var p loanGroupPayload
	if err := json.Unmarshal([]byte(payload), &p); err != nil {
		return fmt.Errorf("invalid loan_group create payload: %w", err)
	}

	if p.Name == "" {
		return fmt.Errorf("loan_group name is required")
	}
	if p.PaymentDay < 1 || p.PaymentDay > 28 {
		p.PaymentDay = 1
	}

	startDate := time.Now()
	if p.StartDate != "" {
		if parsed, err := time.Parse("2006-01-02", p.StartDate); err == nil {
			startDate = parsed
		}
	}

	groupType := p.GroupType
	if groupType == "" {
		groupType = "commercial_only"
	}

	var accountID *uuid.UUID
	if p.AccountID != "" {
		aid, err := uuid.Parse(p.AccountID)
		if err == nil {
			accountID = &aid
		}
	}

	_, err := tx.Exec(ctx,
		`INSERT INTO loan_groups (id, user_id, name, group_type, total_principal, payment_day, start_date, account_id)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
		entityID, userID, p.Name, groupType, p.TotalPrincipal, p.PaymentDay, startDate, accountID,
	)
	if err != nil {
		return fmt.Errorf("failed to insert loan_group: %w", err)
	}
	return nil
}

func (s *Service) applyLoanGroupUpdate(ctx context.Context, tx pgx.Tx, userID uuid.UUID, entityID uuid.UUID, payload string) error {
	var p loanGroupPayload
	if err := json.Unmarshal([]byte(payload), &p); err != nil {
		return fmt.Errorf("invalid loan_group update payload: %w", err)
	}

	if err := s.verifyOwnership(ctx, tx, userID, entityID, "loan_groups"); err != nil {
		return err
	}

	setClauses := []string{"updated_at = NOW()"}
	args := []interface{}{}
	argIdx := 1

	if p.Name != "" {
		args = append(args, p.Name)
		setClauses = append(setClauses, fmt.Sprintf("name = $%d", argIdx))
		argIdx++
	}
	if p.TotalPrincipal > 0 {
		args = append(args, p.TotalPrincipal)
		setClauses = append(setClauses, fmt.Sprintf("total_principal = $%d", argIdx))
		argIdx++
	}

	if len(args) == 0 {
		_, err := tx.Exec(ctx, "UPDATE loan_groups SET updated_at = NOW() WHERE id = $1", entityID)
		return err
	}

	args = append(args, entityID)
	query := fmt.Sprintf("UPDATE loan_groups SET %s WHERE id = $%d AND deleted_at IS NULL",
		strings.Join(setClauses, ", "), argIdx)
	_, err := tx.Exec(ctx, query, args...)
	if err != nil {
		return fmt.Errorf("failed to update loan_group: %w", err)
	}
	return nil
}

// ── Investment sync operations ──────────────────────────────────────────────

type investmentPayload struct {
	Symbol     string  `json:"symbol"`
	Name       string  `json:"name"`
	MarketType string  `json:"market_type"`
	Quantity   float64 `json:"quantity"`
	CostBasis  int64   `json:"cost_basis"`
}

func (s *Service) applyInvestmentOp(ctx context.Context, tx pgx.Tx, userID uuid.UUID, entityID uuid.UUID, opType string, payload string) error {
	switch opType {
	case "create":
		return s.applyInvestmentCreate(ctx, tx, userID, entityID, payload)
	case "update":
		return s.applyInvestmentUpdate(ctx, tx, userID, entityID, payload)
	case "delete":
		return s.applyGenericSoftDelete(ctx, tx, userID, entityID, "investments")
	default:
		log.Printf("sync: unknown op_type %q for investment, skipping", opType)
		return nil
	}
}

func (s *Service) applyInvestmentCreate(ctx context.Context, tx pgx.Tx, userID uuid.UUID, entityID uuid.UUID, payload string) error {
	var p investmentPayload
	if err := json.Unmarshal([]byte(payload), &p); err != nil {
		return fmt.Errorf("invalid investment create payload: %w", err)
	}

	if p.Symbol == "" || p.Name == "" {
		return fmt.Errorf("investment symbol and name are required")
	}
	if p.MarketType == "" {
		p.MarketType = "a_share"
	}

	_, err := tx.Exec(ctx,
		`INSERT INTO investments (id, user_id, symbol, name, market_type, quantity, cost_basis)
		 VALUES ($1, $2, $3, $4, $5, $6, $7)
		 ON CONFLICT (user_id, symbol, market_type) DO UPDATE SET
		   name = EXCLUDED.name, quantity = EXCLUDED.quantity, cost_basis = EXCLUDED.cost_basis, updated_at = NOW(), deleted_at = NULL`,
		entityID, userID, p.Symbol, p.Name, p.MarketType, p.Quantity, p.CostBasis,
	)
	if err != nil {
		return fmt.Errorf("failed to insert investment: %w", err)
	}
	return nil
}

func (s *Service) applyInvestmentUpdate(ctx context.Context, tx pgx.Tx, userID uuid.UUID, entityID uuid.UUID, payload string) error {
	var p investmentPayload
	if err := json.Unmarshal([]byte(payload), &p); err != nil {
		return fmt.Errorf("invalid investment update payload: %w", err)
	}

	if err := s.verifyOwnership(ctx, tx, userID, entityID, "investments"); err != nil {
		return err
	}

	setClauses := []string{"updated_at = NOW()"}
	args := []interface{}{}
	argIdx := 1

	if p.Name != "" {
		args = append(args, p.Name)
		setClauses = append(setClauses, fmt.Sprintf("name = $%d", argIdx))
		argIdx++
	}
	if p.Quantity != 0 {
		args = append(args, p.Quantity)
		setClauses = append(setClauses, fmt.Sprintf("quantity = $%d", argIdx))
		argIdx++
	}
	if p.CostBasis != 0 {
		args = append(args, p.CostBasis)
		setClauses = append(setClauses, fmt.Sprintf("cost_basis = $%d", argIdx))
		argIdx++
	}

	if len(args) == 0 {
		_, err := tx.Exec(ctx, "UPDATE investments SET updated_at = NOW() WHERE id = $1", entityID)
		return err
	}

	args = append(args, entityID)
	query := fmt.Sprintf("UPDATE investments SET %s WHERE id = $%d AND deleted_at IS NULL",
		strings.Join(setClauses, ", "), argIdx)
	_, err := tx.Exec(ctx, query, args...)
	if err != nil {
		return fmt.Errorf("failed to update investment: %w", err)
	}
	return nil
}

// ── Fixed Asset sync operations ─────────────────────────────────────────────

type fixedAssetPayload struct {
	Name          string `json:"name"`
	AssetType     string `json:"asset_type"`
	PurchasePrice int64  `json:"purchase_price"`
	CurrentValue  int64  `json:"current_value"`
	PurchaseDate  string `json:"purchase_date"`
	Description   string `json:"description"`
}

func (s *Service) applyFixedAssetOp(ctx context.Context, tx pgx.Tx, userID uuid.UUID, entityID uuid.UUID, opType string, payload string) error {
	switch opType {
	case "create":
		return s.applyFixedAssetCreate(ctx, tx, userID, entityID, payload)
	case "update":
		return s.applyFixedAssetUpdate(ctx, tx, userID, entityID, payload)
	case "delete":
		return s.applyGenericSoftDelete(ctx, tx, userID, entityID, "fixed_assets")
	default:
		log.Printf("sync: unknown op_type %q for fixed_asset, skipping", opType)
		return nil
	}
}

func (s *Service) applyFixedAssetCreate(ctx context.Context, tx pgx.Tx, userID uuid.UUID, entityID uuid.UUID, payload string) error {
	var p fixedAssetPayload
	if err := json.Unmarshal([]byte(payload), &p); err != nil {
		return fmt.Errorf("invalid fixed_asset create payload: %w", err)
	}

	if p.Name == "" {
		return fmt.Errorf("fixed_asset name is required")
	}
	if p.AssetType == "" {
		p.AssetType = "other"
	}

	purchaseDate := time.Now()
	if p.PurchaseDate != "" {
		if parsed, err := time.Parse("2006-01-02", p.PurchaseDate); err == nil {
			purchaseDate = parsed
		}
	}

	currentValue := p.CurrentValue
	if currentValue == 0 {
		currentValue = p.PurchasePrice
	}

	_, err := tx.Exec(ctx,
		`INSERT INTO fixed_assets (id, user_id, name, asset_type, purchase_price, current_value, purchase_date, description)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
		entityID, userID, p.Name, p.AssetType, p.PurchasePrice, currentValue, purchaseDate, p.Description,
	)
	if err != nil {
		return fmt.Errorf("failed to insert fixed_asset: %w", err)
	}
	return nil
}

func (s *Service) applyFixedAssetUpdate(ctx context.Context, tx pgx.Tx, userID uuid.UUID, entityID uuid.UUID, payload string) error {
	var p fixedAssetPayload
	if err := json.Unmarshal([]byte(payload), &p); err != nil {
		return fmt.Errorf("invalid fixed_asset update payload: %w", err)
	}

	if err := s.verifyOwnership(ctx, tx, userID, entityID, "fixed_assets"); err != nil {
		return err
	}

	setClauses := []string{"updated_at = NOW()"}
	args := []interface{}{}
	argIdx := 1

	if p.Name != "" {
		args = append(args, p.Name)
		setClauses = append(setClauses, fmt.Sprintf("name = $%d", argIdx))
		argIdx++
	}
	if p.CurrentValue > 0 {
		args = append(args, p.CurrentValue)
		setClauses = append(setClauses, fmt.Sprintf("current_value = $%d", argIdx))
		argIdx++
	}
	if p.Description != "" {
		args = append(args, p.Description)
		setClauses = append(setClauses, fmt.Sprintf("description = $%d", argIdx))
		argIdx++
	}

	if len(args) == 0 {
		_, err := tx.Exec(ctx, "UPDATE fixed_assets SET updated_at = NOW() WHERE id = $1", entityID)
		return err
	}

	args = append(args, entityID)
	query := fmt.Sprintf("UPDATE fixed_assets SET %s WHERE id = $%d AND deleted_at IS NULL",
		strings.Join(setClauses, ", "), argIdx)
	_, err := tx.Exec(ctx, query, args...)
	if err != nil {
		return fmt.Errorf("failed to update fixed_asset: %w", err)
	}
	return nil
}

// ── Budget sync operations ──────────────────────────────────────────────────

type budgetPayload struct {
	Year        int32  `json:"year"`
	Month       int32  `json:"month"`
	TotalAmount int64  `json:"total_amount"`
	FamilyID    string `json:"family_id"`
}

func (s *Service) applyBudgetOp(ctx context.Context, tx pgx.Tx, userID uuid.UUID, entityID uuid.UUID, opType string, payload string) error {
	switch opType {
	case "create":
		return s.applyBudgetCreate(ctx, tx, userID, entityID, payload)
	case "update":
		return s.applyBudgetUpdate(ctx, tx, userID, entityID, payload)
	case "delete":
		// Budgets don't have deleted_at; just delete the row
		_, err := tx.Exec(ctx, "DELETE FROM budgets WHERE id = $1 AND user_id = $2", entityID, userID)
		if err != nil {
			return fmt.Errorf("failed to delete budget: %w", err)
		}
		return nil
	default:
		log.Printf("sync: unknown op_type %q for budget, skipping", opType)
		return nil
	}
}

func (s *Service) applyBudgetCreate(ctx context.Context, tx pgx.Tx, userID uuid.UUID, entityID uuid.UUID, payload string) error {
	var p budgetPayload
	if err := json.Unmarshal([]byte(payload), &p); err != nil {
		return fmt.Errorf("invalid budget create payload: %w", err)
	}

	if p.Year == 0 || p.Month == 0 || p.TotalAmount <= 0 {
		return fmt.Errorf("budget year, month, and total_amount are required")
	}

	var familyID *uuid.UUID
	if p.FamilyID != "" {
		fid, err := uuid.Parse(p.FamilyID)
		if err == nil {
			familyID = &fid
		}
	}

	var query string
	if familyID == nil {
		query = `INSERT INTO budgets (id, user_id, family_id, year, month, total_amount)
		 VALUES ($1, $2, $3, $4, $5, $6)
		 ON CONFLICT (user_id, year, month) WHERE family_id IS NULL
		 DO UPDATE SET total_amount = EXCLUDED.total_amount, updated_at = NOW()`
	} else {
		query = `INSERT INTO budgets (id, user_id, family_id, year, month, total_amount)
		 VALUES ($1, $2, $3, $4, $5, $6)
		 ON CONFLICT (user_id, year, month, family_id) WHERE family_id IS NOT NULL
		 DO UPDATE SET total_amount = EXCLUDED.total_amount, updated_at = NOW()`
	}

	_, err := tx.Exec(ctx, query,
		entityID, userID, familyID, p.Year, p.Month, p.TotalAmount,
	)
	if err != nil {
		return fmt.Errorf("failed to insert budget: %w", err)
	}
	return nil
}

func (s *Service) applyBudgetUpdate(ctx context.Context, tx pgx.Tx, userID uuid.UUID, entityID uuid.UUID, payload string) error {
	var p budgetPayload
	if err := json.Unmarshal([]byte(payload), &p); err != nil {
		return fmt.Errorf("invalid budget update payload: %w", err)
	}

	if p.TotalAmount > 0 {
		_, err := tx.Exec(ctx,
			`UPDATE budgets SET total_amount = $1, updated_at = NOW() WHERE id = $2 AND user_id = $3`,
			p.TotalAmount, entityID, userID,
		)
		if err != nil {
			return fmt.Errorf("failed to update budget: %w", err)
		}
	}
	return nil
}

// ── Shared helpers ──────────────────────────────────────────────────────────

// verifyOwnership checks that the entity in the given table belongs to the user.
func (s *Service) verifyOwnership(ctx context.Context, tx pgx.Tx, userID uuid.UUID, entityID uuid.UUID, table string) error {
	var ownerID uuid.UUID
	query := fmt.Sprintf("SELECT user_id FROM %s WHERE id = $1 AND deleted_at IS NULL", table)
	err := tx.QueryRow(ctx, query, entityID).Scan(&ownerID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return fmt.Errorf("%s %s not found", table, entityID)
		}
		return fmt.Errorf("failed to fetch %s for update: %w", table, err)
	}
	if ownerID != userID {
		return fmt.Errorf("%s %s does not belong to user", table, entityID)
	}
	return nil
}

// applyGenericSoftDelete performs a soft delete on the given table.
func (s *Service) applyGenericSoftDelete(ctx context.Context, tx pgx.Tx, userID uuid.UUID, entityID uuid.UUID, table string) error {
	query := fmt.Sprintf(
		"UPDATE %s SET deleted_at = NOW(), updated_at = NOW() WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL",
		table,
	)
	tag, err := tx.Exec(ctx, query, entityID, userID)
	if err != nil {
		return fmt.Errorf("failed to soft-delete %s: %w", table, err)
	}
	if tag.RowsAffected() == 0 {
		log.Printf("sync: %s %s already deleted or not owned by user, skipping", table, entityID)
	}
	return nil
}
