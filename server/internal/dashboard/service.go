package dashboard

import (
	"context"
	"fmt"
	"log"
	"math"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"github.com/familyledger/server/pkg/middleware"
	pb "github.com/familyledger/server/proto/dashboard"
)

type Service struct {
	pb.UnimplementedDashboardServiceServer
	pool *pgxpool.Pool
}

func NewService(pool *pgxpool.Pool) *Service {
	return &Service{pool: pool}
}

// ── GetNetWorth ─────────────────────────────────────────────────────────────

func (s *Service) GetNetWorth(ctx context.Context, req *pb.GetNetWorthRequest) (*pb.NetWorth, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	// 1. 现金+银行 = SUM(accounts.balance) WHERE type IN (cash, bank_card, alipay, wechat_pay)
	var cashAndBank int64
	err = s.pool.QueryRow(ctx,
		`SELECT COALESCE(SUM(balance), 0)
		 FROM accounts
		 WHERE user_id = $1 AND deleted_at IS NULL AND is_active = true
		   AND type IN ('cash', 'bank_card', 'alipay', 'wechat_pay')`,
		userID,
	).Scan(&cashAndBank)
	if err != nil {
		log.Printf("dashboard: cashAndBank error: %v", err)
		return nil, status.Error(codes.Internal, "failed to query cash and bank")
	}

	// 2. 投资市值 = SUM(investments.quantity × market_quotes.current_price)
	//    如果没有行情数据，回退到 investments.cost_basis
	var investmentValue int64
	err = s.pool.QueryRow(ctx,
		`SELECT COALESCE(SUM(
			CASE
				WHEN mq.current_price > 0 THEN CAST(i.quantity * mq.current_price AS BIGINT)
				ELSE i.cost_basis
			END
		), 0)
		 FROM investments i
		 LEFT JOIN market_quotes mq ON i.symbol = mq.symbol AND i.market_type = mq.market_type
		 WHERE i.user_id = $1 AND i.deleted_at IS NULL`,
		userID,
	).Scan(&investmentValue)
	if err != nil {
		log.Printf("dashboard: investmentValue error: %v", err)
		return nil, status.Error(codes.Internal, "failed to query investment value")
	}

	// 3. 固定资产 = SUM(fixed_assets.current_value)
	var fixedAssetValue int64
	err = s.pool.QueryRow(ctx,
		`SELECT COALESCE(SUM(current_value), 0)
		 FROM fixed_assets
		 WHERE user_id = $1 AND deleted_at IS NULL`,
		userID,
	).Scan(&fixedAssetValue)
	if err != nil {
		log.Printf("dashboard: fixedAssetValue error: %v", err)
		return nil, status.Error(codes.Internal, "failed to query fixed asset value")
	}

	// 4. 贷款余额 = SUM(loans.remaining_principal)
	var loanBalance int64
	err = s.pool.QueryRow(ctx,
		`SELECT COALESCE(SUM(remaining_principal), 0)
		 FROM loans
		 WHERE user_id = $1 AND deleted_at IS NULL`,
		userID,
	).Scan(&loanBalance)
	if err != nil {
		log.Printf("dashboard: loanBalance error: %v", err)
		return nil, status.Error(codes.Internal, "failed to query loan balance")
	}

	// 5. 净资产 = 现金银行 + 投资 + 固定资产 - 贷款
	total := cashAndBank + investmentValue + fixedAssetValue - loanBalance

	// 6. 上月净资产估算 — 简化实现：查上月最后一天的 asset_valuations 总和 + accounts
	lastMonthTotal := s.estimateLastMonthNetWorth(ctx, userID)
	changeFromLastMonth := total - lastMonthTotal
	var changePercent float64
	if lastMonthTotal != 0 {
		changePercent = float64(changeFromLastMonth) / math.Abs(float64(lastMonthTotal))
	}

	// 7. 资产构成
	// 计算总正向资产（不含贷款）
	totalPositive := cashAndBank + investmentValue + fixedAssetValue
	if totalPositive == 0 {
		totalPositive = 1 // 防除零
	}

	composition := []*pb.AssetComposition{
		{
			Category: "cash",
			Label:    "现金与银行",
			Value:    cashAndBank,
			Weight:   float64(cashAndBank) / float64(totalPositive),
		},
		{
			Category: "investment",
			Label:    "投资",
			Value:    investmentValue,
			Weight:   float64(investmentValue) / float64(totalPositive),
		},
		{
			Category: "fixed_asset",
			Label:    "固定资产",
			Value:    fixedAssetValue,
			Weight:   float64(fixedAssetValue) / float64(totalPositive),
		},
		{
			Category: "loan",
			Label:    "贷款",
			Value:    -loanBalance,
			Weight:   0, // 贷款不算占比
		},
	}

	return &pb.NetWorth{
		Total:               total,
		CashAndBank:         cashAndBank,
		InvestmentValue:     investmentValue,
		FixedAssetValue:     fixedAssetValue,
		LoanBalance:         -loanBalance,
		ChangeFromLastMonth: changeFromLastMonth,
		ChangePercent:       changePercent,
		Composition:         composition,
	}, nil
}

