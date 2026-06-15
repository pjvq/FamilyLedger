package market

import (
	"context"
	"encoding/json"
	"fmt"
	"hash/fnv"
	"io"
	"log"
	"math"
	"math/rand"
	"net/http"
	"strconv"
	"strings"
	"time"

	"golang.org/x/text/encoding/simplifiedchinese"
	"golang.org/x/text/transform"
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

// ── RealFetcher ─────────────────────────────────────────────────────────────

// RealFetcher fetches real market data from external APIs:
//   - A股/港股/基金 → 东方财富 (East Money)
//   - 美股 → Yahoo Finance
//   - 加密货币 → CoinGecko
//
// RealFetcher fetches market data from external APIs.
// On error, it returns the error (no silent mock fallback).
type RealFetcher struct {
	client *http.Client
}

func NewRealFetcher() *RealFetcher {
	return &RealFetcher{
		client: &http.Client{Timeout: 10 * time.Second},
	}
}

func (r *RealFetcher) FetchQuote(ctx context.Context, symbol string, marketType string) (*MarketQuote, error) {
	var quote *MarketQuote
	var err error

	switch marketType {
	case "a_share":
		quote, err = r.fetchEastMoneyAShare(ctx, symbol)
	case "hk_stock":
		quote, err = r.fetchEastMoneyHKStock(ctx, symbol)
	case "fund":
		quote, err = r.fetchEastMoneyFund(ctx, symbol)
	case "us_stock":
		quote, err = r.fetchYahooQuote(ctx, symbol)
	case "crypto":
		quote, err = r.fetchCoinGeckoQuote(ctx, symbol)
	case "precious_metal":
		quote, err = r.fetchPreciousMetal(ctx, symbol)
	default:
		log.Printf("market: unknown market type %q for symbol %s", marketType, symbol)
		return nil, fmt.Errorf("unsupported market type: %s", marketType)
	}

	if err != nil {
		log.Printf("market: FetchQuote(%s, %s) error: %v", symbol, marketType, err)
		return nil, fmt.Errorf("fetch %s/%s: %w", marketType, symbol, err)
	}
	return quote, nil
}

func (r *RealFetcher) SearchSymbol(ctx context.Context, query string, marketType string) ([]SymbolInfo, error) {
	var results []SymbolInfo
	var err error

	switch marketType {
	case "a_share", "hk_stock", "fund":
		results, err = r.searchEastMoney(ctx, query, marketType)
	case "us_stock":
		results, err = r.searchYahoo(ctx, query)
	case "crypto":
		results, err = r.searchCoinGecko(ctx, query)
	case "precious_metal":
		results, err = r.searchPreciousMetal(ctx, query)
	default:
		log.Printf("market: unknown market type %q for search", marketType)
		return nil, fmt.Errorf("unsupported market type for search: %s", marketType)
	}

	if err != nil {
		log.Printf("market: SearchSymbol(%s, %s) error: %v", query, marketType, err)
		return nil, fmt.Errorf("search %s/%s: %w", marketType, query, err)
	}
	return results, nil
}

// ── 东方财富 A股 ────────────────────────────────────────────────────────────

// eastMoneySecID returns the secid prefix for an A-share symbol.
// SH (prefix "1."): codes starting with 6, 9, 5
// SZ (prefix "0."): codes starting with 0, 1, 2, 3
//
// A-share codes are strictly 6-digit numeric. Non-numeric inputs (e.g. a
// precious-metal symbol "Au99.99" mistakenly stored with market_type=a_share)
// would otherwise produce a bogus secid like "0.Au99.99" and hammer the
// upstream API with EOF errors — so reject them up front.
func eastMoneySecID(symbol string) (string, error) {
	if !isNumericSymbol(symbol) {
		return "", fmt.Errorf("invalid A-share symbol %q (expected 6-digit numeric)", symbol)
	}
	switch symbol[0] {
	case '6', '9', '5':
		return "1." + symbol, nil
	default:
		return "0." + symbol, nil
	}
}

// isNumericSymbol reports whether symbol is a non-empty all-digit string.
func isNumericSymbol(symbol string) bool {
	if symbol == "" {
		return false
	}
	for i := 0; i < len(symbol); i++ {
		if symbol[i] < '0' || symbol[i] > '9' {
			return false
		}
	}
	return true
}

func (r *RealFetcher) fetchEastMoneyStock(ctx context.Context, secid string, symbol string, marketType string) (*MarketQuote, error) {
	url := fmt.Sprintf(
		"https://push2.eastmoney.com/api/qt/stock/get?secid=%s&fields=f43,f44,f45,f46,f57,f58,f60,f169,f170&fltt=2",
		secid,
	)

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Referer", "https://www.eastmoney.com/")

	resp, err := r.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("http get: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("eastmoney returned status %d", resp.StatusCode)
	}

	var result struct {
		Data struct {
			F43  json.Number `json:"f43"`  // current price (元)
			F44  json.Number `json:"f44"`  // high (元)
			F45  json.Number `json:"f45"`  // low (元)
			F46  json.Number `json:"f46"`  // open (元)
			F57  string      `json:"f57"`  // symbol code
			F58  string      `json:"f58"`  // name
			F60  json.Number `json:"f60"`  // prev close (元)
			F169 json.Number `json:"f169"` // change amount (元)
			F170 json.Number `json:"f170"` // change percent (%)
		} `json:"data"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("decode json: %w", err)
	}

	// Parse and convert 元 → 分 (×100)
	currentPrice := yuanToCents(result.Data.F43)
	highPrice := yuanToCents(result.Data.F44)
	lowPrice := yuanToCents(result.Data.F45)
	openPrice := yuanToCents(result.Data.F46)
	prevClose := yuanToCents(result.Data.F60)
	changeAmount := yuanToCents(result.Data.F169)
	changePercent, _ := result.Data.F170.Float64()

	// When market is closed (pre-open / after-hours), currentPrice may be 0.
	// Fall back to prevClose so callers always get a meaningful price.
	if currentPrice == 0 && prevClose > 0 {
		currentPrice = prevClose
	}

	name := result.Data.F58
	if name == "" {
		name = symbol
	}

	return &MarketQuote{
		Symbol:        symbol,
		Name:          name,
		MarketType:    marketType,
		CurrentPrice:  currentPrice,
		ChangeAmount:  changeAmount,
		ChangePercent: math.Round(changePercent*100) / 100,
		Open:          openPrice,
		High:          highPrice,
		Low:           lowPrice,
		PrevClose:     prevClose,
	}, nil
}

func (r *RealFetcher) fetchEastMoneyAShare(ctx context.Context, symbol string) (*MarketQuote, error) {
	secid, err := eastMoneySecID(symbol)
	if err != nil {
		return nil, err
	}
	return r.fetchEastMoneyStock(ctx, secid, symbol, "a_share")
}

func (r *RealFetcher) fetchEastMoneyHKStock(ctx context.Context, symbol string) (*MarketQuote, error) {
	if !isNumericSymbol(symbol) {
		return nil, fmt.Errorf("invalid HK stock symbol %q (expected numeric code)", symbol)
	}
	secid := "116." + symbol
	return r.fetchEastMoneyStock(ctx, secid, symbol, "hk_stock")
}

// ── 东方财富 基金 ────────────────────────────────────────────────────────────

func (r *RealFetcher) fetchEastMoneyFund(ctx context.Context, symbol string) (*MarketQuote, error) {
	url := fmt.Sprintf("https://fundgz.1234567.com.cn/js/%s.js", symbol)

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Referer", "https://www.eastmoney.com/")

	resp, err := r.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("http get: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("fund api returned status %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read body: %w", err)
	}

	// Response is JSONP: jsonpgz({...});
	raw := string(body)
	start := strings.Index(raw, "(")
	end := strings.LastIndex(raw, ")")
	if start < 0 || end < 0 || end <= start {
		return nil, fmt.Errorf("invalid JSONP response: %s", raw)
	}
	jsonStr := raw[start+1 : end]

	var fund struct {
		Name string `json:"name"` // 基金名称
		Dwjz string `json:"dwjz"` // 上一日净值 (元)
		Gsz  string `json:"gsz"`  // 估算净值 (元)
	}
	if err := json.Unmarshal([]byte(jsonStr), &fund); err != nil {
		return nil, fmt.Errorf("decode fund json: %w", err)
	}

	// Parse NAV values: string → float64 → int64 (分)
	gsz, _ := strconv.ParseFloat(fund.Gsz, 64)
	dwjz, _ := strconv.ParseFloat(fund.Dwjz, 64)

	currentPrice := int64(math.Round(gsz * 100))
	prevClose := int64(math.Round(dwjz * 100))
	changeAmount := currentPrice - prevClose
	var changePercent float64
	if prevClose > 0 {
		changePercent = float64(changeAmount) / float64(prevClose) * 100.0
	}

	name := fund.Name
	if name == "" {
		name = symbol
	}

	return &MarketQuote{
		Symbol:        symbol,
		Name:          name,
		MarketType:    "fund",
		CurrentPrice:  currentPrice,
		ChangeAmount:  changeAmount,
		ChangePercent: math.Round(changePercent*100) / 100,
		Open:          prevClose, // 基金无盘中数据, 用昨日净值
		High:          currentPrice,
		Low:           currentPrice,
		PrevClose:     prevClose,
	}, nil
}

// ── Yahoo Finance 美股 ──────────────────────────────────────────────────────

func (r *RealFetcher) fetchYahooQuote(ctx context.Context, symbol string) (*MarketQuote, error) {
	url := fmt.Sprintf(
		"https://query1.finance.yahoo.com/v8/finance/chart/%s?interval=1d&range=1d",
		symbol,
	)

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (compatible; FamilyLedger/1.0)")

	resp, err := r.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("http get: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("yahoo returned status %d", resp.StatusCode)
	}

	var chart struct {
		Chart struct {
			Result []struct {
				Meta struct {
					Symbol             string  `json:"symbol"`
					RegularMarketPrice float64 `json:"regularMarketPrice"`
					PreviousClose      float64 `json:"previousClose"`
					ShortName          string  `json:"shortName"`
				} `json:"meta"`
				Indicators struct {
					Quote []struct {
						Open  []float64 `json:"open"`
						High  []float64 `json:"high"`
						Low   []float64 `json:"low"`
						Close []float64 `json:"close"`
					} `json:"quote"`
				} `json:"indicators"`
			} `json:"result"`
		} `json:"chart"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&chart); err != nil {
		return nil, fmt.Errorf("decode json: %w", err)
	}

	if len(chart.Chart.Result) == 0 {
		return nil, fmt.Errorf("yahoo returned empty result for %s", symbol)
	}

	meta := chart.Chart.Result[0].Meta
	currentPrice := int64(math.Round(meta.RegularMarketPrice * 100))
	prevClose := int64(math.Round(meta.PreviousClose * 100))

	var openPrice, highPrice, lowPrice int64
	if quotes := chart.Chart.Result[0].Indicators.Quote; len(quotes) > 0 && len(quotes[0].Open) > 0 {
		q := quotes[0]
		openPrice = int64(math.Round(q.Open[0] * 100))
		if len(q.High) > 0 {
			highPrice = int64(math.Round(q.High[0] * 100))
		}
		if len(q.Low) > 0 {
			lowPrice = int64(math.Round(q.Low[0] * 100))
		}
	}

	changeAmount := currentPrice - prevClose
	var changePercent float64
	if prevClose > 0 {
		changePercent = float64(changeAmount) / float64(prevClose) * 100.0
	}

	name := meta.ShortName
	if name == "" {
		name = symbol
	}

	return &MarketQuote{
		Symbol:        symbol,
		Name:          name,
		MarketType:    "us_stock",
		CurrentPrice:  currentPrice,
		ChangeAmount:  changeAmount,
		ChangePercent: math.Round(changePercent*100) / 100,
		Open:          openPrice,
		High:          highPrice,
		Low:           lowPrice,
		PrevClose:     prevClose,
	}, nil
}

// ── CoinGecko 加密货币 ──────────────────────────────────────────────────────

func (r *RealFetcher) fetchCoinGeckoQuote(ctx context.Context, symbol string) (*MarketQuote, error) {
	url := fmt.Sprintf(
		"https://api.coingecko.com/api/v3/simple/price?ids=%s&vs_currencies=usd&include_24hr_change=true",
		symbol,
	)

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}

	resp, err := r.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("http get: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("coingecko returned status %d", resp.StatusCode)
	}

	// CoinGecko returns: {"bitcoin": {"usd": 12345.67, "usd_24h_change": -2.5}}
	var data map[string]struct {
		USD          float64 `json:"usd"`
		USD24hChange float64 `json:"usd_24h_change"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&data); err != nil {
		return nil, fmt.Errorf("decode json: %w", err)
	}

	coinData, ok := data[symbol]
	if !ok {
		return nil, fmt.Errorf("coingecko: no data for %q", symbol)
	}

	currentPrice := int64(math.Round(coinData.USD * 100))
	changePercent := math.Round(coinData.USD24hChange*100) / 100

	// Estimate prevClose from current price and 24h change
	var prevClose int64
	if changePercent != 0 {
		prevClose = int64(math.Round(coinData.USD / (1 + coinData.USD24hChange/100) * 100))
	} else {
		prevClose = currentPrice
	}
	changeAmount := currentPrice - prevClose

	return &MarketQuote{
		Symbol:        symbol,
		Name:          symbol + "/USD",
		MarketType:    "crypto",
		CurrentPrice:  currentPrice,
		ChangeAmount:  changeAmount,
		ChangePercent: changePercent,
		Open:          prevClose, // CoinGecko simple API has no OHLC
		High:          currentPrice,
		Low:           currentPrice,
		PrevClose:     prevClose,
	}, nil
}

// ── Search implementations ──────────────────────────────────────────────────

func (r *RealFetcher) searchEastMoney(ctx context.Context, query string, marketType string) ([]SymbolInfo, error) {
	url := fmt.Sprintf(
		"https://searchapi.eastmoney.com/api/suggest/get?input=%s&type=14&count=10",
		query,
	)

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Referer", "https://www.eastmoney.com/")

	resp, err := r.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("http get: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("eastmoney search returned status %d", resp.StatusCode)
	}

	var result struct {
		QuotationCodeTable struct {
			Data []struct {
				Code   string `json:"Code"`
				Name   string `json:"Name"`
				MktNum string `json:"MktNum"`
			} `json:"Data"`
		} `json:"QuotationCodeTable"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("decode json: %w", err)
	}

	var results []SymbolInfo
	for _, item := range result.QuotationCodeTable.Data {
		// Filter by market type based on MktNum
		itemMarket := eastMoneyMktNumToMarketType(item.MktNum)
		if marketType != "" && itemMarket != marketType {
			continue
		}
		results = append(results, SymbolInfo{
			Symbol:     item.Code,
			Name:       item.Name,
			MarketType: itemMarket,
		})
	}
	return results, nil
}

