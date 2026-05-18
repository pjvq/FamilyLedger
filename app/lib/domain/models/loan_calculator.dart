import 'dart:math' as math;
import 'loan_models.dart';

// ── Loan Calculator (local, offline-capable) ──

class LoanCalculator {
  LoanCalculator._();

  /// Validate common inputs. Throws [ArgumentError] on invalid data.
  static void _validateInputs({
    required int principal,
    required double annualRate,
    required int totalMonths,
    required int paymentDay,
  }) {
    if (principal <= 0) {
      throw ArgumentError.value(principal, 'principal', 'must be > 0');
    }
    if (totalMonths <= 0) {
      throw ArgumentError.value(totalMonths, 'totalMonths', 'must be > 0');
    }
    if (annualRate < 0) {
      throw ArgumentError.value(annualRate, 'annualRate', 'must be >= 0');
    }
    if (paymentDay < 1 || paymentDay > 31) {
      throw ArgumentError.value(paymentDay, 'paymentDay', 'must be 1-31');
    }
  }

  /// 等额本息还款计划
  static List<LoanScheduleDisplayItem> equalInstallment({
    required int principal,       // 分
    required double annualRate,   // 如 4.2
    required int totalMonths,
    required DateTime startDate,
    required int paymentDay,
    int paidMonths = 0,
  }) {
    final monthlyRate = annualRate / 100 / 12;
    final items = <LoanScheduleDisplayItem>[];

    if (monthlyRate == 0) {
      // 0利率
      final monthlyPayment = (principal / totalMonths).round();
      var remaining = principal;
      for (var i = 1; i <= totalMonths; i++) {
        final principalPart =
            i == totalMonths ? remaining : math.min(monthlyPayment, remaining);
        remaining -= principalPart;
        if (remaining < 0) remaining = 0;
        items.add(LoanScheduleDisplayItem(
          monthNumber: i,
          payment: principalPart,
          principalPart: principalPart,
          interestPart: 0,
          remainingPrincipal: remaining,
          dueDate: calcDueDate(startDate, i, paymentDay),
          isPaid: i <= paidMonths,
        ));
      }
      return items;
    }

    // 标准等额本息: M = P * r * (1+r)^n / ((1+r)^n - 1)
    final pow = math.pow(1 + monthlyRate, totalMonths);
    final monthlyPayment =
        (principal * monthlyRate * pow / (pow - 1)).round();

    var remaining = principal;
    for (var i = 1; i <= totalMonths; i++) {
      final interestPart = (remaining * monthlyRate).round();
      final principalPart = i == totalMonths
          ? remaining
          : monthlyPayment - interestPart;
      remaining -= principalPart;
      if (remaining < 0) remaining = 0;

      items.add(LoanScheduleDisplayItem(
        monthNumber: i,
        payment: i == totalMonths ? principalPart + interestPart : monthlyPayment,
        principalPart: principalPart,
        interestPart: interestPart,
        remainingPrincipal: remaining,
        dueDate: calcDueDate(startDate, i, paymentDay),
        isPaid: i <= paidMonths,
      ));
    }
    return items;
  }

  /// 等额本金还款计划
  static List<LoanScheduleDisplayItem> equalPrincipal({
    required int principal,       // 分
    required double annualRate,   // 如 4.2
    required int totalMonths,
    required DateTime startDate,
    required int paymentDay,
    int paidMonths = 0,
  }) {
    final monthlyRate = annualRate / 100 / 12;
    final monthlyPrincipal = (principal / totalMonths).round();
    final items = <LoanScheduleDisplayItem>[];

    var remaining = principal;
    for (var i = 1; i <= totalMonths; i++) {
      final interestPart = (remaining * monthlyRate).round();
      final principalPart =
          i == totalMonths ? remaining : monthlyPrincipal;
      remaining -= principalPart;
      if (remaining < 0) remaining = 0;

      items.add(LoanScheduleDisplayItem(
        monthNumber: i,
        payment: principalPart + interestPart,
        principalPart: principalPart,
        interestPart: interestPart,
        remainingPrincipal: remaining,
        dueDate: calcDueDate(startDate, i, paymentDay),
        isPaid: i <= paidMonths,
      ));
    }
    return items;
  }

