import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:familyledger/data/local/database.dart' as db;
import 'package:familyledger/domain/providers/app_providers.dart';
import 'package:familyledger/domain/providers/auth_provider.dart';
import 'package:familyledger/domain/providers/budget_provider.dart';
import 'package:familyledger/domain/providers/family_provider.dart';
import 'package:familyledger/domain/providers/notification_provider.dart';
import 'package:familyledger/domain/providers/sync_status_provider.dart';
import 'package:familyledger/domain/providers/theme_provider.dart';
import 'package:familyledger/domain/providers/transaction_provider.dart';
import 'package:familyledger/features/budget/budget_page.dart';
import 'package:familyledger/features/budget/set_budget_sheet.dart';
import 'package:familyledger/features/notification/notification_settings_page.dart';
import 'package:familyledger/features/notification/notifications_page.dart';
import 'package:familyledger/features/settings/family_members_page.dart';
import 'package:familyledger/features/settings/settings_page.dart';

import 'test_helpers.dart';

// ─── Extra overrides ──────────────────────────────────────────

late SharedPreferences _prefs;

List<Override> _themeOverrides() => [
      sharedPreferencesProvider.overrideWithValue(_prefs),
      themeModeProvider.overrideWith((_) => ThemeModeNotifier(_prefs)),
      currentUserIdProvider.overrideWith((ref) => 'user-1'),
    ];

// ─── Helpers ──────────────────────────────────────────────────

db.Family _makeFamily({
  String id = 'fam-1',
  String name = '小Q的家庭',
  String ownerId = 'user-1',
}) =>
    db.Family(
      id: id,
      name: name,
      ownerId: ownerId,
      inviteCode: 'ABC123',
      createdAt: DateTime(2025, 1, 1),
    );

db.FamilyMember _makeMember({
  String id = 'mem-1',
  String familyId = 'fam-1',
  String userId = 'user-1',
  String email = 'alice@example.com',
  String role = 'owner',
}) =>
    db.FamilyMember(
      id: id,
      familyId: familyId,
      userId: userId,
      email: email,
      role: role,
      canView: true,
      canCreate: true,
      canEdit: true,
      canDelete: false,
      canManageAccounts: false,
      joinedAt: DateTime(2025, 1, 1),
    );

db.Notification _makeNotification({
  String id = 'n-1',
  String type = 'budget_alert',
  String title = '预算超支',
  String body = '餐饮分类已超出预算',
  bool isRead = false,
  DateTime? createdAt,
}) =>
    db.Notification(
      id: id,
      userId: 'user-1',
      type: type,
      title: title,
      body: body,
      dataJson: '{}',
      isRead: isRead,
      createdAt: createdAt ?? DateTime.now(),
    );

