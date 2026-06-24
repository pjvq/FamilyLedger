import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:drift/drift.dart' show Value;
import '../../data/local/database.dart' as db;
import '../services/market/market_fetcher.dart';
import 'app_providers.dart';

// ── Display models ──

class QuoteDisplay {
  final String symbol;
  final String name;
  final String marketType;
  final int currentPrice; // 分
  final int changeAmount; // 分
  final double changePercent;
  final DateTime updatedAt;

  const QuoteDisplay({
    required this.symbol,
    required this.name,
    required this.marketType,
    required this.currentPrice,
    required this.changeAmount,
    required this.changePercent,
    required this.updatedAt,
  });

  bool get isUp => changeAmount > 0;
  bool get isDown => changeAmount < 0;
}

class SymbolSearchResult {
  final String symbol;
  final String name;
  final String marketType;

  const SymbolSearchResult({
    required this.symbol,
    required this.name,
    required this.marketType,
  });
}

class PricePoint {
  final DateTime timestamp;
  final int price; // 分

  const PricePoint({required this.timestamp, required this.price});
}

// ── State ──

class MarketDataState {
  final Map<String, QuoteDisplay> quotes; // key: "$symbol:$marketType"
  final List<SymbolSearchResult> searchResults;
  final List<PricePoint> priceHistory;
  final Map<String, List<PricePoint>>
  sparklineCache; // key: "$symbol:$marketType"
  final bool isLoading;
  final String? error;

  const MarketDataState({
    this.quotes = const {},
    this.searchResults = const [],
    this.priceHistory = const [],
    this.sparklineCache = const {},
    this.isLoading = false,
    this.error,
  });

  MarketDataState copyWith({
    Map<String, QuoteDisplay>? quotes,
    List<SymbolSearchResult>? searchResults,
    List<PricePoint>? priceHistory,
    Map<String, List<PricePoint>>? sparklineCache,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearSearch = false,
    bool clearHistory = false,
  }) => MarketDataState(
    quotes: quotes ?? this.quotes,
    searchResults: clearSearch
        ? const []
        : (searchResults ?? this.searchResults),
    priceHistory: clearHistory ? const [] : (priceHistory ?? this.priceHistory),
    sparklineCache: sparklineCache ?? this.sparklineCache,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
  );

  static String quoteKey(String symbol, String marketType) =>
      '$symbol:$marketType';
}

// ── Notifier ──

/// Market-data notifier backed by direct client-side HTTP fetches.
///
/// Quotes / K-line / search are pulled straight from the same public,
/// auth-free sources the server used (EastMoney / Yahoo / CoinGecko / Sina) via
/// [MarketFetcher] — no backend required ("去服务化" Phase 1, issue #142). The
/// public interface (getQuote / batchGetQuotes / searchSymbol /
/// getPriceHistory / batchLoadSparklines) is unchanged so callers are unaffected.
///
/// Caching is two-tiered: an in-memory 15-min TTL avoids redundant network hits
/// within a session, and the Drift `market_quotes` table provides an offline
/// fallback when a fetch fails.
class MarketDataNotifier extends StateNotifier<MarketDataState> {
  final db.AppDatabase _db;
  final MarketFetcher _fetcher;

  /// In-memory cache timestamps for 15-min TTL.
  final Map<String, DateTime> _cacheTimes = {};

  static const _cacheDuration = Duration(minutes: 15);

  MarketDataNotifier(this._db, this._fetcher) : super(const MarketDataState());

  /// Get a single quote (cached 15 min).
  Future<QuoteDisplay?> getQuote(String symbol, String marketType) async {
    final key = MarketDataState.quoteKey(symbol, marketType);

    // Check in-memory cache.
    final cachedTime = _cacheTimes[key];
    if (cachedTime != null &&
        DateTime.now().difference(cachedTime) < _cacheDuration &&
        state.quotes.containsKey(key)) {
      return state.quotes[key];
    }

    try {
      final data = await _fetcher.fetchQuote(symbol, marketType);

      final quote = QuoteDisplay(
        symbol: data.symbol,
        name: data.name,
        marketType: data.marketType,
        currentPrice: data.currentPrice,
        changeAmount: data.changeAmount,
        changePercent: data.changePercent,
        updatedAt: DateTime.now(),
      );

      // Save to local cache.
      await _db.upsertMarketQuote(
        db.MarketQuotesCompanion.insert(
          symbol: symbol,
          marketType: marketType,
          name: Value(data.name),
          currentPrice: Value(data.currentPrice),
          changeAmount: Value(data.changeAmount),
          changePercent: Value(data.changePercent),
          updatedAt: Value(DateTime.now()),
        ),
      );

      _cacheTimes[key] = DateTime.now();
      final newQuotes = Map<String, QuoteDisplay>.from(state.quotes);
      newQuotes[key] = quote;
      state = state.copyWith(quotes: newQuotes);
      return quote;
    } catch (_) {
      // Try local DB.
      final cached = await _db.getMarketQuote(symbol, marketType);
      if (cached != null) {
        final quote = QuoteDisplay(
          symbol: cached.symbol,
          name: cached.name,
          marketType: cached.marketType,
          currentPrice: cached.currentPrice,
          changeAmount: cached.changeAmount,
          changePercent: cached.changePercent,
          updatedAt: cached.updatedAt,
        );
        final newQuotes = Map<String, QuoteDisplay>.from(state.quotes);
        newQuotes[key] = quote;
        state = state.copyWith(quotes: newQuotes);
        return quote;
      }
    }
    return null;
  }

