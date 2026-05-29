import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familyledger/features/overview/widgets/net_worth_hero_card.dart';
import 'package:familyledger/features/overview/widgets/monthly_summary_card.dart';
import 'package:familyledger/features/overview/widgets/budget_progress_card.dart';
import 'package:familyledger/features/overview/widgets/recent_transactions_card.dart';
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
      await tester.pumpWidget(wrapInApp(
        const NetWorthHeroCard(),
        overrides: [
          dashboardProvider.overrideWith((_) => FakeDashboardNotifier(
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
          )),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('净资产'), findsOneWidget);
      expect(find.textContaining('50'), findsWidgets); // ¥50.00万
    });
  });

  group('MonthlySummaryCard', () {
    testWidgets('renders income and expense', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const MonthlySummaryCard(),
        overrides: [
          dashboardProvider.overrideWith((_) => FakeDashboardNotifier(
            const DashboardState(
              incomeExpenseTrend: [
                TrendPointData(label: '2026-05', income: 2500000, expense: 1200000, net: 1300000),
              ],
            ),
          )),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('本月收支'), findsOneWidget);
      expect(find.textContaining('收入'), findsOneWidget);
      expect(find.textContaining('支出'), findsOneWidget);
      expect(find.textContaining('结余'), findsOneWidget);
    });

    testWidgets('shows placeholder when no data', (tester) async {
      await tester.pumpWidget(wrapInApp(const MonthlySummaryCard()));
      await tester.pumpAndSettle();

      // Empty state — still shows the card with zero values
      expect(find.text('本月收支'), findsOneWidget);
    });
  });

  group('BudgetProgressCard', () {
    testWidgets('hidden when no budget', (tester) async {
      await tester.pumpWidget(wrapInApp(const BudgetProgressCard()));
      await tester.pumpAndSettle();

      expect(find.text('预算进度'), findsNothing);
    });

    testWidgets('shows top 3 categories when budget exists', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const BudgetProgressCard(),
        overrides: [
          budgetProvider.overrideWith((_) => FakeBudgetNotifier(
            BudgetState(
              execution: const BudgetExecutionData(
                totalBudget: 1000000,
                totalSpent: 750000,
                executionRate: 0.75,
                categoryExecutions: [
                  CategoryExecutionData(
                    categoryId: 'c1',
                    categoryName: '餐饮',
                    budgetAmount: 300000,
                    spentAmount: 280000,
                    executionRate: 0.93,
                  ),
                  CategoryExecutionData(
                    categoryId: 'c2',
                    categoryName: '交通',
                    budgetAmount: 200000,
                    spentAmount: 150000,
                    executionRate: 0.75,
                  ),
                  CategoryExecutionData(
                    categoryId: 'c3',
                    categoryName: '购物',
                    budgetAmount: 500000,
                    spentAmount: 320000,
                    executionRate: 0.64,
                  ),
                ],
              ),
            ),
          )),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('预算进度'), findsOneWidget);
      expect(find.text('餐饮'), findsOneWidget);
      expect(find.text('交通'), findsOneWidget);
      expect(find.text('购物'), findsOneWidget);
    });
  });

  group('RecentTransactionsCard', () {
    testWidgets('hidden when no transactions', (tester) async {
      await tester.pumpWidget(wrapInApp(const RecentTransactionsCard()));
      await tester.pumpAndSettle();

      expect(find.text('最近交易'), findsNothing);
    });

    testWidgets('shows up to 5 transactions', (tester) async {
      final txns = List.generate(7, (i) => Transaction(
        id: 'tx-$i',
        userId: 'u1',
        accountId: 'a1',
        categoryId: 'cat1',
        amount: (i + 1) * 1000,
        currency: 'CNY',
        amountCny: (i + 1) * 1000,
        exchangeRate: 1.0,
        type: i.isEven ? 'expense' : 'income',
        note: '交易$i',
        tags: '',
        imageUrls: '',
        txnDate: DateTime(2026, 5, 29 - i),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        syncStatus: 'synced',
      ));

      await tester.pumpWidget(wrapInApp(
        const RecentTransactionsCard(),
        overrides: [
          transactionProvider.overrideWith((_) => FakeTransactionNotifier(
            TransactionState(transactions: txns, isLoading: false),
          )),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('最近交易'), findsOneWidget);
      expect(find.text('查看全部'), findsOneWidget);
      // Only 5 shown, not 7
      expect(find.text('交易0'), findsOneWidget);
      expect(find.text('交易4'), findsOneWidget);
      expect(find.text('交易5'), findsNothing);
      expect(find.text('交易6'), findsNothing);
    });
  });
}
