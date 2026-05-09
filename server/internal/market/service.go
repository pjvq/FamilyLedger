package market

import (
	"context"
	"log"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/familyledger/server/pkg/db"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	pb "github.com/familyledger/server/proto/investment"
)

const quoteCacheTTL = 15 * time.Minute

type Service struct {
	pb.UnimplementedMarketDataServiceServer
	pool db.Pool
	fetcher MarketDataFetcher
}

func NewService(pool db.Pool, fetcher MarketDataFetcher) *Service {
	return &Service{pool: pool, fetcher: fetcher}
}

// ── GetQuote ────────────────────────────────────────────────────────────────

func (s *Service) GetQuote(ctx context.Context, req *pb.GetQuoteRequest) (*pb.MarketQuote, error) {
	if req.Symbol == "" {
		return nil, status.Error(codes.InvalidArgument, "symbol is required")
	}
	if req.MarketType == pb.MarketType_MARKET_TYPE_UNSPECIFIED {
		return nil, status.Error(codes.InvalidArgument, "market_type is required")
	}

	mt := marketTypeToString(req.MarketType)
	quote, err := s.getOrFetchQuote(ctx, req.Symbol, mt)
	if err != nil {
		return nil, err
	}
	return quoteToProto(quote), nil
}

// ── BatchGetQuotes ──────────────────────────────────────────────────────────

func (s *Service) BatchGetQuotes(ctx context.Context, req *pb.BatchGetQuotesRequest) (*pb.BatchGetQuotesResponse, error) {
	if len(req.Requests) == 0 {
		return &pb.BatchGetQuotesResponse{}, nil
	}
	if len(req.Requests) > 50 {
		return nil, status.Error(codes.InvalidArgument, "max 50 quotes per batch")
	}

	quotes := make([]*pb.MarketQuote, 0, len(req.Requests))
	for _, r := range req.Requests {
		if r.Symbol == "" || r.MarketType == pb.MarketType_MARKET_TYPE_UNSPECIFIED {
			continue
		}
		mt := marketTypeToString(r.MarketType)
		q, err := s.getOrFetchQuote(ctx, r.Symbol, mt)
		if err != nil {
			log.Printf("market: batch quote error for %s/%s: %v", r.Symbol, mt, err)
			continue
		}
		quotes = append(quotes, quoteToProto(q))
	}
	return &pb.BatchGetQuotesResponse{Quotes: quotes}, nil
}

// ── SearchSymbol ────────────────────────────────────────────────────────────

func (s *Service) SearchSymbol(ctx context.Context, req *pb.SearchSymbolRequest) (*pb.SearchSymbolResponse, error) {
	if req.Query == "" {
		return nil, status.Error(codes.InvalidArgument, "query is required")
	}

	mt := ""
	if req.MarketType != pb.MarketType_MARKET_TYPE_UNSPECIFIED {
		mt = marketTypeToString(req.MarketType)
	}

	// Search cached quotes first
	var results []*pb.SymbolInfo

	query := "%" + req.Query + "%"
	var rows pgx.Rows
	var err error

	if mt != "" {
		rows, err = s.pool.Query(ctx,
			`SELECT symbol, name, market_type FROM market_quotes
			 WHERE market_type = $1 AND (symbol ILIKE $2 OR name ILIKE $2)
			 LIMIT 20`,
			mt, query,
		)
	} else {
		rows, err = s.pool.Query(ctx,
			`SELECT symbol, name, market_type FROM market_quotes
			 WHERE symbol ILIKE $1 OR name ILIKE $1
			 LIMIT 20`,
			query,
		)
	}
	if err != nil {
		return nil, status.Errorf(codes.Internal, "search cache: %v", err)
	}
	defer rows.Close()

	for rows.Next() {
		var sym, name, mkt string
		if err := rows.Scan(&sym, &name, &mkt); err != nil {
			continue
		}
		results = append(results, &pb.SymbolInfo{
			Symbol:     sym,
			Name:       name,
			MarketType: stringToMarketType(mkt),
		})
	}

	// If cache had no results, try external fetcher
	if len(results) == 0 {
		external, err := s.fetcher.SearchSymbol(ctx, req.Query, mt)
		if err != nil {
			log.Printf("market: external search error: %v", err)
		} else {
			for _, si := range external {
				results = append(results, &pb.SymbolInfo{
					Symbol:     si.Symbol,
					Name:       si.Name,
					MarketType: stringToMarketType(si.MarketType),
				})
			}
		}
	}

	if results == nil {
		results = []*pb.SymbolInfo{}
	}
	return &pb.SearchSymbolResponse{Symbols: results}, nil
}

