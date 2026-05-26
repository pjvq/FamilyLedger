import 'package:familyledger/core/theme/tokens/semantic_theme_extension.dart';
import 'package:familyledger/data/local/database.dart';
import 'package:familyledger/domain/providers/account_provider.dart';
import 'package:familyledger/features/account/account_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  final testAccount = Account(
    id: 'acc-1',
    userId: 'user-1',
    name: '测试账户',
    accountType: 'debit',
    balance: 100000,
    icon: '💳',
    isActive: true,
    currency: 'CNY',
    familyId: '',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  Widget buildPage({
    String? accountId,
    AccountState? accountState,
  }) {
    return ProviderScope(
      overrides: testOverrides(
        account: accountState ?? AccountState(accounts: [testAccount]),
      ),
      child: MaterialApp(
        theme: ThemeData.light(useMaterial3: true).copyWith(
          extensions: const [AppSemanticColors.light],
        ),
        home: AccountDetailPage(accountId: accountId ?? testAccount.id),
      ),
    );
  }

  testWidgets('renders account info when account exists', (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.pump();

    expect(find.text('测试账户'), findsWidgets);
    expect(find.text('储蓄卡'), findsOneWidget);
    expect(find.text('最近交易'), findsOneWidget);
  });

  testWidgets('shows error when account does not exist', (tester) async {
    await tester.pumpWidget(buildPage(
      accountId: 'nonexistent',
      accountState: const AccountState(accounts: []),
    ));
    await tester.pumpAndSettle();

    expect(find.text('账户不存在'), findsOneWidget);
  });
}
