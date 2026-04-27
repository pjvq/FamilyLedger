package market

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func mustLoadLocation(tz string) *time.Location {
	loc, err := time.LoadLocation(tz)
	if err != nil {
		panic(err)
	}
	return loc
}

// ─── IsTradingHours ─────────────────────────────────────────────────────────

func TestIsTradingHours_AShare_DuringMorningSession(t *testing.T) {
	// Wednesday 10:00 Shanghai time
	cst := mustLoadLocation("Asia/Shanghai")
	now := time.Date(2026, 4, 22, 10, 0, 0, 0, cst) // Wednesday
	assert.True(t, IsTradingHours(now, "a_share"))
}

func TestIsTradingHours_AShare_DuringAfternoonSession(t *testing.T) {
	cst := mustLoadLocation("Asia/Shanghai")
	now := time.Date(2026, 4, 22, 14, 0, 0, 0, cst) // Wednesday 14:00
	assert.True(t, IsTradingHours(now, "a_share"))
}

func TestIsTradingHours_AShare_LunchBreak(t *testing.T) {
	cst := mustLoadLocation("Asia/Shanghai")
	now := time.Date(2026, 4, 22, 12, 0, 0, 0, cst) // Wednesday 12:00
	assert.False(t, IsTradingHours(now, "a_share"))
}

func TestIsTradingHours_AShare_AfterClose(t *testing.T) {
	cst := mustLoadLocation("Asia/Shanghai")
	now := time.Date(2026, 4, 22, 16, 0, 0, 0, cst) // Wednesday 16:00
	assert.False(t, IsTradingHours(now, "a_share"))
}

func TestIsTradingHours_AShare_BeforeOpen(t *testing.T) {
	cst := mustLoadLocation("Asia/Shanghai")
	now := time.Date(2026, 4, 22, 9, 0, 0, 0, cst) // Wednesday 09:00
	assert.False(t, IsTradingHours(now, "a_share"))
}

func TestIsTradingHours_AShare_Weekend(t *testing.T) {
	cst := mustLoadLocation("Asia/Shanghai")
	now := time.Date(2026, 4, 25, 10, 0, 0, 0, cst) // Saturday 10:00
	assert.False(t, IsTradingHours(now, "a_share"))
}

func TestIsTradingHours_AShare_Sunday(t *testing.T) {
	cst := mustLoadLocation("Asia/Shanghai")
	now := time.Date(2026, 4, 26, 10, 0, 0, 0, cst) // Sunday 10:00
	assert.False(t, IsTradingHours(now, "a_share"))
}

func TestIsTradingHours_HKStock_DuringMorning(t *testing.T) {
	hkt := mustLoadLocation("Asia/Hong_Kong")
	now := time.Date(2026, 4, 22, 10, 30, 0, 0, hkt) // Wednesday 10:30 HKT
	assert.True(t, IsTradingHours(now, "hk_stock"))
}

func TestIsTradingHours_HKStock_Afternoon(t *testing.T) {
	hkt := mustLoadLocation("Asia/Hong_Kong")
	now := time.Date(2026, 4, 22, 15, 0, 0, 0, hkt) // Wednesday 15:00 HKT
	assert.True(t, IsTradingHours(now, "hk_stock"))
}

func TestIsTradingHours_HKStock_AfterClose(t *testing.T) {
	hkt := mustLoadLocation("Asia/Hong_Kong")
	now := time.Date(2026, 4, 22, 16, 30, 0, 0, hkt) // Wednesday 16:30 HKT
	assert.False(t, IsTradingHours(now, "hk_stock"))
}

func TestIsTradingHours_USStock_DuringTrading(t *testing.T) {
	ny := mustLoadLocation("America/New_York")
	now := time.Date(2026, 4, 22, 12, 0, 0, 0, ny) // Wednesday 12:00 ET
	assert.True(t, IsTradingHours(now, "us_stock"))
}

func TestIsTradingHours_USStock_FromBeijingTime(t *testing.T) {
	// US market open 9:30 ET = Beijing 21:30 (non-DST) or 22:30 (DST April)
	// In April, EDT is UTC-4, so 9:30 ET = 21:30 UTC+8
	cst := mustLoadLocation("Asia/Shanghai")
	now := time.Date(2026, 4, 22, 22, 0, 0, 0, cst) // Wednesday 22:00 Beijing
	assert.True(t, IsTradingHours(now, "us_stock"))
}

