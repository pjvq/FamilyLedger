import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familyledger/features/overview/widgets/net_worth_hero_card.dart';
import 'package:familyledger/features/overview/widgets/monthly_summary_card.dart';
import 'package:familyledger/features/overview/widgets/budget_progress_card.dart';
import 'package:familyledger/domain/providers/dashboard_provider.dart';
import 'package:familyledger/domain/providers/budget_provider.dart';
import 'package:familyledger/domain/providers/transaction_provider.dart';
import 'package:familyledger/domain/models/dashboard_models.dart';
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
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
  }

  group('NetWorthHeroCard', () {
    testWidgets('renders net worth amount', (tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const NetWorthHeroCard(),
          overrides: [
            dashboardProvider.overrideWith(
              (_) => FakeDashboardNotifier(
                const DashboardState(
                  netWorth: NetWorthData(
                    total: 50000000, // ¥500,000
                    cashAndBank: 20000000,
                    investmentValue: 25000000,
                    fixedAssetValue: 15000000,
                    loanBalance: 10000000,
                    changeFromLastMonth: 500000,
                    changePercent: 1.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('净资产'), findsOneWidget);
      expect(find.textContaining('50'), findsWidgets); // ¥50.00万
    });
  });

  group('MonthlySummaryCard', () {
    testWidgets('renders income and expense', (tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const MonthlySummaryCard(),
          overrides: [
            dashboardProvider.overrideWith(
              (_) => FakeDashboardNotifier(
                const DashboardState(
                  incomeExpenseTrend: [
                    TrendPointData(
                      label: '2026-05',
                      income: 2500000,
                      expense: 1200000,
                      net: 1300000,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('本月收支'), findsOneWidget);
      expect(find.textContaining('收入'), findsOneWidget);
      expect(find.textContaining('支出'), findsOneWidget);
      expect(find.textContaining('结余'), findsOneWidget);
    });

    testWidgets('hidden when no trend data', (tester) async {
      await tester.pumpWidget(wrapInApp(const MonthlySummaryCard()));
      await tester.pumpAndSettle();

      // Empty state — card is hidden
      expect(find.text('本月收支'), findsNothing);
    });
  });

  group('BudgetProgressCard', () {
    testWidgets('hidden when no budget', (tester) async {
      await tester.pumpWidget(wrapInApp(const BudgetProgressCard()));
      await tester.pumpAndSettle();

      expect(find.text('预算进度'), findsNothing);
    });

    testWidgets('shows budget amount and progress when budget exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapInApp(
          const BudgetProgressCard(),
          overrides: [
            budgetProvider.overrideWith(
              (_) => FakeBudgetNotifier(
                BudgetState(
                  execution: const BudgetExecutionData(
                    totalBudget: 1000000,
                    totalSpent: 750000,
                    executionRate: 0.75,
                    categoryExecutions: [],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('月预算'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('已花 ¥7500'), findsOneWidget);
      expect(find.text('预算 ¥10000'), findsOneWidget);
    });
  });
}
