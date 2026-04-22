package investment

import (
	"context"
	"log"
	"math"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/familyledger/server/pkg/middleware"
	pb "github.com/familyledger/server/proto/investment"
)

type Service struct {
	pb.UnimplementedInvestmentServiceServer
	pool *pgxpool.Pool
}

func NewService(pool *pgxpool.Pool) *Service {
	return &Service{pool: pool}
}

// ── CreateInvestment ────────────────────────────────────────────────────────

func (s *Service) CreateInvestment(ctx context.Context, req *pb.CreateInvestmentRequest) (*pb.Investment, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}
	if req.Symbol == "" {
		return nil, status.Error(codes.InvalidArgument, "symbol is required")
	}
	if req.Name == "" {
		return nil, status.Error(codes.InvalidArgument, "name is required")
	}
	if req.MarketType == pb.MarketType_MARKET_TYPE_UNSPECIFIED {
		return nil, status.Error(codes.InvalidArgument, "market_type is required")
	}

	mt := marketTypeToString(req.MarketType)

	var id uuid.UUID
	var createdAt, updatedAt time.Time
	err = s.pool.QueryRow(ctx,
		`INSERT INTO investments (user_id, symbol, name, market_type)
		 VALUES ($1, $2, $3, $4)
		 RETURNING id, created_at, updated_at`,
		userID, req.Symbol, req.Name, mt,
	).Scan(&id, &createdAt, &updatedAt)
	if err != nil {
		// Check for unique constraint violation
		if isDuplicateError(err) {
			return nil, status.Errorf(codes.AlreadyExists, "investment %s/%s already exists", req.Symbol, mt)
		}
		log.Printf("investment: create error: %v", err)
		return nil, status.Error(codes.Internal, "failed to create investment")
	}

	log.Printf("investment: created %s (%s/%s) for user %s", id, req.Symbol, mt, userID)
	return &pb.Investment{
		Id:         id.String(),
		UserId:     userID,
		Symbol:     req.Symbol,
		Name:       req.Name,
		MarketType: req.MarketType,
		CreatedAt:  timestamppb.New(createdAt),
		UpdatedAt:  timestamppb.New(updatedAt),
	}, nil
}

// ── GetInvestment ───────────────────────────────────────────────────────────

func (s *Service) GetInvestment(ctx context.Context, req *pb.GetInvestmentRequest) (*pb.Investment, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}
	if req.InvestmentId == "" {
		return nil, status.Error(codes.InvalidArgument, "investment_id is required")
	}
	return s.loadInvestmentWithMarket(ctx, req.InvestmentId, userID)
}

// ── ListInvestments ─────────────────────────────────────────────────────────

func (s *Service) ListInvestments(ctx context.Context, req *pb.ListInvestmentsRequest) (*pb.ListInvestmentsResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	var rows pgx.Rows
	if req.MarketType != pb.MarketType_MARKET_TYPE_UNSPECIFIED {
		mt := marketTypeToString(req.MarketType)
		rows, err = s.pool.Query(ctx,
			`SELECT i.id, i.user_id, i.symbol, i.name, i.market_type, i.quantity, i.cost_basis,
			        i.created_at, i.updated_at,
			        mq.current_price
			 FROM investments i
			 LEFT JOIN market_quotes mq ON i.symbol = mq.symbol AND i.market_type = mq.market_type
			 WHERE i.user_id = $1 AND i.deleted_at IS NULL AND i.market_type = $2
			 ORDER BY i.created_at DESC`,
			userID, mt,
		)
	} else {
		rows, err = s.pool.Query(ctx,
			`SELECT i.id, i.user_id, i.symbol, i.name, i.market_type, i.quantity, i.cost_basis,
			        i.created_at, i.updated_at,
			        mq.current_price
			 FROM investments i
			 LEFT JOIN market_quotes mq ON i.symbol = mq.symbol AND i.market_type = mq.market_type
			 WHERE i.user_id = $1 AND i.deleted_at IS NULL
			 ORDER BY i.created_at DESC`,
			userID,
		)
	}
	if err != nil {
		return nil, status.Errorf(codes.Internal, "list investments: %v", err)
	}
	defer rows.Close()

	var investments []*pb.Investment
	for rows.Next() {
		inv, err := scanInvestmentRow(rows)
		if err != nil {
			return nil, err
		}
		investments = append(investments, inv)
	}
	if investments == nil {
		investments = []*pb.Investment{}
	}
	return &pb.ListInvestmentsResponse{Investments: investments}, nil
}

