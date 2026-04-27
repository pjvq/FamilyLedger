package market

import (
	"time"
)

// TradingSession defines a trading time window in a specific timezone.
type TradingSession struct {
	StartHour, StartMinute int
	EndHour, EndMinute     int
}

// MarketSchedule defines trading sessions for a market type.
type MarketSchedule struct {
	Timezone string
	Sessions []TradingSession
}

var marketSchedules = map[string]MarketSchedule{
	"a_share": {
		Timezone: "Asia/Shanghai",
		Sessions: []TradingSession{
			{9, 30, 11, 30},
			{13, 0, 15, 0},
		},
	},
	"hk_stock": {
		Timezone: "Asia/Hong_Kong",
		Sessions: []TradingSession{
			{9, 30, 12, 0},
			{13, 0, 16, 0},
		},
	},
	"us_stock": {
		Timezone: "America/New_York",
		Sessions: []TradingSession{
			{9, 30, 16, 0},
		},
	},
	"fund": {
		// Funds follow A-share schedule (NAV calculated at close)
		Timezone: "Asia/Shanghai",
		Sessions: []TradingSession{
			{9, 30, 11, 30},
			{13, 0, 15, 0},
		},
	},
	// crypto: 24/7, no schedule needed (always trading)
}

const (
	intervalTrading    = 15 * time.Minute
	intervalOffHours   = 4 * time.Hour
	intervalCrypto     = 15 * time.Minute
)

// IsTradingHours checks if the given time falls within trading hours
// for the specified market type.
func IsTradingHours(now time.Time, marketType string) bool {
	if marketType == "crypto" {
		return true // 24/7
	}

	schedule, ok := marketSchedules[marketType]
	if !ok {
		return false
	}

	loc, err := time.LoadLocation(schedule.Timezone)
	if err != nil {
		// Fallback: treat as trading hours to avoid missing data
		return true
	}

	localNow := now.In(loc)
	weekday := localNow.Weekday()

	// Weekends are never trading days
	if weekday == time.Saturday || weekday == time.Sunday {
		return false
	}

	hhmm := localNow.Hour()*60 + localNow.Minute()
	for _, session := range schedule.Sessions {
		start := session.StartHour*60 + session.StartMinute
		end := session.EndHour*60 + session.EndMinute
		if hhmm >= start && hhmm < end {
			return true
		}
	}
	return false
}

// ComputeMarketIntervalForTypes returns the appropriate refresh interval
// based on the current time and the market types being refreshed.
// If any market is in trading hours, returns the trading interval (15 min).
// Otherwise returns the off-hours interval (4 hours).
func ComputeMarketIntervalForTypes(now time.Time, marketTypes []string) time.Duration {
	for _, mt := range marketTypes {
		if IsTradingHours(now, mt) {
			return intervalTrading
		}
	}
	return intervalOffHours
}

// computeMarketInterval is the updated version used by the scheduler.
// It considers all market types that might be refreshed.
func computeMarketInterval(now time.Time) time.Duration {
	// Check if any market is in trading hours
	allTypes := []string{"a_share", "hk_stock", "us_stock", "fund", "crypto"}
	return ComputeMarketIntervalForTypes(now, allTypes)
}