func TestIsTradingHours_USStock_BeforeOpen(t *testing.T) {
	ny := mustLoadLocation("America/New_York")
	now := time.Date(2026, 4, 22, 8, 0, 0, 0, ny) // Wednesday 08:00 ET
	assert.False(t, IsTradingHours(now, "us_stock"))
}

func TestIsTradingHours_USStock_Weekend(t *testing.T) {
	ny := mustLoadLocation("America/New_York")
	now := time.Date(2026, 4, 25, 12, 0, 0, 0, ny) // Saturday 12:00 ET
	assert.False(t, IsTradingHours(now, "us_stock"))
}

func TestIsTradingHours_Crypto_Always(t *testing.T) {
	cst := mustLoadLocation("Asia/Shanghai")
	// Test various times: weekend night, weekday morning, etc.
	times := []time.Time{
		time.Date(2026, 4, 25, 3, 0, 0, 0, cst),  // Saturday 03:00
		time.Date(2026, 4, 22, 10, 0, 0, 0, cst), // Wednesday 10:00
		time.Date(2026, 4, 22, 23, 0, 0, 0, cst), // Wednesday 23:00
	}
	for _, now := range times {
		assert.True(t, IsTradingHours(now, "crypto"), "crypto should always be trading: %v", now)
	}
}

// ─── ComputeMarketIntervalForTypes ──────────────────────────────────────────

func TestComputeMarketIntervalForTypes_AShareTrading(t *testing.T) {
	cst := mustLoadLocation("Asia/Shanghai")
	now := time.Date(2026, 4, 22, 10, 0, 0, 0, cst) // Wednesday 10:00
	interval := ComputeMarketIntervalForTypes(now, []string{"a_share"})
	assert.Equal(t, 15*time.Minute, interval)
}

func TestComputeMarketIntervalForTypes_AShareClosed(t *testing.T) {
	cst := mustLoadLocation("Asia/Shanghai")
	now := time.Date(2026, 4, 22, 20, 0, 0, 0, cst) // Wednesday 20:00
	interval := ComputeMarketIntervalForTypes(now, []string{"a_share"})
	assert.Equal(t, 4*time.Hour, interval)
}

func TestComputeMarketIntervalForTypes_Weekend(t *testing.T) {
	cst := mustLoadLocation("Asia/Shanghai")
	now := time.Date(2026, 4, 25, 10, 0, 0, 0, cst) // Saturday 10:00
	interval := ComputeMarketIntervalForTypes(now, []string{"a_share", "hk_stock"})
	assert.Equal(t, 4*time.Hour, interval)
}

func TestComputeMarketIntervalForTypes_MultiMarket_OneTrading(t *testing.T) {
	// Beijing 22:00 Wednesday → US market is open (10:00 ET in April)
	cst := mustLoadLocation("Asia/Shanghai")
	now := time.Date(2026, 4, 22, 22, 0, 0, 0, cst)
	interval := ComputeMarketIntervalForTypes(now, []string{"a_share", "us_stock"})
	// a_share is closed, but us_stock is open → should use trading interval
	assert.Equal(t, 15*time.Minute, interval)
}

func TestComputeMarketIntervalForTypes_CryptoAlways15Min(t *testing.T) {
	cst := mustLoadLocation("Asia/Shanghai")
	now := time.Date(2026, 4, 25, 3, 0, 0, 0, cst) // Saturday 03:00
	interval := ComputeMarketIntervalForTypes(now, []string{"crypto"})
	assert.Equal(t, 15*time.Minute, interval)
}

func TestComputeMarketIntervalForTypes_AllClosed(t *testing.T) {
	cst := mustLoadLocation("Asia/Shanghai")
	// Saturday 10:00 Beijing — all stock markets closed
	now := time.Date(2026, 4, 25, 10, 0, 0, 0, cst)
	interval := ComputeMarketIntervalForTypes(now, []string{"a_share", "hk_stock", "us_stock", "fund"})
	assert.Equal(t, 4*time.Hour, interval)
}

// ─── computeMarketInterval (global function used by scheduler) ──────────────

func TestComputeMarketInterval_IncludesCrypto(t *testing.T) {
	cst := mustLoadLocation("Asia/Shanghai")
	// Even on weekends, computeMarketInterval includes crypto → always 15 min
	now := time.Date(2026, 4, 25, 3, 0, 0, 0, cst) // Saturday 03:00
	interval := computeMarketInterval(now)
	assert.Equal(t, 15*time.Minute, interval)
}
