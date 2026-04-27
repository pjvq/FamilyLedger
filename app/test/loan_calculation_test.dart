/// Loan calculation tests — validates LoanCalculator logic for:
/// - 等额本息 (equal installment)
/// - 等额本金 (equal principal)
/// - Prepayment simulation
/// - Boundary conditions
/// - Precision invariants
import 'package:flutter_test/flutter_test.dart';
import 'package:familyledger/domain/providers/loan_provider.dart';

void main() {
  group('LoanCalculator — 等额本息 (equal installment)', () {
    test('500,000 yuan at 4.1% for 30 years — monthly payment ≈ 2,413.66',
        () {
      // 50万 = 50000000分, 4.1%, 360 months
      final schedule = LoanCalculator.equalInstallment(
        principal: 50000000, // 50万元 = 50,000,000 分
        annualRate: 4.1,
        totalMonths: 360,
        startDate: DateTime(2024, 1, 1),
        paymentDay: 15,
      );

      expect(schedule.length, 360);

      // Monthly payment: M = P * r * (1+r)^n / ((1+r)^n - 1)
      // With P=50000000, r=4.1/100/12=0.003417, n=360
      // M ≈ 241599 分 (≈ 2415.99 yuan)
      // Allow ±200 分 tolerance due to rounding
      final monthlyPayment = schedule.first.payment;
      expect(monthlyPayment, closeTo(241599, 200));
    });

    test('precision: total principal + total interest = total payments', () {
      final schedule = LoanCalculator.equalInstallment(
        principal: 50000000,
        annualRate: 4.1,
        totalMonths: 360,
        startDate: DateTime(2024, 1, 1),
        paymentDay: 15,
      );

      final totalPayments = schedule.fold<int>(0, (s, i) => s + i.payment);
      final totalPrincipal =
          schedule.fold<int>(0, (s, i) => s + i.principalPart);
      final totalInterest =
          schedule.fold<int>(0, (s, i) => s + i.interestPart);

      // Total principal paid should equal original principal
      expect(totalPrincipal, 50000000);

      // Total payments = principal + interest (within 1 分 tolerance)
      expect((totalPayments - (totalPrincipal + totalInterest)).abs(),
          lessThanOrEqualTo(1));
    });

    test('remaining principal is 0 after last payment', () {
      final schedule = LoanCalculator.equalInstallment(
        principal: 50000000,
        annualRate: 4.1,
        totalMonths: 360,
        startDate: DateTime(2024, 1, 1),
        paymentDay: 15,
      );

      expect(schedule.last.remainingPrincipal, 0);
    });

    test('month numbers are sequential from 1 to totalMonths', () {
      final schedule = LoanCalculator.equalInstallment(
        principal: 10000000,
        annualRate: 3.5,
        totalMonths: 120,
        startDate: DateTime(2024, 1, 1),
        paymentDay: 1,
      );

      for (var i = 0; i < schedule.length; i++) {
        expect(schedule[i].monthNumber, i + 1);
      }
    });
  });

  group('LoanCalculator — 等额本金 (equal principal)', () {
    test('500,000 yuan at 4.1% for 30 years — first month ≈ 3,097.22', () {
      // 首月月供 = 本金/360 + 本金*月利率
      // = 50000000/360 + 50000000*(4.1/100/12)
      // = 138889 + 170833 = 309722 分 ≈ 3097.22 元
      final schedule = LoanCalculator.equalPrincipal(
        principal: 50000000,
        annualRate: 4.1,
        totalMonths: 360,
        startDate: DateTime(2024, 1, 1),
        paymentDay: 15,
      );

      expect(schedule.length, 360);

      final firstPayment = schedule.first.payment;
      // Allow ±1 yuan tolerance
      expect(firstPayment, closeTo(309722, 100));
    });

    test('monthly principal is roughly constant', () {
      final schedule = LoanCalculator.equalPrincipal(
        principal: 50000000,
        annualRate: 4.1,
        totalMonths: 360,
        startDate: DateTime(2024, 1, 1),
        paymentDay: 15,
      );

      // Expected monthly principal = 50000000 / 360 ≈ 138889
      final expectedPrincipal = (50000000 / 360).round();
      // Most months should match (last month may differ)
      for (var i = 0; i < schedule.length - 1; i++) {
        expect(schedule[i].principalPart, expectedPrincipal);
      }
    });

    test('payments decrease over time (interest part decreases)', () {
      final schedule = LoanCalculator.equalPrincipal(
        principal: 50000000,
        annualRate: 4.1,
        totalMonths: 360,
        startDate: DateTime(2024, 1, 1),
        paymentDay: 15,
      );

      for (var i = 1; i < schedule.length; i++) {
        expect(schedule[i].payment, lessThanOrEqualTo(schedule[i - 1].payment));
      }
    });

    test('precision: total principal paid = original principal', () {
      final schedule = LoanCalculator.equalPrincipal(
        principal: 50000000,
        annualRate: 4.1,
        totalMonths: 360,
        startDate: DateTime(2024, 1, 1),
        paymentDay: 15,
      );

      final totalPrincipal =
          schedule.fold<int>(0, (s, i) => s + i.principalPart);
      expect(totalPrincipal, 50000000);
    });

    test('remaining principal is 0 after last payment', () {
      final schedule = LoanCalculator.equalPrincipal(
        principal: 50000000,
        annualRate: 4.1,
        totalMonths: 360,
        startDate: DateTime(2024, 1, 1),
        paymentDay: 15,
      );

      expect(schedule.last.remainingPrincipal, 0);
    });
  });

  group('LoanCalculator — boundary conditions', () {
    test('0% interest rate — no interest, equal payments', () {
      final schedule = LoanCalculator.equalInstallment(
        principal: 12000000, // 12万
        annualRate: 0.0,
        totalMonths: 12,
        startDate: DateTime(2024, 1, 1),
        paymentDay: 1,
      );

      expect(schedule.length, 12);

      // Each payment is principal / months = 1000000 分
      for (final item in schedule) {
        expect(item.interestPart, 0);
        expect(item.payment, 1000000);
      }

      final totalPrincipal =
          schedule.fold<int>(0, (s, i) => s + i.principalPart);
      expect(totalPrincipal, 12000000);
    });

    test('1 month term', () {
      final schedule = LoanCalculator.equalInstallment(
        principal: 10000000, // 10万
        annualRate: 5.0,
        totalMonths: 1,
        startDate: DateTime(2024, 6, 1),
        paymentDay: 1,
      );

      expect(schedule.length, 1);
      // All principal paid in first month + 1 month interest
      expect(schedule.first.principalPart, 10000000);
      // Interest = 10000000 * 5.0/100/12 ≈ 41667
      expect(schedule.first.interestPart, closeTo(41667, 10));
      expect(schedule.first.remainingPrincipal, 0);
    });

    test('equal principal with 0% interest', () {
      final schedule = LoanCalculator.equalPrincipal(
        principal: 6000000, // 6万
        annualRate: 0.0,
        totalMonths: 6,
        startDate: DateTime(2024, 1, 1),
        paymentDay: 15,
      );

      expect(schedule.length, 6);
      for (final item in schedule) {
        expect(item.interestPart, 0);
        expect(item.principalPart, 1000000);
      }
    });
  });

  group('LoanCalculator — precision invariant', () {
    // Table-driven test: for various inputs, verify total interest + total
    // principal = total payments (within 1 分 tolerance)
    final testCases = [
      _LoanTestCase(
          principal: 50000000, rate: 4.1, months: 360, method: 'equal_installment'),
      _LoanTestCase(
          principal: 50000000, rate: 4.1, months: 360, method: 'equal_principal'),
      _LoanTestCase(
          principal: 30000000, rate: 3.85, months: 240, method: 'equal_installment'),
      _LoanTestCase(
          principal: 10000000, rate: 6.0, months: 60, method: 'equal_principal'),
      _LoanTestCase(
          principal: 100000, rate: 12.0, months: 12, method: 'equal_installment'),
    ];

    for (final tc in testCases) {
      test(
          '${tc.method}: ${tc.principal / 100}元 @ ${tc.rate}% / ${tc.months}m',
          () {
        final schedule = LoanCalculator.calculate(
          principal: tc.principal,
          annualRate: tc.rate,
          totalMonths: tc.months,
          repaymentMethod: tc.method,
          startDate: DateTime(2024, 1, 1),
          paymentDay: 15,
        );

        final totalPayments = schedule.fold<int>(0, (s, i) => s + i.payment);
        final totalPrincipal =
            schedule.fold<int>(0, (s, i) => s + i.principalPart);
        final totalInterest =
            schedule.fold<int>(0, (s, i) => s + i.interestPart);

        // Principal must equal original
        expect(totalPrincipal, tc.principal);
        // payments = principal + interest (within 1 分)
        expect((totalPayments - (totalPrincipal + totalInterest)).abs(),
            lessThanOrEqualTo(1));
        // Remaining after last payment = 0
        expect(schedule.last.remainingPrincipal, 0);
      });
    }
  });

  group('LoanCalculator — prepayment simulation', () {
    test('reduce months: saves interest and reduces months', () {
      final result = LoanCalculator.simulateReduceMonths(
        remainingPrincipal: 45000000, // 45万
        annualRate: 4.1,
        remainingMonths: 300,
        paidMonths: 60,
        prepaymentAmount: 10000000, // 10万
        repaymentMethod: 'equal_installment',
        startDate: DateTime(2024, 1, 1),
        paymentDay: 15,
        originalPrincipal: 50000000,
        originalTotalMonths: 360,
      );

      expect(result.prepaymentAmount, 10000000);
      expect(result.interestSaved, greaterThan(0));
      expect(result.monthsReduced, greaterThan(0));
      expect(result.totalInterestAfter, lessThan(result.totalInterestBefore));
    });

    test('reduce payment: keeps months, reduces monthly amount', () {
      final result = LoanCalculator.simulateReducePayment(
        remainingPrincipal: 45000000,
        annualRate: 4.1,
        remainingMonths: 300,
        paidMonths: 60,
        prepaymentAmount: 10000000,
        repaymentMethod: 'equal_installment',
        startDate: DateTime(2024, 1, 1),
        paymentDay: 15,
        originalPrincipal: 50000000,
        originalTotalMonths: 360,
      );

      expect(result.prepaymentAmount, 10000000);
      expect(result.interestSaved, greaterThan(0));
      expect(result.monthsReduced, 0); // months not reduced
      expect(result.newMonthlyPayment, greaterThan(0));
      expect(result.totalInterestAfter, lessThan(result.totalInterestBefore));
    });

    test('prepay full remaining principal — loan closes', () {
      final result = LoanCalculator.simulateReduceMonths(
        remainingPrincipal: 10000000,
        annualRate: 4.1,
        remainingMonths: 100,
        paidMonths: 260,
        prepaymentAmount: 10000000,
        repaymentMethod: 'equal_installment',
        startDate: DateTime(2020, 1, 1),
        paymentDay: 15,
        originalPrincipal: 50000000,
        originalTotalMonths: 360,
      );

      expect(result.monthsReduced, 100);
      expect(result.newMonthlyPayment, 0);
      expect(result.newSchedule, isEmpty);
    });
  });

  group('LoanCalculator — calculate dispatcher', () {
    test('dispatches to equalInstallment by default', () {
      final schedule = LoanCalculator.calculate(
        principal: 10000000,
        annualRate: 5.0,
        totalMonths: 12,
        repaymentMethod: 'equal_installment',
        startDate: DateTime(2024, 1, 1),
        paymentDay: 1,
      );

      // All payments should be roughly equal (equal installment)
      final payments = schedule.map((s) => s.payment).toSet();
      // At most 2 distinct values (last month may differ slightly)
      expect(payments.length, lessThanOrEqualTo(2));
    });

    test('dispatches to equalPrincipal', () {
      final schedule = LoanCalculator.calculate(
        principal: 10000000,
        annualRate: 5.0,
        totalMonths: 12,
        repaymentMethod: 'equal_principal',
        startDate: DateTime(2024, 1, 1),
        paymentDay: 1,
      );

      // Payments should decrease (equal principal characteristic)
      for (var i = 1; i < schedule.length; i++) {
        expect(schedule[i].payment, lessThanOrEqualTo(schedule[i - 1].payment));
      }
    });
  });

  group('LoanCalculator — due date calculation', () {
    test('correctly handles month overflow', () {
      final schedule = LoanCalculator.equalInstallment(
        principal: 1200000,
        annualRate: 5.0,
        totalMonths: 14,
        startDate: DateTime(2024, 11, 1), // November — will overflow year
        paymentDay: 28,
      );

      // 14th month from Nov 2024 = Jan 2026
      expect(schedule.last.dueDate.year, 2026);
      expect(schedule.last.dueDate.month, 1);
    });

    test('payment day capped at max days in month (Feb)', () {
      final schedule = LoanCalculator.equalInstallment(
        principal: 600000,
        annualRate: 5.0,
        totalMonths: 3,
        startDate: DateTime(2024, 1, 1), // start Jan
        paymentDay: 31,
      );

      // monthNumber=1 → _dueDate(start, 1, 31) → Feb 2024 (leap year, 29 days)
      // paymentDay=31 capped to 29
      expect(schedule[0].dueDate.month, 2);
      expect(schedule[0].dueDate.day, 29);
    });
  });
}

class _LoanTestCase {
  final int principal;
  final double rate;
  final int months;
  final String method;

  const _LoanTestCase({
    required this.principal,
    required this.rate,
    required this.months,
    required this.method,
  });
}