// estimateLastMonthNetWorth 估算上月末净资产。
// 简化方案：查询上月末的各项汇总。
func (s *Service) estimateLastMonthNetWorth(ctx context.Context, userID string) int64 {
	now := time.Now()
	lastMonthEnd := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.UTC).Add(-time.Second)

	// 上月末 accounts balance — 近似用当前值减去本月净收支
	var currentCash int64
	_ = s.pool.QueryRow(ctx,
		`SELECT COALESCE(SUM(balance), 0)
		 FROM accounts
		 WHERE user_id = $1 AND deleted_at IS NULL AND is_active = true
		   AND type IN ('cash', 'bank_card', 'alipay', 'wechat_pay')`,
		userID,
	).Scan(&currentCash)

	// 本月净收支
	startOfMonth := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.UTC)
	var monthIncome, monthExpense int64
	_ = s.pool.QueryRow(ctx,
		`SELECT COALESCE(SUM(CASE WHEN type = 'income' THEN amount_cny ELSE 0 END), 0),
		        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount_cny ELSE 0 END), 0)
		 FROM transactions
		 WHERE user_id = $1 AND deleted_at IS NULL
		   AND txn_date >= $2 AND txn_date < $3`,
		userID, startOfMonth, now,
	).Scan(&monthIncome, &monthExpense)

	lastMonthCash := currentCash - monthIncome + monthExpense

	// 上月末投资市值 — 查 price_history 近似
	var lastMonthInvestment int64
	_ = s.pool.QueryRow(ctx,
		`SELECT COALESCE(SUM(
			CASE
				WHEN ph.price > 0 THEN CAST(i.quantity * ph.price AS BIGINT)
				ELSE i.cost_basis
			END
		), 0)
		 FROM investments i
		 LEFT JOIN LATERAL (
			SELECT price FROM price_history
			WHERE symbol = i.symbol AND market_type = i.market_type
			  AND timestamp <= $2
			ORDER BY timestamp DESC LIMIT 1
		 ) ph ON true
		 WHERE i.user_id = $1 AND i.deleted_at IS NULL`,
		userID, lastMonthEnd,
	).Scan(&lastMonthInvestment)

	// 上月末固定资产 — 查 asset_valuations
	var lastMonthAsset int64
	_ = s.pool.QueryRow(ctx,
		`SELECT COALESCE(SUM(latest_val.value), 0)
		 FROM fixed_assets fa
		 JOIN LATERAL (
			SELECT value FROM asset_valuations
			WHERE asset_id = fa.id AND valuation_date <= $2
			ORDER BY valuation_date DESC, created_at DESC LIMIT 1
		 ) latest_val ON true
		 WHERE fa.user_id = $1 AND fa.deleted_at IS NULL`,
		userID, lastMonthEnd,
	).Scan(&lastMonthAsset)

	// 上月末贷款余额 — 近似用当前值（贷款变化小，可接受）
	var lastMonthLoan int64
	_ = s.pool.QueryRow(ctx,
		`SELECT COALESCE(SUM(remaining_principal), 0)
		 FROM loans
		 WHERE user_id = $1 AND deleted_at IS NULL`,
		userID,
	).Scan(&lastMonthLoan)

	return lastMonthCash + lastMonthInvestment + lastMonthAsset - lastMonthLoan
}