// ── UpdateInvestment ────────────────────────────────────────────────────────

func (s *Service) UpdateInvestment(ctx context.Context, req *pb.UpdateInvestmentRequest) (*pb.Investment, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}
	if req.InvestmentId == "" {
		return nil, status.Error(codes.InvalidArgument, "investment_id is required")
	}
	if req.Name == "" {
		return nil, status.Error(codes.InvalidArgument, "name is required")
	}

	tag, err := s.pool.Exec(ctx,
		`UPDATE investments SET name = $1, updated_at = NOW()
		 WHERE id = $2 AND user_id = $3 AND deleted_at IS NULL`,
		req.Name, req.InvestmentId, userID,
	)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "update investment: %v", err)
	}
	if tag.RowsAffected() == 0 {
		return nil, status.Error(codes.NotFound, "investment not found")
	}
	return s.loadInvestmentWithMarket(ctx, req.InvestmentId, userID)
}

// ── DeleteInvestment ────────────────────────────────────────────────────────

func (s *Service) DeleteInvestment(ctx context.Context, req *pb.DeleteInvestmentRequest) (*emptypb.Empty, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}
	if req.InvestmentId == "" {
		return nil, status.Error(codes.InvalidArgument, "investment_id is required")
	}

	tag, err := s.pool.Exec(ctx,
		`UPDATE investments SET deleted_at = NOW(), updated_at = NOW()
		 WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL`,
		req.InvestmentId, userID,
	)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "delete investment: %v", err)
	}
	if tag.RowsAffected() == 0 {
		return nil, status.Error(codes.NotFound, "investment not found")
	}
	log.Printf("investment: soft-deleted %s by user %s", req.InvestmentId, userID)
	return &emptypb.Empty{}, nil
}

// ── RecordTrade ─────────────────────────────────────────────────────────────

func (s *Service) RecordTrade(ctx context.Context, req *pb.RecordTradeRequest) (*pb.InvestmentTrade, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}
	if err := validateTradeRequest(req); err != nil {
		return nil, err
	}

	totalAmount := int64(math.Round(float64(req.Price) * req.Quantity))

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to begin transaction")
	}
	defer tx.Rollback(ctx)

	// Verify ownership and get current state
	var curQuantity float64
	var curCostBasis int64
	err = tx.QueryRow(ctx,
		`SELECT quantity, cost_basis FROM investments
		 WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL
		 FOR UPDATE`,
		req.InvestmentId, userID,
	).Scan(&curQuantity, &curCostBasis)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, status.Error(codes.NotFound, "investment not found")
		}
		return nil, status.Errorf(codes.Internal, "query investment: %v", err)
	}

	var newQuantity float64
	var newCostBasis int64
	tradeType := tradeTypeToString(req.TradeType)

	switch req.TradeType {
	case pb.TradeType_TRADE_TYPE_BUY:
		newQuantity = curQuantity + req.Quantity
		newCostBasis = curCostBasis + totalAmount + req.Fee
	case pb.TradeType_TRADE_TYPE_SELL:
		if req.Quantity > curQuantity {
			return nil, status.Errorf(codes.InvalidArgument,
				"sell quantity %.8f exceeds holding %.8f", req.Quantity, curQuantity)
		}
		newQuantity = curQuantity - req.Quantity
		// Reduce cost basis proportionally (average cost method)
		if curQuantity > 0 {
			soldRatio := req.Quantity / curQuantity
			costReduction := int64(math.Round(float64(curCostBasis) * soldRatio))
			newCostBasis = curCostBasis - costReduction
		}
		if newQuantity < 1e-10 {
			newQuantity = 0
			newCostBasis = 0
		}
	}

	// Update investment
	_, err = tx.Exec(ctx,
		`UPDATE investments SET quantity = $1, cost_basis = $2, updated_at = NOW()
		 WHERE id = $3`,
		newQuantity, newCostBasis, req.InvestmentId,
	)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "update investment: %v", err)
	}

	// Insert trade record
	tradeDate := time.Now()
	if req.TradeDate != nil {
		tradeDate = req.TradeDate.AsTime()
	}

	var tradeID uuid.UUID
	err = tx.QueryRow(ctx,
		`INSERT INTO investment_trades (investment_id, trade_type, quantity, price, total_amount, fee, trade_date)
		 VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id`,
		req.InvestmentId, tradeType, req.Quantity, req.Price, totalAmount, req.Fee, tradeDate,
	).Scan(&tradeID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "insert trade: %v", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Error(codes.Internal, "failed to commit")
	}

	log.Printf("investment: trade %s %s qty=%.4f price=%d for %s", tradeType, req.InvestmentId, req.Quantity, req.Price, userID)
	return &pb.InvestmentTrade{
		Id:           tradeID.String(),
		InvestmentId: req.InvestmentId,
		TradeType:    req.TradeType,
		Quantity:     req.Quantity,
		Price:        req.Price,
		TotalAmount:  totalAmount,
		Fee:          req.Fee,
		TradeDate:    timestamppb.New(tradeDate),
	}, nil
}

