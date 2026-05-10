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
// On error, it falls back to MockFetcher to avoid crashing.
type RealFetcher struct {
	client *http.Client
	mock   *MockFetcher // fallback
}

func NewRealFetcher() *RealFetcher {
	return &RealFetcher{
		client: &http.Client{Timeout: 10 * time.Second},
		mock:   NewMockFetcher(),
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
		log.Printf("market: unknown market type %q, falling back to mock", marketType)
		return r.mock.FetchQuote(ctx, symbol, marketType)
	}

	if err != nil {
		// For precious metals, don't fall back to mock (mock gives misleading fake prices)
		if marketType == "precious_metal" {
			log.Printf("market: FetchQuote(%s, %s) error: %v", symbol, marketType, err)
			return nil, err
		}
		log.Printf("market: FetchQuote(%s, %s) error: %v, falling back to mock", symbol, marketType, err)
		return r.mock.FetchQuote(ctx, symbol, marketType)
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
		log.Printf("market: unknown market type %q for search, falling back to mock", marketType)
		return r.mock.SearchSymbol(ctx, query, marketType)
	}

	if err != nil {
		log.Printf("market: SearchSymbol(%s, %s) error: %v, falling back to mock", query, marketType, err)
		return r.mock.SearchSymbol(ctx, query, marketType)
	}
	return results, nil
}

// ── 东方财富 A股 ────────────────────────────────────────────────────────────

// eastMoneySecID returns the secid prefix for an A-share symbol.
// SH (prefix "1."): codes starting with 6, 9, 5
// SZ (prefix "0."): codes starting with 0, 1, 2, 3
func eastMoneySecID(symbol string) string {
	if len(symbol) == 0 {
		return "1." + symbol
	}
	switch symbol[0] {
	case '6', '9', '5':
		return "1." + symbol
	default:
		return "0." + symbol
	}
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
	secid := eastMoneySecID(symbol)
	return r.fetchEastMoneyStock(ctx, secid, symbol, "a_share")
}

func (r *RealFetcher) fetchEastMoneyHKStock(ctx context.Context, symbol string) (*MarketQuote, error) {
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
		USD         float64 `json:"usd"`
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
	{Symbol: "Ag99.99", Name: "白银9999", MarketType: "precious_metal"},
	{Symbol: "Ag(T+D)", Name: "白银T+D", MarketType: "precious_metal"},
	{Symbol: "Pt99.95", Name: "铂金9995", MarketType: "precious_metal"},
}

// preciousMetalSecID maps our display symbol to the SGE code (f12 field in clist API).
var preciousMetalSecID = map[string]string{
	"Au99.99":   "AU9999",
	"Au99.95":   "AU9995",
	"Au100g":    "AU100",
	"Au(T+D)":  "AUTD",
	"mAu(T+D)": "mAUTD",
	"Ag99.99":  "AG9999",
	"Ag(T+D)":  "AGTD",
	"Pt99.95":  "PT9995",
}

func (r *RealFetcher) fetchPreciousMetal(ctx context.Context, symbol string) (*MarketQuote, error) {
	// SGE uses clist endpoint (qt/stock/get doesn't work for market 118)
	// Fetch all SGE products in one call and filter by code
	code, ok := preciousMetalSecID[symbol]
	if !ok {
		return nil, fmt.Errorf("unknown precious metal symbol: %s", symbol)
	}

	// Try realtime clist endpoint first
	quote, err := r.fetchPreciousMetalRealtime(ctx, symbol, code)
	if err == nil {
		return quote, nil
	}
	log.Printf("market: realtime SGE fetch failed for %s: %v, trying kline fallback", symbol, err)

	// Fallback: use kline history (works on weekends / non-trading hours)
	return r.fetchPreciousMetalKline(ctx, symbol, code)
}

