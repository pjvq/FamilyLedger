package market

import (
	"context"
	"math"
	"testing"

	"github.com/jackc/pgx/v5"
	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestGetExchangeRate_SameCurrency(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewExchangeService(mock)
	rate, err := svc.GetExchangeRate(context.Background(), "CNY", "CNY")
	require.NoError(t, err)
	assert.Equal(t, 1.0, rate)
}

func TestGetExchangeRate_DirectPair(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewExchangeService(mock)

	mock.ExpectQuery("SELECT rate FROM exchange_rates WHERE currency_pair").
		WithArgs("USD_CNY").
		WillReturnRows(pgxmock.NewRows([]string{"rate"}).AddRow(7.25))

	rate, err := svc.GetExchangeRate(context.Background(), "USD", "CNY")
	require.NoError(t, err)
	assert.Equal(t, 7.25, rate)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGetExchangeRate_InversePair(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewExchangeService(mock)

	// Direct lookup fails
	mock.ExpectQuery("SELECT rate FROM exchange_rates WHERE currency_pair").
		WithArgs("CNY_USD").
		WillReturnError(pgx.ErrNoRows)

	// Inverse lookup succeeds
	mock.ExpectQuery("SELECT rate FROM exchange_rates WHERE currency_pair").
		WithArgs("USD_CNY").
		WillReturnRows(pgxmock.NewRows([]string{"rate"}).AddRow(7.25))

	rate, err := svc.GetExchangeRate(context.Background(), "CNY", "USD")
	require.NoError(t, err)
	expected := 1.0 / 7.25
	assert.InDelta(t, expected, rate, 0.0001)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGetExchangeRate_NotFound(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewExchangeService(mock)

	mock.ExpectQuery("SELECT rate FROM exchange_rates WHERE currency_pair").
		WithArgs("XYZ_ABC").
		WillReturnError(pgx.ErrNoRows)
	mock.ExpectQuery("SELECT rate FROM exchange_rates WHERE currency_pair").
		WithArgs("ABC_XYZ").
		WillReturnError(pgx.ErrNoRows)

	rate, err := svc.GetExchangeRate(context.Background(), "XYZ", "ABC")
	assert.NoError(t, err)
	assert.Equal(t, 1.0, rate) // fallback to default 1.0
}

func TestComputeRate(t *testing.T) {
	svc := &ExchangeService{}
	rates := map[string]float64{
		"USD": 0.1379, // 1 CNY = 0.1379 USD
		"EUR": 0.1268, // 1 CNY = 0.1268 EUR
		"JPY": 21.33,  // 1 CNY = 21.33 JPY
	}

	// CNY_USD: direct lookup
	rate, ok := svc.computeRate("CNY", "USD", rates)
	assert.True(t, ok)
	assert.Equal(t, 0.1379, rate)

	// USD_CNY: inverse
	rate, ok = svc.computeRate("USD", "CNY", rates)
	assert.True(t, ok)
	expected := math.Round((1.0/0.1379)*1e8) / 1e8
	assert.Equal(t, expected, rate)

	// USD_EUR: cross rate
	rate, ok = svc.computeRate("USD", "EUR", rates)
	assert.True(t, ok)
	expected = math.Round((0.1268/0.1379)*1e8) / 1e8
	assert.Equal(t, expected, rate)

	// Unknown currency
	_, ok = svc.computeRate("CNY", "XYZ", rates)
	assert.False(t, ok)
}

func TestRefreshMock(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewExchangeService(mock)

	mock.ExpectQuery("SELECT currency_pair, rate FROM exchange_rates").
		WillReturnRows(pgxmock.NewRows([]string{"currency_pair", "rate"}).
			AddRow("USD_CNY", 7.25).
			AddRow("EUR_CNY", 7.89))

	mock.ExpectExec("UPDATE exchange_rates SET rate").
		WithArgs(pgxmock.AnyArg(), "USD_CNY").
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectExec("UPDATE exchange_rates SET rate").
		WithArgs(pgxmock.AnyArg(), "EUR_CNY").
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	err = svc.refreshMock(context.Background())
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}