// ── GetIncomeExpenseTrend ───────────────────────────────────────────────────

func (s *Service) GetIncomeExpenseTrend(ctx context.Context, req *pb.TrendRequest) (*pb.TrendResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	count := int(req.Count)
	if count <= 0 {
		count = 12
	}
	if count > 60 {
		count = 60
	}

	truncUnit := "month"
	labelFormat := "2006-01"
	if req.Period == "yearly" {
		truncUnit = "year"
		labelFormat = "2006"
	}

	now := time.Now()
	var startDate time.Time
	if req.Period == "yearly" {
		startDate = time.Date(now.Year()-count, 1, 1, 0, 0, 0, 0, time.UTC)
	} else {
		startDate = time.Date(now.Year(), now.Month()-time.Month(count), 1, 0, 0, 0, 0, time.UTC)
	}

	query := fmt.Sprintf(
		`SELECT DATE_TRUNC('%s', txn_date) AS period,
		        COALESCE(SUM(CASE WHEN type = 'income' THEN amount_cny ELSE 0 END), 0) AS income,
		        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount_cny ELSE 0 END), 0) AS expense
		 FROM transactions
		 WHERE user_id = $1 AND deleted_at IS NULL AND txn_date >= $2
		 GROUP BY 1 ORDER BY 1`, truncUnit)

	rows, err := s.pool.Query(ctx, query, userID, startDate)
	if err != nil {
		log.Printf("dashboard: income/expense trend error: %v", err)
		return nil, status.Error(codes.Internal, "failed to query trend")
	}
	defer rows.Close()

	var points []*pb.TrendPoint
	for rows.Next() {
		var period time.Time
		var income, expense int64
		if err := rows.Scan(&period, &income, &expense); err != nil {
			return nil, status.Error(codes.Internal, "failed to scan trend row")
		}
		points = append(points, &pb.TrendPoint{
			Label:   period.Format(labelFormat),
			Income:  income,
			Expense: expense,
			Net:     income - expense,
		})
	}

	if points == nil {
		points = []*pb.TrendPoint{}
	}
	return &pb.TrendResponse{Points: points}, nil
}

// ── GetCategoryBreakdown ────────────────────────────────────────────────────

func (s *Service) GetCategoryBreakdown(ctx context.Context, req *pb.CategoryBreakdownRequest) (*pb.CategoryBreakdownResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	if req.Year == 0 || req.Month == 0 {
		now := time.Now()
		if req.Year == 0 {
			req.Year = int32(now.Year())
		}
		if req.Month == 0 {
			req.Month = int32(now.Month())
		}
	}

	txnType := "expense"
	if req.Type == "income" {
		txnType = "income"
	}

	startOfMonth := time.Date(int(req.Year), time.Month(req.Month), 1, 0, 0, 0, 0, time.UTC)
	endOfMonth := startOfMonth.AddDate(0, 1, 0)

	rows, err := s.pool.Query(ctx,
		`SELECT t.category_id, c.name, c.icon, COALESCE(SUM(t.amount_cny), 0) AS amount
		 FROM transactions t
		 JOIN categories c ON c.id = t.category_id
		 WHERE t.user_id = $1 AND t.type = $2 AND t.deleted_at IS NULL
		   AND t.txn_date >= $3 AND t.txn_date < $4
		 GROUP BY t.category_id, c.name, c.icon
		 ORDER BY amount DESC`,
		userID, txnType, startOfMonth, endOfMonth,
	)
	if err != nil {
		log.Printf("dashboard: category breakdown error: %v", err)
		return nil, status.Error(codes.Internal, "failed to query category breakdown")
	}
	defer rows.Close()

	var items []*pb.CategoryItem
	var total int64
	for rows.Next() {
		var catID, catName string
		var icon *string
		var amount int64
		if err := rows.Scan(&catID, &catName, &icon, &amount); err != nil {
			return nil, status.Error(codes.Internal, "failed to scan category row")
		}
		iconStr := ""
		if icon != nil {
			iconStr = *icon
		}
		items = append(items, &pb.CategoryItem{
			CategoryId:   catID,
			CategoryName: catName,
			Icon:         iconStr,
			Amount:       amount,
		})
		total += amount
	}

	// 计算占比
	for _, item := range items {
		if total > 0 {
			item.Weight = float64(item.Amount) / float64(total)
		}
	}

	if items == nil {
		items = []*pb.CategoryItem{}
	}

	return &pb.CategoryBreakdownResponse{
		Total: total,
		Items: items,
	}, nil
}

