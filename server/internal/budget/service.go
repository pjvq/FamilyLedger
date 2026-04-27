package budget

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/familyledger/server/pkg/db"
	"github.com/familyledger/server/pkg/permission"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/familyledger/server/pkg/middleware"
	pb "github.com/familyledger/server/proto/budget"
)

type Service struct {
	pb.UnimplementedBudgetServiceServer
	pool db.Pool
}

func NewService(pool db.Pool) *Service {
	return &Service{pool: pool}
}

func (s *Service) CreateBudget(ctx context.Context, req *pb.CreateBudgetRequest) (*pb.CreateBudgetResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	uid, err := uuid.Parse(userID)
	if err != nil {
		return nil, status.Error(codes.Internal, "invalid user id")
	}

	if req.Month < 1 || req.Month > 12 {
		return nil, status.Error(codes.InvalidArgument, "month must be between 1 and 12")
	}
	if req.Year < 2000 || req.Year > 2100 {
		return nil, status.Error(codes.InvalidArgument, "invalid year")
	}
	if req.TotalAmount <= 0 {
		return nil, status.Error(codes.InvalidArgument, "total_amount must be positive")
	}

	var familyID *uuid.UUID
	if req.FamilyId != "" {
		fid, err := uuid.Parse(req.FamilyId)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid family_id")
		}
		familyID = &fid
	}

	// Permission check: editing budget in family mode requires canEdit
	if err := permission.Check(ctx, s.pool, userID, req.FamilyId, permission.CanEdit); err != nil {
		return nil, err
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to begin transaction")
	}
	defer tx.Rollback(ctx)

	var budgetID uuid.UUID
	var createdAt time.Time
	err = tx.QueryRow(ctx,
		`INSERT INTO budgets (user_id, family_id, year, month, total_amount)
		 VALUES ($1, $2, $3, $4, $5)
		 RETURNING id, created_at`,
		uid, familyID, req.Year, req.Month, req.TotalAmount,
	).Scan(&budgetID, &createdAt)
	if err != nil {
		log.Printf("budget: create error: %v", err)
		return nil, status.Error(codes.AlreadyExists, "budget already exists for this user/month")
	}

	// Insert category budgets
	for _, cb := range req.CategoryBudgets {
		catID, err := uuid.Parse(cb.CategoryId)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, fmt.Sprintf("invalid category_id: %s", cb.CategoryId))
		}
		_, err = tx.Exec(ctx,
			`INSERT INTO category_budgets (budget_id, category_id, amount) VALUES ($1, $2, $3)`,
			budgetID, catID, cb.Amount,
		)
		if err != nil {
			log.Printf("budget: create category budget error: %v", err)
			return nil, status.Error(codes.Internal, "failed to create category budget")
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Error(codes.Internal, "failed to commit")
	}

	log.Printf("budget: created budget %s for user %s (%d-%02d)", budgetID, userID, req.Year, req.Month)

	return &pb.CreateBudgetResponse{
		Budget: &pb.Budget{
			Id:              budgetID.String(),
			UserId:          userID,
			FamilyId:        req.FamilyId,
			Year:            req.Year,
			Month:           req.Month,
			TotalAmount:     req.TotalAmount,
			CategoryBudgets: req.CategoryBudgets,
			CreatedAt:       timestamppb.New(createdAt),
		},
	}, nil
}

func (s *Service) GetBudget(ctx context.Context, req *pb.GetBudgetRequest) (*pb.GetBudgetResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	budgetID, err := uuid.Parse(req.BudgetId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid budget_id")
	}

	budget, err := s.loadBudget(ctx, budgetID, userID)
	if err != nil {
		return nil, err
	}

	execution, err := s.computeExecution(ctx, budgetID, budget)
	if err != nil {
		return nil, err
	}

	return &pb.GetBudgetResponse{
		Budget:    budget,
		Execution: execution,
	}, nil
}

