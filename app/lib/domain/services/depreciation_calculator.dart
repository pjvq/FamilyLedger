/// Pure, side-effect-free monthly depreciation calculator.
///
/// Ports the server-side algorithm (`server/internal/asset/service.go`,
/// `applyMonthlyDepreciation` + `calcStraightLineMonthly` /
/// `calcDoubleDecliningMonthly`) to the client so depreciation can run
/// fully offline.
///
/// The server runs one depreciation step per asset on the 1st of every
/// month: it deducts a fixed monthly amount from `current_value`, clamps at
/// the salvage value, and records a `depreciation` valuation. This service
/// reproduces that behaviour while being idempotent — given the set of
/// months already depreciated, it only computes the missing month(s).
///
/// No Drift / network / state knowledge: the provider wires it to the DB and
/// the launch trigger.
class DepreciationCalculator {
  const DepreciationCalculator();

  /// Compute the depreciation steps that are still missing for an asset.
  ///
  /// [currentValue] is the asset's last known book value (cents).
  /// [purchaseDate] is the original purchase date.
  /// [method] is `straight_line` or `double_declining` (anything else → no-op).
  /// [alreadyDepreciatedMonths] is the set of months (as [DateTime] anchored to
  ///   the 1st, year+month significant) that already have a depreciation
  ///   valuation — used as the idempotency guard.
  /// [now] is the reference "current" time (injected for testability).
  ///
  /// Returns the ordered list of [DepreciationStep]s to persist, one per
  /// missing month, each carrying the resulting book value. Returns an empty
  /// list when there is nothing to do (method none/unknown, value already at
  /// salvage, no month boundary crossed, or all months already processed).
  List<DepreciationStep> computeMissingSteps({
    required int purchasePrice,
    required int currentValue,
    required DateTime purchaseDate,
    required String method,
    required int usefulLifeYears,
    required double salvageRate,
    required Set<DateTime> alreadyDepreciatedMonths,
    required DateTime now,
  }) {
    if (method != 'straight_line' && method != 'double_declining') {
      return const [];
    }
    if (usefulLifeYears <= 0) return const [];

    final salvageValue = (purchasePrice * salvageRate).round();

    // The first month a depreciation step can apply is the month *after* the
    // purchase month (the server runs on the 1st, so the purchase month
    // itself is never depreciated). Catch up every month boundary from there
    // up to and including the current month.
    final firstMonth = _monthKey(
      DateTime(purchaseDate.year, purchaseDate.month + 1, 1),
    );
    final currentMonth = _monthKey(DateTime(now.year, now.month, 1));

    final normalizedDone = alreadyDepreciatedMonths.map(_monthKey).toSet();

    final steps = <DepreciationStep>[];
    var value = currentValue;

    for (
      var m = firstMonth;
      !m.isAfter(currentMonth);
      m = _monthKey(DateTime(m.year, m.month + 1, 1))
    ) {
      if (normalizedDone.contains(m)) continue;
      if (value <= salvageValue) {
        // Already at/below salvage — record nothing further. Mirrors the
        // server short-circuit in applyMonthlyDepreciation.
        break;
      }

      final monthsElapsed = _monthsBetween(purchaseDate, m);
      final monthlyDep = _monthlyDepreciation(
        method: method,
        purchasePrice: purchasePrice,
        currentValue: value,
        salvageValue: salvageValue,
        usefulLifeYears: usefulLifeYears,
        monthsElapsed: monthsElapsed,
      );

      var newValue = value - monthlyDep;
      if (newValue < salvageValue) newValue = salvageValue;
      if (newValue == value) {
        // No movement (e.g. monthlyDep <= 0) — stop to avoid emitting no-op
        // rows on every launch.
        break;
      }

      steps.add(DepreciationStep(month: m, value: newValue));
      value = newValue;
    }

    return steps;
  }

  /// Monthly depreciation amount (cents) for a single step.
  int _monthlyDepreciation({
    required String method,
    required int purchasePrice,
    required int currentValue,
    required int salvageValue,
    required int usefulLifeYears,
    required int monthsElapsed,
  }) {
    switch (method) {
      case 'straight_line':
        return _straightLineMonthly(
          purchasePrice,
          salvageValue,
          usefulLifeYears,
        );
      case 'double_declining':
        return _doubleDecliningMonthly(
          currentValue,
          salvageValue,
          usefulLifeYears,
          monthsElapsed,
        );
      default:
        return 0;
    }
  }

  /// 直线法：年折旧额 = (购入价 - 残值) / 使用年限，月折旧额 = 年折旧额 / 12。
  int _straightLineMonthly(
    int purchasePrice,
    int salvageValue,
    int usefulLifeYears,
  ) {
    final annualDep = (purchasePrice - salvageValue) / usefulLifeYears;
    final monthlyDep = annualDep / 12.0;
    return monthlyDep.round();
  }

  /// 双倍余额递减法：
  /// 年折旧率 = 2 / 使用年限；年折旧额 = 期初净值 × 年折旧率；月折旧额 = 年折旧额 / 12。
  /// 最后两年(24 个月)改为直线法：(期初净值 - 残值) / 24。
  int _doubleDecliningMonthly(
    int currentValue,
    int salvageValue,
    int usefulLifeYears,
    int monthsElapsed,
  ) {
    final totalMonths = usefulLifeYears * 12;
    final remainingMonths = totalMonths - monthsElapsed;

    if (remainingMonths <= 24) {
      if (remainingMonths <= 0) return 0;
      final monthlyDep = (currentValue - salvageValue) / 24.0;
      if (monthlyDep < 0) return 0;
      return monthlyDep.round();
    }

    final annualRate = 2.0 / usefulLifeYears;
    final annualDep = currentValue * annualRate;
    final monthlyDep = annualDep / 12.0;
    return monthlyDep.round();
  }

  /// Complete months between two dates (matches server `monthsBetween`).
  int _monthsBetween(DateTime from, DateTime to) {
    final years = to.year - from.year;
    final months = to.month - from.month;
    return years * 12 + months;
  }

  /// Normalise a date to the first day of its month (local time). Used as the
  /// idempotency key for a depreciation period.
  static DateTime _monthKey(DateTime d) => DateTime(d.year, d.month, 1);

  /// Public helper so the provider can derive the same month key from a stored
  /// valuation date.
  static DateTime monthKey(DateTime d) => _monthKey(d);
}

/// One month's depreciation result: the period [month] (anchored to the 1st)
/// and the resulting book [value] in cents.
class DepreciationStep {
  final DateTime month;
  final int value;

  const DepreciationStep({required this.month, required this.value});

  @override
  String toString() => 'DepreciationStep(month: $month, value: $value)';
}