// eastMoneyMktNumToMarketType maps 东方财富 MktNum to our market type.
func eastMoneyMktNumToMarketType(mktNum string) string {
	switch mktNum {
	case "0", "1": // SZ, SH
		return "a_share"
	case "116": // HK
		return "hk_stock"
	default:
		return "a_share" // default
	}
}

func (r *RealFetcher) searchYahoo(ctx context.Context, query string) ([]SymbolInfo, error) {
	url := fmt.Sprintf(
		"https://query2.finance.yahoo.com/v1/finance/search?q=%s&quotesCount=10&newsCount=0",
		query,
	)

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (compatible; FamilyLedger/1.0)")

	resp, err := r.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("http get: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("yahoo search returned status %d", resp.StatusCode)
	}

	var result struct {
		Quotes []struct {
			Symbol    string `json:"symbol"`
			ShortName string `json:"shortname"`
			Exchange  string `json:"exchange"`
		} `json:"quotes"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("decode json: %w", err)
	}

	var results []SymbolInfo
	for _, q := range result.Quotes {
		results = append(results, SymbolInfo{
			Symbol:     q.Symbol,
			Name:       q.ShortName,
			MarketType: "us_stock",
		})
	}
	return results, nil
}

func (r *RealFetcher) searchCoinGecko(ctx context.Context, query string) ([]SymbolInfo, error) {
	url := fmt.Sprintf(
		"https://api.coingecko.com/api/v3/search?query=%s",
		query,
	)

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}

	resp, err := r.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("http get: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("coingecko search returned status %d", resp.StatusCode)
	}

	var result struct {
		Coins []struct {
			ID     string `json:"id"`
			Name   string `json:"name"`
			Symbol string `json:"symbol"`
		} `json:"coins"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("decode json: %w", err)
	}

	var results []SymbolInfo
	for _, c := range result.Coins {
		results = append(results, SymbolInfo{
			Symbol:     c.ID,
			Name:       fmt.Sprintf("%s (%s)", c.Name, strings.ToUpper(c.Symbol)),
			MarketType: "crypto",
		})
	}
	return results, nil
}

