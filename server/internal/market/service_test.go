package market

import (
	"context"
	"testing"
	"time"

	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	pb "github.com/familyledger/server/proto/investment"
)

// mockFetcher implements MarketDataFetcher for tests.
type mockFetcher struct {
	quote  *MarketQuote
	err    error
	search []SymbolInfo
}

func (m *mockFetcher) FetchQuote(_ context.Context, symbol, marketType string) (*MarketQuote, error) {
	if m.err != nil {
		return nil, m.err
	}
	return m.quote, nil
}

func (m *mockFetcher) SearchSymbol(_ context.Context, query, marketType string) ([]SymbolInfo, error) {
	return m.search, nil
}

func defaultQuote() *MarketQuote {
	return &MarketQuote{
		Symbol: "AAPL", Name: "Apple Inc", MarketType: "us_stock",
		CurrentPrice: 18500, ChangeAmount: 200, ChangePercent: 1.09,
		Open: 18300, High: 18600, Low: 18200, PrevClose: 18300,
	}
}

// ─── GetQuote ───────────────────────────────────────────────────────────────

func TestGetQuote_CacheHit(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock, &mockFetcher{})

	now := time.Now()
	var open, high, low, prev int64 = 18300, 18600, 18200, 18300
	mock.ExpectQuery("SELECT .+ FROM market_quotes").
		WithArgs("AAPL", "us_stock").
		WillReturnRows(pgxmock.NewRows([]string{"symbol", "market_type", "name", "current_price", "change_amount", "change_percent", "open_price", "high_price", "low_price", "prev_close", "updated_at"}).
			AddRow("AAPL", "us_stock", "Apple Inc", int64(18500), int64(200), 1.09, &open, &high, &low, &prev, now))

	resp, err := svc.GetQuote(context.Background(), &pb.GetQuoteRequest{
		Symbol:     "AAPL",
		MarketType: pb.MarketType_MARKET_TYPE_US_STOCK,
	})
	require.NoError(t, err)
	assert.Equal(t, "AAPL", resp.Symbol)
	assert.Equal(t, int64(18500), resp.CurrentPrice)
}

func TestGetQuote_EmptySymbol(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock, &mockFetcher{})
	_, err = svc.GetQuote(context.Background(), &pb.GetQuoteRequest{Symbol: ""})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestGetQuote_UnspecifiedMarket(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock, &mockFetcher{})
	_, err = svc.GetQuote(context.Background(), &pb.GetQuoteRequest{
		Symbol:     "AAPL",
		MarketType: pb.MarketType_MARKET_TYPE_UNSPECIFIED,
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── BatchGetQuotes ─────────────────────────────────────────────────────────

func TestBatchGetQuotes_Empty(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock, &mockFetcher{})

	resp, err := svc.BatchGetQuotes(context.Background(), &pb.BatchGetQuotesRequest{Requests: nil})
	require.NoError(t, err)
	assert.Empty(t, resp.Quotes)
}

func TestBatchGetQuotes_TooMany(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock, &mockFetcher{})

	reqs := make([]*pb.GetQuoteRequest, 51)
	for i := range reqs {
		reqs[i] = &pb.GetQuoteRequest{Symbol: "X", MarketType: pb.MarketType_MARKET_TYPE_US_STOCK}
	}
	_, err = svc.BatchGetQuotes(context.Background(), &pb.BatchGetQuotesRequest{Requests: reqs})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── SearchSymbol ───────────────────────────────────────────────────────────

func TestSearchSymbol_CacheHit(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock, &mockFetcher{})

	mock.ExpectQuery("SELECT .+ FROM market_quotes").
		WithArgs("%AAPL%").
		WillReturnRows(pgxmock.NewRows([]string{"symbol", "name", "market_type"}).
			AddRow("AAPL", "Apple Inc", "us_stock"))

	resp, err := svc.SearchSymbol(context.Background(), &pb.SearchSymbolRequest{Query: "AAPL"})
	require.NoError(t, err)
	assert.Len(t, resp.Symbols, 1)
}