// fetchPreciousMetalRealtime fetches from the clist realtime endpoint (trading hours only).
func (r *RealFetcher) fetchPreciousMetalRealtime(ctx context.Context, symbol, code string) (*MarketQuote, error) {
	url := "https://push2.eastmoney.com/api/qt/clist/get?pn=1&pz=30&fs=m:118&fields=f2,f3,f4,f12,f14,f18&fltt=2"

	// Retry up to 3 times (SGE endpoint can be flaky)
	var lastErr error
	for attempt := 0; attempt < 3; attempt++ {
		if attempt > 0 {
			time.Sleep(time.Duration(attempt) * 500 * time.Millisecond)
		}

		req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
		if err != nil {
			return nil, fmt.Errorf("create request: %w", err)
		}
		req.Header.Set("Referer", "https://www.eastmoney.com/")
		req.Header.Set("User-Agent", "Mozilla/5.0 (compatible)")

		resp, err := r.client.Do(req)
		if err != nil {
			lastErr = fmt.Errorf("http get: %w", err)
			continue
		}

		if resp.StatusCode != http.StatusOK {
			resp.Body.Close()
			lastErr = fmt.Errorf("eastmoney returned status %d", resp.StatusCode)
			continue
		}

		var result struct {
			Data struct {
				Diff map[string]struct {
					F2  float64 `json:"f2"`  // current price (元/克)
					F3  float64 `json:"f3"`  // change percent (%)
					F4  float64 `json:"f4"`  // change amount (元)
					F12 string  `json:"f12"` // code (AU9999)
					F14 string  `json:"f14"` // name (黄金9999)
					F18 float64 `json:"f18"` // prev close (昨收元/克)
				} `json:"diff"`
			} `json:"data"`
		}

		if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
			resp.Body.Close()
			lastErr = fmt.Errorf("decode json: %w", err)
			continue
		}
		resp.Body.Close()

		if result.Data.Diff == nil {
			lastErr = fmt.Errorf("no data returned for SGE")
			continue
		}

		for _, item := range result.Data.Diff {
			if strings.EqualFold(item.F12, code) {
				// Use current price; if market closed (f2=0), fall back to prev close
				price := item.F2
				if price <= 0 {
					price = item.F18 // prev close
				}
				if price <= 0 {
					return nil, fmt.Errorf("%s: no valid price (market closed, no prev close)", symbol)
				}
				priceCents := int64(math.Round(price * 100))
				changeCents := int64(math.Round(item.F4 * 100))
				return &MarketQuote{
					Symbol:        symbol,
					Name:          item.F14,
					MarketType:    "precious_metal",
					CurrentPrice:  priceCents,
					ChangeAmount:  changeCents,
					ChangePercent: item.F3,
				}, nil
			}
		}
		return nil, fmt.Errorf("%s: not found in SGE listing", symbol)
	}

	return nil, fmt.Errorf("fetchPreciousMetalRealtime(%s) failed after 3 retries: %w", symbol, lastErr)
}

// fetchPreciousMetalKline fetches the last close price from kline history.
// Works on weekends and non-trading hours when the realtime endpoint is down.
func (r *RealFetcher) fetchPreciousMetalKline(ctx context.Context, symbol, code string) (*MarketQuote, error) {
	url := fmt.Sprintf(
		"https://push2his.eastmoney.com/api/qt/stock/kline/get?secid=118.%s&fields1=f1,f2,f3,f4&fields2=f51,f52,f53,f54,f55&klt=101&fqt=0&end=20500101&lmt=3",
		code,
	)

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("create kline request: %w", err)
	}
	req.Header.Set("Referer", "https://www.eastmoney.com/")
	req.Header.Set("User-Agent", "Mozilla/5.0 (compatible)")

	resp, err := r.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("kline http get: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("kline endpoint returned status %d", resp.StatusCode)
	}

	var result struct {
		Data struct {
			Code   string   `json:"code"`
			Name   string   `json:"name"`
			Klines []string `json:"klines"`
		} `json:"data"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("decode kline json: %w", err)
	}

	if len(result.Data.Klines) == 0 {
		return nil, fmt.Errorf("%s: no kline data available", symbol)
	}

	// Parse last kline: "date,open,close,high,low"
	lastKline := result.Data.Klines[len(result.Data.Klines)-1]
	parts := strings.Split(lastKline, ",")
	if len(parts) < 3 {
		return nil, fmt.Errorf("%s: invalid kline format: %s", symbol, lastKline)
	}

	closePrice, err := strconv.ParseFloat(parts[2], 64) // close price
	if err != nil {
		return nil, fmt.Errorf("%s: parse close price: %w", symbol, err)
	}

	// Calculate change from prev kline if available
	var prevClose float64
	if len(result.Data.Klines) >= 2 {
		prevKline := result.Data.Klines[len(result.Data.Klines)-2]
		prevParts := strings.Split(prevKline, ",")
		if len(prevParts) >= 3 {
			prevClose, _ = strconv.ParseFloat(prevParts[2], 64)
		}
	}

	var changeAmount float64
	var changePercent float64
	if prevClose > 0 {
		changeAmount = closePrice - prevClose
		changePercent = (changeAmount / prevClose) * 100
	}

	name := result.Data.Name
	if name == "" {
		// Lookup from our static list
		for _, pm := range preciousMetalList {
			if pm.Symbol == symbol {
				name = pm.Name
				break
			}
		}
	}

	priceCents := int64(math.Round(closePrice * 100))
	changeCents := int64(math.Round(changeAmount * 100))

	return &MarketQuote{
		Symbol:        symbol,
		Name:          name,
		MarketType:    "precious_metal",
		CurrentPrice:  priceCents,
		ChangeAmount:  changeCents,
		ChangePercent: changePercent,
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
