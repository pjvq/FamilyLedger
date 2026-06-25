/// Unit tests for [DepreciationCalculator] — pure monthly depreciation math.
///
/// Mirrors the server-side algorithm in `server/internal/asset/service.go`
/// (straight-line + double-declining), and verifies idempotency (running
/// twice in one month is a no-op, catching up multiple missed months).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:familyledger/domain/services/depreciation_calculator.dart';

void main() {
  const calc = DepreciationCalculator();

  DateTime monthKey(int y, int m) => DateTime(y, m, 1);

  group('straight_line', () {
    test('one month elapsed: deducts (price-salvage)/years/12', () {
      // price ¥100,000 = 10,000,000 cents, 5y, 5% salvage.
      // salvage = 500,000; annual = (10,000,000-500,000)/5 = 1,900,000;
      // monthly = 158,333.33 -> rounds to 158333.
      final steps = calc.computeMissingSteps(
        purchasePrice: 10000000,
        currentValue: 10000000,
        purchaseDate: DateTime(2026, 1, 15),
        method: 'straight_line',
        usefulLifeYears: 5,
        salvageRate: 0.05,
        alreadyDepreciatedMonths: const {},
        now: DateTime(2026, 2, 10),
      );
      expect(steps.length, 1);
      expect(steps.first.month, monthKey(2026, 2));
      expect(steps.first.value, 10000000 - 158333);
    });

    test('purchase month is never depreciated', () {
      final steps = calc.computeMissingSteps(
        purchasePrice: 10000000,
        currentValue: 10000000,
        purchaseDate: DateTime(2026, 6, 1),
        method: 'straight_line',
        usefulLifeYears: 5,
        salvageRate: 0.05,
        alreadyDepreciatedMonths: const {},
        now: DateTime(2026, 6, 20),
      );
      expect(steps, isEmpty);
    });

    test('catch up multiple missed months', () {
      // Purchased Jan 2026, now May 2026 -> Feb, Mar, Apr, May = 4 steps.
      final steps = calc.computeMissingSteps(
        purchasePrice: 10000000,
        currentValue: 10000000,
        purchaseDate: DateTime(2026, 1, 10),
        method: 'straight_line',
        usefulLifeYears: 5,
        salvageRate: 0.05,
        alreadyDepreciatedMonths: const {},
        now: DateTime(2026, 5, 5),
      );
      expect(steps.length, 4);
      expect(steps.map((s) => s.month).toList(), [
        monthKey(2026, 2),
        monthKey(2026, 3),
        monthKey(2026, 4),
        monthKey(2026, 5),
      ]);
      // Each step deducts a constant 158333 for straight-line.
      expect(steps[0].value, 10000000 - 158333);
      expect(steps[1].value, 10000000 - 158333 * 2);
      expect(steps[3].value, 10000000 - 158333 * 4);
    });

    test('clamps at salvage value and stops', () {
      // Far in the future: value should clamp at salvage and emit no further.
      final steps = calc.computeMissingSteps(
        purchasePrice: 1000000,
        currentValue: 60000, // just above salvage 50,000
        purchaseDate: DateTime(2020, 1, 1),
        method: 'straight_line',
        usefulLifeYears: 5,
        salvageRate: 0.05,
        alreadyDepreciatedMonths: const {},
        now: DateTime(2026, 6, 1),
      );
      // monthly = (1,000,000-50,000)/5/12 = 15,833. 60,000 -> clamp 50,000.
      expect(steps.length, 1);
      expect(steps.first.value, 50000);
    });

    test('no steps when already at salvage', () {
      final steps = calc.computeMissingSteps(
        purchasePrice: 1000000,
        currentValue: 50000,
        purchaseDate: DateTime(2020, 1, 1),
        method: 'straight_line',
        usefulLifeYears: 5,
        salvageRate: 0.05,
        alreadyDepreciatedMonths: const {},
        now: DateTime(2026, 6, 1),
      );
      expect(steps, isEmpty);
    });
  });

  group('double_declining', () {
    test('first month uses currentValue * (2/years)/12', () {
      // ¥100,000, 5y, 5% salvage. rate=0.4, annual=10,000,000*0.4=4,000,000,
      // monthly = 333,333.33 -> 333333.
      final steps = calc.computeMissingSteps(
        purchasePrice: 10000000,
        currentValue: 10000000,
        purchaseDate: DateTime(2026, 1, 15),
        method: 'double_declining',
        usefulLifeYears: 5,
        salvageRate: 0.05,
        alreadyDepreciatedMonths: const {},
        now: DateTime(2026, 2, 10),
      );
      expect(steps.length, 1);
      expect(steps.first.value, 10000000 - 333333);
    });

    test('declines faster than straight-line over same period', () {
      final dd = calc.computeMissingSteps(
        purchasePrice: 10000000,
        currentValue: 10000000,
        purchaseDate: DateTime(2026, 1, 1),
        method: 'double_declining',
        usefulLifeYears: 5,
        salvageRate: 0.05,
        alreadyDepreciatedMonths: const {},
        now: DateTime(2026, 4, 1),
      );
      final sl = calc.computeMissingSteps(
        purchasePrice: 10000000,
        currentValue: 10000000,
        purchaseDate: DateTime(2026, 1, 1),
        method: 'straight_line',
        usefulLifeYears: 5,
        salvageRate: 0.05,
        alreadyDepreciatedMonths: const {},
        now: DateTime(2026, 4, 1),
      );
      expect(dd.last.value, lessThan(sl.last.value));
    });

    test('switches to straight-line in last 24 months', () {
      // 5y = 60 months. Purchased 40 months before "now" so remainingMonths
      // for the step month is <= 24 -> uses (currentValue-salvage)/24.
      final purchase = DateTime(2023, 1, 1);
      final now = DateTime(2026, 6, 1); // ~41 months later
      final steps = calc.computeMissingSteps(
        purchasePrice: 10000000,
        currentValue: 3000000,
        purchaseDate: purchase,
        method: 'double_declining',
        usefulLifeYears: 5,
        salvageRate: 0.05,
        alreadyDepreciatedMonths: _allMonthsExcept(purchase, now),
        now: now,
      );
      // Only the current month (June 2026) is missing.
      expect(steps.length, 1);
      // (3,000,000 - 500,000)/24 = 104,166.67 -> 104167.
      expect(steps.first.value, 3000000 - 104167);
    });
  });

  group('idempotency', () {
    test('running twice in one month is a no-op the second time', () {
      const params = {
        'purchasePrice': 10000000,
        'usefulLifeYears': 5,
      };
      final purchase = DateTime(2026, 1, 1);
      final now = DateTime(2026, 2, 15);

      final first = calc.computeMissingSteps(
        purchasePrice: params['purchasePrice'] as int,
        currentValue: 10000000,
        purchaseDate: purchase,
        method: 'straight_line',
        usefulLifeYears: params['usefulLifeYears'] as int,
        salvageRate: 0.05,
        alreadyDepreciatedMonths: const {},
        now: now,
      );
      expect(first.length, 1);

      // Simulate persistence: the Feb month is now recorded.
      final done = {first.first.month};
      final second = calc.computeMissingSteps(
        purchasePrice: params['purchasePrice'] as int,
        currentValue: first.first.value,
        purchaseDate: purchase,
        method: 'straight_line',
        usefulLifeYears: params['usefulLifeYears'] as int,
        salvageRate: 0.05,
        alreadyDepreciatedMonths: done,
        now: now,
      );
      expect(second, isEmpty);
    });

    test('partial catch-up: skips already-recorded months', () {
      final purchase = DateTime(2026, 1, 1);
      final now = DateTime(2026, 5, 5);
      // Feb and Mar already done; expect only Apr + May.
      final done = {monthKey(2026, 2), monthKey(2026, 3)};
      final steps = calc.computeMissingSteps(
        purchasePrice: 10000000,
        currentValue: 10000000 - 158333 * 2, // value after Feb+Mar
        purchaseDate: purchase,
        method: 'straight_line',
        usefulLifeYears: 5,
        salvageRate: 0.05,
        alreadyDepreciatedMonths: done,
        now: now,
      );
      expect(steps.map((s) => s.month).toList(), [
        monthKey(2026, 4),
        monthKey(2026, 5),
      ]);
    });

    test('valuation date in mid-month is normalised to month key', () {
      final purchase = DateTime(2026, 1, 1);
      final now = DateTime(2026, 2, 28);
      // Recorded with a mid-month date — must still count as Feb done.
      final done = {DepreciationCalculator.monthKey(DateTime(2026, 2, 14))};
      final steps = calc.computeMissingSteps(
        purchasePrice: 10000000,
        currentValue: 9841667,
        purchaseDate: purchase,
        method: 'straight_line',
        usefulLifeYears: 5,
        salvageRate: 0.05,
        alreadyDepreciatedMonths: done,
        now: now,
      );
      expect(steps, isEmpty);
    });
  });

  group('edge cases', () {
    test('method none / unknown produces no steps', () {
      for (final method in ['none', 'unknown', '']) {
        final steps = calc.computeMissingSteps(
          purchasePrice: 10000000,
          currentValue: 10000000,
          purchaseDate: DateTime(2026, 1, 1),
          method: method,
          usefulLifeYears: 5,
          salvageRate: 0.05,
          alreadyDepreciatedMonths: const {},
          now: DateTime(2026, 6, 1),
        );
        expect(steps, isEmpty, reason: 'method=$method');
      }
    });

    test('zero/negative useful life produces no steps', () {
      final steps = calc.computeMissingSteps(
        purchasePrice: 10000000,
        currentValue: 10000000,
        purchaseDate: DateTime(2026, 1, 1),
        method: 'straight_line',
        usefulLifeYears: 0,
        salvageRate: 0.05,
        alreadyDepreciatedMonths: const {},
        now: DateTime(2026, 6, 1),
      );
      expect(steps, isEmpty);
    });

    test('crossing a year boundary catches up correctly', () {
      // Purchased Nov 2025, now Feb 2026 -> Dec 2025, Jan 2026, Feb 2026.
      final steps = calc.computeMissingSteps(
        purchasePrice: 10000000,
        currentValue: 10000000,
        purchaseDate: DateTime(2025, 11, 10),
        method: 'straight_line',
        usefulLifeYears: 5,
        salvageRate: 0.05,
        alreadyDepreciatedMonths: const {},
        now: DateTime(2026, 2, 5),
      );
      expect(steps.map((s) => s.month).toList(), [
        monthKey(2025, 12),
        monthKey(2026, 1),
        monthKey(2026, 2),
      ]);
    });
  });
}

/// Helper: every depreciation month between purchase and now EXCEPT the
/// current month, so [computeMissingSteps] only has the current month to do.
Set<DateTime> _allMonthsExcept(DateTime purchase, DateTime now) {
  final done = <DateTime>{};
  var m = DateTime(purchase.year, purchase.month + 1, 1);
  final current = DateTime(now.year, now.month, 1);
  while (m.isBefore(current)) {
    done.add(m);
    m = DateTime(m.year, m.month + 1, 1);
  }
  return done;
}
