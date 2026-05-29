import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familyledger/features/overview/widgets/greeting_header.dart';
import 'package:familyledger/features/overview/widgets/reminders_card.dart';
import 'package:familyledger/features/overview/widgets/quick_actions.dart';
import 'package:familyledger/domain/providers/dashboard_provider.dart';
import 'package:familyledger/domain/providers/loan_provider.dart';
import 'package:familyledger/domain/providers/reminder_provider.dart';
import 'package:familyledger/domain/models/dashboard_models.dart';
import 'package:familyledger/domain/models/loan_models.dart';
import 'package:familyledger/data/local/database.dart';
import 'package:familyledger/core/theme/tokens/semantic_theme_extension.dart';

import 'test_helpers.dart';

void main() {
  Widget wrapInApp(Widget child, {List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: testOverrides().followedBy(overrides).toList(),
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          extensions: const [AppSemanticColors.light],
        ),
        home: Scaffold(body: child),
      ),
    );
  }

  group('GreetingHeader', () {
    testWidgets('renders greeting for morning', (tester) async {
      final morning = DateTime(2026, 3, 16, 8, 30); // Monday
      await tester.pumpWidget(wrapInApp(GreetingHeader(now: morning)));
      await tester.pumpAndSettle();

      expect(find.textContaining('早上好'), findsOneWidget);
      expect(find.textContaining('3月16日'), findsOneWidget);
      expect(find.textContaining('周一'), findsOneWidget);
    });

    testWidgets('renders greeting for evening', (tester) async {
      final evening = DateTime(2026, 6, 1, 20, 0); // Monday
      await tester.pumpWidget(wrapInApp(GreetingHeader(now: evening)));
      await tester.pumpAndSettle();

      expect(find.textContaining('晚上好'), findsOneWidget);
      expect(find.textContaining('6月1日'), findsOneWidget);
      expect(find.textContaining('周一'), findsOneWidget);
    });

    testWidgets('renders greeting for late night', (tester) async {
      final lateNight = DateTime(2026, 1, 1, 2, 0); // Wednesday
      await tester.pumpWidget(wrapInApp(GreetingHeader(now: lateNight)));
      await tester.pumpAndSettle();

      expect(find.textContaining('夜深了'), findsOneWidget);
    });
  });

  group('QuickActions', () {
    testWidgets('renders 4 action buttons', (tester) async {
      await tester.pumpWidget(wrapInApp(const QuickActions()));
      await tester.pumpAndSettle();

      expect(find.text('转账'), findsOneWidget);
      expect(find.text('贷款'), findsOneWidget);
      expect(find.text('投资'), findsOneWidget);
      expect(find.text('报表'), findsOneWidget);
    });
  });

  group('RemindersCard', () {
    testWidgets('hidden when no reminders', (tester) async {
      await tester.pumpWidget(wrapInApp(const RemindersCard()));
      await tester.pumpAndSettle();

      // No reminders = no card rendered
      expect(find.text('待办提醒'), findsNothing);
    });

    testWidgets('shows budget warning when >80%', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const RemindersCard(),
        overrides: [
          dashboardProvider.overrideWith((_) => FakeDashboardNotifier(
            const DashboardState(
              budgetSummary: BudgetSummaryData(
                totalBudget: 1000000,
                totalSpent: 900000,
                executionRate: 0.9,
              ),
            ),
          )),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('待办提醒'), findsOneWidget);
      expect(find.text('预算预警'), findsOneWidget);
      expect(find.textContaining('已使用 90%'), findsOneWidget);
    });

    testWidgets('shows loan payment reminder when due within 7 days',
        (tester) async {
      final now = DateTime.now();
      final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
      // Set payment day to 2 days from now, clamped to month length
      final payDay = (now.day + 2) > daysInMonth ? 1 : now.day + 2;

      await tester.pumpWidget(wrapInApp(
        const RemindersCard(),
        overrides: [
          loanProvider.overrideWith((_) => FakeLoanNotifier(
            LoanState(loans: [
              Loan(
                id: 'loan-1',
                userId: 'u1',
                familyId: '',
                name: '房贷',
                loanType: 'mortgage',
                principal: 100000000,
                remainingPrincipal: 80000000,
                annualRate: 3.85,
                totalMonths: 360,
                paidMonths: 24,
                repaymentMethod: 'equal_installment',
                paymentDay: payDay,
                startDate: DateTime(2024, 1, 1),
                accountId: '',
                groupId: '',
                subType: '',
                rateType: 'lpr',
                lprBase: 3.85,
                lprSpread: 0.0,
                rateAdjustMonth: 1,
                repaymentCategoryId: '',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            ]),
          )),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('待办提醒'), findsOneWidget);
      expect(find.text('房贷'), findsOneWidget);
    });
  });

  group('daysUntilPayment', () {
    test('payDay 31 in February clamps to 28', () {
      final feb15 = DateTime(2026, 2, 15);
      // Effective pay day = 28 (Feb has 28 days in 2026)
      expect(daysUntilPayment(31, feb15), 28 - 15);
    });

    test('payDay 31 in February leap year clamps to 29', () {
      final feb15Leap = DateTime(2028, 2, 15); // 2028 is leap year
      expect(daysUntilPayment(31, feb15Leap), 29 - 15);
    });

    test('payDay already passed this month — rolls to next month', () {
      final jan20 = DateTime(2026, 1, 20);
      // payDay 10 already passed → next month Feb 10
      // Feb 10 - Jan 20 = 21 days
      expect(daysUntilPayment(10, jan20), 21);
    });

    test('payDay 31 passed in Jan → next month Feb clamps to 28', () {
      final jan31 = DateTime(2026, 1, 31);
      // payDay=31, today=31 → effective this month = 31, 31-31 = 0
      expect(daysUntilPayment(31, jan31), 0);
    });

    test('payDay today returns 0', () {
      final mar15 = DateTime(2026, 3, 15);
      expect(daysUntilPayment(15, mar15), 0);
    });

    test('payDay tomorrow returns 1', () {
      final mar15 = DateTime(2026, 3, 15);
      expect(daysUntilPayment(16, mar15), 1);
    });

    test('payDay 31 rolls from April (30 days) to next correctly', () {
      // April has 30 days. payDay=31, today=30.
      // Effective this month = 30, 30 - 30 = 0
      final apr30 = DateTime(2026, 4, 30);
      expect(daysUntilPayment(31, apr30), 0);
    });
  });
}
