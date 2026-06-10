import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familyledger/features/assets/assets_tab_page.dart';
import 'package:familyledger/features/assets/widgets/show_more_button.dart';
import 'package:familyledger/features/assets/widgets/loan_group_item.dart';
import 'package:familyledger/domain/providers/account_provider.dart';
import 'package:familyledger/domain/providers/dashboard_provider.dart';
import 'package:familyledger/domain/models/dashboard_models.dart';
import 'package:familyledger/domain/models/loan_models.dart';
import 'package:familyledger/data/local/database.dart';
import 'package:familyledger/core/theme/tokens/semantic_theme_extension.dart';

import 'test_helpers.dart';

void main() {
  Widget buildTestApp({
    AccountState? account,
    DashboardState? dashboard,
    LoanState? loan,
  }) {
    return ProviderScope(
      overrides: testOverrides(
        account: account,
        dashboard: dashboard,
        loan: loan,
      ),
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          extensions: const [AppSemanticColors.light],
        ),
        home: const AssetsTabPage(),
      ),
    );
  }

  group('AssetsTabPage', () {
    testWidgets('renders without crash with empty state', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(AssetsTabPage), findsOneWidget);
      expect(find.text('资产'), findsOneWidget);
    });

    testWidgets('shows net worth hero card', (tester) async {
      await tester.pumpWidget(buildTestApp(
        dashboard: const DashboardState(
          netWorth: NetWorthData(
            total: 50000000,
            cashAndBank: 30000000,
            investmentValue: 25000000,
            fixedAssetValue: 10000000,
            loanBalance: -15000000,
            changeFromLastMonth: 2000000,
            changePercent: 0.04,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('净资产'), findsOneWidget);
    });

    testWidgets('shows accounts section when accounts exist',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        account: AccountState(
          accounts: [
            Account(
              id: 'acc-1',
              name: '工商银行',
              icon: '🏦',
              balance: 1000000,
              accountType: 'debit',
              currency: 'CNY',
              userId: 'u1',
              familyId: '',
              isActive: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('现金与存款'), findsOneWidget);
      expect(find.text('工商银行'), findsOneWidget);
    });

    testWidgets('shows empty state when no assets at all', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('暂无资产数据'), findsOneWidget);
    });

    // ── Boundary tests (review #11) ──

    testWidgets('NaN changePercent does not crash', (tester) async {
      await tester.pumpWidget(buildTestApp(
        dashboard: const DashboardState(
          netWorth: NetWorthData(
            total: 100000,
            changePercent: double.nan,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Should not display "NaN%"
      expect(find.textContaining('NaN'), findsNothing);
      expect(find.text('净资产'), findsOneWidget);
    });

    testWidgets('Infinity changePercent does not crash', (tester) async {
      await tester.pumpWidget(buildTestApp(
        dashboard: const DashboardState(
          netWorth: NetWorthData(
            total: 100000,
            changePercent: double.infinity,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Infinity'), findsNothing);
    });

    testWidgets('negative net worth renders correctly', (tester) async {
      await tester.pumpWidget(buildTestApp(
        dashboard: const DashboardState(
          netWorth: NetWorthData(
            total: -500000,
            loanBalance: -800000,
            cashAndBank: 300000,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('净资产'), findsOneWidget);
    });

    testWidgets('shows "查看全部" when >5 accounts', (tester) async {
      final manyAccounts = List.generate(
        7,
        (i) => Account(
          id: 'acc-$i',
          name: '账户$i',
          icon: '💰',
          balance: 100000 * (i + 1),
          accountType: 'debit',
          currency: 'CNY',
          userId: 'u1',
          familyId: '',
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(buildTestApp(
        account: AccountState(accounts: manyAccounts),
      ));
      await tester.pumpAndSettle();

      // Scroll down to find the "show more" button
      await tester.dragUntilVisible(
        find.byType(ShowMoreButton),
        find.byType(CustomScrollView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      expect(find.text('查看全部 7 个账户'), findsOneWidget);
    });

    // ── 负债总额回归测试（组合贷 bug，2026-06-10）──
    //
    // Bug: 资产 Tab 负债总额只累加 standalone loans（getStandaloneLoans 排除
    // groupId 非空的子贷款），漏掉了组合贷（loan group）的剩余本金，导致
    // 总额严重偏小（实测 358.67万 显示成 23.27万）。
    // 修复后：负债总额 = standalone 剩余本金 + 各 loan group 的
    // totalRemainingPrincipal。

    Loan makeStandaloneLoan({
      String id = 'loan-s1',
      int remainingPrincipal = 10800000, // 10.80万 = 108000元 = 10800000分
    }) {
      final now = DateTime(2024, 1, 1);
      return Loan(
        id: id,
        userId: 'u1',
        familyId: '',
        name: '招行闪电贷',
        loanType: 'consumer',
        principal: 120000000,
        remainingPrincipal: remainingPrincipal,
        annualRate: 3.0,
        totalMonths: 12,
        paidMonths: 2,
        repaymentMethod: 'equal_installment',
        paymentDay: 2,
        startDate: now,
        accountId: '',
        groupId: '', // standalone
        subType: '',
        rateType: 'fixed',
        lprBase: 0.0,
        lprSpread: 0.0,
        rateAdjustMonth: 1,
        repaymentCategoryId: '',
        createdAt: now,
        updatedAt: now,
      );
    }

    LoanGroupDisplayItem makeGroupDisplay({
      int totalRemainingPrincipal = 335400000, // 335.40万
    }) {
      final now = DateTime(2024, 1, 1);
      return LoanGroupDisplayItem(
        group: LoanGroup(
          id: 'group-1',
          userId: 'u1',
          familyId: '',
          name: '观晖美寓',
          groupType: 'combined',
          totalPrincipal: 350000000,
          paymentDay: 2,
          startDate: now,
          accountId: '',
          loanType: 'mortgage',
          createdAt: now,
          updatedAt: now,
          deletedAt: null,
        ),
        subLoans: const [],
        totalMonthlyPayment: 17800,
        totalRemainingPrincipal: totalRemainingPrincipal,
        overallProgress: 0.1,
      );
    }

    testWidgets('负债总额包含组合贷剩余本金（回归）', (tester) async {
      await tester.pumpWidget(buildTestApp(
        loan: LoanState(
          loans: [makeStandaloneLoan()], // 10.80万
          loanGroups: [makeGroupDisplay()], // 335.40万
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('负债'), findsOneWidget);
      // 10.80万 + 335.40万 = 346.20万，必须包含组合贷。
      expect(find.text('-¥346.20万'), findsOneWidget);
      // 修复前的错误值（只算 standalone）不应出现。
      expect(find.text('-¥10.80万'), findsNothing);
    });

    testWidgets('只有组合贷时负债区仍显示且总额正确', (tester) async {
      await tester.pumpWidget(buildTestApp(
        loan: LoanState(
          loans: const [], // 无独立贷款
          loanGroups: [makeGroupDisplay()], // 335.40万
        ),
      ));
      await tester.pumpAndSettle();

      // section 显示条件改为 loans 或 loanGroups 任一非空。
      expect(find.text('负债'), findsOneWidget);
      expect(find.text('-¥335.40万'), findsOneWidget);
      // 组合贷现在作为汇总行渲染（LoanGroupItem），不再是空列表。
      expect(find.byType(LoanGroupItem), findsOneWidget);
      expect(find.text('观晖美寓'), findsOneWidget);
      expect(find.text('组合贷'), findsOneWidget);
      // 总共 1 笔 ≤ 3，不应出现“查看全部”。
      expect(find.textContaining('查看全部'), findsNothing);
    });

    testWidgets('超过 3 笔贷款（含组合贷）显示查看全部 N 笔', (tester) async {
      await tester.pumpWidget(buildTestApp(
        loan: LoanState(
          loans: [
            makeStandaloneLoan(id: 'l1'),
            makeStandaloneLoan(id: 'l2'),
            makeStandaloneLoan(id: 'l3'),
          ],
          loanGroups: [makeGroupDisplay()],
        ),
      ));
      await tester.pumpAndSettle();

      // 3 独立 + 1 组合 = 4 笔 > 3，应显示查看全部。
      await tester.dragUntilVisible(
        find.byType(ShowMoreButton),
        find.byType(CustomScrollView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(find.text('查看全部 4 笔贷款'), findsOneWidget);
    });

    testWidgets('bar not shown when both assets and liabilities are 0',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        dashboard: const DashboardState(
          netWorth: NetWorthData(
            total: 0,
            cashAndBank: 0,
            investmentValue: 0,
            fixedAssetValue: 0,
            loanBalance: 0,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Legend text should not appear when bar is hidden
      expect(find.text('资产 ¥0.00'), findsNothing);
    });
  });
}
