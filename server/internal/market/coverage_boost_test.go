package market

import (
	"context"
	"encoding/json"
	"fmt"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	pb "github.com/familyledger/server/proto/investment"
)

// ── yuanToCents ─────────────────────────────────────────────────────────────

func TestBoost_YuanToCents_ValidFloat(t *testing.T) {
	n := json.Number("12.34")
	assert.Equal(t, int64(1234), yuanToCents(n))
}

func TestBoost_YuanToCents_Integer(t *testing.T) {
	n := json.Number("100")
	assert.Equal(t, int64(10000), yuanToCents(n))
}

func TestBoost_YuanToCents_Zero(t *testing.T) {
	n := json.Number("0")
	assert.Equal(t, int64(0), yuanToCents(n))
}

func TestBoost_YuanToCents_Negative(t *testing.T) {
	n := json.Number("-1.5")
	assert.Equal(t, int64(-150), yuanToCents(n))
}

func TestBoost_YuanToCents_InvalidString(t *testing.T) {
	n := json.Number("not_a_number")
	assert.Equal(t, int64(0), yuanToCents(n))
}

func TestBoost_YuanToCents_SmallFraction(t *testing.T) {
	n := json.Number("0.01")
	assert.Equal(t, int64(1), yuanToCents(n))
}

func TestBoost_YuanToCents_Rounding(t *testing.T) {
	// 12.345 → 1234.5 → rounds to 1235 (math.Round)
	n := json.Number("12.345")
	assert.Equal(t, int64(1235), yuanToCents(n))
}

// ── MockFetcher ─────────────────────────────────────────────────────────────

func TestBoost_NewMockFetcher(t *testing.T) {
	f := NewMockFetcher()
	require.NotNil(t, f)
}

func TestBoost_MockFetcher_FetchQuote_AllMarketTypes(t *testing.T) {
	f := NewMockFetcher()
	ctx := context.Background()

	marketTypes := []string{"a_share", "hk_stock", "us_stock", "crypto", "fund"}
	for _, mt := range marketTypes {
		t.Run(mt, func(t *testing.T) {
			q, err := f.FetchQuote(ctx, "TEST123", mt)
			require.NoError(t, err)
			require.NotNil(t, q)
			assert.Equal(t, "TEST123", q.Symbol)
			assert.Equal(t, mt, q.MarketType)
			assert.Greater(t, q.CurrentPrice, int64(0))
			assert.Greater(t, q.High, int64(0))
			assert.Greater(t, q.Low, int64(0))
		})
	}
}

func TestBoost_MockFetcher_FetchQuote_UnknownMarketType(t *testing.T) {
	f := NewMockFetcher()
	q, err := f.FetchQuote(context.Background(), "XYZ", "unknown_type")
	require.NoError(t, err)
	require.NotNil(t, q)
	assert.Equal(t, "XYZ", q.Symbol)
	assert.Equal(t, "unknown_type", q.MarketType)
}

func TestBoost_MockFetcher_FetchQuote_DeterministicForSameSymbol(t *testing.T) {
	f := NewMockFetcher()
	ctx := context.Background()

	q1, err := f.FetchQuote(ctx, "STABLE", "a_share")
	require.NoError(t, err)
	q2, err := f.FetchQuote(ctx, "STABLE", "a_share")
	require.NoError(t, err)

	// Same symbol + same time window → same result
	assert.Equal(t, q1.CurrentPrice, q2.CurrentPrice)
	assert.Equal(t, q1.Name, q2.Name)
}

func TestBoost_MockFetcher_FetchQuote_DifferentSymbols(t *testing.T) {
	f := NewMockFetcher()
	ctx := context.Background()

	q1, err := f.FetchQuote(ctx, "AAAA", "a_share")
	require.NoError(t, err)
	q2, err := f.FetchQuote(ctx, "BBBB", "a_share")
	require.NoError(t, err)

	// Different symbols have different base prices (extremely unlikely to collide)
	assert.NotEqual(t, q1.PrevClose, q2.PrevClose)
}

func TestBoost_MockFetcher_SearchSymbol(t *testing.T) {
	f := NewMockFetcher()
	results, err := f.SearchSymbol(context.Background(), "TEST", "a_share")
	require.NoError(t, err)
	require.Len(t, results, 1)
	assert.Equal(t, "TEST", results[0].Symbol)
	assert.Equal(t, "a_share", results[0].MarketType)
	assert.Contains(t, results[0].Name, "TEST")
}