// ── Utility functions ───────────────────────────────────────────────────────

// yuanToCents converts a json.Number in 元 to int64 in 分.
func yuanToCents(n json.Number) int64 {
	f, err := n.Float64()
	if err != nil {
		return 0
	}
	return int64(math.Round(f * 100))
}

// ── MockFetcher ─────────────────────────────────────────────────────────────

// Deprecated: MockFetcher returns deterministic-but-varying mock prices based on symbol hash.
// Kept as fallback for RealFetcher and for tests.
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
	volatility := (noise - 0.5) * 0.10        // ±5%

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

// ── Precious Metal (贵金属) ────────────────────────────────────────────────
// Uses 东方财富 commodity API for Shanghai Gold Exchange products.
// Common symbols: Au99.99, Au99.95, Ag99.99, Au(T+D), Ag(T+D), pt99.95

// preciousMetalList is the static catalog of supported precious metals.
var preciousMetalList = []SymbolInfo{
	{Symbol: "Au99.99", Name: "黄金9999", MarketType: "precious_metal"},
	{Symbol: "Au99.95", Name: "黄金9995", MarketType: "precious_metal"},
	{Symbol: "Au100g", Name: "黄金100克", MarketType: "precious_metal"},
	{Symbol: "Au(T+D)", Name: "黄金T+D", MarketType: "precious_metal"},
	{Symbol: "mAu(T+D)", Name: "迷你黄金T+D", MarketType: "precious_metal"},
	{Symbol: "Ag(T+D)", Name: "白银T+D", MarketType: "precious_metal"},
	{Symbol: "Pt99.95", Name: "铂金9995", MarketType: "precious_metal"},
}