func (s *Service) ListBudgets(ctx context.Context, req *pb.ListBudgetsRequest) (*pb.ListBudgetsResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	uid, err := uuid.Parse(userID)
	if err != nil {
		return nil, status.Error(codes.Internal, "invalid user id")
	}

	var rows pgx.Rows
	if req.FamilyId != "" {
		fid, err := uuid.Parse(req.FamilyId)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid family_id")
		}
		// Verify user is a member of this family
		var isMember bool
		err = s.pool.QueryRow(ctx,
			`SELECT EXISTS(SELECT 1 FROM family_members WHERE family_id = $1 AND user_id = $2)`,
			fid, uid,
		).Scan(&isMember)
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to verify family membership")
		}
		if !isMember {
			return nil, status.Error(codes.PermissionDenied, "not a member of this family")
		}
		query := `SELECT b.id, b.user_id, b.family_id, b.year, b.month, b.total_amount, b.created_at
			 FROM budgets b
			 WHERE b.family_id = $1
			 AND ($2::int = 0 OR b.year = $2)
			 ORDER BY b.year DESC, b.month DESC`
		rows, err = s.pool.Query(ctx, query, fid, req.Year)
	} else {
		query := `SELECT b.id, b.user_id, b.family_id, b.year, b.month, b.total_amount, b.created_at
			 FROM budgets b
			 WHERE b.user_id = $1 AND b.family_id IS NULL
			 AND ($2::int = 0 OR b.year = $2)
			 ORDER BY b.year DESC, b.month DESC`
		rows, err = s.pool.Query(ctx, query, uid, req.Year)
	}
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to query budgets")
	}
	defer rows.Close()

	var budgets []*pb.Budget
	for rows.Next() {
		var id, bUserID uuid.UUID
		var bFamilyID *uuid.UUID
		var year, month int32
		var totalAmount int64
		var createdAt time.Time

		if err := rows.Scan(&id, &bUserID, &bFamilyID, &year, &month, &totalAmount, &createdAt); err != nil {
			return nil, status.Error(codes.Internal, "failed to scan budget")
		}

		budget := &pb.Budget{
			Id:          id.String(),
			UserId:      bUserID.String(),
			Year:        year,
			Month:       month,
			TotalAmount: totalAmount,
			CreatedAt:   timestamppb.New(createdAt),
		}
		if bFamilyID != nil {
			budget.FamilyId = bFamilyID.String()
		}

		// Load category budgets
		cbs, err := s.loadCategoryBudgets(ctx, id)
		if err != nil {
			return nil, err
		}
		budget.CategoryBudgets = cbs

		budgets = append(budgets, budget)
	}

	if budgets == nil {
		budgets = []*pb.Budget{}
	}

	return &pb.ListBudgetsResponse{Budgets: budgets}, nil
}

func (s *Service) UpdateBudget(ctx context.Context, req *pb.UpdateBudgetRequest) (*pb.UpdateBudgetResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	budgetID, err := uuid.Parse(req.BudgetId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid budget_id")
	}

	// Verify ownership or family permission
	var ownerID string
	var budgetFamilyID *string
	err = s.pool.QueryRow(ctx, "SELECT user_id, family_id FROM budgets WHERE id = $1", budgetID).Scan(&ownerID, &budgetFamilyID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, status.Error(codes.NotFound, "budget not found")
		}
		return nil, status.Error(codes.Internal, "failed to query budget")
	}
	if ownerID != userID {
		if budgetFamilyID != nil {
			if err := permission.Check(ctx, s.pool, userID, *budgetFamilyID, permission.CanEdit); err != nil {
				return nil, err
			}
		} else {
			return nil, status.Error(codes.PermissionDenied, "not your budget")
		}
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to begin transaction")
	}
	defer tx.Rollback(ctx)

	if req.TotalAmount > 0 {
		_, err = tx.Exec(ctx,
			"UPDATE budgets SET total_amount = $1, updated_at = NOW() WHERE id = $2",
			req.TotalAmount, budgetID,
		)
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to update budget")
		}
	}

	if len(req.CategoryBudgets) > 0 {
		// Delete existing category budgets and re-insert
		_, err = tx.Exec(ctx, "DELETE FROM category_budgets WHERE budget_id = $1", budgetID)
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to clear category budgets")
		}

		for _, cb := range req.CategoryBudgets {
			catID, err := uuid.Parse(cb.CategoryId)
			if err != nil {
				return nil, status.Error(codes.InvalidArgument, fmt.Sprintf("invalid category_id: %s", cb.CategoryId))
			}
			_, err = tx.Exec(ctx,
				"INSERT INTO category_budgets (budget_id, category_id, amount) VALUES ($1, $2, $3)",
				budgetID, catID, cb.Amount,
			)
			if err != nil {
				return nil, status.Error(codes.Internal, "failed to insert category budget")
			}
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Error(codes.Internal, "failed to commit")
	}

	budget, err := s.loadBudget(ctx, budgetID, userID)
	if err != nil {
		return nil, err
	}

	log.Printf("budget: updated budget %s", budgetID)
	return &pb.UpdateBudgetResponse{Budget: budget}, nil
}