// ─── Main ──────────────────────────────────────────────────────

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });

  // ═══════════════════════════════════════════════════════════
  // 1. SettingsPage
  // ═══════════════════════════════════════════════════════════
  group('SettingsPage', () {
    testWidgets('renders appbar title "设置"', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const SettingsPage(),
        auth: const AuthState(
          status: AuthStatus.authenticated,
          userId: 'test@example.com',
        ),
        extra: _themeOverrides(),
        routes: {
          '/settings/members': (_) => const Scaffold(),
          '/loans': (_) => const Scaffold(),
          '/notifications/settings': (_) => const Scaffold(),
          '/login': (_) => const Scaffold(),
        },
      ));
      await tester.pumpAndSettle();

      expect(find.text('设置'), findsOneWidget);
    });

    testWidgets('shows user email in user info card', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const SettingsPage(),
        auth: const AuthState(
          status: AuthStatus.authenticated,
          userId: 'alice@example.com',
        ),
        extra: _themeOverrides(),
        routes: {
          '/settings/members': (_) => const Scaffold(),
          '/loans': (_) => const Scaffold(),
          '/notifications/settings': (_) => const Scaffold(),
          '/login': (_) => const Scaffold(),
        },
      ));
      await tester.pumpAndSettle();

      expect(find.text('alice@example.com'), findsOneWidget);
      expect(find.text('我的账号'), findsOneWidget);
    });

    testWidgets('shows family info when family exists', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const SettingsPage(),
        auth: const AuthState(
          status: AuthStatus.authenticated,
          userId: 'user-1',
        ),
        family: FamilyState(
          currentFamily: _makeFamily(),
          members: [_makeMember(), _makeMember(id: 'mem-2', userId: 'user-2', email: 'bob@example.com', role: 'member')],
        ),
        extra: _themeOverrides(),
        routes: {
          '/settings/members': (_) => const Scaffold(),
          '/loans': (_) => const Scaffold(),
          '/notifications/settings': (_) => const Scaffold(),
          '/login': (_) => const Scaffold(),
        },
      ));
      await tester.pumpAndSettle();

      expect(find.text('小Q的家庭'), findsOneWidget);
      expect(find.text('2 位成员'), findsOneWidget);
      expect(find.text('生成邀请码'), findsOneWidget);
      expect(find.text('退出家庭'), findsOneWidget);
    });

    testWidgets('shows create/join family when no family', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const SettingsPage(),
        auth: const AuthState(
          status: AuthStatus.authenticated,
          userId: 'user-1',
        ),
        extra: _themeOverrides(),
        routes: {
          '/settings/members': (_) => const Scaffold(),
          '/loans': (_) => const Scaffold(),
          '/notifications/settings': (_) => const Scaffold(),
          '/login': (_) => const Scaffold(),
        },
      ));
      await tester.pumpAndSettle();

      expect(find.text('创建家庭'), findsOneWidget);
      expect(find.text('加入家庭'), findsOneWidget);
    });

    testWidgets('shows theme, sync, loans, notification, logout sections',
        (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const SettingsPage(),
        auth: const AuthState(
          status: AuthStatus.authenticated,
          userId: 'user-1',
        ),
        extra: _themeOverrides(),
        routes: {
          '/settings/members': (_) => const Scaffold(),
          '/loans': (_) => const Scaffold(),
          '/notifications/settings': (_) => const Scaffold(),
          '/login': (_) => const Scaffold(),
        },
      ));
      await tester.pumpAndSettle();

      expect(find.text('外观模式'), findsOneWidget);
      expect(find.text('已同步'), findsOneWidget);

      // Scroll down to reveal items at the bottom of the ListView
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(find.text('贷款管理'), findsOneWidget);
      expect(find.text('通知设置'), findsOneWidget);
      expect(find.text('退出登录'), findsOneWidget);
    });

    testWidgets('shows sync status pending state', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const SettingsPage(),
        auth: const AuthState(
          status: AuthStatus.authenticated,
          userId: 'user-1',
        ),
        sync: const SyncState(status: SyncStatus.pending, pendingCount: 5),
        extra: _themeOverrides(),
        routes: {
          '/settings/members': (_) => const Scaffold(),
          '/loans': (_) => const Scaffold(),
          '/notifications/settings': (_) => const Scaffold(),
          '/login': (_) => const Scaffold(),
        },
      ));
      await tester.pumpAndSettle();

      expect(find.text('待同步'), findsOneWidget);
      expect(find.text('5 条操作等待上传'), findsOneWidget);
    });

    testWidgets('tapping logout shows confirmation dialog', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const SettingsPage(),
        auth: const AuthState(
          status: AuthStatus.authenticated,
          userId: 'user-1',
        ),
        extra: _themeOverrides(),
        routes: {
          '/settings/members': (_) => const Scaffold(),
          '/loans': (_) => const Scaffold(),
          '/notifications/settings': (_) => const Scaffold(),
          '/login': (_) => const Scaffold(),
        },
      ));
      await tester.pumpAndSettle();

      // Scroll down to reveal the logout button
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      await tester.tap(find.text('退出登录'));
      await tester.pumpAndSettle();

      expect(find.text('确定要退出登录吗？'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // 2. NotificationsPage
  // ═══════════════════════════════════════════════════════════
  group('NotificationsPage', () {
    testWidgets('shows empty state when no notifications', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const NotificationsPage(),
        routes: {
          '/notifications/settings': (_) => const Scaffold(),
        },
      ));
      await tester.pumpAndSettle();

      expect(find.text('通知'), findsOneWidget);
      expect(find.text('暂无通知'), findsOneWidget);
      expect(find.text('新的通知会出现在这里'), findsOneWidget);
    });

    testWidgets('shows loading indicator when loading', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const NotificationsPage(),
        notification: const NotificationState(isLoading: true),
        routes: {
          '/notifications/settings': (_) => const Scaffold(),
        },
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders notification list', (tester) async {
      final now = DateTime.now();
      final notifications = [
        _makeNotification(
          id: 'n-1',
          title: '餐饮预算超支',
          body: '本月餐饮支出已超过预算',
          createdAt: now,
        ),
        _makeNotification(
          id: 'n-2',
          type: 'daily_summary',
          title: '今日支出汇总',
          body: '今日消费 ¥120.00',
          isRead: true,
          createdAt: now,
        ),
      ];

      await tester.pumpWidget(wrapWithProviders(
        const NotificationsPage(),
        notification: NotificationState(notifications: notifications),
        routes: {
          '/notifications/settings': (_) => const Scaffold(),
        },
      ));
      await tester.pumpAndSettle();

      expect(find.text('餐饮预算超支'), findsOneWidget);
      expect(find.text('今日支出汇总'), findsOneWidget);
      expect(find.text('今天'), findsOneWidget);
    });

    testWidgets('has settings icon button in appbar', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const NotificationsPage(),
        routes: {
          '/notifications/settings': (_) =>
              const Scaffold(body: Text('Settings Page')),
        },
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
      expect(find.byTooltip('通知设置'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // 3. NotificationSettingsPage
  // ═══════════════════════════════════════════════════════════
  group('NotificationSettingsPage', () {
    testWidgets('renders appbar and section headers', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const NotificationSettingsPage(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('通知设置'), findsOneWidget);
      expect(find.text('预算提醒'), findsOneWidget);
      expect(find.text('定期提醒'), findsOneWidget);
    });

    testWidgets('renders all switch tiles with labels', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const NotificationSettingsPage(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('预算超支提醒'), findsOneWidget);
      expect(find.text('预算80%预警'), findsOneWidget);
      expect(find.text('每日支出汇总'), findsOneWidget);
      expect(find.text('还款日提醒'), findsOneWidget);
    });

    testWidgets('shows reminder days slider when loan reminder on',
        (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const NotificationSettingsPage(),
        notification: const NotificationState(
          settings: NotificationSettingsModel(loanReminder: true),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('提前提醒天数'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('hides reminder slider when loan reminder off',
        (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const NotificationSettingsPage(),
        notification: const NotificationState(
          settings: NotificationSettingsModel(loanReminder: false),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('提前提醒天数'), findsNothing);
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('switch tiles use SwitchListTile widgets', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const NotificationSettingsPage(),
      ));
      await tester.pumpAndSettle();

      // Default settings: budgetAlert=true, budgetWarning=true, dailySummary=false, loanReminder=true
      expect(find.byType(SwitchListTile), findsNWidgets(4));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // 4. FamilyMembersPage
  // ═══════════════════════════════════════════════════════════
  group('FamilyMembersPage', () {
    testWidgets('shows empty state when no members', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const FamilyMembersPage(),
        extra: [
          currentUserIdProvider.overrideWith((ref) => 'user-1'),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('家庭成员'), findsOneWidget);
      expect(find.text('暂无成员'), findsOneWidget);
      expect(find.text('邀请家人加入吧'), findsOneWidget);
    });

    testWidgets('shows member list with roles', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const FamilyMembersPage(),
        family: FamilyState(
          currentFamily: _makeFamily(),
          members: [
            _makeMember(
              id: 'mem-1',
              userId: 'user-1',
              email: 'alice@example.com',
              role: 'owner',
            ),
            _makeMember(
              id: 'mem-2',
              userId: 'user-2',
              email: 'bob@example.com',
              role: 'member',
            ),
          ],
        ),
        extra: [
          currentUserIdProvider.overrideWith((ref) => 'user-1'),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('alice'), findsOneWidget);
      expect(find.text('bob'), findsOneWidget);
      expect(find.text('创建者'), findsOneWidget);
      expect(find.text('成员'), findsOneWidget);
      expect(find.text('(我)'), findsOneWidget);
    });

    testWidgets('shows settings icon for manageable members', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const FamilyMembersPage(),
        family: FamilyState(
          currentFamily: _makeFamily(),
          members: [
            _makeMember(
              id: 'mem-1',
              userId: 'user-1',
              email: 'alice@example.com',
              role: 'owner',
            ),
            _makeMember(
              id: 'mem-2',
              userId: 'user-2',
              email: 'bob@example.com',
              role: 'member',
            ),
          ],
        ),
        extra: [
          currentUserIdProvider.overrideWith((ref) => 'user-1'),
        ],
      ));
      await tester.pumpAndSettle();

      // The owner (user-1) can manage user-2 → settings icon appears
      expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // 5. BudgetPage
  // ═══════════════════════════════════════════════════════════
  group('BudgetPage', () {
    testWidgets('shows empty state when no budget', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const BudgetPage(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('还没有设置预算'), findsOneWidget);
      expect(find.text('设置每月预算，掌控支出'), findsOneWidget);
      // FAB should say '设置预算'
      expect(find.text('设置预算'), findsNWidgets(2)); // FAB + empty state button
    });

    testWidgets('shows loading indicator when loading', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const BudgetPage(),
        budget: const BudgetState(isLoading: true),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders budget data with category list', (tester) async {
      final budget = db.Budget(
        id: 'b-1',
        userId: 'user-1',
        familyId: '',
        year: 2026,
        month: 4,
        totalAmount: 500000,
        createdAt: DateTime(2026, 4, 1),
        updatedAt: DateTime(2026, 4, 1),
      );

      await tester.pumpWidget(wrapWithProviders(
        const BudgetPage(),
        budget: BudgetState(
          currentBudget: budget,
          execution: const BudgetExecutionData(
            totalBudget: 500000,
            totalSpent: 250000,
            executionRate: 0.5,
            categoryExecutions: [
              CategoryExecutionData(
                categoryId: 'cat-1',
                categoryName: '餐饮',
                budgetAmount: 200000,
                spentAmount: 120000,
                executionRate: 0.6,
              ),
              CategoryExecutionData(
                categoryId: 'cat-2',
                categoryName: '交通',
                budgetAmount: 100000,
                spentAmount: 30000,
                executionRate: 0.3,
              ),
            ],
          ),
        ),
      ));
      // Need extra pump for BudgetExecutionCard animation
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();

      expect(find.text('分类预算'), findsOneWidget);
      // Category items may require scrolling in small viewports
      await tester.dragUntilVisible(
        find.text('餐饮'),
        find.byType(Scrollable).last,
        const Offset(0, -200),
      );
      expect(find.text('餐饮'), findsOneWidget);
      expect(find.text('交通'), findsOneWidget);
      // FAB should say '编辑预算' when budget exists
      expect(find.text('编辑预算'), findsOneWidget);
    });

    testWidgets('appbar shows current month', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const BudgetPage(),
      ));
      await tester.pumpAndSettle();

      final now = DateTime.now();
      expect(find.text('${now.month}月预算'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // 6. SetBudgetSheet
  // ═══════════════════════════════════════════════════════════
  group('SetBudgetSheet', () {
    testWidgets('renders title and total budget input', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const SetBudgetSheet(),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Open the sheet
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('设置预算'), findsOneWidget);
      expect(find.text('每月总预算'), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
    });

    testWidgets('shows category budget toggle', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const SetBudgetSheet(),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('分类预算'), findsOneWidget);
      expect(find.text('为每个支出分类设置独立预算'), findsOneWidget);
    });

    testWidgets('has close button', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const SetBudgetSheet(),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.byTooltip('关闭'), findsOneWidget);
    });
  });
}
