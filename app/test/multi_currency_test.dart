import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:familyledger/data/local/database.dart';
import 'package:familyledger/domain/providers/exchange_rate_provider.dart';

void main() {
  group('ExchangeRateNotifier — 多币种计算精度', () {
    late AppDatabase db;
    late ExchangeRateNotifier notifier;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      notifier = ExchangeRateNotifier(db);
      // Wait for async _loadFromDb to complete
      await Future.delayed(const Duration(milliseconds: 200));
    });

    tearDown(() async {
      await Future.delayed(const Duration(milliseconds: 100));
      notifier.dispose();
      await db.close();
    });

    group('美元 → 人民币转换精度', () {
      test('100 美元分 → 人民币分（不丢分）', () {
        // 100 美分 = 1 USD, rate 7.25 → 725 分
        final result = notifier.toCny(100, 'USD');
        expect(result, 725);
      });

      test('1 美分 → 人民币分精度', () {
        // 1 美分 * 7.25 = 7.25, round → 7 分
        final result = notifier.toCny(1, 'USD');
        expect(result, 7); // 0.01 USD = 0.0725 CNY → 7 分
      });

      test('99 美分 → 人民币分精度（验证 round 而非 truncate）', () {
        // 99 * 7.25 = 717.75 → round → 718
        final result = notifier.toCny(99, 'USD');
        expect(result, 718);
      });

      test('CNY to CNY returns same value', () {
        final result = notifier.toCny(12345, 'CNY');
        expect(result, 12345);
      });
    });

    group('日元 → 人民币（日元无小数位）', () {
      test('100 日元 → 人民币分', () {
        // JPY 没有小数位，100 日元 = 100 fen in JPY
        // rate: 0.048, 100 * 0.048 = 4.8 → round → 5
        final result = notifier.toCny(100, 'JPY');
        expect(result, 5);
      });

      test('10000 日元 → 人民币分', () {
        // 10000 * 0.048 = 480
        final result = notifier.toCny(10000, 'JPY');
        expect(result, 480);
      });

      test('1 日元 → 人民币分（不丢失）', () {
        // 1 * 0.048 = 0.048 → round → 0
        // This is expected: 1 日元 ≈ 0 分 (less than half a fen)
        final result = notifier.toCny(1, 'JPY');
        expect(result, 0);
      });

      test('11 日元 → 人民币分（验证 round）', () {
        // 11 * 0.048 = 0.528 → round → 1
        final result = notifier.toCny(11, 'JPY');
        expect(result, 1);
      });
    });

    group('汇率 0 时不除零崩溃', () {
      test('getRate with zero rate in reverse does not crash', () async {
        // Manually set a zero rate
        await notifier.saveRates({'TEST/CNY': 0.0});

        // Forward: from TEST to CNY, rate is 0
        final rate = notifier.getRate('TEST', 'CNY');
        expect(rate, 0.0);

        // toCny with rate 0 → result is 0 (not crash)
        final result = notifier.toCny(1000, 'TEST');
        expect(result, 0); // 1000 * 0.0 = 0
      });

      test('getRate from CNY to currency with zero rate → returns 1.0 fallback', () async {
        await notifier.saveRates({'ZERO/CNY': 0.0});

        // CNY → ZERO: 1/rate, but rate=0 → guard condition returns 1.0
        final rate = notifier.getRate('CNY', 'ZERO');
        // The code checks `if (toCny > 0)` before dividing
        // When toCny = 0, it falls through to return 1.0
        expect(rate, 1.0);
      });

      test('cross-rate with zero denominator → returns 1.0 fallback', () async {
        await notifier.saveRates({'AAA/CNY': 5.0, 'BBB/CNY': 0.0});
        // AAA → BBB cross-rate: fromCny/toCny = 5.0/0.0
        // Code checks `if (toCny > 0)` → false → returns 1.0
        final rate = notifier.getRate('AAA', 'BBB');
        expect(rate, 1.0);
      });
    });

    group('汇率缺失时的回退行为', () {
      test('unknown currency to CNY → rate defaults to 1.0', () {
        final rate = notifier.getRate('UNKNOWN', 'CNY');
        // state['UNKNOWN/CNY'] is null → returns 1.0 (the ?? 1.0 fallback)
        expect(rate, 1.0);
      });

      test('toCny for unknown currency treats as 1:1', () {
        final result = notifier.toCny(5000, 'UNKNOWN');
        // rate = 1.0, so 5000 * 1.0 = 5000
        expect(result, 5000);
      });

      test('cross-rate with one unknown currency defaults gracefully', () {
        // USD → UNKNOWN: fromCny = 7.25, toCny = 1.0 → 7.25/1.0 = 7.25
        final rate = notifier.getRate('USD', 'UNKNOWN');
        expect(rate, 7.25);
      });
    });

    group('大金额(1亿)转换不溢出', () {
      test('1亿人民币分 (100万元) USD → CNY 不溢出', () {
        // 100,000,000 美分 = 1,000,000 USD
        // * 7.25 = 725,000,000
        final result = notifier.toCny(100000000, 'USD');
        expect(result, 725000000);
      });

      test('10亿日元 → 人民币分不溢出', () {
        // 1,000,000,000 * 0.048 = 48,000,000
        final result = notifier.toCny(1000000000, 'JPY');
        expect(result, 48000000);
      });

      test('BTC 大金额转换', () {
        // 100 BTC satoshi-like units * 480000 = 48,000,000
        final result = notifier.toCny(100, 'BTC');
        expect(result, 48000000);
      });
    });

    group('小金额(0.01)转换不丢失', () {
      test('1分 USD → CNY', () {
        // 1 * 7.25 = 7.25 → round → 7
        final result = notifier.toCny(1, 'USD');
        expect(result, 7);
      });

      test('1分 EUR → CNY', () {
        // 1 * 7.90 = 7.9 → round → 8
        final result = notifier.toCny(1, 'EUR');
        expect(result, 8);
      });

      test('2分 GBP → CNY', () {
        // 2 * 9.15 = 18.3 → round → 18
        final result = notifier.toCny(2, 'GBP');
        expect(result, 18);
      });

      test('getRate same currency returns exactly 1.0', () {
        expect(notifier.getRate('USD', 'USD'), 1.0);
        expect(notifier.getRate('CNY', 'CNY'), 1.0);
        expect(notifier.getRate('JPY', 'JPY'), 1.0);
      });
    });

    group('saveRates and DB persistence', () {
      test('saved rates override defaults', () async {
        await notifier.saveRates({'USD/CNY': 7.30});
        final rate = notifier.getRate('USD', 'CNY');
        expect(rate, 7.30);
      });

      test('saved rates are reflected in toCny', () async {
        await notifier.saveRates({'USD/CNY': 8.00});
        final result = notifier.toCny(100, 'USD');
        expect(result, 800);
      });
    });
  });
}
