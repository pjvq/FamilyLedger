import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familyledger/features/assets/assets_tab_page.dart';
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
            total: 50000000, // 50万
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
  });
}