// preciousMetalSinaCode maps our display symbol to the Sina SGE list code
// (used as gds_<CODE> on hq.sinajs.cn). Sina is the primary precious-metal
// source because the EastMoney clist/kline endpoints reject IDC/cloud IPs
// (EOF / empty reply), while Sina serves cloud IPs reliably.
//
// Note: Ag99.99 (silver spot) is intentionally NOT included — Sina only
// provides silver T+D (gds_AGTD), and SGE silver-spot turnover is negligible,
// so it was dropped from the supported set.
var preciousMetalSinaCode = map[string]string{
	"Au99.99":  "AU9999",
	"Au99.95":  "AU9995",
	"Au100g":   "AU100G",
	"Au(T+D)":  "AUTD",
	"mAu(T+D)": "MAUTD",
	"Ag(T+D)":  "AGTD",
	"Pt99.95":  "PT9995",
}

// fetchPreciousMetal fetches an SGE precious-metal quote from Sina finance.
//
// Source rationale: EastMoney's clist/kline endpoints reject IDC/cloud-server
// IPs (observed as EOF / "empty reply from server"), so they are unusable from
// our deployment host. Sina's hq.sinajs.cn serves cloud IPs reliably, so it is
// the sole source here. Stale-cache fallback lives in the Service layer
// (getOrFetchQuote): if this fetch fails, the last cached quote is returned.
func (r *RealFetcher) fetchPreciousMetal(ctx context.Context, symbol string) (*MarketQuote, error) {
	code, ok := preciousMetalSinaCode[symbol]
	if !ok {
		return nil, fmt.Errorf("unsupported precious metal symbol: %s", symbol)
	}
	return r.fetchSinaPreciousMetal(ctx, symbol, code)
}