func (s *Service) DeleteBudget(ctx context.Context, req *pb.DeleteBudgetRequest) (*pb.DeleteBudgetResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	budgetID, err := uuid.Parse(req.BudgetId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid budget_id")
	}

	// Check ownership or family permission
	var ownerID string
	var budgetFamilyID *string
	err = s.pool.QueryRow(ctx, "SELECT user_id, family_id FROM budgets WHERE id = $1", budgetID).Scan(&ownerID, &budgetFamilyID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, status.Error(codes.NotFound, "budget not found")
		}
		return nil, status.Error(codes.Internal, "failed to query budget")
	}
	if ownerID != userID {
		if budgetFamilyID != nil {
			if err := permission.Check(ctx, s.pool, userID, *budgetFamilyID, permission.CanDelete); err != nil {
				return nil, err
			}
		} else {
			return nil, status.Error(codes.PermissionDenied, "not your budget")
		}
	}

	tag, err := s.pool.Exec(ctx, "DELETE FROM budgets WHERE id = $1", budgetID)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to delete budget")
	}
	if tag.RowsAffected() == 0 {
		return nil, status.Error(codes.NotFound, "budget not found")
	}

	log.Printf("budget: deleted budget %s", budgetID)
	return &pb.DeleteBudgetResponse{}, nil
}

func (s *Service) GetBudgetExecution(ctx context.Context, req *pb.GetBudgetExecutionRequest) (*pb.GetBudgetExecutionResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	budgetID, err := uuid.Parse(req.BudgetId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid budget_id")
	}

	budget, err := s.loadBudget(ctx, budgetID, userID)
	if err != nil {
		return nil, err
	}

	execution, err := s.computeExecution(ctx, budgetID, budget)
	if err != nil {
		return nil, err
	}

	return &pb.GetBudgetExecutionResponse{Execution: execution}, nil
}

// ── Internal helpers ────────────────────────────────────────────────────────

func (s *Service) loadBudget(ctx context.Context, budgetID uuid.UUID, userID string) (*pb.Budget, error) {
	var bUserID uuid.UUID
	var bFamilyID *uuid.UUID
	var year, month int32
	var totalAmount int64
	var createdAt time.Time

	err := s.pool.QueryRow(ctx,
		"SELECT user_id, family_id, year, month, total_amount, created_at FROM budgets WHERE id = $1",
		budgetID,
	).Scan(&bUserID, &bFamilyID, &year, &month, &totalAmount, &createdAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, status.Error(codes.NotFound, "budget not found")
		}
		return nil, status.Error(codes.Internal, "failed to query budget")
	}
	if bUserID.String() != userID {
		// If this is a family budget, check family membership
		if bFamilyID != nil {
			if err := permission.Check(ctx, s.pool, userID, bFamilyID.String(), permission.CanView); err != nil {
				return nil, status.Error(codes.PermissionDenied, "not your budget")
			}
		} else {
			return nil, status.Error(codes.PermissionDenied, "not your budget")
		}
	}

	budget := &pb.Budget{
		Id:          budgetID.String(),
		UserId:      bUserID.String(),
		Year:        year,
		Month:       month,
		TotalAmount: totalAmount,
		CreatedAt:   timestamppb.New(createdAt),
	}
	if bFamilyID != nil {
		budget.FamilyId = bFamilyID.String()
	}

	cbs, err := s.loadCategoryBudgets(ctx, budgetID)
	if err != nil {
		return nil, err
	}
	budget.CategoryBudgets = cbs

	return budget, nil
}

func (s *Service) loadCategoryBudgets(ctx context.Context, budgetID uuid.UUID) ([]*pb.CategoryBudget, error) {
	rows, err := s.pool.Query(ctx,
		"SELECT category_id, amount FROM category_budgets WHERE budget_id = $1",
		budgetID,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to query category budgets")
	}
	defer rows.Close()

	var cbs []*pb.CategoryBudget
	for rows.Next() {
		var catID uuid.UUID
		var amount int64
		if err := rows.Scan(&catID, &amount); err != nil {
			return nil, status.Error(codes.Internal, "failed to scan category budget")
		}
		cbs = append(cbs, &pb.CategoryBudget{
			CategoryId: catID.String(),
			Amount:     amount,
		})
	}
	return cbs, nil
}

