import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:familyledger/data/local/database.dart';
import 'package:familyledger/domain/providers/market_data_provider.dart';
import 'package:familyledger/domain/services/market/market_fetcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Fake [http.Client] that tracks how many requests are in flight at once, so
/// we can assert [MarketDataNotifier.batchGetQuotes] caps its fan-out (runs
/// concurrently in chunks rather than serially or all-at-once). Each request
/// resolves an EastMoney-shaped quote keyed by the secid in the URL. Network is
/// never touched.
class _ConcurrencyTrackingClient extends http.BaseClient {
  int inFlight = 0;
  int maxInFlight = 0;
  int totalRequests = 0;

  /// Completer all in-flight requests await, so several can pile up before any
  /// completes — that's what exposes the concurrency level.
  final Completer<void> _gate = Completer<void>();

  void openGate() => _gate.complete();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    totalRequests++;
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    await _gate.future;
    inFlight--;

    final body = jsonEncode({
      'data': {
        'f43': 10.0,
        'f58': 'stock-${request.url.queryParameters['secid']}',
        'f60': 10.0,
        'f170': 0.0,
      },
    });
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      request: request,
    );
  }
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('batchGetQuotes fetches concurrently, capped at 5 in flight', () async {
    final client = _ConcurrencyTrackingClient();
    final notifier = MarketDataNotifier(db, MarketFetcher(client));

    // 12 distinct A-share symbols → 3 chunks of 5/5/2 with a cap of 5.
    final requests = List.generate(
      12,
      (i) => (symbol: '60000${i.toString().padLeft(2, '0')}', marketType: 'a_share'),
    );

    final future = notifier.batchGetQuotes(requests);

    // Let the first chunk pile up before releasing the gate.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
      client.maxInFlight,
      lessThanOrEqualTo(5),
      reason: 'fan-out must be capped at the concurrency limit',
    );
    expect(
      client.maxInFlight,
      greaterThan(1),
      reason: 'requests should run concurrently, not serially',
    );

    client.openGate();
    await future;

    expect(client.totalRequests, 12);
    expect(notifier.state.quotes.length, 12);
  });

  test('batchGetQuotes preserves per-symbol mapping', () async {
    final client = _ConcurrencyTrackingClient()..openGate();
    final notifier = MarketDataNotifier(db, MarketFetcher(client));

    final requests = [
      (symbol: '600519', marketType: 'a_share'),
      (symbol: '000001', marketType: 'a_share'),
    ];
    await notifier.batchGetQuotes(requests);

    final q1 = notifier.state.quotes[MarketDataState.quoteKey('600519', 'a_share')];
    final q2 = notifier.state.quotes[MarketDataState.quoteKey('000001', 'a_share')];
    expect(q1, isNotNull);
    expect(q2, isNotNull);
    expect(q1!.symbol, '600519');
    expect(q2!.symbol, '000001');
  });

  test('batchGetQuotes falls back to local DB on per-symbol fetch failure',
      () async {
    // Seed a cached quote, then use a client that 500s on every request.
    await db.upsertMarketQuote(
      MarketQuotesCompanion.insert(
        symbol: '600519',
        marketType: 'a_share',
        name: const Value('贵州茅台'),
        currentPrice: const Value(170000),
        changeAmount: const Value(100),
        changePercent: const Value(0.06),
        updatedAt: Value(DateTime(2024, 1, 1)),
      ),
    );

    final failing = _AlwaysFailClient();
    final notifier = MarketDataNotifier(db, MarketFetcher(failing));

    await notifier.batchGetQuotes([(symbol: '600519', marketType: 'a_share')]);

    final q = notifier.state.quotes[MarketDataState.quoteKey('600519', 'a_share')];
    expect(q, isNotNull);
    expect(q!.currentPrice, 170000, reason: 'should come from the local cache');
  });
}

/// Returns HTTP 500 for every request (drives the DB-fallback path).
class _AlwaysFailClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(const Stream.empty(), 500, request: request);
  }
}
