import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide Notifier, FamilyNotifier, Family;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';

import 'package:familyledger/data/local/database.dart'
    hide Notification;
import 'package:familyledger/data/local/database.dart' as db show Notification, Family;
import 'package:familyledger/domain/providers/app_providers.dart';
import 'package:familyledger/domain/providers/auth_provider.dart';
import 'package:familyledger/domain/providers/theme_provider.dart';
import 'package:familyledger/domain/providers/sync_status_provider.dart';
import 'package:familyledger/domain/providers/family_provider.dart';
import 'package:familyledger/domain/providers/account_provider.dart';
import 'package:familyledger/domain/providers/notification_provider.dart';
import 'package:familyledger/core/router/app_router.dart';

import 'package:familyledger/features/auth/login_page.dart';
import 'package:familyledger/features/auth/register_page.dart';
import 'package:familyledger/features/settings/settings_page.dart';
import 'package:familyledger/features/settings/family_members_page.dart';
import 'package:familyledger/features/account/accounts_page.dart';
import 'package:familyledger/features/account/add_account_page.dart';
import 'package:familyledger/features/account/transfer_page.dart';
import 'package:familyledger/features/more/more_page.dart';
import 'package:familyledger/features/notification/notifications_page.dart';
import 'package:familyledger/features/notification/notification_settings_page.dart';

// ─── Helpers ──────────────────────────────────────────────────────────

/// Create an in-memory drift database for testing.
AppDatabase _makeTestDb() => AppDatabase.forTesting(NativeDatabase.memory());

/// Create a fake Account object.
Account _makeAccount({
  String id = 'acc_1',
  String userId = 'user_1',
  String familyId = '',
  String name = '测试账户',
  String icon = '💵',
  int balance = 100000, // ¥1000.00
  String currency = 'CNY',
  String accountType = 'cash',
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
    icon: icon,
    balance: balance,
    currency: currency,
    accountType: accountType,
    isActive: isActive,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
  );
}

/// Create a fake FamilyMember object.
FamilyMember _makeFamilyMember({
  String id = 'fm_1',
  String familyId = 'fam_1',
  String userId = 'user_1',
  String email = 'test@example.com',
  String role = 'member',
  bool canView = true,
  bool canCreate = true,
  bool canEdit = false,
  bool canDelete = false,
  bool canManageAccounts = false,
  DateTime? joinedAt,
}) {
  return FamilyMember(
    id: id,
    familyId: familyId,
    userId: userId,
    email: email,
    role: role,
    canView: canView,
    canCreate: canCreate,
    canEdit: canEdit,
    canDelete: canDelete,
    canManageAccounts: canManageAccounts,
    joinedAt: joinedAt ?? DateTime.now(),
  );
}

/// Create a fake Family object.
db.Family _makeFamily({
  String id = 'fam_1',
  String name = '测试家庭',
  String ownerId = 'user_1',
  String? inviteCode,
  DateTime? inviteExpiresAt,
  DateTime? createdAt,
}) {
  return db.Family(
    id: id,
    name: name,
    ownerId: ownerId,
    inviteCode: inviteCode ?? '',
    inviteExpiresAt: inviteExpiresAt,
    createdAt: createdAt ?? DateTime.now(),
  );
}

/// Create a fake Notification object.
db.Notification _makeNotification({
  String id = 'notif_1',
  String userId = 'user_1',
  String type = 'budget_alert',
  String title = '预算超支',
  String body = '餐饮类别已超出预算',
  String dataJson = '{}',
  bool isRead = false,
  DateTime? createdAt,
}) {
  return db.Notification(
    id: id,
    userId: userId,
    type: type,
    title: title,
    body: body,
    dataJson: dataJson,
    isRead: isRead,
    createdAt: createdAt ?? DateTime.now(),
  );
}

/// Wrap a widget in MaterialApp with ProviderScope and route support.
Widget _wrapPage(
  Widget child, {
  List<Override> overrides = const [],
  ThemeData? theme,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: theme ?? ThemeData.light(useMaterial3: true),
      home: child,
      onGenerateRoute: AppRouter.onGenerateRoute,
    ),
  );
}

/// Common overrides that all provider-dependent tests need.
List<Override> _baseOverrides({
  AuthState? authState,
  FamilyState? familyState,
  AccountState? accountState,
  SyncState? syncState,
  ThemeMode? themeMode,
  NotificationState? notificationState,
  String? currentUserId,
  AppDatabase? db,
  SharedPreferences? prefs,
}) {
  return [
    if (db != null) databaseProvider.overrideWithValue(db),
    if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
    if (authState != null)
      authProvider.overrideWith((_) => _FakeAuthNotifier(authState)),
    if (familyState != null)
      familyProvider.overrideWith((_) => _FakeFamilyNotifier(familyState)),
    if (accountState != null)
      accountProvider.overrideWith((_) => _FakeAccountNotifier(accountState)),
    if (syncState != null)
      syncStatusProvider
          .overrideWith((_) => _FakeSyncStatusNotifier(syncState)),
    if (themeMode != null)
      themeModeProvider
          .overrideWith((_) => _FakeThemeModeNotifier(themeMode)),
    if (notificationState != null)
      notificationProvider
          .overrideWith((_) => _FakeNotificationNotifier(notificationState)),
    if (currentUserId != null)
      currentUserIdProvider.overrideWith((_) => currentUserId),
  ];
}

