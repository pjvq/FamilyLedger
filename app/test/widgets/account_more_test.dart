import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:familyledger/data/local/database.dart';
import 'package:familyledger/domain/providers/account_provider.dart';
import 'package:familyledger/domain/providers/auth_provider.dart';
import 'package:familyledger/domain/providers/family_provider.dart';
import 'package:familyledger/features/more/more_page.dart';
import 'package:familyledger/features/account/accounts_page.dart';
import 'package:familyledger/features/account/add_account_page.dart';
import 'package:familyledger/features/account/transfer_page.dart';
import 'package:familyledger/core/widgets/shared_element_route.dart';

import 'test_helpers.dart';

// ─── Test Data Helpers ──────────────────────────────────────

Account _makeAccount({
  String id = 'acc_1',
  String userId = 'u1',
  String familyId = '',
  String name = '招商银行',
  String accountType = 'bank_card',
  String icon = '🏦',
  int balance = 1000000, // 10000.00 yuan in cents
  String currency = 'CNY',
  bool isActive = true,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final now = DateTime.now();
  return Account(
    id: id,
    userId: userId,
    familyId: familyId,
    name: name,
    accountType: accountType,
    icon: icon,
    balance: balance,
    currency: currency,
    isActive: isActive,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
  );
}

Family _makeFamily({
  String id = 'fam_1',
  String name = '我的家庭',
  String ownerId = 'u1',
  String inviteCode = '',
  DateTime? createdAt,
}) {
  return Family(
    id: id,
    name: name,
    ownerId: ownerId,
    inviteCode: inviteCode,
    createdAt: createdAt ?? DateTime.now(),
  );
}

FamilyMember _makeMember({
  String id = 'mem_1',
  String familyId = 'fam_1',
  String userId = 'u1',
  String email = 'test@example.com',
  String role = 'owner',
  DateTime? joinedAt,
}) {
  return FamilyMember(
    id: id,
    familyId: familyId,
    userId: userId,
    email: email,
    role: role,
    canView: true,
    canCreate: true,
    canEdit: false,
    canDelete: false,
    canManageAccounts: false,
    joinedAt: joinedAt ?? DateTime.now(),
  );
}

/// Standard routes map so Navigator.pushNamed doesn't throw.
Map<String, WidgetBuilder> _stubRoutes() => {
      '/loans': (_) => const Scaffold(body: Text('loans')),
      '/investments': (_) => const Scaffold(body: Text('investments')),
      '/assets': (_) => const Scaffold(body: Text('assets')),
      '/report': (_) => const Scaffold(body: Text('report')),
      '/export': (_) => const Scaffold(body: Text('export')),
      '/import/csv': (_) => const Scaffold(body: Text('csv_import')),
      '/settings': (_) => const Scaffold(body: Text('settings')),
      '/notifications/settings': (_) =>
          const Scaffold(body: Text('notification_settings')),
      '/login': (_) => const Scaffold(body: Text('login')),
      '/accounts/add': (_) => const Scaffold(body: Text('add_account')),
      '/transfer': (_) => const Scaffold(body: Text('transfer')),
    };

void main() {
  // ═══════════════════════════════════════════════════════════
  // MorePage Tests
  // ═══════════════════════════════════════════════════════════
  group('MorePage', () {
    testWidgets('renders app bar title', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const MorePage(),
        routes: _stubRoutes(),
      ));
      expect(find.text('更多'), findsOneWidget);
    });

    testWidgets('renders all three section headers', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const MorePage(),
        routes: _stubRoutes(),
      ));
      // '资产管理' appears as both section header AND a tile title
      expect(find.text('资产管理'), findsNWidgets(2));
      expect(find.text('数据'), findsOneWidget);
      // '设置' section header may be off-screen, scroll to reveal
      await tester.scrollUntilVisible(find.text('设置'), 200);
      expect(find.text('设置'), findsOneWidget);
    });

    testWidgets('renders all 9 navigation tiles', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const MorePage(),
        routes: _stubRoutes(),
      ));

      // 资产管理 section: 3 tiles (visible in initial viewport)
      expect(find.text('贷款管理'), findsOneWidget);
      expect(find.text('投资管理'), findsOneWidget);
      // '资产管理' appears as both section header AND tile title
      expect(find.text('资产管理'), findsNWidgets(2));

      // 数据 section: 3 tiles
      expect(find.text('交易报表'), findsOneWidget);
      expect(find.text('数据导出'), findsOneWidget);

      // Scroll down to reveal items at the bottom
      await tester.scrollUntilVisible(find.text('CSV 导入'), 200);
      expect(find.text('CSV 导入'), findsOneWidget);

      // 设置 section: 3 tiles
      await tester.scrollUntilVisible(find.text('退出登录'), 200);
      expect(find.text('通知设置'), findsOneWidget);
      expect(find.text('退出登录'), findsOneWidget);
    });

    testWidgets('displays user info card', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const MorePage(),
        auth: const AuthState(
          status: AuthStatus.authenticated,
          userId: 'user_123',
        ),
        routes: _stubRoutes(),
      ));
      expect(find.text('我的账号'), findsOneWidget);
      expect(find.text('user_123'), findsOneWidget);
    });

    testWidgets('shows family name when family exists', (tester) async {
      final family = _makeFamily(name: '张家');
      final members = [_makeMember(), _makeMember(id: 'mem_2', userId: 'u2')];
      await tester.pumpWidget(wrapWithProviders(
        const MorePage(),
        family: FamilyState(
          currentFamily: family,
          families: [family],
          members: members,
        ),
        routes: _stubRoutes(),
      ));
      // Family tile may be scrolled off-screen
      await tester.scrollUntilVisible(find.text('张家'), 200);
      expect(find.text('张家'), findsOneWidget);
      expect(find.text('2 位成员'), findsOneWidget);
    });

    testWidgets('shows default family text when no family', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const MorePage(),
        family: const FamilyState(),
        routes: _stubRoutes(),
      ));
      await tester.scrollUntilVisible(find.text('家庭管理'), 200);
      expect(find.text('家庭管理'), findsOneWidget);
      expect(find.text('创建或加入家庭'), findsOneWidget);
    });

    testWidgets('logout shows confirm dialog', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const MorePage(),
        routes: _stubRoutes(),
      ));

      // Scroll to make logout visible, then tap
      await tester.scrollUntilVisible(find.text('退出登录'), 200);
      await tester.tap(find.text('退出登录'));
      await tester.pumpAndSettle();

      // Dialog should appear
      expect(find.text('确定要退出登录吗？'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('退出'), findsOneWidget);
    });

    testWidgets('logout dialog cancel dismisses dialog', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const MorePage(),
        routes: _stubRoutes(),
      ));

      await tester.scrollUntilVisible(find.text('退出登录'), 200);
      await tester.tap(find.text('退出登录'));
      await tester.pumpAndSettle();

      // Tap cancel
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.text('确定要退出登录吗？'), findsNothing);
    });

    testWidgets('tapping tile navigates to correct route', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const MorePage(),
        routes: _stubRoutes(),
      ));

      // Scroll to make sure '贷款管理' is visible and tap
      await tester.tap(find.text('贷款管理'));
      await tester.pumpAndSettle();

      expect(find.text('loans'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // AccountsPage Tests
  // ═══════════════════════════════════════════════════════════
  group('AccountsPage', () {
    testWidgets('renders app bar title', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AccountsPage(),
        routes: _stubRoutes(),
      ));
      expect(find.text('账户'), findsOneWidget);
    });

    testWidgets('shows empty state when no accounts', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AccountsPage(),
        account: const AccountState(accounts: []),
        routes: _stubRoutes(),
      ));
      expect(find.text('还没有账户'), findsOneWidget);
      expect(find.text('点击右下角按钮添加第一个账户'), findsOneWidget);
    });

    testWidgets('shows loading indicator when isLoading', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AccountsPage(),
        account: const AccountState(isLoading: true),
        routes: _stubRoutes(),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows account list with accounts', (tester) async {
      final accounts = [
        _makeAccount(id: 'a1', name: '招商银行', balance: 1000000),
        _makeAccount(
          id: 'a2',
          name: '支付宝',
          accountType: 'alipay',
          icon: '🔵',
          balance: 500050,
        ),
      ];
      await tester.pumpWidget(wrapWithProviders(
        const AccountsPage(),
        account: AccountState(accounts: accounts),
        routes: _stubRoutes(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('招商银行'), findsOneWidget);
      // '支付宝' appears as both the account name and the type display name
      // (AccountTypeHelper.displayName('alipay') == '支付宝')
      expect(find.text('支付宝'), findsNWidgets(2));
    });

    testWidgets('shows total balance card', (tester) async {
      final accounts = [
        _makeAccount(id: 'a1', balance: 1000000),
        _makeAccount(id: 'a2', balance: 500000),
      ];
      await tester.pumpWidget(wrapWithProviders(
        const AccountsPage(),
        account: AccountState(accounts: accounts),
        routes: _stubRoutes(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('总资产'), findsOneWidget);
      // Total = 15000.00 yuan → "¥ 15000"
      expect(find.text('¥ 15000'), findsOneWidget);
      expect(find.text('共 2 个账户'), findsOneWidget);
    });

    testWidgets('has FAB with add account button', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AccountsPage(),
        account: const AccountState(accounts: []),
        routes: _stubRoutes(),
      ));

      expect(find.text('添加账户'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });

    testWidgets('has transfer FAB', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AccountsPage(),
        account: const AccountState(accounts: []),
        routes: _stubRoutes(),
      ));

      expect(find.byIcon(Icons.swap_horiz_rounded), findsOneWidget);
    });

    testWidgets('account card shows correct type name', (tester) async {
      final accounts = [
        _makeAccount(accountType: 'cash', name: '现金钱包'),
      ];
      await tester.pumpWidget(wrapWithProviders(
        const AccountsPage(),
        account: AccountState(accounts: accounts),
        routes: _stubRoutes(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('现金钱包'), findsOneWidget);
      // AccountTypeHelper.displayName('cash') => '现金'
      expect(find.text('现金'), findsOneWidget);
    });

    testWidgets('formats balance correctly with decimals', (tester) async {
      final accounts = [
        _makeAccount(id: 'a1', balance: 123456), // 1234.56 yuan
      ];
      await tester.pumpWidget(wrapWithProviders(
        const AccountsPage(),
        account: AccountState(accounts: accounts),
        routes: _stubRoutes(),
      ));
      await tester.pumpAndSettle();

      // Both _TotalBalanceCard and _AccountCard display the amount
      expect(find.text('¥ 1234.56'), findsNWidgets(2));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // AddAccountPage Tests
  // ═══════════════════════════════════════════════════════════
  group('AddAccountPage', () {
    testWidgets('renders form elements', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AddAccountPage(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('添加账户'), findsOneWidget);
      expect(find.text('账户名称'), findsOneWidget);
      expect(find.text('账户类型'), findsOneWidget);
      expect(find.text('初始余额'), findsOneWidget);
    });

    testWidgets('has name text field with hint', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AddAccountPage(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('例如：招商银行储蓄卡'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('renders all account type chips', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AddAccountPage(),
      ));
      await tester.pumpAndSettle();

      // AccountTypeHelper.allTypes has 7 types
      // Check display names
      expect(find.text('现金'), findsOneWidget);
      expect(find.text('银行卡'), findsOneWidget);
      expect(find.text('信用卡'), findsOneWidget);
      expect(find.text('支付宝'), findsOneWidget);
      expect(find.text('微信支付'), findsOneWidget);
      expect(find.text('投资账户'), findsOneWidget);
      expect(find.text('其他'), findsOneWidget);
    });

    testWidgets('shows initial balance as 0', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AddAccountPage(),
      ));
      await tester.pumpAndSettle();

      // The default _amountStr is '0', displayed alongside ¥
      expect(find.text('¥'), findsOneWidget);
      // '0' appears in both the amount display and the number pad key
      expect(find.text('0'), findsNWidgets(2));
    });

    testWidgets('has number pad', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AddAccountPage(),
      ));
      await tester.pumpAndSettle();

      // NumberPad should be rendered
      // Check for some numeric buttons
      expect(find.text('1'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('.'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // TransferPage Tests
  // ═══════════════════════════════════════════════════════════
  group('TransferPage', () {
    testWidgets('renders app bar title', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const TransferPage(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('转账'), findsOneWidget);
    });

    testWidgets('renders source and destination selectors', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const TransferPage(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('从'), findsOneWidget);
      expect(find.text('到'), findsOneWidget);
      // Two "选择账户" hints
      expect(find.text('选择账户'), findsNWidgets(2));
    });

    testWidgets('shows amount display and note field', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const TransferPage(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('¥'), findsOneWidget);
      // '0' appears in both the amount display and the number pad key
      expect(find.text('0'), findsNWidgets(2));
      expect(find.text('备注（可选）'), findsOneWidget);
    });

    testWidgets('has number pad', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const TransferPage(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('renders dropdown items when accounts exist', (tester) async {
      final accounts = [
        _makeAccount(id: 'a1', name: '招商银行'),
        _makeAccount(id: 'a2', name: '支付宝', accountType: 'alipay', icon: '🔵'),
      ];
      await tester.pumpWidget(wrapWithProviders(
        const TransferPage(),
        account: AccountState(accounts: accounts),
      ));
      await tester.pumpAndSettle();

      // DropdownButtons should exist
      expect(find.byType(DropdownButton<String>), findsNWidgets(2));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // SharedElement & HeroTags Tests
  // ═══════════════════════════════════════════════════════════
  group('HeroTags', () {
    test('forAccount produces correct tag', () {
      expect(HeroTags.account('abc'), equals('account_abc'));
    });

    test('forTransaction produces correct tag', () {
      expect(HeroTags.transaction('t1'), equals('transaction_t1'));
    });

    test('investment produces correct tag', () {
      expect(HeroTags.investment('inv1'), equals('investment_inv1'));
    });

    test('asset produces correct tag', () {
      expect(HeroTags.asset('a1'), equals('asset_a1'));
    });

    test('loan produces correct tag', () {
      expect(HeroTags.loan('l1'), equals('loan_l1'));
    });

    test('amount produces correct tag', () {
      expect(HeroTags.amount('x'), equals('amount_x'));
    });
  });

  group('SharedElement', () {
    testWidgets('wraps child in Hero widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SharedElement(
              tag: 'test_tag',
              child: const Text('hello'),
            ),
          ),
        ),
      );

      // Should find a Hero widget with the correct tag
      final heroFinder = find.byType(Hero);
      expect(heroFinder, findsOneWidget);
      final hero = tester.widget<Hero>(heroFinder);
      expect(hero.tag, equals('test_tag'));

      // Child content should be rendered
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('wraps child in Material(transparency)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SharedElement(
              tag: 'mat_test',
              child: const Text('content'),
            ),
          ),
        ),
      );

      // Should have Material with transparency type
      final materialFinder = find.byWidgetPredicate(
        (w) => w is Material && w.type == MaterialType.transparency,
      );
      expect(materialFinder, findsOneWidget);
    });
  });

  group('SharedElementRoute', () {
    testWidgets('creates a page route with fade transition', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  SharedElementRoute(
                    builder: (_) => const Scaffold(body: Text('target')),
                  ),
                );
              },
              child: const Text('navigate'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('navigate'));
      await tester.pumpAndSettle();

      expect(find.text('target'), findsOneWidget);
    });
  });
}