// ── GetBudgetSummary ────────────────────────────────────────────────────────

func (s *Service) GetBudgetSummary(ctx context.Context, req *pb.BudgetSummaryRequest) (*pb.BudgetSummaryResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	now := time.Now()
	year := int(req.Year)
	month := int(req.Month)
	if year == 0 {
		year = now.Year()
	}
	if month == 0 {
		month = int(now.Month())
	}

	// 查预算
	var budgetID string
	var totalBudget int64
	err = s.pool.QueryRow(ctx,
		`SELECT id, total_amount FROM budgets
		 WHERE user_id = $1 AND year = $2 AND month = $3
		 ORDER BY created_at DESC LIMIT 1`,
		userID, year, month,
	).Scan(&budgetID, &totalBudget)
	if err != nil {
		// 没有预算也返回空结果
		return &pb.BudgetSummaryResponse{}, nil
	}

	startOfMonth := time.Date(year, time.Month(month), 1, 0, 0, 0, 0, time.UTC)
	endOfMonth := startOfMonth.AddDate(0, 1, 0)

	// 总支出
	var totalSpent int64
	_ = s.pool.QueryRow(ctx,
		`SELECT COALESCE(SUM(amount_cny), 0)
		 FROM transactions
		 WHERE user_id = $1 AND type = 'expense' AND deleted_at IS NULL
		   AND txn_date >= $2 AND txn_date < $3`,
		userID, startOfMonth, endOfMonth,
	).Scan(&totalSpent)

	var executionRate float64
	if totalBudget > 0 {
		executionRate = float64(totalSpent) / float64(totalBudget)
	}

	// 分类预算
	catRows, err := s.pool.Query(ctx,
		`SELECT cb.category_id, c.name, cb.amount
		 FROM category_budgets cb
		 JOIN categories c ON c.id = cb.category_id
		 WHERE cb.budget_id = $1`,
		budgetID,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to query category budgets")
	}
	defer catRows.Close()

	type catBudget struct {
		catID      string
		catName    string
		budgetAmt int64
	}
	var catBudgets []catBudget
	for catRows.Next() {
		var cb catBudget
		if err := catRows.Scan(&cb.catID, &cb.catName, &cb.budgetAmt); err != nil {
			return nil, status.Error(codes.Internal, "failed to scan category budget")
		}
		catBudgets = append(catBudgets, cb)
	}

	// 分类支出
	spentRows, err := s.pool.Query(ctx,
		`SELECT t.category_id, COALESCE(SUM(t.amount_cny), 0)
		 FROM transactions t
		 WHERE t.user_id = $1 AND t.type = 'expense' AND t.deleted_at IS NULL
		   AND t.txn_date >= $2 AND t.txn_date < $3
		 GROUP BY t.category_id`,
		userID, startOfMonth, endOfMonth,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to query category spent")
	}
	defer spentRows.Close()

	spentMap := make(map[string]int64)
	for spentRows.Next() {
		var catID string
		var spent int64
		if err := spentRows.Scan(&catID, &spent); err != nil {
			return nil, status.Error(codes.Internal, "failed to scan category spent")
		}
		spentMap[catID] = spent
	}

	var categories []*pb.CategoryBudgetItem
	for _, cb := range catBudgets {
		spent := spentMap[cb.catID]
		var rate float64
		if cb.budgetAmt > 0 {
			rate = float64(spent) / float64(cb.budgetAmt)
		}
		categories = append(categories, &pb.CategoryBudgetItem{
			CategoryId:    cb.catID,
			CategoryName:  cb.catName,
			BudgetAmount:  cb.budgetAmt,
			SpentAmount:   spent,
			ExecutionRate: rate,
		})
	}

	return &pb.BudgetSummaryResponse{
		TotalBudget:   totalBudget,
		TotalSpent:    totalSpent,
		ExecutionRate: executionRate,
		Categories:    categories,
	}, nil
}

