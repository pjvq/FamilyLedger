import 'dart:convert';

import 'package:drift/native.dart';
import 'package:familyledger/data/local/database.dart';
import 'package:familyledger/domain/providers/exchange_rate_provider.dart';
import 'package:familyledger/domain/services/market/exchange_rate_fetcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Sample open.er-api.com (base=CNY) payload: rates[X] = units of X per 1 CNY.
String _okBody() => jsonEncode({
      'result': 'success',
      'base_code': 'CNY',
      'rates': {
        'CNY': 1,
        'USD': 0.1379, // 1/0.1379 ≈ 7.2516 CNY per USD
        'EUR': 0.1266,
        'JPY': 21.5,
        'HKD': 1.075,
      },
    });

void main() {
  group('ExchangeRateFetcher', () {
    test('maps base-CNY rates to X/CNY (1/rate), only returned currencies',
        () async {
      final client = MockClient((req) async {
        expect(req.url.toString(), contains('open.er-api.com'));
        return http.Response(_okBody(), 200);
      });
      final fetcher = ExchangeRateFetcher(client);

      final out = await fetcher.fetchCnyRates(supportedCurrencies);

      expect(out['USD/CNY']!, closeTo(1 / 0.1379, 1e-6));
      expect(out['JPY/CNY']!, closeTo(1 / 21.5, 1e-6));
      // CNY is skipped; BTC isn't in the payload so it's omitted.
      expect(out.containsKey('CNY/CNY'), isFalse);
      expect(out.containsKey('BTC/CNY'), isFalse);
    });

    test('throws on non-200', () async {
      final fetcher = ExchangeRateFetcher(
        MockClient((_) async => http.Response('nope', 503)),
      );
      expect(
        () => fetcher.fetchCnyRates(supportedCurrencies),
        throwsA(isA<ExchangeRateFetchException>()),
      );
    });

    test('throws when result != success', () async {
      final fetcher = ExchangeRateFetcher(
        MockClient((_) async =>
            http.Response(jsonEncode({'result': 'error'}), 200)),
      );
      expect(
        () => fetcher.fetchCnyRates(supportedCurrencies),
        throwsA(isA<ExchangeRateFetchException>()),
      );
    });
  });

  group('ExchangeRateNotifier.refreshRates', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() async => db.close());

    test('fetches, persists to DB, and updates state', () async {
      final fetcher = ExchangeRateFetcher(
        MockClient((_) async => http.Response(_okBody(), 200)),
      );
      final notifier = ExchangeRateNotifier(db, fetcher: fetcher);

      await notifier.refreshRates();

      // State updated with the fetched USD/CNY (~7.25).
      expect(notifier.state['USD/CNY']!, closeTo(1 / 0.1379, 1e-6));
      // Persisted to the local cache.
      final rows = await db.select(db.exchangeRates).get();
      final usd = rows.firstWhere((r) => r.currencyPair == 'USD/CNY');
      expect(usd.rate, closeTo(1 / 0.1379, 1e-6));
      // getRate uses the refreshed value.
      expect(notifier.getRate('USD', 'CNY'), closeTo(1 / 0.1379, 1e-6));
    });

    test('keeps cached/default rates on network failure', () async {
      final fetcher = ExchangeRateFetcher(
        MockClient((_) async => http.Response('boom', 500)),
      );
      final notifier = ExchangeRateNotifier(db, fetcher: fetcher);

      await notifier.refreshRates();

      // Falls back to defaults — not cleared.
      expect(notifier.state['USD/CNY'], 7.25);
    });
  });
}
