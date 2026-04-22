import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fixnum/fixnum.dart';
import 'package:drift/drift.dart' show Value;
import '../../data/local/database.dart' as db;
import '../../data/remote/grpc_clients.dart';
import '../../generated/proto/investment.pb.dart' as pb;
import '../../generated/proto/investment.pbgrpc.dart';
import '../../generated/proto/investment.pbenum.dart' as pb_enum;
import '../../generated/proto/google/protobuf/timestamp.pb.dart' as ts_pb;
import 'app_providers.dart';
pb_enum.MarketType _toProtoMarketType(String type) {
  switch (type) {
    case 'a_share':
      return pb_enum.MarketType.MARKET_TYPE_A_SHARE;
    case 'hk_stock':
      return pb_enum.MarketType.MARKET_TYPE_HK_STOCK;
    case 'us_stock':
      return pb_enum.MarketType.MARKET_TYPE_US_STOCK;
    case 'crypto':
      return pb_enum.MarketType.MARKET_TYPE_CRYPTO;
    case 'fund':
      return pb_enum.MarketType.MARKET_TYPE_FUND;
    default:
      return pb_enum.MarketType.MARKET_TYPE_A_SHARE;
  }
}

String _fromProtoMarketType(pb_enum.MarketType type) {
  switch (type) {
    case pb_enum.MarketType.MARKET_TYPE_A_SHARE:
      return 'a_share';
    case pb_enum.MarketType.MARKET_TYPE_HK_STOCK:
      return 'hk_stock';
    case pb_enum.MarketType.MARKET_TYPE_US_STOCK:
      return 'us_stock';
    case pb_enum.MarketType.MARKET_TYPE_CRYPTO:
      return 'crypto';
    case pb_enum.MarketType.MARKET_TYPE_FUND:
      return 'fund';
    default:
      return 'a_share';
  }
}

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
  final bool isLoading;
  final String? error;

  const MarketDataState({
    this.quotes = const {},
    this.searchResults = const [],
    this.priceHistory = const [],
    this.isLoading = false,
    this.error,
  });

  MarketDataState copyWith({
    Map<String, QuoteDisplay>? quotes,
    List<SymbolSearchResult>? searchResults,
    List<PricePoint>? priceHistory,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearSearch = false,
    bool clearHistory = false,
  }) =>
      MarketDataState(
        quotes: quotes ?? this.quotes,
        searchResults: clearSearch ? const [] : (searchResults ?? this.searchResults),
        priceHistory: clearHistory ? const [] : (priceHistory ?? this.priceHistory),
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );

  static String quoteKey(String symbol, String marketType) =>
      '$symbol:$marketType';
}

// ── Notifier ──

class MarketDataNotifier extends StateNotifier<MarketDataState> {
  final db.AppDatabase _db;
  final MarketDataServiceClient _client;

  /// In-memory cache timestamps for 15-min TTL
  final Map<String, DateTime> _cacheTimes = {};

  static const _cacheDuration = Duration(minutes: 15);

  MarketDataNotifier(this._db, this._client)
      : super(const MarketDataState());