// fetchSinaPreciousMetal queries https://hq.sinajs.cn/list=gds_<CODE>.
//
// Response is a single line, GBK-encoded:
//
//	var hq_str_gds_AU9999="937.52,0,938.50,939.89,943.00,909.00,15:30:01,907.47,912.60,...,沪金99";
//
// Comma-separated fields (0-indexed), verified against EastMoney kline history:
//
//	[0]  current price (元/克)
//	[4]  high
//	[5]  low
//	[6]  time HH:MM:SS
//	[7]  previous close  (used to derive change)
//	[8]  open
//	[13] product name
func (r *RealFetcher) fetchSinaPreciousMetal(ctx context.Context, symbol, code string) (*MarketQuote, error) {
	url := "https://hq.sinajs.cn/list=gds_" + code

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("create sina request: %w", err)
	}
	// Sina rejects requests without a finance.sina.com.cn Referer.
	req.Header.Set("Referer", "https://finance.sina.com.cn/")
	req.Header.Set("User-Agent", "Mozilla/5.0 (compatible)")

	resp, err := r.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("sina http get: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("sina returned status %d", resp.StatusCode)
	}

	// Body is GBK; decode to UTF-8.
	utf8Reader := transform.NewReader(resp.Body, simplifiedchinese.GBK.NewDecoder())
	raw, err := io.ReadAll(utf8Reader)
	if err != nil {
		return nil, fmt.Errorf("read sina body: %w", err)
	}

	return parseSinaPreciousMetal(symbol, code, string(raw))
}

