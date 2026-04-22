package market

import (
	"context"
	"hash/fnv"
	"math"
	"math/rand"
	"time"
)

// MarketQuote represents a market quote from an external data source.
type MarketQuote struct {
	Symbol        string
	Name          string
	MarketType    string
	CurrentPrice  int64   // 分
	ChangeAmount  int64   // 分
	ChangePercent float64 // 百分比
	Open          int64
	High          int64
	Low           int64
	PrevClose     int64
}

// SymbolInfo represents basic symbol information from a search result.
type SymbolInfo struct {
	Symbol     string
	Name       string
	MarketType string
}

// MarketDataFetcher defines the interface for external market data providers.
// Default implementation is MockFetcher; replace with real APIs later
// (东方财富/Yahoo Finance/CoinGecko).
type MarketDataFetcher interface {
	FetchQuote(ctx context.Context, symbol string, marketType string) (*MarketQuote, error)
	SearchSymbol(ctx context.Context, query string, marketType string) ([]SymbolInfo, error)
}

// ── MockFetcher ─────────────────────────────────────────────────────────────

// MockFetcher returns deterministic-but-varying mock prices based on symbol hash.
type MockFetcher struct{}

func NewMockFetcher() *MockFetcher {
	return &MockFetcher{}
}

func (m *MockFetcher) FetchQuote(_ context.Context, symbol string, marketType string) (*MarketQuote, error) {
	basePrice := symbolBasePrice(symbol, marketType)
	// Add time-based volatility: ±5% based on current 15-min window
	window := time.Now().Unix() / (15 * 60) // changes every 15 min
	h := fnv.New64a()
	h.Write([]byte(symbol))
	h.Write([]byte{byte(window), byte(window >> 8)})
	noise := float64(h.Sum64()%1000) / 1000.0 // 0.0 ~ 0.999
	volatility := (noise - 0.5) * 0.10         // ±5%

	currentPrice := int64(float64(basePrice) * (1.0 + volatility))
	if currentPrice < 1 {
		currentPrice = 1
	}

	prevClose := basePrice
	change := currentPrice - prevClose
	var changePercent float64
	if prevClose > 0 {
		changePercent = float64(change) / float64(prevClose) * 100.0
	}

	// Simulate open/high/low
	openPrice := int64(float64(basePrice) * (1.0 + volatility*0.3))
	highPrice := currentPrice + int64(float64(basePrice)*0.02)
	lowPrice := currentPrice - int64(float64(basePrice)*0.02)
	if lowPrice < 1 {
		lowPrice = 1
	}

	return &MarketQuote{
		Symbol:        symbol,
		Name:          mockName(symbol, marketType),
		MarketType:    marketType,
		CurrentPrice:  currentPrice,
		ChangeAmount:  change,
		ChangePercent: math.Round(changePercent*100) / 100,
		Open:          openPrice,
		High:          highPrice,
		Low:           lowPrice,
		PrevClose:     prevClose,
	}, nil
}

func (m *MockFetcher) SearchSymbol(_ context.Context, query string, marketType string) ([]SymbolInfo, error) {
	// Return a few mock results based on the query
	results := []SymbolInfo{
		{Symbol: query, Name: mockName(query, marketType), MarketType: marketType},
	}
	return results, nil
}

// symbolBasePrice generates a stable base price from the symbol hash.
func symbolBasePrice(symbol string, marketType string) int64 {
	h := fnv.New64a()
	h.Write([]byte(symbol))
	h.Write([]byte(marketType))
	hash := h.Sum64()

	switch marketType {
	case "a_share":
		// A股: 5元 ~ 500元 → 500分 ~ 50000分
		return int64(hash%49500) + 500
	case "hk_stock":
		// 港股: 1 HKD ~ 800 HKD → 100分 ~ 80000分
		return int64(hash%79900) + 100
	case "us_stock":
		// 美股: 5 USD ~ 500 USD → 500分 ~ 50000分
		return int64(hash%49500) + 500
	case "crypto":
		// 加密货币: 0.01 ~ 100000 USD → wide range, use log scale
		r := rand.New(rand.NewSource(int64(hash)))
		exp := r.Float64() * 7 // 10^0 ~ 10^7 cents
		return int64(math.Pow(10, exp))
	case "fund":
		// 基金: 0.5 ~ 10元 → 50分 ~ 1000分
		return int64(hash%950) + 50
	default:
		return int64(hash%10000) + 100
	}
}

// mockName generates a placeholder name for mock data.
func mockName(symbol string, marketType string) string {
	switch marketType {
	case "a_share":
		return symbol + " A股"
	case "hk_stock":
		return symbol + " 港股"
	case "us_stock":
		return symbol + " US"
	case "crypto":
		return symbol + "/USDT"
	case "fund":
		return symbol + " 基金"
	default:
		return symbol
	}
}