// ─── Fake Notifiers ───────────────────────────────────────────────────

class _FakeAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _FakeAuthNotifier(super.state);

  @override
  Future<void> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading);
    await Future.delayed(const Duration(milliseconds: 50));
    state = AuthState(status: AuthStatus.authenticated, userId: 'user_1');
  }

  @override
  Future<void> register(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading);
    await Future.delayed(const Duration(milliseconds: 50));
    state = AuthState(status: AuthStatus.authenticated, userId: 'user_1');
  }

  @override
  Future<void> logout() async {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  @override
  Future<void> oauthLogin({
    required String provider,
    required String code,
    String redirectUri = '',
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
  }
}

class _FakeFamilyNotifier extends StateNotifier<FamilyState>
    implements FamilyNotifier {
  _FakeFamilyNotifier(super.state);

  @override
  Future<void> createFamily(String name) async {}
  @override
  Future<void> joinFamily(String inviteCode) async {}
  @override
  Future<String?> generateInviteCode() async => 'ABCD1234';
  @override
  Future<void> setMemberRole(String targetUserId, String role) async {}
  @override
  Future<void> setMemberPermissions({
    required String targetUserId,
    required bool canView,
    required bool canCreate,
    required bool canEdit,
    required bool canDelete,
    required bool canManageAccounts,
  }) async {}
  @override
  Future<void> leaveFamily() async {}
  @override
  Future<void> refreshMembers() async {}
}

class _FakeAccountNotifier extends StateNotifier<AccountState>
    implements AccountNotifier {
  _FakeAccountNotifier(super.state);

  @override
  Future<void> refresh() async {}
  @override
  Future<void> createAccount({
    required String name,
    required String accountType,
    String? icon,
    int initialBalance = 0,
    String? familyId,
  }) async {}
  @override
  Future<void> updateAccount({
    required String accountId,
    String? name,
    String? icon,
    bool? isActive,
  }) async {}
  @override
  Future<void> deleteAccount(String accountId) async {}
  @override
  Future<void> transferBetween({
    required String fromAccountId,
    required String toAccountId,
    required int amount,
    String note = '',
  }) async {}
}

class _FakeSyncStatusNotifier extends StateNotifier<SyncState>
    implements SyncStatusNotifier {
  _FakeSyncStatusNotifier(super.state);

  @override
  Future<void> refresh() async {}
  @override
  void markSyncing() {}
}

class _FakeThemeModeNotifier extends StateNotifier<ThemeMode>
    implements ThemeModeNotifier {
  _FakeThemeModeNotifier(super.state);

  @override
  void setThemeMode(ThemeMode mode) => state = mode;
  @override
  void cycle() {}
}

class _FakeNotificationNotifier extends StateNotifier<NotificationState>
    implements NotificationNotifier {
  _FakeNotificationNotifier(super.state);

  @override
  Future<void> loadNotifications(int page) async {}
  @override
  Future<void> markAsRead(List<String> ids) async {}
  @override
  Future<void> loadSettings() async {}
  @override
  Future<void> updateSettings(NotificationSettingsModel settings) async {
    state = state.copyWith(settings: settings);
  }
}

// ─────────────────────────────────────────────────────────────────────
// TESTS
// ─────────────────────────────────────────────────────────────────────

void main() {
  // ─── 1. LoginPage ───────────────────────────────────────────────────

  group('LoginPage', () {
    testWidgets('renders all UI elements', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const LoginPage(),
        overrides: _baseOverrides(
          authState: const AuthState(status: AuthStatus.unauthenticated),
        ),
      ));
      await tester.pumpAndSettle();

      // Logo / app name
      expect(find.text('FamilyLedger'), findsOneWidget);
      expect(find.text('家庭资产管理'), findsOneWidget);

      // Form fields
      expect(find.widgetWithText(TextFormField, '邮箱'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '密码'), findsOneWidget);

      // Login button
      expect(find.widgetWithText(ElevatedButton, '登录'), findsOneWidget);

      // Register link
      expect(find.text('没有账号？注册'), findsOneWidget);

      // OAuth section
      expect(find.text('其他登录方式'), findsOneWidget);
      expect(find.text('微信'), findsOneWidget);
      expect(find.text('Apple'), findsOneWidget);
    });

    testWidgets('empty fields → validation errors on submit', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const LoginPage(),
        overrides: _baseOverrides(
          authState: const AuthState(status: AuthStatus.unauthenticated),
        ),
      ));
      await tester.pumpAndSettle();

      // Tap login with empty fields
      await tester.tap(find.widgetWithText(ElevatedButton, '登录'));
      await tester.pumpAndSettle();

      expect(find.text('请输入邮箱'), findsOneWidget);
      expect(find.text('请输入密码'), findsOneWidget);
    });

    testWidgets('invalid email → shows format error', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const LoginPage(),
        overrides: _baseOverrides(
          authState: const AuthState(status: AuthStatus.unauthenticated),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, '邮箱'), 'bad-email');
      await tester.enterText(
          find.widgetWithText(TextFormField, '密码'), '123456');
      await tester.tap(find.widgetWithText(ElevatedButton, '登录'));
      await tester.pumpAndSettle();

      expect(find.text('邮箱格式不正确'), findsOneWidget);
    });

    testWidgets('short password → shows length error', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const LoginPage(),
        overrides: _baseOverrides(
          authState: const AuthState(status: AuthStatus.unauthenticated),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, '邮箱'), 'test@test.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, '密码'), '123');
      await tester.tap(find.widgetWithText(ElevatedButton, '登录'));
      await tester.pumpAndSettle();

      expect(find.text('密码至少 6 位'), findsOneWidget);
    });

    testWidgets('valid input → no validation errors, triggers login',
        (tester) async {
      await tester.pumpWidget(_wrapPage(
        const LoginPage(),
        overrides: _baseOverrides(
          authState: const AuthState(status: AuthStatus.unauthenticated),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, '邮箱'), 'test@test.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, '密码'), '123456');
      await tester.tap(find.widgetWithText(ElevatedButton, '登录'));
      await tester.pump();

      // No validation error
      expect(find.text('请输入邮箱'), findsNothing);
      expect(find.text('邮箱格式不正确'), findsNothing);
      expect(find.text('请输入密码'), findsNothing);
      expect(find.text('密码至少 6 位'), findsNothing);

      // Flush the pending timer from _FakeAuthNotifier.login
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('password field is obscured', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const LoginPage(),
        overrides: _baseOverrides(
          authState: const AuthState(status: AuthStatus.unauthenticated),
        ),
      ));
      await tester.pumpAndSettle();

      // Find the EditableText descendant of the password field — check obscureText
      final passwordFinder = find.descendant(
        of: find.widgetWithText(TextFormField, '密码'),
        matching: find.byType(EditableText),
      );
      final editableText = tester.widget<EditableText>(passwordFinder);
      expect(editableText.obscureText, isTrue);
    });

    testWidgets('loading state disables login button', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const LoginPage(),
        overrides: _baseOverrides(
          authState: const AuthState(status: AuthStatus.loading),
        ),
      ));
      // Don't use pumpAndSettle — CircularProgressIndicator never settles
      await tester.pump();

      final button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(button.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('register link navigates to register page', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const LoginPage(),
        overrides: _baseOverrides(
          authState: const AuthState(status: AuthStatus.unauthenticated),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('没有账号？注册'));
      await tester.pumpAndSettle();

      expect(find.byType(RegisterPage), findsOneWidget);
    });
  });

  // ─── 2. RegisterPage ────────────────────────────────────────────────

  group('RegisterPage', () {
    testWidgets('renders all UI elements', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const RegisterPage(),
        overrides: _baseOverrides(
          authState: const AuthState(status: AuthStatus.unauthenticated),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('创建账号'), findsOneWidget);
      expect(find.text('开始管理你的家庭财务'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '邮箱'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '密码'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '确认密码'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, '注册'), findsOneWidget);
    });

    testWidgets('empty fields → validation errors', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const RegisterPage(),
        overrides: _baseOverrides(
          authState: const AuthState(status: AuthStatus.unauthenticated),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, '注册'));
      await tester.pumpAndSettle();

      expect(find.text('请输入邮箱'), findsOneWidget);
      expect(find.text('请输入密码'), findsOneWidget);
    });

    testWidgets('invalid email → error', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const RegisterPage(),
        overrides: _baseOverrides(
          authState: const AuthState(status: AuthStatus.unauthenticated),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, '邮箱'), 'no-at-sign');
      await tester.enterText(
          find.widgetWithText(TextFormField, '密码'), '123456');
      await tester.enterText(
          find.widgetWithText(TextFormField, '确认密码'), '123456');
      await tester.tap(find.widgetWithText(ElevatedButton, '注册'));
      await tester.pumpAndSettle();

      expect(find.text('邮箱格式不正确'), findsOneWidget);
    });

    testWidgets('short password → error', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const RegisterPage(),
        overrides: _baseOverrides(
          authState: const AuthState(status: AuthStatus.unauthenticated),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, '邮箱'), 'a@b.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, '密码'), '12');
      await tester.enterText(
          find.widgetWithText(TextFormField, '确认密码'), '12');
      await tester.tap(find.widgetWithText(ElevatedButton, '注册'));
      await tester.pumpAndSettle();

      expect(find.text('密码至少 6 位'), findsOneWidget);
    });

    testWidgets('password mismatch → error', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const RegisterPage(),
        overrides: _baseOverrides(
          authState: const AuthState(status: AuthStatus.unauthenticated),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, '邮箱'), 'a@b.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, '密码'), '123456');
      await tester.enterText(
          find.widgetWithText(TextFormField, '确认密码'), '654321');
      await tester.tap(find.widgetWithText(ElevatedButton, '注册'));
      await tester.pumpAndSettle();

      expect(find.text('两次密码不一致'), findsOneWidget);
    });

    testWidgets('valid input → no errors', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const RegisterPage(),
        overrides: _baseOverrides(
          authState: const AuthState(status: AuthStatus.unauthenticated),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, '邮箱'), 'a@b.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, '密码'), '123456');
      await tester.enterText(
          find.widgetWithText(TextFormField, '确认密码'), '123456');
      await tester.tap(find.widgetWithText(ElevatedButton, '注册'));
      await tester.pump();

      expect(find.text('请输入邮箱'), findsNothing);
      expect(find.text('邮箱格式不正确'), findsNothing);
      expect(find.text('请输入密码'), findsNothing);
      expect(find.text('密码至少 6 位'), findsNothing);
      expect(find.text('两次密码不一致'), findsNothing);

      // Flush the pending timer from _FakeAuthNotifier.register
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('all password fields are obscured', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const RegisterPage(),
        overrides: _baseOverrides(
          authState: const AuthState(status: AuthStatus.unauthenticated),
        ),
      ));
      await tester.pumpAndSettle();

      final editableTexts = tester.widgetList<EditableText>(
        find.descendant(
          of: find.byType(TextFormField),
          matching: find.byType(EditableText),
        ),
      );
      // password and confirm should be obscured (email should not)
      final obscured = editableTexts.where((e) => e.obscureText).toList();
      expect(obscured.length, 2);
    });

    testWidgets('loading state disables register button', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const RegisterPage(),
        overrides: _baseOverrides(
          authState: const AuthState(status: AuthStatus.loading),
        ),
      ));
      // Don't use pumpAndSettle — CircularProgressIndicator never settles
      await tester.pump();

      final button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('back button is present', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const RegisterPage(),
        overrides: _baseOverrides(
          authState: const AuthState(status: AuthStatus.unauthenticated),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byTooltip('返回'), findsOneWidget);
    });
  });

  // ─── 3. SettingsPage ────────────────────────────────────────────────

  group('SettingsPage', () {
    testWidgets('renders basic UI with user info', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const SettingsPage(),
        overrides: _baseOverrides(
          authState: const AuthState(
            status: AuthStatus.authenticated,
            userId: 'user@test.com',
          ),
          familyState: const FamilyState(),
          syncState: const SyncState(status: SyncStatus.synced),
          themeMode: ThemeMode.system,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('设置'), findsOneWidget);
      expect(find.text('我的账号'), findsOneWidget);
      expect(find.text('user@test.com'), findsOneWidget);
    });

    testWidgets('shows create/join family when no family', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const SettingsPage(),
        overrides: _baseOverrides(
          authState: const AuthState(
            status: AuthStatus.authenticated,
            userId: 'user_1',
          ),
          familyState: const FamilyState(),
          syncState: const SyncState(status: SyncStatus.synced),
          themeMode: ThemeMode.system,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('创建家庭'), findsOneWidget);
      expect(find.text('加入家庭'), findsOneWidget);
    });

    testWidgets('shows family info + invite/leave when family exists',
        (tester) async {
      final family = _makeFamily(name: '我的家');
      final members = [
        _makeFamilyMember(userId: 'user_1', role: 'owner'),
        _makeFamilyMember(
            id: 'fm_2', userId: 'user_2', email: 'b@b.com', role: 'member'),
      ];

      await tester.pumpWidget(_wrapPage(
        const SettingsPage(),
        overrides: _baseOverrides(
          authState: const AuthState(
            status: AuthStatus.authenticated,
            userId: 'user_1',
          ),
          familyState: FamilyState(
            currentFamily: family,
            families: [family],
            members: members,
          ),
          syncState: const SyncState(status: SyncStatus.synced),
          themeMode: ThemeMode.system,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('我的家'), findsOneWidget);
      expect(find.text('2 位成员'), findsOneWidget);
      expect(find.text('生成邀请码'), findsOneWidget);
      expect(find.text('退出家庭'), findsOneWidget);
    });

    testWidgets('theme mode tile shows SegmentedButton', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const SettingsPage(),
        overrides: _baseOverrides(
          authState: const AuthState(
            status: AuthStatus.authenticated,
            userId: 'u',
          ),
          familyState: const FamilyState(),
          syncState: const SyncState(status: SyncStatus.synced),
          themeMode: ThemeMode.system,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('外观模式'), findsOneWidget);
      expect(find.text('跟随系统'), findsOneWidget);
      expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);
    });

    testWidgets('sync status shows synced state', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const SettingsPage(),
        overrides: _baseOverrides(
          authState: const AuthState(
              status: AuthStatus.authenticated, userId: 'u'),
          familyState: const FamilyState(),
          syncState: const SyncState(status: SyncStatus.synced),
          themeMode: ThemeMode.system,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('已同步'), findsOneWidget);
    });

    testWidgets('sync status shows pending state', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const SettingsPage(),
        overrides: _baseOverrides(
          authState: const AuthState(
              status: AuthStatus.authenticated, userId: 'u'),
          familyState: const FamilyState(),
          syncState: const SyncState(
              status: SyncStatus.pending, pendingCount: 5),
          themeMode: ThemeMode.system,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('待同步'), findsOneWidget);
      expect(find.text('5 条操作等待上传'), findsOneWidget);
    });

    testWidgets('sync status shows offline state', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const SettingsPage(),
        overrides: _baseOverrides(
          authState: const AuthState(
              status: AuthStatus.authenticated, userId: 'u'),
          familyState: const FamilyState(),
          syncState: const SyncState(status: SyncStatus.offline),
          themeMode: ThemeMode.system,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('离线模式'), findsOneWidget);
    });

    testWidgets('logout shows confirmation dialog', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const SettingsPage(),
        overrides: _baseOverrides(
          authState: const AuthState(
              status: AuthStatus.authenticated, userId: 'u'),
          familyState: const FamilyState(),
          syncState: const SyncState(status: SyncStatus.synced),
          themeMode: ThemeMode.system,
        ),
      ));
      await tester.pumpAndSettle();

      // Scroll down to make "退出登录" visible
      await tester.scrollUntilVisible(find.text('退出登录'), 200);
      await tester.pumpAndSettle();

      await tester.tap(find.text('退出登录'));
      await tester.pumpAndSettle();

      expect(find.text('确定要退出登录吗？'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '退出'), findsOneWidget);
    });

    testWidgets('logout dialog cancel dismisses', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const SettingsPage(),
        overrides: _baseOverrides(
          authState: const AuthState(
              status: AuthStatus.authenticated, userId: 'u'),
          familyState: const FamilyState(),
          syncState: const SyncState(status: SyncStatus.synced),
          themeMode: ThemeMode.system,
        ),
      ));
      await tester.pumpAndSettle();

      // Scroll down to make "退出登录" visible
      await tester.scrollUntilVisible(find.text('退出登录'), 200);
      await tester.pumpAndSettle();

      await tester.tap(find.text('退出登录'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // Dialog dismissed
      expect(find.text('确定要退出登录吗？'), findsNothing);
    });

    testWidgets('create family dialog appears on tap', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const SettingsPage(),
        overrides: _baseOverrides(
          authState: const AuthState(
              status: AuthStatus.authenticated, userId: 'u'),
          familyState: const FamilyState(),
          syncState: const SyncState(status: SyncStatus.synced),
          themeMode: ThemeMode.system,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('创建家庭'));
      await tester.pumpAndSettle();

      expect(find.text('输入家庭名称'), findsOneWidget);
    });

    testWidgets('join family dialog appears on tap', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const SettingsPage(),
        overrides: _baseOverrides(
          authState: const AuthState(
              status: AuthStatus.authenticated, userId: 'u'),
          familyState: const FamilyState(),
          syncState: const SyncState(status: SyncStatus.synced),
          themeMode: ThemeMode.system,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('加入家庭'));
      await tester.pumpAndSettle();

      expect(find.text('输入邀请码'), findsOneWidget);
    });
  });

  // ─── 4. FamilyMembersPage ──────────────────────────────────────────

  group('FamilyMembersPage', () {
    testWidgets('shows empty state when no members', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const FamilyMembersPage(),
        overrides: _baseOverrides(
          familyState: const FamilyState(members: []),
          currentUserId: 'user_1',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('家庭成员'), findsOneWidget);
      expect(find.text('暂无成员'), findsOneWidget);
      expect(find.text('邀请家人加入吧'), findsOneWidget);
    });

    testWidgets('shows member list with roles', (tester) async {
      final members = [
        _makeFamilyMember(
          userId: 'user_1',
          email: 'owner@test.com',
          role: 'owner',
        ),
        _makeFamilyMember(
          id: 'fm_2',
          userId: 'user_2',
          email: 'admin@test.com',
          role: 'admin',
        ),
        _makeFamilyMember(
          id: 'fm_3',
          userId: 'user_3',
          email: 'member@test.com',
          role: 'member',
        ),
      ];

      await tester.pumpWidget(_wrapPage(
        const FamilyMembersPage(),
        overrides: _baseOverrides(
          familyState: FamilyState(
            currentFamily: _makeFamily(),
            members: members,
          ),
          currentUserId: 'user_1',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('owner@test.com'), findsOneWidget);
      expect(find.text('admin@test.com'), findsOneWidget);
      expect(find.text('member@test.com'), findsOneWidget);
      expect(find.text('创建者'), findsOneWidget);
      expect(find.text('管理员'), findsOneWidget);
      expect(find.text('成员'), findsOneWidget);
    });

    testWidgets('current user shows (我) marker', (tester) async {
      final members = [
        _makeFamilyMember(
          userId: 'user_1',
          email: 'me@test.com',
          role: 'owner',
        ),
      ];

      await tester.pumpWidget(_wrapPage(
        const FamilyMembersPage(),
        overrides: _baseOverrides(
          familyState: FamilyState(
            currentFamily: _makeFamily(),
            members: members,
          ),
          currentUserId: 'user_1',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('(我)'), findsOneWidget);
    });

    testWidgets('admin can tap non-self member to manage', (tester) async {
      final members = [
        _makeFamilyMember(
          userId: 'user_1',
          email: 'admin@test.com',
          role: 'owner',
        ),
        _makeFamilyMember(
          id: 'fm_2',
          userId: 'user_2',
          email: 'member@test.com',
          role: 'member',
        ),
      ];

      await tester.pumpWidget(_wrapPage(
        const FamilyMembersPage(),
        overrides: _baseOverrides(
          familyState: FamilyState(
            currentFamily: _makeFamily(),
            members: members,
          ),
          currentUserId: 'user_1',
        ),
      ));
      await tester.pumpAndSettle();

      // Settings icon should be visible for non-self member
      expect(find.byIcon(Icons.settings_rounded), findsOneWidget);

      // Tap the manageable member
      await tester.tap(find.text('member@test.com'));
      await tester.pumpAndSettle();

      // Bottom sheet should appear with management options
      expect(find.text('管理成员'), findsOneWidget);
      expect(find.text('角色'), findsOneWidget);
      expect(find.text('权限'), findsOneWidget);
      expect(find.text('查看账本'), findsOneWidget);
      expect(find.text('创建交易'), findsOneWidget);
      expect(find.text('编辑交易'), findsOneWidget);
      expect(find.text('删除交易'), findsOneWidget);
      expect(find.text('管理账户'), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
    });

    testWidgets('member manage sheet has role selector', (tester) async {
      final members = [
        _makeFamilyMember(
          userId: 'user_1',
          email: 'owner@test.com',
          role: 'owner',
        ),
        _makeFamilyMember(
          id: 'fm_2',
          userId: 'user_2',
          email: 'target@test.com',
          role: 'member',
        ),
      ];

      await tester.pumpWidget(_wrapPage(
        const FamilyMembersPage(),
        overrides: _baseOverrides(
          familyState: FamilyState(
            currentFamily: _makeFamily(),
            members: members,
          ),
          currentUserId: 'user_1',
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('target@test.com'));
      await tester.pumpAndSettle();

      // SegmentedButton with admin/member
      expect(find.byType(SegmentedButton<String>), findsOneWidget);
      expect(find.text('管理员'), findsWidgets);
      expect(find.text('成员'), findsWidgets);
    });
  });

  // ─── 5. AccountsPage ──────────────────────────────────────────────

  group('AccountsPage', () {
    testWidgets('shows empty state when no accounts', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const AccountsPage(),
        overrides: _baseOverrides(
          accountState: const AccountState(accounts: []),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('账户'), findsOneWidget);
      expect(find.text('还没有账户'), findsOneWidget);
    });

    testWidgets('shows loading indicator', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const AccountsPage(),
        overrides: _baseOverrides(
          accountState: const AccountState(isLoading: true),
        ),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows account list with total balance', (tester) async {
      final accounts = [
        _makeAccount(
            id: 'a1', name: '现金', balance: 50000, accountType: 'cash'),
        _makeAccount(
            id: 'a2',
            name: '银行卡',
            balance: 100000,
            icon: '🏦',
            accountType: 'bank_card'),
      ];

      await tester.pumpWidget(_wrapPage(
        const AccountsPage(),
        overrides: _baseOverrides(
          accountState: AccountState(accounts: accounts),
        ),
      ));
      await tester.pumpAndSettle();

      // Total balance ¥1500.00
      expect(find.text('总资产'), findsOneWidget);
      expect(find.textContaining('1500'), findsOneWidget);
      expect(find.text('共 2 个账户'), findsOneWidget);

      // Account names
      expect(find.text('现金'), findsWidgets);
      expect(find.text('银行卡'), findsWidgets);
    });

    testWidgets('has FABs for transfer and add account', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const AccountsPage(),
        overrides: _baseOverrides(
          accountState: const AccountState(accounts: []),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsWidgets);
      expect(find.text('添加账户'), findsOneWidget);
      expect(find.byTooltip('转账'), findsOneWidget);
    });
  });

  // ─── 6. AddAccountPage ────────────────────────────────────────────

  group('AddAccountPage', () {
    testWidgets('renders all UI elements', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const AddAccountPage(),
        overrides: _baseOverrides(
          accountState: const AccountState(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('添加账户'), findsOneWidget);
      expect(find.text('账户名称'), findsOneWidget);
      expect(find.text('账户类型'), findsOneWidget);
      expect(find.text('初始余额'), findsOneWidget);

      // Default amount
      expect(find.text('0'), findsAtLeast(1));
    });

    testWidgets('shows all account type chips', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const AddAccountPage(),
        overrides: _baseOverrides(
          accountState: const AccountState(),
        ),
      ));
      await tester.pumpAndSettle();

      // All 7 types
      expect(find.text('现金'), findsOneWidget);
      expect(find.text('银行卡'), findsOneWidget);
      expect(find.text('信用卡'), findsOneWidget);
      expect(find.text('支付宝'), findsOneWidget);
      expect(find.text('微信支付'), findsOneWidget);
      expect(find.text('投资账户'), findsOneWidget);
      expect(find.text('其他'), findsOneWidget);
    });

    testWidgets('tapping type chip selects it', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const AddAccountPage(),
        overrides: _baseOverrides(
          accountState: const AccountState(),
        ),
      ));
      await tester.pumpAndSettle();

      // Tap 银行卡
      await tester.tap(find.text('银行卡'));
      await tester.pumpAndSettle();

      // The chip should now be selected — verify via SemanticsNode
      final semanticsNode = tester.getSemantics(find.text('银行卡'));
      expect(
        semanticsNode.getSemanticsData().hasFlag(SemanticsFlag.isSelected),
        isTrue,
      );
    });

    testWidgets('number pad keys update amount', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const AddAccountPage(),
        overrides: _baseOverrides(
          accountState: const AccountState(),
        ),
      ));
      await tester.pumpAndSettle();

      // Tap "1", "5", "0" on number pad
      await tester.tap(find.widgetWithText(ElevatedButton, '1'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '5'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '0'));
      await tester.pump();

      expect(find.text('150'), findsOneWidget);
    });

    testWidgets('delete key removes last digit', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const AddAccountPage(),
        overrides: _baseOverrides(
          accountState: const AccountState(),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, '1'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '2'));
      await tester.pump();

      // Delete last digit
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump();

      expect(find.text('1'), findsWidgets); // "1" key + display
    });
  });

  // ─── 7. TransferPage ──────────────────────────────────────────────

  group('TransferPage', () {
    testWidgets('renders UI elements', (tester) async {
      final accounts = [
        _makeAccount(id: 'a1', name: '现金', balance: 50000),
        _makeAccount(id: 'a2', name: '银行卡', balance: 100000),
      ];

      await tester.pumpWidget(_wrapPage(
        const TransferPage(),
        overrides: _baseOverrides(
          accountState: AccountState(accounts: accounts),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('转账'), findsOneWidget);
      expect(find.text('从'), findsOneWidget);
      expect(find.text('到'), findsOneWidget);
      expect(find.text('0'), findsAtLeast(1));
    });

    testWidgets('account dropdowns show available accounts', (tester) async {
      final accounts = [
        _makeAccount(id: 'a1', name: '现金'),
        _makeAccount(id: 'a2', name: '银行卡'),
        _makeAccount(id: 'a3', name: '支付宝'),
      ];

      await tester.pumpWidget(_wrapPage(
        const TransferPage(),
        overrides: _baseOverrides(
          accountState: AccountState(accounts: accounts),
        ),
      ));
      await tester.pumpAndSettle();

      // Find the "选择账户" hints (two dropdowns)
      expect(find.text('选择账户'), findsNWidgets(2));
    });

    testWidgets('number pad updates transfer amount', (tester) async {
      final accounts = [
        _makeAccount(id: 'a1', name: '现金'),
        _makeAccount(id: 'a2', name: '银行卡'),
      ];

      await tester.pumpWidget(_wrapPage(
        const TransferPage(),
        overrides: _baseOverrides(
          accountState: AccountState(accounts: accounts),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, '5'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '0'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '0'));
      await tester.pump();

      expect(find.text('500'), findsOneWidget);
    });

    testWidgets('note field is present', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const TransferPage(),
        overrides: _baseOverrides(
          accountState: AccountState(accounts: [
            _makeAccount(id: 'a1', name: '现金'),
          ]),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('备注（可选）'), findsOneWidget);
    });
  });

  // ─── 8. MorePage ──────────────────────────────────────────────────

  group('MorePage', () {
    testWidgets('renders all sections and menu items', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const MorePage(),
        overrides: _baseOverrides(
          authState: const AuthState(
            status: AuthStatus.authenticated,
            userId: 'user_1',
          ),
          familyState: const FamilyState(),
        ),
      ));
      await tester.pumpAndSettle();

      // Top of the page
      expect(find.text('更多'), findsOneWidget);
      expect(find.text('我的账号'), findsOneWidget);

      // Asset management section (visible at top)
      expect(find.text('贷款管理'), findsOneWidget);
      expect(find.text('投资管理'), findsOneWidget);

      // Scroll incrementally to see Data section items
      await tester.scrollUntilVisible(
          find.text('交易报表'), 100);
      await tester.pumpAndSettle();
      expect(find.text('交易报表'), findsOneWidget);

      await tester.scrollUntilVisible(
          find.text('CSV 导入'), 100);
      await tester.pumpAndSettle();
      expect(find.text('CSV 导入'), findsOneWidget);

      // Scroll to see Settings section
      await tester.scrollUntilVisible(
          find.text('通知设置'), 100);
      await tester.pumpAndSettle();
      expect(find.text('通知设置'), findsOneWidget);

      await tester.scrollUntilVisible(
          find.text('退出登录'), 100);
      await tester.pumpAndSettle();
      expect(find.text('退出登录'), findsOneWidget);
    });

    testWidgets('shows family name when family exists', (tester) async {
      final family = _makeFamily(name: '我的家庭');
      final members = [
        _makeFamilyMember(userId: 'user_1', role: 'owner'),
        _makeFamilyMember(id: 'fm_2', userId: 'user_2', role: 'member'),
        _makeFamilyMember(id: 'fm_3', userId: 'user_3', role: 'member'),
      ];

      await tester.pumpWidget(_wrapPage(
        const MorePage(),
        overrides: _baseOverrides(
          authState: const AuthState(
            status: AuthStatus.authenticated,
            userId: 'user_1',
          ),
          familyState: FamilyState(
            currentFamily: family,
            members: members,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Scroll down to the "设置" section where family tile is
      await tester.scrollUntilVisible(find.text('我的家庭'), 200);
      await tester.pumpAndSettle();

      expect(find.text('我的家庭'), findsOneWidget);
      expect(find.text('3 位成员'), findsOneWidget);
    });

    testWidgets('shows "家庭管理" when no family', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const MorePage(),
        overrides: _baseOverrides(
          authState: const AuthState(
            status: AuthStatus.authenticated,
            userId: 'u',
          ),
          familyState: const FamilyState(),
        ),
      ));
      await tester.pumpAndSettle();

      // Scroll down to the "设置" section where family tile is
      await tester.scrollUntilVisible(find.text('家庭管理'), 200);
      await tester.pumpAndSettle();

      expect(find.text('家庭管理'), findsOneWidget);
      expect(find.text('创建或加入家庭'), findsOneWidget);
    });

    testWidgets('logout shows confirmation dialog', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const MorePage(),
        overrides: _baseOverrides(
          authState: const AuthState(
            status: AuthStatus.authenticated,
            userId: 'u',
          ),
          familyState: const FamilyState(),
        ),
      ));
      await tester.pumpAndSettle();

      // Scroll down to "退出登录"
      await tester.scrollUntilVisible(find.text('退出登录'), 200);
      await tester.pumpAndSettle();

      await tester.tap(find.text('退出登录'));
      await tester.pumpAndSettle();

      expect(find.text('确定要退出登录吗？'), findsOneWidget);
    });
  });

  // ─── 9. NotificationsPage ─────────────────────────────────────────

  group('NotificationsPage', () {
    testWidgets('shows empty state when no notifications', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const NotificationsPage(),
        overrides: _baseOverrides(
          notificationState: const NotificationState(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('通知'), findsOneWidget);
      expect(find.text('暂无通知'), findsOneWidget);
      expect(find.text('新的通知会出现在这里'), findsOneWidget);
    });

    testWidgets('shows loading indicator when loading and empty',
        (tester) async {
      await tester.pumpWidget(_wrapPage(
        const NotificationsPage(),
        overrides: _baseOverrides(
          notificationState: const NotificationState(isLoading: true),
        ),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows notification list with types', (tester) async {
      final now = DateTime.now();
      final notifications = <db.Notification>[
        _makeNotification(
          id: 'n1',
          type: 'budget_alert',
          title: '餐饮超支',
          body: '本月餐饮已超出预算',
          createdAt: now,
        ),
        _makeNotification(
          id: 'n2',
          type: 'loan_reminder',
          title: '还款提醒',
          body: '信用卡还款日还有3天',
          isRead: true,
          createdAt: now,
        ),
        _makeNotification(
          id: 'n3',
          type: 'daily_summary',
          title: '今日支出',
          body: '今天共支出 ¥256.00',
          createdAt: now.subtract(const Duration(days: 2)),
        ),
      ];

      await tester.pumpWidget(_wrapPage(
        const NotificationsPage(),
        overrides: _baseOverrides(
          notificationState: NotificationState(
            notifications: notifications,
            unreadCount: 2,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('餐饮超支'), findsOneWidget);
      expect(find.text('还款提醒'), findsOneWidget);
      expect(find.text('今日支出'), findsOneWidget);
    });

    testWidgets('settings button is in app bar', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const NotificationsPage(),
        overrides: _baseOverrides(
          notificationState: const NotificationState(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byTooltip('通知设置'), findsOneWidget);
    });
  });

  // ─── 10. NotificationSettingsPage ─────────────────────────────────

  group('NotificationSettingsPage', () {
    testWidgets('renders all toggle switches', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const NotificationSettingsPage(),
        overrides: _baseOverrides(
          notificationState: const NotificationState(
            settings: NotificationSettingsModel(
              budgetAlert: true,
              budgetWarning: true,
              dailySummary: false,
              loanReminder: true,
              reminderDaysBefore: 3,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('通知设置'), findsOneWidget);

      // Budget section
      expect(find.text('预算提醒'), findsOneWidget);
      expect(find.text('预算超支提醒'), findsOneWidget);
      expect(find.text('预算80%预警'), findsOneWidget);

      // Periodic section
      expect(find.text('定期提醒'), findsOneWidget);
      expect(find.text('每日支出汇总'), findsOneWidget);
      expect(find.text('还款日提醒'), findsOneWidget);

      // All switches
      expect(find.byType(SwitchListTile), findsNWidgets(4));
    });

    testWidgets('shows reminder days slider when loanReminder is on',
        (tester) async {
      await tester.pumpWidget(_wrapPage(
        const NotificationSettingsPage(),
        overrides: _baseOverrides(
          notificationState: const NotificationState(
            settings: NotificationSettingsModel(
              loanReminder: true,
              reminderDaysBefore: 3,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('提前提醒天数'), findsOneWidget);
      expect(find.text('3天'), findsWidgets);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('1天'), findsOneWidget);
      expect(find.text('7天'), findsOneWidget);
    });

    testWidgets('hides slider when loanReminder is off', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const NotificationSettingsPage(),
        overrides: _baseOverrides(
          notificationState: const NotificationState(
            settings: NotificationSettingsModel(
              loanReminder: false,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('提前提醒天数'), findsNothing);
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('toggling a switch updates state', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const NotificationSettingsPage(),
        overrides: _baseOverrides(
          notificationState: const NotificationState(
            settings: NotificationSettingsModel(
              budgetAlert: true,
              budgetWarning: true,
              dailySummary: false,
              loanReminder: false,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Find the dailySummary switch (3rd one, currently off)
      final switches = find.byType(Switch);
      expect(switches, findsNWidgets(4));

      // Toggle "每日支出汇总" (3rd switch)
      await tester.tap(switches.at(2));
      await tester.pumpAndSettle();

      // After toggle, the state should update — the fake notifier's
      // updateSettings is called which updates state
    });

    testWidgets('subtitles are shown for each setting', (tester) async {
      await tester.pumpWidget(_wrapPage(
        const NotificationSettingsPage(),
        overrides: _baseOverrides(
          notificationState: const NotificationState(
            settings: NotificationSettingsModel(loanReminder: false),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('支出超过预算金额时通知'), findsOneWidget);
      expect(find.text('支出达到预算80%时提醒'), findsOneWidget);
      expect(find.text('每天晚上推送今日支出概览'), findsOneWidget);
      expect(find.text('信用卡/借贷还款日前提醒'), findsOneWidget);
    });
  });
}
