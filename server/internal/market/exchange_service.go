package market

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"math"
	"net/http"
	"time"

	"github.com/familyledger/server/pkg/db"
)

// ExchangeRate represents a currency exchange rate.
type ExchangeRate struct {
	CurrencyPair string
	Rate         float64
	Source       string
	UpdatedAt    time.Time
}

// ExchangeService provides currency exchange rate operations.
type ExchangeService struct {
	pool   db.Pool
	client *http.Client
}

// NewExchangeService creates a new ExchangeService.
func NewExchangeService(pool db.Pool) *ExchangeService {
	return &ExchangeService{
		pool:   pool,
		client: &http.Client{Timeout: 15 * time.Second},
	}
}

// GetExchangeRate returns the exchange rate from one currency to another.
// The pair is stored as FROM_TO (e.g., USD_CNY).
func (s *ExchangeService) GetExchangeRate(ctx context.Context, from, to string) (float64, error) {
	if from == to {
		return 1.0, nil
	}

	pair := fmt.Sprintf("%s_%s", from, to)

	var rate float64
	err := s.pool.QueryRow(ctx,
		`SELECT rate FROM exchange_rates WHERE currency_pair = $1`,
		pair,
	).Scan(&rate)
	if err != nil {
		// Try inverse pair
		inversePair := fmt.Sprintf("%s_%s", to, from)
		var inverseRate float64
		err2 := s.pool.QueryRow(ctx,
			`SELECT rate FROM exchange_rates WHERE currency_pair = $1`,
			inversePair,
		).Scan(&inverseRate)
		if err2 != nil {
			return 0, fmt.Errorf("exchange rate not found for %s or %s: %w", pair, inversePair, err)
		}
		if inverseRate == 0 {
			return 0, fmt.Errorf("inverse rate is zero for %s", inversePair)
		}
		return 1.0 / inverseRate, nil
	}

	return rate, nil
}

// RefreshExchangeRates fetches real exchange rates from open.er-api.com (free, no key required).
// Base currency: CNY. Updates all existing pairs in the DB.
// Falls back to mock fluctuation if the API call fails.
func (s *ExchangeService) RefreshExchangeRates(ctx context.Context) error {
	rates, err := s.fetchRealRates(ctx)
	if err != nil {
		log.Printf("exchange: real API failed (%v), falling back to mock", err)
		return s.refreshMock(ctx)
	}

	// Get all existing pairs from DB
	rows, err := s.pool.Query(ctx,
		`SELECT currency_pair FROM exchange_rates WHERE currency_pair != 'CNY_CNY'`,
	)
	if err != nil {
		return fmt.Errorf("query exchange rates: %w", err)
	}
	defer rows.Close()

	var pairs []string
	for rows.Next() {
		var pair string
		if err := rows.Scan(&pair); err != nil {
			continue
		}
		pairs = append(pairs, pair)
	}

	updated := 0
	for _, pair := range pairs {
		// Parse pair: "USD_CNY" → from="USD", to="CNY"
		if len(pair) < 7 {
			continue
		}
		from := pair[:3]
		to := pair[4:]

		newRate, ok := s.computeRate(from, to, rates)
		if !ok {
			log.Printf("exchange: no rate data for %s", pair)
			continue
		}

		_, err := s.pool.Exec(ctx,
			`UPDATE exchange_rates SET rate = $1, source = 'open.er-api.com', updated_at = NOW()
			 WHERE currency_pair = $2`,
			newRate, pair,
		)
		if err != nil {
			log.Printf("exchange: update rate error %s: %v", pair, err)
			continue
		}
		updated++
	}

	log.Printf("exchange: refreshed %d/%d rates from real API", updated, len(pairs))
	return nil
}

// fetchRealRates calls open.er-api.com with base=CNY, returns map of currency→rate.
// Example: rates["USD"] = 0.1379 means 1 CNY = 0.1379 USD.
func (s *ExchangeService) fetchRealRates(ctx context.Context) (map[string]float64, error) {
	url := "https://open.er-api.com/v6/latest/CNY"

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}

	resp, err := s.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("http get: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API returned status %d", resp.StatusCode)
	}

	var result struct {
		Result string             `json:"result"`
		Rates  map[string]float64 `json:"rates"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("decode json: %w", err)
	}

	if result.Result != "success" || len(result.Rates) == 0 {
		return nil, fmt.Errorf("API returned result=%s, rates count=%d", result.Result, len(result.Rates))
	}

	return result.Rates, nil
}

// computeRate calculates the rate for a FROM_TO pair using CNY-based rates.
// rates map: currency → how many units of that currency per 1 CNY.
func (s *ExchangeService) computeRate(from, to string, rates map[string]float64) (float64, bool) {
	// Special case: X_CNY → we need "how many CNY per 1 X" = 1 / rates[X]
	// Special case: CNY_X → rates[X] directly
	if from == "CNY" {
		r, ok := rates[to]
		return math.Round(r*1e8) / 1e8, ok
	}
	if to == "CNY" {
		r, ok := rates[from]
		if !ok || r == 0 {
			return 0, false
		}
		return math.Round((1.0/r)*1e8) / 1e8, ok
	}
	// General case: FROM_TO = rates[TO] / rates[FROM]
	rFrom, okF := rates[from]
	rTo, okT := rates[to]
	if !okF || !okT || rFrom == 0 {
		return 0, false
	}
	return math.Round((rTo/rFrom)*1e8) / 1e8, true
}

// refreshMock applies small random fluctuation to existing rates (fallback).
func (s *ExchangeService) refreshMock(ctx context.Context) error {
	rows, err := s.pool.Query(ctx,
		`SELECT currency_pair, rate FROM exchange_rates WHERE currency_pair != 'CNY_CNY'`,
	)
	if err != nil {
		return fmt.Errorf("query exchange rates: %w", err)
	}
	defer rows.Close()

	type rateEntry struct {
		pair string
		rate float64
	}
	var entries []rateEntry
	for rows.Next() {
		var e rateEntry
		if err := rows.Scan(&e.pair, &e.rate); err != nil {
			continue
		}
		entries = append(entries, e)
	}

	for _, e := range entries {
		// Keep existing rate with tiny drift (±0.1%) as fallback
		drift := 1.0 + (float64(time.Now().UnixNano()%200)-100)/100000.0
		newRate := math.Round(e.rate*drift*1e8) / 1e8

		_, err := s.pool.Exec(ctx,
			`UPDATE exchange_rates SET rate = $1, source = 'mock-fallback', updated_at = NOW()
			 WHERE currency_pair = $2`,
			newRate, e.pair,
		)
		if err != nil {
			log.Printf("exchange: mock update error %s: %v", e.pair, err)
		}
	}

	log.Printf("exchange: mock-refreshed %d rates", len(entries))
	return nil
}