func TestBoost_MockFetcher_SearchSymbol_AllMarketTypes(t *testing.T) {
	f := NewMockFetcher()
	ctx := context.Background()

	for _, mt := range []string{"a_share", "hk_stock", "us_stock", "crypto", "fund"} {
		t.Run(mt, func(t *testing.T) {
			results, err := f.SearchSymbol(ctx, "Q", mt)
			require.NoError(t, err)
			require.Len(t, results, 1)
			assert.Equal(t, mt, results[0].MarketType)
		})
	}
}

// ── symbolBasePrice ─────────────────────────────────────────────────────────

func TestBoost_SymbolBasePrice_AShare(t *testing.T) {
	p := symbolBasePrice("600519", "a_share")
	assert.GreaterOrEqual(t, p, int64(500))
	assert.LessOrEqual(t, p, int64(50000))
}

func TestBoost_SymbolBasePrice_HKStock(t *testing.T) {
	p := symbolBasePrice("00700", "hk_stock")
	assert.GreaterOrEqual(t, p, int64(100))
	assert.LessOrEqual(t, p, int64(80000))
}

func TestBoost_SymbolBasePrice_USStock(t *testing.T) {
	p := symbolBasePrice("AAPL", "us_stock")
	assert.GreaterOrEqual(t, p, int64(500))
	assert.LessOrEqual(t, p, int64(50000))
}

func TestBoost_SymbolBasePrice_Crypto(t *testing.T) {
	p := symbolBasePrice("bitcoin", "crypto")
	assert.Greater(t, p, int64(0))
}

func TestBoost_SymbolBasePrice_Fund(t *testing.T) {
	p := symbolBasePrice("110011", "fund")
	assert.GreaterOrEqual(t, p, int64(50))
	assert.LessOrEqual(t, p, int64(1000))
}

func TestBoost_SymbolBasePrice_Unknown(t *testing.T) {
	p := symbolBasePrice("UNKNOWN", "forex")
	assert.GreaterOrEqual(t, p, int64(100))
	assert.LessOrEqual(t, p, int64(10100))
}

func TestBoost_SymbolBasePrice_Deterministic(t *testing.T) {
	p1 := symbolBasePrice("SYM", "a_share")
	p2 := symbolBasePrice("SYM", "a_share")
	assert.Equal(t, p1, p2)
}

// ── mockName ────────────────────────────────────────────────────────────────

func TestBoost_MockName(t *testing.T) {
	tests := []struct {
		symbol, mt, expected string
	}{
		{"600519", "a_share", "600519 A股"},
		{"00700", "hk_stock", "00700 港股"},
		{"AAPL", "us_stock", "AAPL US"},
		{"bitcoin", "crypto", "bitcoin/USDT"},
		{"110011", "fund", "110011 基金"},
		{"XYZ", "other", "XYZ"},
	}
	for _, tt := range tests {
		t.Run(tt.mt, func(t *testing.T) {
			assert.Equal(t, tt.expected, mockName(tt.symbol, tt.mt))
		})
	}
}

// ── eastMoneyMktNumToMarketType ─────────────────────────────────────────────

func TestBoost_EastMoneyMktNumToMarketType(t *testing.T) {
	tests := []struct {
		mktNum, expected string
	}{
		{"0", "a_share"},
		{"1", "a_share"},
		{"116", "hk_stock"},
		{"999", "a_share"}, // default fallback
		{"", "a_share"},    // empty → default
	}
	for _, tt := range tests {
		t.Run(tt.mktNum, func(t *testing.T) {
			assert.Equal(t, tt.expected, eastMoneyMktNumToMarketType(tt.mktNum))
		})
	}
}

// ── eastMoneySecID ──────────────────────────────────────────────────────────

func TestBoost_EastMoneySecID(t *testing.T) {
	tests := []struct {
		symbol, expected string
	}{
		{"600519", "1.600519"}, // SH: starts with 6
		{"900001", "1.900001"}, // SH: starts with 9
		{"510050", "1.510050"}, // SH: starts with 5
		{"000001", "0.000001"}, // SZ: starts with 0
		{"159915", "0.159915"}, // SZ: starts with 1
		{"300750", "0.300750"}, // SZ: starts with 3
		{"200000", "0.200000"}, // SZ: starts with 2
		{"", "1."},             // empty symbol → default "1."
	}
	for _, tt := range tests {
		t.Run(tt.symbol, func(t *testing.T) {
			assert.Equal(t, tt.expected, eastMoneySecID(tt.symbol))
		})
	}
}