  /// 先息后本还款计划
  static List<LoanScheduleDisplayItem> interestOnly({
    required int principal,
    required double annualRate,
    required int totalMonths,
    required DateTime startDate,
    required int paymentDay,
    int paidMonths = 0,
    String calcMethod = 'monthly',
  }) {
    final items = <LoanScheduleDisplayItem>[];

    if (calcMethod == 'daily_act_365' || calcMethod == 'daily_act_360') {
      final divisor = calcMethod == 'daily_act_365' ? 365.0 : 360.0;
      final dailyRate = annualRate / 100.0 / divisor;
      var periodStart = startDate;
      for (var i = 1; i <= totalMonths; i++) {
        final dueDate = calcDueDate(startDate, i, paymentDay);
        var days = dueDate.difference(periodStart).inDays;
        if (days <= 0) days = 30;
        final interest = (principal * dailyRate * days).round();
        final isLast = i == totalMonths;
        final principalPart = isLast ? principal : 0;
        items.add(LoanScheduleDisplayItem(
          monthNumber: i,
          payment: principalPart + interest,
          principalPart: principalPart,
          interestPart: interest,
          remainingPrincipal: isLast ? 0 : principal,
          dueDate: dueDate,
          isPaid: i <= paidMonths,
        ));
        periodStart = dueDate;
      }
    } else {
      final monthlyRate = annualRate / 100 / 12;
      final monthlyInterest = (principal * monthlyRate).round();
      for (var i = 1; i <= totalMonths; i++) {
        final isLast = i == totalMonths;
        final principalPart = isLast ? principal : 0;
        items.add(LoanScheduleDisplayItem(
          monthNumber: i,
          payment: principalPart + monthlyInterest,
          principalPart: principalPart,
          interestPart: monthlyInterest,
          remainingPrincipal: isLast ? 0 : principal,
          dueDate: calcDueDate(startDate, i, paymentDay),
          isPaid: i <= paidMonths,
        ));
      }
    }
    return items;
  }

  /// 一次性还本付息还款计划
  static List<LoanScheduleDisplayItem> bullet({
    required int principal,
    required double annualRate,
    required int totalMonths,
    required DateTime startDate,
    required int paymentDay,
    int paidMonths = 0,
    String calcMethod = 'monthly',
  }) {
    final items = <LoanScheduleDisplayItem>[];
    int totalInterest;

    if (calcMethod == 'daily_act_365' || calcMethod == 'daily_act_360') {
      final divisor = calcMethod == 'daily_act_365' ? 365.0 : 360.0;
      final dailyRate = annualRate / 100.0 / divisor;
      // 累计实际天数的利息
      var prevDate = startDate;
      totalInterest = 0;
      for (var i = 1; i <= totalMonths; i++) {
        final dueDate = calcDueDate(startDate, i, paymentDay);
        var days = dueDate.difference(prevDate).inDays;
        if (days <= 0) days = 30;
        totalInterest += (principal * dailyRate * days).round();
        prevDate = dueDate;
      }
    } else {
      final monthlyRate = annualRate / 100 / 12;
      totalInterest = (principal * monthlyRate * totalMonths).round();
    }

    for (var i = 1; i <= totalMonths; i++) {
      final isLast = i == totalMonths;
      items.add(LoanScheduleDisplayItem(
        monthNumber: i,
        payment: isLast ? principal + totalInterest : 0,
        principalPart: isLast ? principal : 0,
        interestPart: isLast ? totalInterest : 0,
        remainingPrincipal: isLast ? 0 : principal,
        dueDate: calcDueDate(startDate, i, paymentDay),
        isPaid: i <= paidMonths,
      ));
    }
    return items;
  }

  /// 等本等息还款计划
  static List<LoanScheduleDisplayItem> equalInterest({
    required int principal,
    required double annualRate,
    required int totalMonths,
    required DateTime startDate,
    required int paymentDay,
    int paidMonths = 0,
  }) {
    final monthlyRate = annualRate / 100 / 12;
    final monthlyPrincipal = (principal / totalMonths).round();
    final monthlyInterest = (principal * monthlyRate).round();
    final items = <LoanScheduleDisplayItem>[];

    var remaining = principal;
    for (var i = 1; i <= totalMonths; i++) {
      final principalPart = i == totalMonths ? remaining : monthlyPrincipal;
      remaining -= principalPart;
      if (remaining < 0) remaining = 0;

      items.add(LoanScheduleDisplayItem(
        monthNumber: i,
        payment: principalPart + monthlyInterest,
        principalPart: principalPart,
        interestPart: monthlyInterest,
        remainingPrincipal: remaining,
        dueDate: calcDueDate(startDate, i, paymentDay),
        isPaid: i <= paidMonths,
      ));
    }
    return items;
  }