// ── GetPriceHistory ─────────────────────────────────────────────────────────

func (s *Service) GetPriceHistory(ctx context.Context, req *pb.GetPriceHistoryRequest) (*pb.PriceHistoryResponse, error) {
	if req.Symbol == "" {
		return nil, status.Error(codes.InvalidArgument, "symbol is required")
	}
	if req.MarketType == pb.MarketType_MARKET_TYPE_UNSPECIFIED {
		return nil, status.Error(codes.InvalidArgument, "market_type is required")
	}

	mt := marketTypeToString(req.MarketType)

	var startDate, endDate time.Time
	if req.StartDate != nil {
		startDate = req.StartDate.AsTime()
	} else {
		startDate = time.Now().AddDate(-1, 0, 0) // default: 1 year ago
	}
	if req.EndDate != nil {
		endDate = req.EndDate.AsTime()
	} else {
		endDate = time.Now()
	}

	rows, err := s.pool.Query(ctx,
		`SELECT price_date, close_price FROM price_history
		 WHERE symbol = $1 AND market_type = $2 AND price_date >= $3 AND price_date <= $4
		 ORDER BY price_date`,
		req.Symbol, mt, startDate, endDate,
	)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "query price history: %v", err)
	}
	defer rows.Close()

	var points []*pb.PricePoint
	for rows.Next() {
		var d time.Time
		var price int64
		if err := rows.Scan(&d, &price); err != nil {
			continue
		}
		points = append(points, &pb.PricePoint{
			Timestamp: timestamppb.New(d),
			Price:     price,
		})
	}
	if points == nil {
		points = []*pb.PricePoint{}
	}

	return &pb.PriceHistoryResponse{
		Symbol:     req.Symbol,
		MarketType: req.MarketType,
		Points:     points,
	}, nil
}

// ── Internal helpers ────────────────────────────────────────────────────────

// getOrFetchQuote checks cache (15min TTL), fetches from external if stale.
func (s *Service) getOrFetchQuote(ctx context.Context, symbol, marketType string) (*cachedQuote, error) {
	// Try cache
	var q cachedQuote
	err := s.pool.QueryRow(ctx,
		`SELECT symbol, market_type, name, current_price, change_amount, change_percent,
		        open_price, high_price, low_price, prev_close, updated_at
		 FROM market_quotes WHERE symbol = $1 AND market_type = $2`,
		symbol, marketType,
	).Scan(&q.Symbol, &q.MarketType, &q.Name, &q.CurrentPrice, &q.ChangeAmount,
		&q.ChangePercent, &q.Open, &q.High, &q.Low, &q.PrevClose, &q.UpdatedAt)

	if err == nil && time.Since(q.UpdatedAt) < quoteCacheTTL {
		return &q, nil
	}

	// Fetch from external
	mq, err := s.fetcher.FetchQuote(ctx, symbol, marketType)
	if err != nil {
		// If we have stale cache, return it
		if q.Symbol != "" {
			return &q, nil
		}
		return nil, status.Errorf(codes.Internal, "fetch quote: %v", err)
	}

	// Upsert cache
	now := time.Now()
	_, err = s.pool.Exec(ctx,
		`INSERT INTO market_quotes (symbol, market_type, name, current_price, change_amount,
		 change_percent, open_price, high_price, low_price, prev_close, updated_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
		 ON CONFLICT (symbol, market_type) DO UPDATE SET
		   name = EXCLUDED.name, current_price = EXCLUDED.current_price,
		   change_amount = EXCLUDED.change_amount, change_percent = EXCLUDED.change_percent,
		   open_price = EXCLUDED.open_price, high_price = EXCLUDED.high_price,
		   low_price = EXCLUDED.low_price, prev_close = EXCLUDED.prev_close,
		   updated_at = EXCLUDED.updated_at`,
		symbol, marketType, mq.Name, mq.CurrentPrice, mq.ChangeAmount,
		mq.ChangePercent, mq.Open, mq.High, mq.Low, mq.PrevClose, now,
	)
	if err != nil {
		log.Printf("market: cache upsert error: %v", err)
	}

	return &cachedQuote{
		Symbol:        symbol,
		MarketType:    marketType,
		Name:          mq.Name,
		CurrentPrice:  mq.CurrentPrice,
		ChangeAmount:  mq.ChangeAmount,
		ChangePercent: mq.ChangePercent,
		Open:          &mq.Open,
		High:          &mq.High,
		Low:           &mq.Low,
		PrevClose:     &mq.PrevClose,
		UpdatedAt:     now,
	}, nil
}