// ── GetNetWorthTrend ────────────────────────────────────────────────────────

func (s *Service) GetNetWorthTrend(ctx context.Context, req *pb.TrendRequest) (*pb.TrendResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	count := int(req.Count)
	if count <= 0 {
		count = 12
	}
	if count > 60 {
		count = 60
	}

	// 简化方案：从当前净资产回推，用每月净收支逆推
	// 先拿当前净资产
	nw, err := s.GetNetWorth(ctx, &pb.GetNetWorthRequest{FamilyId: req.FamilyId})
	if err != nil {
		return nil, err
	}
	currentTotal := nw.Total

	now := time.Now()
	var points []*pb.TrendPoint

	// 查每月净收支
	startDate := time.Date(now.Year(), now.Month()-time.Month(count-1), 1, 0, 0, 0, 0, time.UTC)
	rows, err := s.pool.Query(ctx,
		`SELECT DATE_TRUNC('month', txn_date) AS period,
		        COALESCE(SUM(CASE WHEN type = 'income' THEN amount_cny ELSE 0 END), 0) AS income,
		        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount_cny ELSE 0 END), 0) AS expense
		 FROM transactions
		 WHERE user_id = $1 AND deleted_at IS NULL AND txn_date >= $2
		 GROUP BY 1 ORDER BY 1`,
		userID, startDate,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to query net worth trend")
	}
	defer rows.Close()

	type monthData struct {
		label string
		net   int64
	}
	var months []monthData
	for rows.Next() {
		var period time.Time
		var income, expense int64
		if err := rows.Scan(&period, &income, &expense); err != nil {
			return nil, status.Error(codes.Internal, "failed to scan trend row")
		}
		months = append(months, monthData{
			label: period.Format("2006-01"),
			net:   income - expense,
		})
	}

	// 从后往前，逆推净资产
	// netWorth[currentMonth] = currentTotal
	// netWorth[previousMonth] = netWorth[currentMonth] - net[currentMonth]
	currentMonthLabel := now.Format("2006-01")

	// 建立 label -> net 映射
	netMap := make(map[string]int64)
	for _, m := range months {
		netMap[m.label] = m.net
	}

	// 生成连续月份列表
	type monthPoint struct {
		label    string
		netWorth int64
	}
	var allMonths []monthPoint
	for i := 0; i < count; i++ {
		t := time.Date(now.Year(), now.Month()-time.Month(i), 1, 0, 0, 0, 0, time.UTC)
		allMonths = append(allMonths, monthPoint{label: t.Format("2006-01")})
	}

	// 逆序填充净资产
	runningTotal := currentTotal
	for i := 0; i < len(allMonths); i++ {
		label := allMonths[i].label
		if i == 0 && label == currentMonthLabel {
			allMonths[i].netWorth = currentTotal
		} else if i > 0 {
			// 减去上个月（allMonths[i-1]）的净收入得到本月末的净资产
			prevLabel := allMonths[i-1].label
			runningTotal -= netMap[prevLabel]
			allMonths[i].netWorth = runningTotal
		} else {
			allMonths[i].netWorth = runningTotal
		}
	}

	// 反转为时间正序
	for i := len(allMonths) - 1; i >= 0; i-- {
		m := allMonths[i]
		points = append(points, &pb.TrendPoint{
			Label: m.label,
			Net:   m.netWorth,
		})
	}

	return &pb.TrendResponse{Points: points}, nil
}
