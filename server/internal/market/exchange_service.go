package market

import (
	"context"
	"fmt"
	"log"
	"math"
	"math/rand"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// ExchangeRate represents a currency exchange rate.
type ExchangeRate struct {
	CurrencyPair string
	Rate         float64
	Source       string
	UpdatedAt    time.Time
}

// ExchangeService provides currency exchange rate operations.
// It extends the market data capabilities with FX rate lookups.
type ExchangeService struct {
	pool *pgxpool.Pool
}

// NewExchangeService creates a new ExchangeService.
func NewExchangeService(pool *pgxpool.Pool) *ExchangeService {
	return &ExchangeService{pool: pool}
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

// RefreshExchangeRates simulates refreshing exchange rates from an external API.
// In production, this would call a real FX API (e.g., exchangerate-api.com).
// Currently adds small random fluctuation to existing rates.
func (s *ExchangeService) RefreshExchangeRates(ctx context.Context) error {
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

	// Apply small random fluctuation (±0.5%)
	rng := rand.New(rand.NewSource(time.Now().UnixNano()))
	for _, e := range entries {
		fluctuation := (rng.Float64() - 0.5) * 0.01 // ±0.5%
		newRate := e.rate * (1.0 + fluctuation)
		// Round to 8 decimal places
		newRate = math.Round(newRate*1e8) / 1e8

		_, err := s.pool.Exec(ctx,
			`UPDATE exchange_rates SET rate = $1, source = 'mock', updated_at = NOW()
			 WHERE currency_pair = $2`,
			newRate, e.pair,
		)
		if err != nil {
			log.Printf("exchange: update rate error %s: %v", e.pair, err)
		}
	}

	log.Printf("exchange: refreshed %d rates", len(entries))
	return nil
}