  /// Get a single quote (cached 15 min)
  Future<QuoteDisplay?> getQuote(String symbol, String marketType) async {
    final key = MarketDataState.quoteKey(symbol, marketType);

    // Check in-memory cache
    final cachedTime = _cacheTimes[key];
    if (cachedTime != null &&
        DateTime.now().difference(cachedTime) < _cacheDuration &&
        state.quotes.containsKey(key)) {
      return state.quotes[key];
    }

    try {
      final resp = await _client.getQuote(pb.GetQuoteRequest()
        ..symbol = symbol
        ..marketType = _toProtoMarketType(marketType));

      final quote = QuoteDisplay(
        symbol: resp.symbol,
        name: resp.name,
        marketType: _fromProtoMarketType(resp.marketType),
        currentPrice: resp.currentPrice.toInt(),
        changeAmount: resp.change.toInt(),
        changePercent: resp.changePercent,
        updatedAt: DateTime.now(),
      );

      // Save to local cache
      await _db.upsertMarketQuote(db.MarketQuotesCompanion.insert(
        symbol: symbol,
        marketType: marketType,
        name: Value(resp.name),
        currentPrice: Value(resp.currentPrice.toInt()),
        changeAmount: Value(resp.change.toInt()),
        changePercent: Value(resp.changePercent),
        updatedAt: Value(DateTime.now()),
      ));

      _cacheTimes[key] = DateTime.now();
      final newQuotes = Map<String, QuoteDisplay>.from(state.quotes);
      newQuotes[key] = quote;
      state = state.copyWith(quotes: newQuotes);
      return quote;
    } catch (_) {
      // Try local DB
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

  /// Batch get quotes
  Future<void> batchGetQuotes(
      List<({String symbol, String marketType})> requests) async {
    if (requests.isEmpty) return;

    try {
      final pbRequests = requests.map((r) => pb.GetQuoteRequest()
        ..symbol = r.symbol
        ..marketType = _toProtoMarketType(r.marketType));
      final resp = await _client.batchGetQuotes(
          pb.BatchGetQuotesRequest()..requests.addAll(pbRequests));

      final newQuotes = Map<String, QuoteDisplay>.from(state.quotes);
      for (final q in resp.quotes) {
        final mt = _fromProtoMarketType(q.marketType);
        final key = MarketDataState.quoteKey(q.symbol, mt);
        final quote = QuoteDisplay(
          symbol: q.symbol,
          name: q.name,
          marketType: mt,
          currentPrice: q.currentPrice.toInt(),
          changeAmount: q.change.toInt(),
          changePercent: q.changePercent,
          updatedAt: DateTime.now(),
        );
        newQuotes[key] = quote;
        _cacheTimes[key] = DateTime.now();

        await _db.upsertMarketQuote(db.MarketQuotesCompanion.insert(
          symbol: q.symbol,
          marketType: mt,
          name: Value(q.name),
          currentPrice: Value(q.currentPrice.toInt()),
          changeAmount: Value(q.change.toInt()),
          changePercent: Value(q.changePercent),
          updatedAt: Value(DateTime.now()),
        ));
      }
      state = state.copyWith(quotes: newQuotes);
    } catch (_) {
      // Load all from local DB as fallback
      final cached = await _db.getAllMarketQuotes();
      final newQuotes = Map<String, QuoteDisplay>.from(state.quotes);
      for (final c in cached) {
        final key = MarketDataState.quoteKey(c.symbol, c.marketType);
        newQuotes[key] = QuoteDisplay(
          symbol: c.symbol,
          name: c.name,
          marketType: c.marketType,
          currentPrice: c.currentPrice,
          changeAmount: c.changeAmount,
          changePercent: c.changePercent,
          updatedAt: c.updatedAt,
        );
      }
      state = state.copyWith(quotes: newQuotes);
    }
  }

  /// Search symbols
  Future<void> searchSymbol(String query, {String? marketType}) async {
    if (query.trim().isEmpty) {
      state = state.copyWith(clearSearch: true);
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final req = pb.SearchSymbolRequest()..query = query;
      if (marketType != null) {
        req.marketType = _toProtoMarketType(marketType);
      }
      final resp = await _client.searchSymbol(req);

      final results = resp.symbols
          .map((s) => SymbolSearchResult(
                symbol: s.symbol,
                name: s.name,
                marketType: _fromProtoMarketType(s.marketType),
              ))
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

  /// Get price history for chart
  Future<void> getPriceHistory(
    String symbol,
    String marketType, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearHistory: true);

    final now = DateTime.now();
    final start = startDate ?? now.subtract(const Duration(days: 30));
    final end = endDate ?? now;

    try {
      final resp = await _client.getPriceHistory(pb.GetPriceHistoryRequest()
        ..symbol = symbol
        ..marketType = _toProtoMarketType(marketType)
        ..startDate = _toTimestamp(start)
        ..endDate = _toTimestamp(end));

      final points = resp.points
          .map((p) => PricePoint(
                timestamp: _fromTimestamp(p.timestamp),
                price: p.price.toInt(),
              ))
          .toList();
      state = state.copyWith(priceHistory: points, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '获取历史行情失败');
    }
  }

  ts_pb.Timestamp _toTimestamp(DateTime dt) {
    final seconds = dt.millisecondsSinceEpoch ~/ 1000;
    return ts_pb.Timestamp(seconds: Int64(seconds));
  }

  DateTime _fromTimestamp(ts_pb.Timestamp ts) {
    return DateTime.fromMillisecondsSinceEpoch(ts.seconds.toInt() * 1000);
  }
}

// ── Provider ──

final marketDataProvider =
    StateNotifierProvider<MarketDataNotifier, MarketDataState>((ref) {
  final database = ref.watch(databaseProvider);
  final client = ref.watch(marketDataClientProvider);
  return MarketDataNotifier(database, client);
});