// parseSinaPreciousMetal parses a UTF-8 (already GBK-decoded) Sina gds_ line
// into a MarketQuote. Split out from the HTTP path for testability.
func parseSinaPreciousMetal(symbol, code, body string) (*MarketQuote, error) {
	// Extract the quoted payload: var hq_str_gds_XXX="...";
	start := strings.Index(body, "\"")
	end := strings.LastIndex(body, "\"")
	if start < 0 || end <= start {
		return nil, fmt.Errorf("%s: unexpected sina response: %q", symbol, body)
	}
	payload := body[start+1 : end]
	if payload == "" {
		return nil, fmt.Errorf("%s: sina returned empty quote (delisted or wrong code %q)", symbol, code)
	}

	fields := strings.Split(payload, ",")
	if len(fields) < 14 {
		return nil, fmt.Errorf("%s: sina payload has %d fields (expected >=14): %q", symbol, len(fields), payload)
	}

	price, err := strconv.ParseFloat(strings.TrimSpace(fields[0]), 64)
	if err != nil {
		return nil, fmt.Errorf("%s: parse current price %q: %w", symbol, fields[0], err)
	}
	if price <= 0 {
		return nil, fmt.Errorf("%s: sina returned non-positive price %v", symbol, price)
	}

	prevClose, _ := strconv.ParseFloat(strings.TrimSpace(fields[7]), 64)

	var changeAmount, changePercent float64
	if prevClose > 0 {
		changeAmount = price - prevClose
		changePercent = (changeAmount / prevClose) * 100
	}

	name := strings.TrimSpace(fields[13])
	if name == "" {
		for _, pm := range preciousMetalList {
			if pm.Symbol == symbol {
				name = pm.Name
				break
			}
		}
	}

	open, _ := strconv.ParseFloat(strings.TrimSpace(fields[8]), 64)
	high, _ := strconv.ParseFloat(strings.TrimSpace(fields[4]), 64)
	low, _ := strconv.ParseFloat(strings.TrimSpace(fields[5]), 64)

	return &MarketQuote{
		Symbol:        symbol,
		Name:          name,
		MarketType:    "precious_metal",
		CurrentPrice:  int64(math.Round(price * 100)),
		ChangeAmount:  int64(math.Round(changeAmount * 100)),
		ChangePercent: changePercent,
		Open:          int64(math.Round(open * 100)),
		High:          int64(math.Round(high * 100)),
		Low:           int64(math.Round(low * 100)),
		PrevClose:     int64(math.Round(prevClose * 100)),
	}, nil
}

func (r *RealFetcher) searchPreciousMetal(_ context.Context, query string) ([]SymbolInfo, error) {
	query = strings.ToLower(query)
	var results []SymbolInfo
	for _, pm := range preciousMetalList {
		if strings.Contains(strings.ToLower(pm.Symbol), query) ||
			strings.Contains(strings.ToLower(pm.Name), query) ||
			strings.Contains(pm.Name, query) {
			results = append(results, pm)
		}
	}
	return results, nil
}
