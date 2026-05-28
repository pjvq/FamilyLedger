import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familyledger/features/overview/widgets/greeting_header.dart';
import 'package:familyledger/features/overview/widgets/reminders_card.dart';
import 'package:familyledger/features/overview/widgets/quick_actions.dart';
import 'package:familyledger/domain/providers/dashboard_provider.dart';
import 'package:familyledger/domain/providers/loan_provider.dart';
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
    testWidgets('renders greeting based on time', (tester) async {
      await tester.pumpWidget(wrapInApp(const GreetingHeader()));
      await tester.pumpAndSettle();

      // Should find a greeting text (varies by time of day)
      expect(find.byType(GreetingHeader), findsOneWidget);
      // Date should contain month number
      final now = DateTime.now();
      expect(find.textContaining('${now.month}月'), findsOneWidget);
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
      final today = DateTime.now().day;
      // Set payment day to 2 days from now (wrap around month)
      final payDay = (today + 2) > 28 ? 1 : today + 2;

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
}
