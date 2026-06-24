/// Plain value objects produced by [MarketFetcher].
///
/// These mirror the server-side `MarketQuote` / `SymbolInfo` structs in
/// `server/internal/market/fetcher.go`. They are intentionally framework-free
/// (no Riverpod, no Drift) so the fetcher can be unit-tested in isolation and
/// reused by both the mobile and (future) desktop clients.
///
/// All monetary values are integer **分 (cents)**, matching the server and the
/// local Drift cache.
library;

/// A single market quote fetched from an external data source.
class MarketQuoteData {
  final String symbol;
  final String name;
  final String marketType;
  final int currentPrice; // 分
  final int changeAmount; // 分
  final double changePercent; // 百分比
  final int open; // 分
  final int high; // 分
  final int low; // 分
  final int prevClose; // 分

  const MarketQuoteData({
    required this.symbol,
    required this.name,
    required this.marketType,
    required this.currentPrice,
    required this.changeAmount,
    required this.changePercent,
    this.open = 0,
    this.high = 0,
    this.low = 0,
    this.prevClose = 0,
  });
}

/// Basic symbol information returned from a search.
class SymbolInfoData {
  final String symbol;
  final String name;
  final String marketType;

  const SymbolInfoData({
    required this.symbol,
    required this.name,
    required this.marketType,
  });
}

/// One point on a price-history (K-line) series.
class PricePointData {
  final DateTime timestamp;
  final int price; // 分

  const PricePointData({required this.timestamp, required this.price});
}
