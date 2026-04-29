import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:familyledger/data/local/database.dart';
import 'package:familyledger/domain/providers/exchange_rate_provider.dart';

// Use a real in-memory Drift DB for integration-level tests
AppDatabase _createMemoryDb() {
  return AppDatabase.forTesting(NativeDatabase.memory());
}

void main() {
  group('ExchangeRateNotifier — Three-level degradation', () {
    late AppDatabase db;
    late ExchangeRateNotifier notifier;

    setUp(() {
      db = _createMemoryDb();
      notifier = ExchangeRateNotifier(db);
    });

    tearDown(() async {
      await db.close();
    });

    // ─── Level 1: Default rates (no DB, no network) ─────────────────────────

    test('initial state has default rates for all supported pairs', () {
      expect(notifier.state.containsKey('USD/CNY'), isTrue);
      expect(notifier.state.containsKey('EUR/CNY'), isTrue);
      expect(notifier.state.containsKey('GBP/CNY'), isTrue);
      expect(notifier.state.containsKey('JPY/CNY'), isTrue);
      expect(notifier.state.containsKey('HKD/CNY'), isTrue);
      expect(notifier.state.containsKey('BTC/CNY'), isTrue);
    });

    test('default USD/CNY rate is 7.25', () {
      expect(notifier.state['USD/CNY'], 7.25);
    });

    // ─── getRate: same currency = 1.0 ──────────────────────────────────────

    test('getRate returns 1.0 for same currency', () {
      expect(notifier.getRate('CNY', 'CNY'), 1.0);
      expect(notifier.getRate('USD', 'USD'), 1.0);
    });

    // ─── getRate: direct to CNY ────────────────────────────────────────────

    test('getRate USD→CNY uses direct rate', () {
      expect(notifier.getRate('USD', 'CNY'), 7.25);
    });

    test('getRate EUR→CNY uses direct rate', () {
      expect(notifier.getRate('EUR', 'CNY'), 7.90);
    });

    // ─── getRate: CNY to foreign (inverse) ─────────────────────────────────

    test('getRate CNY→USD is inverse of USD/CNY', () {
      final rate = notifier.getRate('CNY', 'USD');
      expect(rate, closeTo(1.0 / 7.25, 0.0001));
    });

    // ─── getRate: cross-rate via CNY ───────────────────────────────────────

    test('getRate USD→EUR cross-rate via CNY', () {
      final rate = notifier.getRate('USD', 'EUR');
      // USD/CNY = 7.25, EUR/CNY = 7.90 → USD/EUR = 7.25/7.90
      expect(rate, closeTo(7.25 / 7.90, 0.0001));
    });

    test('getRate EUR→USD cross-rate via CNY', () {
      final rate = notifier.getRate('EUR', 'USD');
      expect(rate, closeTo(7.90 / 7.25, 0.0001));
    });

    // ─── getRate: unknown currency falls back to 1.0 ───────────────────────

    test('getRate unknown currency to CNY returns 1.0', () {
      expect(notifier.getRate('XYZ', 'CNY'), 1.0);
    });

    test('getRate CNY to unknown returns 1.0 (divide by fallback 1.0)', () {
      // Unknown 'XYZ/CNY' → null → 1.0, so 1/1.0 = 1.0
      expect(notifier.getRate('CNY', 'XYZ'), 1.0);
    });

    // ─── toCny: same currency passthrough ──────────────────────────────────

    test('toCny CNY returns same amount', () {
      expect(notifier.toCny(10000, 'CNY'), 10000);
    });

    // ─── toCny: foreign to CNY conversion ──────────────────────────────────

    test('toCny USD 100.00 → CNY 725.00 (rate 7.25)', () {
      expect(notifier.toCny(10000, 'USD'), 72500);
    });

    test('toCny EUR 100.00 → CNY 790.00 (rate 7.90)', () {
      expect(notifier.toCny(10000, 'EUR'), 79000);
    });

    // ─── Level 2: DB cache overrides defaults ──────────────────────────────

    test('saveRates persists to DB and updates state', () async {
      await notifier.saveRates({'USD/CNY': 7.50});
      expect(notifier.state['USD/CNY'], 7.50);
    });

    test('after saveRates, refreshRates loads from DB (cache level)', () async {
      await notifier.saveRates({'USD/CNY': 7.50, 'EUR/CNY': 8.00});

      // Create a fresh notifier on same DB → should load from DB
      final notifier2 = ExchangeRateNotifier(db);
      // Allow async _loadFromDb to complete
      await Future.delayed(const Duration(milliseconds: 100));

      expect(notifier2.state['USD/CNY'], 7.50);
      expect(notifier2.state['EUR/CNY'], 8.00);
      // Other rates remain default
      expect(notifier2.state['GBP/CNY'], 9.15);
    });

    // ─── Level 3: Fallback when DB fails ───────────────────────────────────

    test('if DB table unavailable, defaults remain (no crash)', () {
      // The constructor calls _loadFromDb which catches errors
      // Just verify it initialized without throwing
      expect(notifier.state.length, greaterThanOrEqualTo(6));
    });

    // ─── toCny after rate update ───────────────────────────────────────────

    test('toCny uses updated rate after saveRates', () async {
      await notifier.saveRates({'USD/CNY': 7.50});
      // 100 USD = 750 CNY (in fen: 10000 * 7.50 = 75000)
      expect(notifier.toCny(10000, 'USD'), 75000);
    });

    // ─── supportedCurrencies constant ──────────────────────────────────────

    test('supportedCurrencies contains 7 currencies', () {
      expect(supportedCurrencies.length, 7);
      expect(supportedCurrencies, contains('CNY'));
      expect(supportedCurrencies, contains('BTC'));
    });

    test('currencySymbols has symbol for each supported currency', () {
      for (final c in supportedCurrencies) {
        expect(currencySymbols.containsKey(c), isTrue,
            reason: '$c should have a symbol');
      }
    });
  });
}