// ── ListTrades ──────────────────────────────────────────────────────────────

func (s *Service) ListTrades(ctx context.Context, req *pb.ListTradesRequest) (*pb.ListTradesResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}
	if req.InvestmentId == "" {
		return nil, status.Error(codes.InvalidArgument, "investment_id is required")
	}

	// Verify ownership
	var exists bool
	err = s.pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM investments WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL)`,
		req.InvestmentId, userID,
	).Scan(&exists)
	if err != nil || !exists {
		return nil, status.Error(codes.NotFound, "investment not found")
	}

	rows, err := s.pool.Query(ctx,
		`SELECT id, investment_id, trade_type, quantity, price, total_amount, fee, trade_date
		 FROM investment_trades WHERE investment_id = $1
		 ORDER BY trade_date DESC`,
		req.InvestmentId,
	)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "list trades: %v", err)
	}
	defer rows.Close()

	var trades []*pb.InvestmentTrade
	for rows.Next() {
		var id uuid.UUID
		var investmentID string
		var tradeType string
		var quantity float64
		var price, totalAmount, fee int64
		var tradeDate time.Time

		if err := rows.Scan(&id, &investmentID, &tradeType, &quantity, &price, &totalAmount, &fee, &tradeDate); err != nil {
			return nil, status.Errorf(codes.Internal, "scan trade: %v", err)
		}
		trades = append(trades, &pb.InvestmentTrade{
			Id:           id.String(),
			InvestmentId: investmentID,
			TradeType:    stringToTradeType(tradeType),
			Quantity:     quantity,
			Price:        price,
			TotalAmount:  totalAmount,
			Fee:          fee,
			TradeDate:    timestamppb.New(tradeDate),
		})
	}
	if trades == nil {
		trades = []*pb.InvestmentTrade{}
	}
	return &pb.ListTradesResponse{Trades: trades}, nil
}

// ── GetPortfolioSummary ─────────────────────────────────────────────────────

func (s *Service) GetPortfolioSummary(ctx context.Context, _ *pb.GetPortfolioSummaryRequest) (*pb.PortfolioSummary, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	rows, err := s.pool.Query(ctx,
		`SELECT i.id, i.symbol, i.name, i.market_type, i.quantity, i.cost_basis,
		        i.created_at, mq.current_price
		 FROM investments i
		 LEFT JOIN market_quotes mq ON i.symbol = mq.symbol AND i.market_type = mq.market_type
		 WHERE i.user_id = $1 AND i.deleted_at IS NULL AND i.quantity > 0
		 ORDER BY i.created_at`,
		userID,
	)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "portfolio query: %v", err)
	}
	defer rows.Close()

	var totalValue, totalCost int64
	var holdings []*pb.HoldingItem

	for rows.Next() {
		var id uuid.UUID
		var symbol, name, marketType string
		var quantity float64
		var costBasis int64
		var createdAt time.Time
		var currentPrice *int64

		if err := rows.Scan(&id, &symbol, &name, &marketType, &quantity, &costBasis, &createdAt, &currentPrice); err != nil {
			return nil, status.Errorf(codes.Internal, "scan portfolio: %v", err)
		}

		var curVal int64
		if currentPrice != nil && quantity > 0 {
			curVal = int64(math.Round(float64(*currentPrice) * quantity))
		}

		var returnRate float64
		if costBasis > 0 {
			returnRate = float64(curVal-costBasis) / float64(costBasis)
		}

		totalValue += curVal
		totalCost += costBasis

		holdings = append(holdings, &pb.HoldingItem{
			InvestmentId: id.String(),
			Symbol:       symbol,
			Name:         name,
			Quantity:     quantity,
			CurrentValue: curVal,
			ReturnRate:   math.Round(returnRate*10000) / 10000, // 4 decimal places
		})
	}

	// Calculate weights
	if totalValue > 0 {
		for _, h := range holdings {
			h.Weight = math.Round(float64(h.CurrentValue)/float64(totalValue)*10000) / 10000
		}
	}

	var totalReturn float64
	if totalCost > 0 {
		totalReturn = float64(totalValue-totalCost) / float64(totalCost)
	}
	totalProfit := totalValue - totalCost

	if holdings == nil {
		holdings = []*pb.HoldingItem{}
	}

	return &pb.PortfolioSummary{
		TotalValue:  totalValue,
		TotalCost:   totalCost,
		TotalProfit: totalProfit,
		TotalReturn: math.Round(totalReturn*10000) / 10000,
		Holdings:    holdings,
	}, nil
}

// ════════════════════════════════════════════════════════════════════════════
// Internal helpers
// ════════════════════════════════════════════════════════════════════════════

func (s *Service) loadInvestmentWithMarket(ctx context.Context, investmentID, userID string) (*pb.Investment, error) {
	var id uuid.UUID
	var uid, symbol, name, marketType string
	var quantity float64
	var costBasis int64
	var createdAt, updatedAt time.Time
	var currentPrice *int64

	err := s.pool.QueryRow(ctx,
		`SELECT i.id, i.user_id, i.symbol, i.name, i.market_type, i.quantity, i.cost_basis,
		        i.created_at, i.updated_at, mq.current_price
		 FROM investments i
		 LEFT JOIN market_quotes mq ON i.symbol = mq.symbol AND i.market_type = mq.market_type
		 WHERE i.id = $1 AND i.deleted_at IS NULL`,
		investmentID,
	).Scan(&id, &uid, &symbol, &name, &marketType, &quantity, &costBasis,
		&createdAt, &updatedAt, &currentPrice)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, status.Error(codes.NotFound, "investment not found")
		}
		return nil, status.Errorf(codes.Internal, "query investment: %v", err)
	}
	if uid != userID {
		return nil, status.Error(codes.PermissionDenied, "not your investment")
	}

	inv := &pb.Investment{
		Id:         id.String(),
		UserId:     uid,
		Symbol:     symbol,
		Name:       name,
		MarketType: stringToMarketType(marketType),
		Quantity:   quantity,
		CostBasis:  costBasis,
		CreatedAt:  timestamppb.New(createdAt),
		UpdatedAt:  timestamppb.New(updatedAt),
	}

	// Calculate current value and returns
	if currentPrice != nil && quantity > 0 {
		inv.CurrentValue = int64(math.Round(float64(*currentPrice) * quantity))
		if costBasis > 0 {
			inv.TotalReturn = float64(inv.CurrentValue-costBasis) / float64(costBasis)
			inv.TotalReturn = math.Round(inv.TotalReturn*10000) / 10000

			// Annualized return: (1 + totalReturn)^(365/holdingDays) - 1
			holdingDays := time.Since(createdAt).Hours() / 24
			if holdingDays >= 1 {
				inv.AnnualizedReturn = math.Pow(1+inv.TotalReturn, 365/holdingDays) - 1
				inv.AnnualizedReturn = math.Round(inv.AnnualizedReturn*10000) / 10000
			}
		}
	}

	return inv, nil
}

func scanInvestmentRow(rows pgx.Rows) (*pb.Investment, error) {
	var id uuid.UUID
	var uid, symbol, name, marketType string
	var quantity float64
	var costBasis int64
	var createdAt, updatedAt time.Time
	var currentPrice *int64

	if err := rows.Scan(&id, &uid, &symbol, &name, &marketType, &quantity, &costBasis,
		&createdAt, &updatedAt, &currentPrice); err != nil {
		return nil, status.Errorf(codes.Internal, "scan investment: %v", err)
	}

	inv := &pb.Investment{
		Id:         id.String(),
		UserId:     uid,
		Symbol:     symbol,
		Name:       name,
		MarketType: stringToMarketType(marketType),
		Quantity:   quantity,
		CostBasis:  costBasis,
		CreatedAt:  timestamppb.New(createdAt),
		UpdatedAt:  timestamppb.New(updatedAt),
	}

	if currentPrice != nil && quantity > 0 {
		inv.CurrentValue = int64(math.Round(float64(*currentPrice) * quantity))
		if costBasis > 0 {
			inv.TotalReturn = float64(inv.CurrentValue-costBasis) / float64(costBasis)
			inv.TotalReturn = math.Round(inv.TotalReturn*10000) / 10000

			holdingDays := time.Since(createdAt).Hours() / 24
			if holdingDays >= 1 {
				inv.AnnualizedReturn = math.Pow(1+inv.TotalReturn, 365/holdingDays) - 1
				inv.AnnualizedReturn = math.Round(inv.AnnualizedReturn*10000) / 10000
			}
		}
	}

	return inv, nil
}

func validateTradeRequest(req *pb.RecordTradeRequest) error {
	if req.InvestmentId == "" {
		return status.Error(codes.InvalidArgument, "investment_id is required")
	}
	if req.TradeType == pb.TradeType_TRADE_TYPE_UNSPECIFIED {
		return status.Error(codes.InvalidArgument, "trade_type is required")
	}
	if req.Quantity <= 0 {
		return status.Error(codes.InvalidArgument, "quantity must be positive")
	}
	if req.Price <= 0 {
		return status.Error(codes.InvalidArgument, "price must be positive")
	}
	if req.Fee < 0 {
		return status.Error(codes.InvalidArgument, "fee must be non-negative")
	}
	return nil
}

func isDuplicateError(err error) bool {
	return err != nil && (contains(err.Error(), "duplicate key") || contains(err.Error(), "unique constraint"))
}

func contains(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(s) > 0 && containsImpl(s, substr))
}

func containsImpl(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}

// ── Type conversions ────────────────────────────────────────────────────────

func marketTypeToString(mt pb.MarketType) string {
	switch mt {
	case pb.MarketType_MARKET_TYPE_A_SHARE:
		return "a_share"
	case pb.MarketType_MARKET_TYPE_HK_STOCK:
		return "hk_stock"
	case pb.MarketType_MARKET_TYPE_US_STOCK:
		return "us_stock"
	case pb.MarketType_MARKET_TYPE_CRYPTO:
		return "crypto"
	case pb.MarketType_MARKET_TYPE_FUND:
		return "fund"
	default:
		return "unspecified"
	}
}

func stringToMarketType(s string) pb.MarketType {
	switch s {
	case "a_share":
		return pb.MarketType_MARKET_TYPE_A_SHARE
	case "hk_stock":
		return pb.MarketType_MARKET_TYPE_HK_STOCK
	case "us_stock":
		return pb.MarketType_MARKET_TYPE_US_STOCK
	case "crypto":
		return pb.MarketType_MARKET_TYPE_CRYPTO
	case "fund":
		return pb.MarketType_MARKET_TYPE_FUND
	default:
		return pb.MarketType_MARKET_TYPE_UNSPECIFIED
	}
}

func tradeTypeToString(tt pb.TradeType) string {
	switch tt {
	case pb.TradeType_TRADE_TYPE_BUY:
		return "buy"
	case pb.TradeType_TRADE_TYPE_SELL:
		return "sell"
	default:
		return "unspecified"
	}
}

func stringToTradeType(s string) pb.TradeType {
	switch s {
	case "buy":
		return pb.TradeType_TRADE_TYPE_BUY
	case "sell":
		return pb.TradeType_TRADE_TYPE_SELL
	default:
		return pb.TradeType_TRADE_TYPE_UNSPECIFIED
	}
}