  /// 计算还款计划
  static List<LoanScheduleDisplayItem> calculate({
    required int principal,
    required double annualRate,
    required int totalMonths,
    required String repaymentMethod,
    required DateTime startDate,
    required int paymentDay,
    int paidMonths = 0,
    String calcMethod = 'monthly',
  }) {
    _validateInputs(principal: principal, annualRate: annualRate, totalMonths: totalMonths, paymentDay: paymentDay);
    switch (repaymentMethod) {
      case 'equal_principal':
        return equalPrincipal(
          principal: principal,
          annualRate: annualRate,
          totalMonths: totalMonths,
          startDate: startDate,
          paymentDay: paymentDay,
          paidMonths: paidMonths,
        );
      case 'interest_only':
        return interestOnly(
          principal: principal,
          annualRate: annualRate,
          totalMonths: totalMonths,
          startDate: startDate,
          paymentDay: paymentDay,
          paidMonths: paidMonths,
          calcMethod: calcMethod,
        );
      case 'bullet':
        return bullet(
          principal: principal,
          annualRate: annualRate,
          totalMonths: totalMonths,
          startDate: startDate,
          paymentDay: paymentDay,
          paidMonths: paidMonths,
          calcMethod: calcMethod,
        );
      case 'equal_interest':
        return equalInterest(
          principal: principal,
          annualRate: annualRate,
          totalMonths: totalMonths,
          startDate: startDate,
          paymentDay: paymentDay,
          paidMonths: paidMonths,
        );
      default:
        return equalInstallment(
          principal: principal,
          annualRate: annualRate,
          totalMonths: totalMonths,
          startDate: startDate,
          paymentDay: paymentDay,
          paidMonths: paidMonths,
        );
    }
  }

  /// 计算贷款的有效年利率（考虑 LPR 浮动）
  static double effectiveRate({
    required String rateType,
    required double annualRate,
    required double lprBase,
    required double lprSpread,
  }) {
    if (rateType == 'lpr_floating' && lprBase > 0) {
      return lprBase + lprSpread;
    }
    return annualRate;
  }

  /// 提前还款模拟 — 缩短期限
  static PrepaymentSimulationResult simulateReduceMonths({
    required int remainingPrincipal,
    required double annualRate,
    required int remainingMonths,
    required int paidMonths,
    required int prepaymentAmount,
    required String repaymentMethod,
    required DateTime startDate,
    required int paymentDay,
    required int originalPrincipal,
    required int originalTotalMonths,
  }) {
    // 原方案总利息
    final originalSchedule = calculate(
      principal: originalPrincipal,
      annualRate: annualRate,
      totalMonths: originalTotalMonths,
      repaymentMethod: repaymentMethod,
      startDate: startDate,
      paymentDay: paymentDay,
    );
    final totalInterestBefore =
        originalSchedule.fold<int>(0, (s, i) => s + i.interestPart);

    // 提前还款后剩余本金
    final newRemaining = remainingPrincipal - prepaymentAmount;
    if (newRemaining <= 0) {
      return PrepaymentSimulationResult(
        prepaymentAmount: prepaymentAmount,
        totalInterestBefore: totalInterestBefore,
        totalInterestAfter: originalSchedule
            .where((i) => i.monthNumber <= paidMonths)
            .fold<int>(0, (s, i) => s + i.interestPart),
        interestSaved: totalInterestBefore -
            originalSchedule
                .where((i) => i.monthNumber <= paidMonths)
                .fold<int>(0, (s, i) => s + i.interestPart),
        monthsReduced: remainingMonths,
        newMonthlyPayment: 0,
        newSchedule: [],
      );
    }

    // 缩短期限: 月供不变，重新算期数
    final monthlyRate = annualRate / 100 / 12;
    int newMonths;
    int monthlyPayment;

    if (repaymentMethod == 'equal_principal') {
      monthlyPayment = (newRemaining / remainingMonths).round();
      var rem = newRemaining;
      newMonths = 0;
      while (rem > 0 && newMonths < remainingMonths) {
        newMonths++;
        final pPart = newMonths == remainingMonths ? rem : monthlyPayment;
        rem -= pPart;
        if (rem < 0) rem = 0;
      }
    } else {
      final origMonthlyPayment = originalSchedule
          .firstWhere((i) => i.monthNumber == paidMonths + 1,
              orElse: () => originalSchedule.last)
          .payment;
      monthlyPayment = origMonthlyPayment;

      if (monthlyRate == 0) {
        newMonths = (newRemaining / monthlyPayment).ceil();
      } else {
        final prm = newRemaining * monthlyRate / monthlyPayment;
        if (prm >= 1) {
          // 月供不足以覆盖利息，无法缩短期限
          return PrepaymentSimulationResult(
            prepaymentAmount: prepaymentAmount,
            totalInterestBefore: totalInterestBefore,
            totalInterestAfter: totalInterestBefore,
            interestSaved: 0,
            monthsReduced: 0,
            newMonthlyPayment: monthlyPayment,
            newSchedule: const [],
          );
        } else {
          newMonths = (-math.log(1 - prm) / math.log(1 + monthlyRate)).ceil();
        }
      }
    }

    final newSchedule = calculate(
      principal: newRemaining,
      annualRate: annualRate,
      totalMonths: newMonths,
      repaymentMethod: repaymentMethod,
      startDate: calcDueDate(startDate, paidMonths, paymentDay),
      paymentDay: paymentDay,
    );

    final totalInterestAfter =
        originalSchedule
            .where((i) => i.monthNumber <= paidMonths)
            .fold<int>(0, (s, i) => s + i.interestPart) +
        newSchedule.fold<int>(0, (s, i) => s + i.interestPart);

    return PrepaymentSimulationResult(
      prepaymentAmount: prepaymentAmount,
      totalInterestBefore: totalInterestBefore,
      totalInterestAfter: totalInterestAfter,
      interestSaved: totalInterestBefore - totalInterestAfter,
      monthsReduced: remainingMonths - newMonths,
      newMonthlyPayment: newSchedule.isNotEmpty ? newSchedule.first.payment : 0,
      newSchedule: newSchedule,
    );
  }