  /// Batch get quotes (per-symbol direct fetch; failures fall back to local DB).
  Future<void> batchGetQuotes(
    List<({String symbol, String marketType})> requests,
  ) async {
    if (requests.isEmpty) return;

    final newQuotes = Map<String, QuoteDisplay>.from(state.quotes);
    var anyFetched = false;

    for (final r in requests) {
      final key = MarketDataState.quoteKey(r.symbol, r.marketType);

      // Honor the in-memory 15-min TTL to avoid redundant network hits.
      final cachedTime = _cacheTimes[key];
      if (cachedTime != null &&
          DateTime.now().difference(cachedTime) < _cacheDuration &&
          newQuotes.containsKey(key)) {
        continue;
      }

      try {
        final data = await _fetcher.fetchQuote(r.symbol, r.marketType);
        newQuotes[key] = QuoteDisplay(
          symbol: data.symbol,
          name: data.name,
          marketType: data.marketType,
          currentPrice: data.currentPrice,
          changeAmount: data.changeAmount,
          changePercent: data.changePercent,
          updatedAt: DateTime.now(),
        );
        _cacheTimes[key] = DateTime.now();
        anyFetched = true;

        await _db.upsertMarketQuote(
          db.MarketQuotesCompanion.insert(
            symbol: r.symbol,
            marketType: r.marketType,
            name: Value(data.name),
            currentPrice: Value(data.currentPrice),
            changeAmount: Value(data.changeAmount),
            changePercent: Value(data.changePercent),
            updatedAt: Value(DateTime.now()),
          ),
        );
      } catch (_) {
        // Per-symbol failure: fall back to local DB for this one.
        final cached = await _db.getMarketQuote(r.symbol, r.marketType);
        if (cached != null) {
          newQuotes[key] = QuoteDisplay(
            symbol: cached.symbol,
            name: cached.name,
            marketType: cached.marketType,
            currentPrice: cached.currentPrice,
            changeAmount: cached.changeAmount,
            changePercent: cached.changePercent,
            updatedAt: cached.updatedAt,
          );
        }
      }
    }

    // If nothing was fetched (e.g. all offline), seed remaining from local DB.
    if (!anyFetched) {
      final cached = await _db.getAllMarketQuotes();
      for (final c in cached) {
        final key = MarketDataState.quoteKey(c.symbol, c.marketType);
        newQuotes.putIfAbsent(
          key,
          () => QuoteDisplay(
            symbol: c.symbol,
            name: c.name,
            marketType: c.marketType,
            currentPrice: c.currentPrice,
            changeAmount: c.changeAmount,
            changePercent: c.changePercent,
            updatedAt: c.updatedAt,
          ),
        );
      }
    }

    state = state.copyWith(quotes: newQuotes);
  }

  /// Search symbols.
  Future<void> searchSymbol(String query, {String? marketType}) async {
    if (query.trim().isEmpty) {
      state = state.copyWith(clearSearch: true);
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final data = await _fetcher.searchSymbol(query, marketType ?? '');
      final results = data
          .map(
            (s) => SymbolSearchResult(
              symbol: s.symbol,
              name: s.name,
              marketType: s.marketType,
            ),
          )
          .toList();
      state = state.copyWith(searchResults: results, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '搜索失败: $e',
        clearSearch: true,
      );
    }
  }

  /// Get price history for chart.
  Future<void> getPriceHistory(
    String symbol,
    String marketType, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearHistory: true,
    );

    final now = DateTime.now();
    final start = startDate ?? now.subtract(const Duration(days: 30));
    final end = endDate ?? now;

    try {
      final data = await _fetcher.fetchPriceHistory(
        symbol,
        marketType,
        start,
        end,
      );
      final points = data
          .map((p) => PricePoint(timestamp: p.timestamp, price: p.price))
          .toList();
      state = state.copyWith(priceHistory: points, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '获取历史行情失败');
    }
  }

  /// Batch load sparkline data for multiple symbols (30-day history).
  /// Skips symbols already in cache. Failures are per-symbol.
  Future<void> batchLoadSparklines(
    List<({String symbol, String marketType})> requests,
  ) async {
    if (requests.isEmpty) return;

    final uncached = requests.where((r) {
      final key = MarketDataState.quoteKey(r.symbol, r.marketType);
      return !state.sparklineCache.containsKey(key);
    }).toList();

    if (uncached.isEmpty) return;

    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));

    final newCache = Map<String, List<PricePoint>>.from(state.sparklineCache);

    for (final r in uncached) {
      final key = MarketDataState.quoteKey(r.symbol, r.marketType);
      try {
        final data = await _fetcher.fetchPriceHistory(
          r.symbol,
          r.marketType,
          start,
          now,
        );
        newCache[key] = data
            .map((p) => PricePoint(timestamp: p.timestamp, price: p.price))
            .toList();
      } catch (_) {
        // Skip this symbol; don't break the batch.
      }
    }

    state = state.copyWith(sparklineCache: newCache);
  }
}

// ── Provider ──

/// Shared HTTP client for direct market-data fetches.
final marketHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Client-side market-data fetcher (direct public HTTP sources).
final marketFetcherProvider = Provider<MarketFetcher>((ref) {
  return MarketFetcher(ref.watch(marketHttpClientProvider));
});

final marketDataProvider =
    StateNotifierProvider<MarketDataNotifier, MarketDataState>((ref) {
      final database = ref.watch(databaseProvider);
      final fetcher = ref.watch(marketFetcherProvider);
      return MarketDataNotifier(database, fetcher);
    });