func TestSearchSymbol_EmptyQuery(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock, &mockFetcher{})
	_, err = svc.SearchSymbol(context.Background(), &pb.SearchSymbolRequest{Query: ""})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestSearchSymbol_Fallback(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	fetcher := &mockFetcher{search: []SymbolInfo{{Symbol: "TSLA", Name: "Tesla", MarketType: "us_stock"}}}
	svc := NewService(mock, fetcher)

	mock.ExpectQuery("SELECT .+ FROM market_quotes").
		WithArgs("%TSLA%").
		WillReturnRows(pgxmock.NewRows([]string{"symbol", "name", "market_type"})) // empty

	resp, err := svc.SearchSymbol(context.Background(), &pb.SearchSymbolRequest{Query: "TSLA"})
	require.NoError(t, err)
	assert.Len(t, resp.Symbols, 1)
	assert.Equal(t, "TSLA", resp.Symbols[0].Symbol)
}

// ─── GetPriceHistory ────────────────────────────────────────────────────────

func TestGetPriceHistory_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock, &mockFetcher{})
	now := time.Now()

	mock.ExpectQuery("SELECT .+ FROM price_history").
		WithArgs("AAPL", "us_stock", pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"price_date", "close_price"}).
			AddRow(now.AddDate(0, 0, -1), int64(18300)).
			AddRow(now, int64(18500)))

	resp, err := svc.GetPriceHistory(context.Background(), &pb.GetPriceHistoryRequest{
		Symbol:     "AAPL",
		MarketType: pb.MarketType_MARKET_TYPE_US_STOCK,
		StartDate:  timestamppb.New(now.AddDate(0, 0, -7)),
		EndDate:    timestamppb.Now(),
	})
	require.NoError(t, err)
	assert.Len(t, resp.Points, 2)
}

func TestGetPriceHistory_Empty(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock, &mockFetcher{})

	mock.ExpectQuery("SELECT .+ FROM price_history").
		WithArgs("XXX", "us_stock", pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"price_date", "close_price"}))

	resp, err := svc.GetPriceHistory(context.Background(), &pb.GetPriceHistoryRequest{
		Symbol:     "XXX",
		MarketType: pb.MarketType_MARKET_TYPE_US_STOCK,
	})
	require.NoError(t, err)
	assert.Empty(t, resp.Points)
}

func TestGetPriceHistory_EmptySymbol(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock, &mockFetcher{})
	_, err = svc.GetPriceHistory(context.Background(), &pb.GetPriceHistoryRequest{Symbol: ""})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── Type conversions ───────────────────────────────────────────────────────

func TestMarketTypeConversions(t *testing.T) {
	types := []struct {
		str string
		val pb.MarketType
	}{
		{"a_share", pb.MarketType_MARKET_TYPE_A_SHARE},
		{"hk_stock", pb.MarketType_MARKET_TYPE_HK_STOCK},
		{"us_stock", pb.MarketType_MARKET_TYPE_US_STOCK},
		{"crypto", pb.MarketType_MARKET_TYPE_CRYPTO},
		{"fund", pb.MarketType_MARKET_TYPE_FUND},
	}
	for _, tt := range types {
		assert.Equal(t, tt.str, marketTypeToString(tt.val))
		assert.Equal(t, tt.val, stringToMarketType(tt.str))
	}
}

func TestQuoteToProto(t *testing.T) {
	var o, h, l, p int64 = 100, 200, 50, 99
	q := &cachedQuote{
		Symbol: "X", MarketType: "a_share", Name: "Test",
		CurrentPrice: 150, ChangeAmount: 51, ChangePercent: 51.52,
		Open: &o, High: &h, Low: &l, PrevClose: &p, UpdatedAt: time.Now(),
	}
	proto := quoteToProto(q)
	assert.Equal(t, "X", proto.Symbol)
	assert.Equal(t, int64(150), proto.CurrentPrice)
	assert.Equal(t, int64(100), proto.Open)
}