  /// 提前还款模拟 — 减少月供
  static PrepaymentSimulationResult simulateReducePayment({
    required int remainingPrincipal,
    required double annualRate,
    required int remainingMonths,
    required int paidMonths,
    required int prepaymentAmount,
    required String repaymentMethod,
    required DateTime startDate,
    required int paymentDay,
    required int originalPrincipal,
    required int originalTotalMonths,
  }) {
    final originalSchedule = calculate(
      principal: originalPrincipal,
      annualRate: annualRate,
      totalMonths: originalTotalMonths,
      repaymentMethod: repaymentMethod,
      startDate: startDate,
      paymentDay: paymentDay,
    );
    final totalInterestBefore =
        originalSchedule.fold<int>(0, (s, i) => s + i.interestPart);

    final newRemaining = remainingPrincipal - prepaymentAmount;
    if (newRemaining <= 0) {
      final paidInterest = originalSchedule
          .where((i) => i.monthNumber <= paidMonths)
          .fold<int>(0, (s, i) => s + i.interestPart);
      return PrepaymentSimulationResult(
        prepaymentAmount: prepaymentAmount,
        totalInterestBefore: totalInterestBefore,
        totalInterestAfter: paidInterest,
        interestSaved: totalInterestBefore - paidInterest,
        monthsReduced: remainingMonths,
        newMonthlyPayment: 0,
        newSchedule: [],
      );
    }

    // 减少月供: 期数不变，重新算月供
    final newSchedule = calculate(
      principal: newRemaining,
      annualRate: annualRate,
      totalMonths: remainingMonths,
      repaymentMethod: repaymentMethod,
      startDate: calcDueDate(startDate, paidMonths, paymentDay),
      paymentDay: paymentDay,
    );

    final totalInterestAfter =
        originalSchedule
            .where((i) => i.monthNumber <= paidMonths)
            .fold<int>(0, (s, i) => s + i.interestPart) +
        newSchedule.fold<int>(0, (s, i) => s + i.interestPart);

    return PrepaymentSimulationResult(
      prepaymentAmount: prepaymentAmount,
      totalInterestBefore: totalInterestBefore,
      totalInterestAfter: totalInterestAfter,
      interestSaved: totalInterestBefore - totalInterestAfter,
      monthsReduced: 0,
      newMonthlyPayment: newSchedule.isNotEmpty ? newSchedule.first.payment : 0,
      newSchedule: newSchedule,
    );
  }

  static DateTime calcDueDate(DateTime startDate, int monthOffset, int paymentDay) {
    assert(monthOffset >= 0, 'monthOffset must be non-negative');
    assert(paymentDay >= 1 && paymentDay <= 31, 'paymentDay must be 1-31');
    final totalMonths = startDate.month - 1 + monthOffset;
    final year = startDate.year + totalMonths ~/ 12;
    final month = totalMonths % 12 + 1;
    final maxDay = DateTime(year, month + 1, 0).day;
    final day = paymentDay > maxDay ? maxDay : paymentDay;
    return DateTime(year, month, day);
  }
}