type cachedQuote struct {
	Symbol        string
	MarketType    string
	Name          string
	CurrentPrice  int64
	ChangeAmount  int64
	ChangePercent float64
	Open          *int64
	High          *int64
	Low           *int64
	PrevClose     *int64
	UpdatedAt     time.Time
}

func quoteToProto(q *cachedQuote) *pb.MarketQuote {
	result := &pb.MarketQuote{
		Symbol:        q.Symbol,
		Name:          q.Name,
		MarketType:    stringToMarketType(q.MarketType),
		CurrentPrice:  q.CurrentPrice,
		Change:        q.ChangeAmount,
		ChangePercent: q.ChangePercent,
		UpdatedAt:     timestamppb.New(q.UpdatedAt),
	}
	if q.Open != nil {
		result.Open = *q.Open
	}
	if q.High != nil {
		result.High = *q.High
	}
	if q.Low != nil {
		result.Low = *q.Low
	}
	if q.PrevClose != nil {
		result.PrevClose = *q.PrevClose
	}
	return result
}

// RefreshQuotes fetches fresh quotes for all actively held symbols.
// Called by the scheduler.
func (s *Service) RefreshQuotes(ctx context.Context, marketTypes []string) error {
	// Find all symbols that have active investments
	rows, err := s.pool.Query(ctx,
		`SELECT DISTINCT symbol, market_type FROM investments
		 WHERE deleted_at IS NULL AND quantity > 0`,
	)
	if err != nil {
		return err
	}
	defer rows.Close()

	type symbolKey struct {
		symbol     string
		marketType string
	}
	var symbols []symbolKey

	for rows.Next() {
		var sk symbolKey
		if err := rows.Scan(&sk.symbol, &sk.marketType); err != nil {
			continue
		}
		// Filter by requested market types
		if len(marketTypes) > 0 {
			found := false
			for _, mt := range marketTypes {
				if sk.marketType == mt {
					found = true
					break
				}
			}
			if !found {
				continue
			}
		}
		symbols = append(symbols, sk)
	}

	if len(symbols) == 0 {
		return nil
	}

	log.Printf("market: refreshing %d quotes", len(symbols))
	for _, sk := range symbols {
		mq, err := s.fetcher.FetchQuote(ctx, sk.symbol, sk.marketType)
		if err != nil {
			log.Printf("market: refresh error %s/%s: %v", sk.symbol, sk.marketType, err)
			continue
		}

		now := time.Now()
		_, err = s.pool.Exec(ctx,
			`INSERT INTO market_quotes (symbol, market_type, name, current_price, change_amount,
			 change_percent, open_price, high_price, low_price, prev_close, updated_at)
			 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
			 ON CONFLICT (symbol, market_type) DO UPDATE SET
			   name = EXCLUDED.name, current_price = EXCLUDED.current_price,
			   change_amount = EXCLUDED.change_amount, change_percent = EXCLUDED.change_percent,
			   open_price = EXCLUDED.open_price, high_price = EXCLUDED.high_price,
			   low_price = EXCLUDED.low_price, prev_close = EXCLUDED.prev_close,
			   updated_at = EXCLUDED.updated_at`,
			sk.symbol, sk.marketType, mq.Name, mq.CurrentPrice, mq.ChangeAmount,
			mq.ChangePercent, mq.Open, mq.High, mq.Low, mq.PrevClose, now,
		)
		if err != nil {
			log.Printf("market: cache upsert error %s/%s: %v", sk.symbol, sk.marketType, err)
		}

		// Also insert into price_history for today
		_, err = s.pool.Exec(ctx,
			`INSERT INTO price_history (symbol, market_type, price_date, close_price)
			 VALUES ($1, $2, $3, $4)
			 ON CONFLICT (symbol, market_type, price_date) DO UPDATE SET close_price = EXCLUDED.close_price`,
			sk.symbol, sk.marketType, now.Format("2006-01-02"), mq.CurrentPrice,
		)
		if err != nil {
			log.Printf("market: price_history upsert error: %v", err)
		}
	}

	return nil
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
	case pb.MarketType_MARKET_TYPE_PRECIOUS_METAL:
		return "precious_metal"
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
	case "precious_metal":
		return pb.MarketType_MARKET_TYPE_PRECIOUS_METAL
	default:
		return pb.MarketType_MARKET_TYPE_UNSPECIFIED
	}
}
