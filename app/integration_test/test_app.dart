/// Test utility to launch the app bypassing login and network dependencies.
///
/// Usage in integration tests:
/// ```dart
/// import 'test_app.dart';
/// await pumpTestApp(tester);
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:familyledger/core/constants/app_constants.dart';
import 'package:familyledger/core/router/app_router.dart';
import 'package:familyledger/core/theme/app_theme.dart';
import 'package:familyledger/domain/providers/app_providers.dart';

/// Pumps the full app with login bypassed and sync disabled.
///
/// Sets up SharedPreferences with a fake user ID so the app routes
/// directly to the home page.
Future<void> pumpTestApp(
  WidgetTester tester, {
  String userId = 'perf-test-user',
  String? familyId,
  List<Override> extraOverrides = const [],
}) async {
  // Pre-populate SharedPreferences with auth token
  SharedPreferences.setMockInitialValues({
    AppConstants.userIdKey: userId,
    AppConstants.accessTokenKey: 'fake-token-for-perf-test',
    // ignore: use_null_aware_elements
    if (familyId != null) AppConstants.familyIdKey: familyId,
  });

  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (familyId != null)
          currentFamilyIdProvider.overrideWith((ref) => familyId),
        ...extraOverrides,
      ],
      child: const _PerfTestApp(),
    ),
  );

  // Let the widget tree settle (animations, async inits, etc.)
  await tester.pumpAndSettle(const Duration(seconds: 3));
}

/// Minimal app shell identical to FamilyLedgerApp but without
/// zone guarding (integration test framework handles errors).
class _PerfTestApp extends ConsumerWidget {
  const _PerfTestApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'FamilyLedger PerfTest',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light, // deterministic for perf tests
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      locale: const Locale('zh', 'CN'),
      // Always start at home — login is bypassed
      initialRoute: AppRouter.home,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