// ── NewRealFetcher ──────────────────────────────────────────────────────────

func TestBoost_NewRealFetcher(t *testing.T) {
	f := NewRealFetcher()
	require.NotNil(t, f)
	require.NotNil(t, f.client)
	require.NotNil(t, f.mock)
	assert.Equal(t, 10*time.Second, f.client.Timeout)
}

// ── NewExchangeService ──────────────────────────────────────────────────────

func TestBoost_NewExchangeService(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewExchangeService(mock)
	require.NotNil(t, svc)
	require.NotNil(t, svc.pool)
	require.NotNil(t, svc.client)
	assert.Equal(t, 15*time.Second, svc.client.Timeout)
}

// ── Service.GetQuote (with MockFetcher + pgxmock) ───────────────────────────

func TestBoost_Service_GetQuote_CacheMiss_FetchAndUpsert(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	fetcher := NewMockFetcher()
	svc := NewService(mock, fetcher)

	// Cache miss
	mock.ExpectQuery("SELECT .+ FROM market_quotes").
		WithArgs("600519", "a_share").
		WillReturnError(pgx.ErrNoRows)

	// Upsert after fetch
	mock.ExpectExec("INSERT INTO market_quotes").
		WithArgs("600519", "a_share", pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(),
			pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	resp, err := svc.GetQuote(context.Background(), &pb.GetQuoteRequest{
		Symbol:     "600519",
		MarketType: pb.MarketType_MARKET_TYPE_A_SHARE,
	})
	require.NoError(t, err)
	assert.Equal(t, "600519", resp.Symbol)
	assert.Equal(t, pb.MarketType_MARKET_TYPE_A_SHARE, resp.MarketType)
	assert.Greater(t, resp.CurrentPrice, int64(0))
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoost_Service_GetQuote_StaleCache_FetchFails_ReturnsStale(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	// A fetcher that always errors
	errFetcher := &mockFetcher{err: fmt.Errorf("network error")}
	svc := NewService(mock, errFetcher)

	// Stale cache (updated 1 hour ago, beyond 15min TTL)
	staleTime := time.Now().Add(-1 * time.Hour)
	var open, high, low, prev int64 = 1000, 1100, 900, 980
	mock.ExpectQuery("SELECT .+ FROM market_quotes").
		WithArgs("600519", "a_share").
		WillReturnRows(pgxmock.NewRows([]string{
			"symbol", "market_type", "name", "current_price", "change_amount",
			"change_percent", "open_price", "high_price", "low_price", "prev_close", "updated_at",
		}).AddRow("600519", "a_share", "贵州茅台", int64(1050), int64(70), 7.14, &open, &high, &low, &prev, staleTime))

	resp, err := svc.GetQuote(context.Background(), &pb.GetQuoteRequest{
		Symbol:     "600519",
		MarketType: pb.MarketType_MARKET_TYPE_A_SHARE,
	})
	require.NoError(t, err)
	assert.Equal(t, "600519", resp.Symbol)
	assert.Equal(t, int64(1050), resp.CurrentPrice)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoost_Service_GetQuote_NoCacheNoFetch_ReturnsError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	errFetcher := &mockFetcher{err: fmt.Errorf("API down")}
	svc := NewService(mock, errFetcher)

	// Cache miss
	mock.ExpectQuery("SELECT .+ FROM market_quotes").
		WithArgs("BROKEN", "us_stock").
		WillReturnError(pgx.ErrNoRows)

	_, err = svc.GetQuote(context.Background(), &pb.GetQuoteRequest{
		Symbol:     "BROKEN",
		MarketType: pb.MarketType_MARKET_TYPE_US_STOCK,
	})
	require.Error(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ── Service.BatchGetQuotes (with MockFetcher + pgxmock) ─────────────────────

func TestBoost_Service_BatchGetQuotes_SingleItem(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	fetcher := NewMockFetcher()
	svc := NewService(mock, fetcher)

	now := time.Now()
	var open, high, low, prev int64 = 18300, 18600, 18200, 18300
	mock.ExpectQuery("SELECT .+ FROM market_quotes").
		WithArgs("AAPL", "us_stock").
		WillReturnRows(pgxmock.NewRows([]string{
			"symbol", "market_type", "name", "current_price", "change_amount",
			"change_percent", "open_price", "high_price", "low_price", "prev_close", "updated_at",
		}).AddRow("AAPL", "us_stock", "Apple Inc", int64(18500), int64(200), 1.09, &open, &high, &low, &prev, now))

	resp, err := svc.BatchGetQuotes(context.Background(), &pb.BatchGetQuotesRequest{
		Requests: []*pb.GetQuoteRequest{
			{Symbol: "AAPL", MarketType: pb.MarketType_MARKET_TYPE_US_STOCK},
		},
	})
	require.NoError(t, err)
	assert.Len(t, resp.Quotes, 1)
	assert.Equal(t, "AAPL", resp.Quotes[0].Symbol)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoost_Service_BatchGetQuotes_SkipsInvalid(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	fetcher := NewMockFetcher()
	svc := NewService(mock, fetcher)

	// One valid, one with empty symbol, one with unspecified market
	now := time.Now()
	var open, high, low, prev int64 = 100, 200, 50, 99
	mock.ExpectQuery("SELECT .+ FROM market_quotes").
		WithArgs("GOOG", "us_stock").
		WillReturnRows(pgxmock.NewRows([]string{
			"symbol", "market_type", "name", "current_price", "change_amount",
			"change_percent", "open_price", "high_price", "low_price", "prev_close", "updated_at",
		}).AddRow("GOOG", "us_stock", "Google", int64(15000), int64(100), 0.67, &open, &high, &low, &prev, now))

	resp, err := svc.BatchGetQuotes(context.Background(), &pb.BatchGetQuotesRequest{
		Requests: []*pb.GetQuoteRequest{
			{Symbol: "", MarketType: pb.MarketType_MARKET_TYPE_US_STOCK},         // skip: empty symbol
			{Symbol: "GOOG", MarketType: pb.MarketType_MARKET_TYPE_UNSPECIFIED},  // skip: unspecified
			{Symbol: "GOOG", MarketType: pb.MarketType_MARKET_TYPE_US_STOCK},     // valid
		},
	})
	require.NoError(t, err)
	assert.Len(t, resp.Quotes, 1)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoost_Service_BatchGetQuotes_FetchError_SkipsItem(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	errFetcher := &mockFetcher{err: fmt.Errorf("fetch failed")}
	svc := NewService(mock, errFetcher)

	// Cache miss → fetch fails → skip
	mock.ExpectQuery("SELECT .+ FROM market_quotes").
		WithArgs("BAD", "us_stock").
		WillReturnError(pgx.ErrNoRows)

	resp, err := svc.BatchGetQuotes(context.Background(), &pb.BatchGetQuotesRequest{
		Requests: []*pb.GetQuoteRequest{
			{Symbol: "BAD", MarketType: pb.MarketType_MARKET_TYPE_US_STOCK},
		},
	})
	require.NoError(t, err)
	assert.Empty(t, resp.Quotes) // error is logged and skipped
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ── Service.SearchSymbol (with MockFetcher + pgxmock) ───────────────────────

func TestBoost_Service_SearchSymbol_WithMarketType_CacheHit(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock, NewMockFetcher())

	mock.ExpectQuery("SELECT .+ FROM market_quotes").
		WithArgs("a_share", "%茅台%").
		WillReturnRows(pgxmock.NewRows([]string{"symbol", "name", "market_type"}).
			AddRow("600519", "贵州茅台", "a_share"))

	resp, err := svc.SearchSymbol(context.Background(), &pb.SearchSymbolRequest{
		Query:      "茅台",
		MarketType: pb.MarketType_MARKET_TYPE_A_SHARE,
	})
	require.NoError(t, err)
	require.Len(t, resp.Symbols, 1)
	assert.Equal(t, "600519", resp.Symbols[0].Symbol)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoost_Service_SearchSymbol_CacheMiss_FallbackToFetcher(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock, NewMockFetcher())

	// No cache results → falls back to external fetcher
	mock.ExpectQuery("SELECT .+ FROM market_quotes").
		WithArgs("%UNKNOWN%").
		WillReturnRows(pgxmock.NewRows([]string{"symbol", "name", "market_type"}))

	resp, err := svc.SearchSymbol(context.Background(), &pb.SearchSymbolRequest{
		Query: "UNKNOWN",
	})
	require.NoError(t, err)
	require.Len(t, resp.Symbols, 1) // MockFetcher returns one result
	assert.Equal(t, "UNKNOWN", resp.Symbols[0].Symbol)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoost_Service_SearchSymbol_CacheQueryError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock, NewMockFetcher())

	mock.ExpectQuery("SELECT .+ FROM market_quotes").
		WithArgs("%X%").
		WillReturnError(fmt.Errorf("db connection lost"))

	_, err = svc.SearchSymbol(context.Background(), &pb.SearchSymbolRequest{
		Query: "X",
	})
	require.Error(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ── ExchangeService.GetExchangeRate (pgxmock) ──────────────────────────────

func TestBoost_ExchangeRate_InverseWithZeroRate(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewExchangeService(mock)

	// Direct lookup fails
	mock.ExpectQuery("SELECT rate FROM exchange_rates WHERE currency_pair").
		WithArgs("CNY_HKD").
		WillReturnError(pgx.ErrNoRows)

	// Inverse lookup returns 0 → fallback to 1.0
	mock.ExpectQuery("SELECT rate FROM exchange_rates WHERE currency_pair").
		WithArgs("HKD_CNY").
		WillReturnRows(pgxmock.NewRows([]string{"rate"}).AddRow(0.0))

	rate, err := svc.GetExchangeRate(context.Background(), "CNY", "HKD")
	require.NoError(t, err)
	assert.Equal(t, 1.0, rate)
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ── computeRate edge cases ──────────────────────────────────────────────────

func TestBoost_ComputeRate_FromZero(t *testing.T) {
	svc := &ExchangeService{}
	rates := map[string]float64{
		"USD": 0.0, // zero rate
		"EUR": 0.13,
	}

	// USD_CNY: 1/rates["USD"] → division by zero guard
	_, ok := svc.computeRate("USD", "CNY", rates)
	assert.False(t, ok)

	// USD_EUR: rates["EUR"]/rates["USD"] → division by zero guard
	_, ok = svc.computeRate("USD", "EUR", rates)
	assert.False(t, ok)
}

func TestBoost_ComputeRate_CNYToUnknown(t *testing.T) {
	svc := &ExchangeService{}
	rates := map[string]float64{"USD": 0.1379}

	_, ok := svc.computeRate("CNY", "MISSING", rates)
	assert.False(t, ok)
}

func TestBoost_ComputeRate_UnknownToCNY(t *testing.T) {
	svc := &ExchangeService{}
	rates := map[string]float64{"USD": 0.1379}

	_, ok := svc.computeRate("MISSING", "CNY", rates)
	assert.False(t, ok)
}

func TestBoost_ComputeRate_GeneralBothUnknown(t *testing.T) {
	svc := &ExchangeService{}
	rates := map[string]float64{"USD": 0.1379}

	_, ok := svc.computeRate("AAA", "BBB", rates)
	assert.False(t, ok)
}

// ── Type conversions extra coverage ─────────────────────────────────────────

func TestBoost_MarketTypeToString_Unspecified(t *testing.T) {
	assert.Equal(t, "unspecified", marketTypeToString(pb.MarketType_MARKET_TYPE_UNSPECIFIED))
}

func TestBoost_StringToMarketType_Unspecified(t *testing.T) {
	assert.Equal(t, pb.MarketType_MARKET_TYPE_UNSPECIFIED, stringToMarketType("unspecified"))
	assert.Equal(t, pb.MarketType_MARKET_TYPE_UNSPECIFIED, stringToMarketType("xyz"))
	assert.Equal(t, pb.MarketType_MARKET_TYPE_UNSPECIFIED, stringToMarketType(""))
}

// ── quoteToProto nil pointers ───────────────────────────────────────────────

func TestBoost_QuoteToProto_NilOptionalFields(t *testing.T) {
	q := &cachedQuote{
		Symbol:        "X",
		MarketType:    "a_share",
		Name:          "Test",
		CurrentPrice:  150,
		ChangeAmount:  10,
		ChangePercent: 7.14,
		Open:          nil,
		High:          nil,
		Low:           nil,
		PrevClose:     nil,
		UpdatedAt:     time.Now(),
	}
	proto := quoteToProto(q)
	assert.Equal(t, int64(0), proto.Open)
	assert.Equal(t, int64(0), proto.High)
	assert.Equal(t, int64(0), proto.Low)
	assert.Equal(t, int64(0), proto.PrevClose)
}

// ── IsTradingHours extra coverage ───────────────────────────────────────────

func TestBoost_IsTradingHours_UnknownMarketType(t *testing.T) {
	now := time.Now()
	assert.False(t, IsTradingHours(now, "forex"))
}

func TestBoost_IsTradingHours_Fund_DuringTrading(t *testing.T) {
	cst := mustLoadLocation("Asia/Shanghai")
	now := time.Date(2026, 4, 22, 10, 0, 0, 0, cst) // Wednesday 10:00
	assert.True(t, IsTradingHours(now, "fund"))
}

func TestBoost_IsTradingHours_Fund_AfterClose(t *testing.T) {
	cst := mustLoadLocation("Asia/Shanghai")
	now := time.Date(2026, 4, 22, 18, 0, 0, 0, cst) // Wednesday 18:00
	assert.False(t, IsTradingHours(now, "fund"))
}

func TestBoost_IsTradingHours_HKStock_LunchBreak(t *testing.T) {
	hkt := mustLoadLocation("Asia/Hong_Kong")
	now := time.Date(2026, 4, 22, 12, 30, 0, 0, hkt) // Wednesday 12:30
	assert.False(t, IsTradingHours(now, "hk_stock"))
}

func TestBoost_IsTradingHours_AShare_ExactOpen(t *testing.T) {
	cst := mustLoadLocation("Asia/Shanghai")
	now := time.Date(2026, 4, 22, 9, 30, 0, 0, cst) // Exactly at open
	assert.True(t, IsTradingHours(now, "a_share"))
}

func TestBoost_IsTradingHours_AShare_ExactClose(t *testing.T) {
	cst := mustLoadLocation("Asia/Shanghai")
	now := time.Date(2026, 4, 22, 15, 0, 0, 0, cst) // Exactly at close
	assert.False(t, IsTradingHours(now, "a_share"))   // end is exclusive
}

// ── RefreshQuotes ───────────────────────────────────────────────────────────

func TestBoost_RefreshQuotes_NoActiveInvestments(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock, NewMockFetcher())

	mock.ExpectQuery("SELECT DISTINCT symbol, market_type FROM investments").
		WillReturnRows(pgxmock.NewRows([]string{"symbol", "market_type"}))

	err = svc.RefreshQuotes(context.Background(), nil)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoost_RefreshQuotes_WithMarketTypeFilter(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock, NewMockFetcher())

	// Return two symbols: one a_share, one us_stock
	mock.ExpectQuery("SELECT DISTINCT symbol, market_type FROM investments").
		WillReturnRows(pgxmock.NewRows([]string{"symbol", "market_type"}).
			AddRow("600519", "a_share").
			AddRow("AAPL", "us_stock"))

	// Only refresh a_share → only one upsert pair
	mock.ExpectExec("INSERT INTO market_quotes").
		WithArgs("600519", "a_share", pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(),
			pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	mock.ExpectExec("INSERT INTO price_history").
		WithArgs("600519", "a_share", pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	err = svc.RefreshQuotes(context.Background(), []string{"a_share"})
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoost_RefreshQuotes_UpsertError_Continues(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock, NewMockFetcher())

	mock.ExpectQuery("SELECT DISTINCT symbol, market_type FROM investments").
		WillReturnRows(pgxmock.NewRows([]string{"symbol", "market_type"}).
			AddRow("AAPL", "us_stock"))

	// Upsert to market_quotes fails
	mock.ExpectExec("INSERT INTO market_quotes").
		WithArgs("AAPL", "us_stock", pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(),
			pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnError(fmt.Errorf("db write error"))

	// Should still continue (error is logged, not returned)
	err = svc.RefreshQuotes(context.Background(), nil)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoost_RefreshQuotes_PriceHistoryError_Continues(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock, NewMockFetcher())

	mock.ExpectQuery("SELECT DISTINCT symbol, market_type FROM investments").
		WillReturnRows(pgxmock.NewRows([]string{"symbol", "market_type"}).
			AddRow("AAPL", "us_stock"))

	mock.ExpectExec("INSERT INTO market_quotes").
		WithArgs("AAPL", "us_stock", pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(),
			pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	// price_history upsert fails
	mock.ExpectExec("INSERT INTO price_history").
		WithArgs("AAPL", "us_stock", pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnError(fmt.Errorf("history write error"))

	err = svc.RefreshQuotes(context.Background(), nil)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoost_RefreshQuotes_FetchError_SkipsSymbol(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	errFetcher := &mockFetcher{err: fmt.Errorf("API down")}
	svc := NewService(mock, errFetcher)

	mock.ExpectQuery("SELECT DISTINCT symbol, market_type FROM investments").
		WillReturnRows(pgxmock.NewRows([]string{"symbol", "market_type"}).
			AddRow("BAD", "us_stock"))

	// No upsert expected since fetch fails
	err = svc.RefreshQuotes(context.Background(), nil)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ── Service.GetPriceHistory extra coverage ──────────────────────────────────

func TestBoost_GetPriceHistory_UnspecifiedMarket(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock, &mockFetcher{})

	_, err = svc.GetPriceHistory(context.Background(), &pb.GetPriceHistoryRequest{
		Symbol:     "AAPL",
		MarketType: pb.MarketType_MARKET_TYPE_UNSPECIFIED,
	})
	require.Error(t, err)
}

// ── NewService ──────────────────────────────────────────────────────────────

func TestBoost_NewService(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	fetcher := NewMockFetcher()
	svc := NewService(mock, fetcher)
	require.NotNil(t, svc)
}

// ── Service.GetQuote cache upsert error (logged, not fatal) ─────────────────

func TestBoost_Service_GetQuote_CacheMiss_UpsertError_StillReturns(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	fetcher := NewMockFetcher()
	svc := NewService(mock, fetcher)

	// Cache miss
	mock.ExpectQuery("SELECT .+ FROM market_quotes").
		WithArgs("GOOG", "us_stock").
		WillReturnError(pgx.ErrNoRows)

	// Upsert fails
	mock.ExpectExec("INSERT INTO market_quotes").
		WithArgs("GOOG", "us_stock", pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(),
			pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnError(fmt.Errorf("db write error"))

	// Should still return the fetched quote
	resp, err := svc.GetQuote(context.Background(), &pb.GetQuoteRequest{
		Symbol:     "GOOG",
		MarketType: pb.MarketType_MARKET_TYPE_US_STOCK,
	})
	require.NoError(t, err)
	assert.Equal(t, "GOOG", resp.Symbol)
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ── RealFetcher fallback to mock for unknown market type ────────────────────

func TestBoost_RealFetcher_FetchQuote_UnknownType_FallsBackToMock(t *testing.T) {
	f := NewRealFetcher()
	q, err := f.FetchQuote(context.Background(), "XYZ", "forex")
	require.NoError(t, err)
	require.NotNil(t, q)
	assert.Equal(t, "XYZ", q.Symbol)
	assert.Equal(t, "forex", q.MarketType)
}

func TestBoost_RealFetcher_SearchSymbol_UnknownType_FallsBackToMock(t *testing.T) {
	f := NewRealFetcher()
	results, err := f.SearchSymbol(context.Background(), "test", "forex")
	require.NoError(t, err)
	require.Len(t, results, 1)
}

// ── computeMarketInterval covers the global function ────────────────────────

func TestBoost_ComputeMarketInterval_Weekday(t *testing.T) {
	cst := mustLoadLocation("Asia/Shanghai")
	// Wednesday 10:00 → a_share trading → 15 min
	now := time.Date(2026, 4, 22, 10, 0, 0, 0, cst)
	assert.Equal(t, 15*time.Minute, computeMarketInterval(now))
}

// ── Service.SearchSymbol with fetcher error ─────────────────────────────────

func TestBoost_Service_SearchSymbol_FetcherError_ReturnsEmpty(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	errSearchFetcher := &mockFetcher{
		search: nil,
	}
	// Override SearchSymbol to return error
	svc := NewService(mock, errSearchFetcher)

	// Cache returns nothing
	mock.ExpectQuery("SELECT .+ FROM market_quotes").
		WithArgs("%nomatch%").
		WillReturnRows(pgxmock.NewRows([]string{"symbol", "name", "market_type"}))

	resp, err := svc.SearchSymbol(context.Background(), &pb.SearchSymbolRequest{
		Query: "nomatch",
	})
	require.NoError(t, err)
	assert.Empty(t, resp.Symbols)
	assert.NoError(t, mock.ExpectationsWereMet())
}