// computeExecution calculates the budget execution by querying expense transactions
// for the budget's month and matching categories.
func (s *Service) computeExecution(ctx context.Context, budgetID uuid.UUID, budget *pb.Budget) (*pb.BudgetExecution, error) {
	// Compute the time range for this budget month
	startOfMonth := time.Date(int(budget.Year), time.Month(budget.Month), 1, 0, 0, 0, 0, time.UTC)
	endOfMonth := startOfMonth.AddDate(0, 1, 0)

	// Query total expense: family budget aggregates all family members' spending,
	// personal budget only counts user's own spending.
	var totalSpent int64
	if budget.FamilyId != "" {
		// Family budget: sum expenses from all accounts belonging to this family
		err := s.pool.QueryRow(ctx,
			`SELECT COALESCE(SUM(t.amount_cny), 0)
			 FROM transactions t
			 JOIN accounts a ON a.id = t.account_id
			 WHERE a.family_id = $1 AND t.type = 'expense' AND t.deleted_at IS NULL
			   AND t.txn_date >= $2 AND t.txn_date < $3`,
			budget.FamilyId, startOfMonth, endOfMonth,
		).Scan(&totalSpent)
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to compute total spent")
		}
	} else {
		// Personal budget: only count user's own expenses
		err := s.pool.QueryRow(ctx,
			`SELECT COALESCE(SUM(amount_cny), 0)
			 FROM transactions
			 WHERE user_id = $1 AND type = 'expense' AND deleted_at IS NULL
			   AND txn_date >= $2 AND txn_date < $3`,
			budget.UserId, startOfMonth, endOfMonth,
		).Scan(&totalSpent)
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to compute total spent")
		}
	}

	execution := &pb.BudgetExecution{
		TotalBudget: budget.TotalAmount,
		TotalSpent:  totalSpent,
	}
	if budget.TotalAmount > 0 {
		execution.ExecutionRate = float64(totalSpent) / float64(budget.TotalAmount)
	}

	// Per-category execution
	if len(budget.CategoryBudgets) > 0 {
		var rows pgx.Rows
		var err error
		if budget.FamilyId != "" {
			// Family budget: category spending across all family accounts
			rows, err = s.pool.Query(ctx,
				`SELECT t.category_id, c.name, COALESCE(SUM(t.amount_cny), 0) AS spent
				 FROM transactions t
				 JOIN categories c ON c.id = t.category_id
				 JOIN accounts a ON a.id = t.account_id
				 WHERE a.family_id = $1 AND t.type = 'expense' AND t.deleted_at IS NULL
				   AND t.txn_date >= $2 AND t.txn_date < $3
				 GROUP BY t.category_id, c.name`,
				budget.FamilyId, startOfMonth, endOfMonth,
			)
		} else {
			// Personal budget: only user's own category spending
			rows, err = s.pool.Query(ctx,
				`SELECT t.category_id, c.name, COALESCE(SUM(t.amount_cny), 0) AS spent
				 FROM transactions t
				 JOIN categories c ON c.id = t.category_id
				 WHERE t.user_id = $1 AND t.type = 'expense' AND t.deleted_at IS NULL
				   AND t.txn_date >= $2 AND t.txn_date < $3
				 GROUP BY t.category_id, c.name`,
				budget.UserId, startOfMonth, endOfMonth,
			)
		}
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to compute category spending")
		}
		defer rows.Close()

		spentMap := make(map[string]int64)
		nameMap := make(map[string]string)
		for rows.Next() {
			var catID uuid.UUID
			var catName string
			var spent int64
			if err := rows.Scan(&catID, &catName, &spent); err != nil {
				return nil, status.Error(codes.Internal, "failed to scan category spending")
			}
			spentMap[catID.String()] = spent
			nameMap[catID.String()] = catName
		}

		for _, cb := range budget.CategoryBudgets {
			spent := spentMap[cb.CategoryId]
			ce := &pb.CategoryExecution{
				CategoryId:   cb.CategoryId,
				CategoryName: nameMap[cb.CategoryId],
				BudgetAmount: cb.Amount,
				SpentAmount:  spent,
			}
			if cb.Amount > 0 {
				ce.ExecutionRate = float64(spent) / float64(cb.Amount)
			}
			execution.CategoryExecutions = append(execution.CategoryExecutions, ce)
		}
	}

	return execution, nil
}
