import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:familyledger/domain/providers/auth_provider.dart';
import 'package:familyledger/features/auth/login_page.dart';
import 'package:familyledger/features/auth/register_page.dart';

class _FakeAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _FakeAuthNotifier([AuthState? initial])
      : super(initial ?? const AuthState(status: AuthStatus.unauthenticated));

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isMethod) return Future<void>.value();
    return null;
  }
}

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: [
      authProvider.overrideWith((_) => _FakeAuthNotifier()),
      ...overrides,
    ],
    child: MaterialApp(
      theme: ThemeData.light(useMaterial3: true),
      routes: {
        '/home': (_) => const Scaffold(body: Text('Home')),
        '/register': (_) => const RegisterPage(),
      },
      home: child,
    ),
  );
}

Widget _wrapDark(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: [
      authProvider.overrideWith((_) => _FakeAuthNotifier()),
      ...overrides,
    ],
    child: MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: child,
    ),
  );
}

void main() {
  // ─────────────────────────────────────────────
  // LoginPage
  // ─────────────────────────────────────────────
  group('LoginPage', () {
    testWidgets('renders email and password fields', (tester) async {
      await tester.pumpWidget(_wrap(const LoginPage()));
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('邮箱'), findsOneWidget);
      expect(find.text('密码'), findsOneWidget);
    });

    testWidgets('renders login button', (tester) async {
      await tester.pumpWidget(_wrap(const LoginPage()));
      expect(find.text('登录'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('renders register link', (tester) async {
      await tester.pumpWidget(_wrap(const LoginPage()));
      expect(find.text('没有账号？注册'), findsOneWidget);
    });

    testWidgets('email icon is present', (tester) async {
      await tester.pumpWidget(_wrap(const LoginPage()));
      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
    });

    testWidgets('lock icon is present', (tester) async {
      await tester.pumpWidget(_wrap(const LoginPage()));
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('empty email shows validation error', (tester) async {
      await tester.pumpWidget(_wrap(const LoginPage()));
      // Tap login without entering anything
      await tester.tap(find.text('登录'));
      await tester.pumpAndSettle();
      expect(find.text('请输入邮箱'), findsOneWidget);
    });

    testWidgets('invalid email shows format error', (tester) async {
      await tester.pumpWidget(_wrap(const LoginPage()));
      await tester.enterText(
          find.byType(TextFormField).first, 'not-an-email');
      await tester.tap(find.text('登录'));
      await tester.pumpAndSettle();
      expect(find.text('邮箱格式不正确'), findsOneWidget);
    });

    testWidgets('empty password shows validation error', (tester) async {
      await tester.pumpWidget(_wrap(const LoginPage()));
      await tester.enterText(
          find.byType(TextFormField).first, 'test@test.com');
      await tester.tap(find.text('登录'));
      await tester.pumpAndSettle();
      expect(find.text('请输入密码'), findsOneWidget);
    });

    testWidgets('short password shows length error', (tester) async {
      await tester.pumpWidget(_wrap(const LoginPage()));
      await tester.enterText(
          find.byType(TextFormField).first, 'test@test.com');
      await tester.enterText(find.byType(TextFormField).last, '123');
      await tester.tap(find.text('登录'));
      await tester.pumpAndSettle();
      expect(find.text('密码至少 6 位'), findsOneWidget);
    });

    testWidgets('valid form passes validation', (tester) async {
      await tester.pumpWidget(_wrap(const LoginPage()));
      await tester.enterText(
          find.byType(TextFormField).first, 'test@test.com');
      await tester.enterText(
          find.byType(TextFormField).last, '123456');
      await tester.tap(find.text('登录'));
      await tester.pumpAndSettle();
      // No validation errors
      expect(find.text('请输入邮箱'), findsNothing);
      expect(find.text('邮箱格式不正确'), findsNothing);
      expect(find.text('请输入密码'), findsNothing);
      expect(find.text('密码至少 6 位'), findsNothing);
    });

    testWidgets('password field is obscured', (tester) async {
      await tester.pumpWidget(_wrap(const LoginPage()));
      final textFields = tester.widgetList<TextField>(
          find.byType(TextField));
      // index 1 = password field
      final pw = textFields.elementAt(1);
      expect(pw.obscureText, isTrue);
    });

    testWidgets('loading state shows CircularProgressIndicator',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authProvider.overrideWith((_) => _FakeAuthNotifier(
                const AuthState(status: AuthStatus.loading))),
        ],
        child: MaterialApp(
          home: const LoginPage(),
        ),
      ));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Login text should not be visible
      expect(find.text('登录'), findsNothing);
    });

    testWidgets('loading state disables button', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authProvider.overrideWith((_) => _FakeAuthNotifier(
                const AuthState(status: AuthStatus.loading))),
        ],
        child: MaterialApp(
          home: const LoginPage(),
        ),
      ));
      await tester.pump();
      final button =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(_wrapDark(const LoginPage()));
      expect(find.text('登录'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });
  });

  // ─────────────────────────────────────────────
  // RegisterPage
  // ─────────────────────────────────────────────
  group('RegisterPage', () {
    testWidgets('renders 3 form fields', (tester) async {
      await tester.pumpWidget(_wrap(const RegisterPage()));
      expect(find.byType(TextFormField), findsNWidgets(3));
    });

    testWidgets('renders title and subtitle', (tester) async {
      await tester.pumpWidget(_wrap(const RegisterPage()));
      expect(find.text('创建账号'), findsOneWidget);
      expect(find.text('开始管理你的家庭财务'), findsOneWidget);
    });

    testWidgets('renders register button', (tester) async {
      await tester.pumpWidget(_wrap(const RegisterPage()));
      expect(find.text('注册'), findsOneWidget);
    });

    testWidgets('renders back button', (tester) async {
      await tester.pumpWidget(_wrap(const RegisterPage()));
      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
    });

    testWidgets('empty email shows error', (tester) async {
      await tester.pumpWidget(_wrap(const RegisterPage()));
      await tester.tap(find.text('注册'));
      await tester.pumpAndSettle();
      expect(find.text('请输入邮箱'), findsOneWidget);
    });

    testWidgets('invalid email shows format error', (tester) async {
      await tester.pumpWidget(_wrap(const RegisterPage()));
      await tester.enterText(
          find.byType(TextFormField).at(0), 'bad-email');
      await tester.tap(find.text('注册'));
      await tester.pumpAndSettle();
      expect(find.text('邮箱格式不正确'), findsOneWidget);
    });

    testWidgets('empty password shows error', (tester) async {
      await tester.pumpWidget(_wrap(const RegisterPage()));
      await tester.enterText(
          find.byType(TextFormField).at(0), 'test@test.com');
      await tester.tap(find.text('注册'));
      await tester.pumpAndSettle();
      expect(find.text('请输入密码'), findsOneWidget);
    });

    testWidgets('short password shows error', (tester) async {
      await tester.pumpWidget(_wrap(const RegisterPage()));
      await tester.enterText(
          find.byType(TextFormField).at(0), 'test@test.com');
      await tester.enterText(find.byType(TextFormField).at(1), '12');
      await tester.tap(find.text('注册'));
      await tester.pumpAndSettle();
      expect(find.text('密码至少 6 位'), findsOneWidget);
    });

    testWidgets('password mismatch shows error', (tester) async {
      await tester.pumpWidget(_wrap(const RegisterPage()));
      await tester.enterText(
          find.byType(TextFormField).at(0), 'test@test.com');
      await tester.enterText(
          find.byType(TextFormField).at(1), '123456');
      await tester.enterText(
          find.byType(TextFormField).at(2), '654321');
      await tester.tap(find.text('注册'));
      await tester.pumpAndSettle();
      expect(find.text('两次密码不一致'), findsOneWidget);
    });

    testWidgets('valid form passes all validation', (tester) async {
      await tester.pumpWidget(_wrap(const RegisterPage()));
      await tester.enterText(
          find.byType(TextFormField).at(0), 'test@test.com');
      await tester.enterText(
          find.byType(TextFormField).at(1), '123456');
      await tester.enterText(
          find.byType(TextFormField).at(2), '123456');
      await tester.tap(find.text('注册'));
      await tester.pumpAndSettle();
      expect(find.text('请输入邮箱'), findsNothing);
      expect(find.text('邮箱格式不正确'), findsNothing);
      expect(find.text('请输入密码'), findsNothing);
      expect(find.text('密码至少 6 位'), findsNothing);
      expect(find.text('两次密码不一致'), findsNothing);
    });

    testWidgets('password fields are obscured', (tester) async {
      await tester.pumpWidget(_wrap(const RegisterPage()));
      // Verify by checking TextField (child of TextFormField)
      final textFields = tester.widgetList<TextField>(
          find.byType(TextField));
      // email, password, confirm = 3 fields; indices 1,2 should be obscured
      final pw = textFields.elementAt(1);
      final confirm = textFields.elementAt(2);
      expect(pw.obscureText, isTrue);
      expect(confirm.obscureText, isTrue);
    });

    testWidgets('loading state shows spinner', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authProvider.overrideWith((_) => _FakeAuthNotifier(
                const AuthState(status: AuthStatus.loading))),
        ],
        child: MaterialApp(
          home: const RegisterPage(),
        ),
      ));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('注册'), findsNothing);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(_wrapDark(const RegisterPage()));
      expect(find.text('创建账号'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────
  // AuthState model tests
  // ─────────────────────────────────────────────
  group('AuthState', () {
    test('default state', () {
      const s = AuthState();
      expect(s.status, AuthStatus.initial);
      expect(s.userId, isNull);
      expect(s.errorMessage, isNull);
    });

    test('AuthStatus has all values', () {
      expect(AuthStatus.values.length, 5);
      expect(AuthStatus.values,
          contains(AuthStatus.authenticated));
      expect(AuthStatus.values,
          contains(AuthStatus.unauthenticated));
      expect(AuthStatus.values, contains(AuthStatus.loading));
      expect(AuthStatus.values, contains(AuthStatus.error));
      expect(AuthStatus.values, contains(AuthStatus.initial));
    });
  });
}
