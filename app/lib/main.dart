import 'dart:async';
import 'dart:developer' as dev;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'domain/providers/app_providers.dart';
import 'domain/providers/theme_provider.dart';

void main() async {
  // Catch all synchronous Flutter framework errors
  FlutterError.onError = (details) {
    dev.log(
      'FlutterError: ${details.exceptionAsString()}',
      name: 'crash-guard',
      error: details.exception,
      stackTrace: details.stack,
    );
    // Don't rethrow — prevents crash
  };

  // Catch all unhandled async errors (platform-level)
  PlatformDispatcher.instance.onError = (error, stack) {
    dev.log(
      'PlatformDispatcher error: $error',
      name: 'crash-guard',
      error: error,
      stackTrace: stack,
    );
    return true; // Mark as handled — prevents crash
  };

  // Wrap everything in a guarded zone for belt-and-suspenders safety
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    final prefs = await SharedPreferences.getInstance();

    // Restore persisted family mode
    final savedFamilyId = prefs.getString(AppConstants.familyIdKey);

    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          if (savedFamilyId != null)
            currentFamilyIdProvider.overrideWith((ref) => savedFamilyId),
        ],
        child: const FamilyLedgerApp(),
      ),
    );
  }, (error, stack) {
    dev.log(
      'Unhandled zone error: $error',
      name: 'crash-guard',
      error: error,
      stackTrace: stack,
    );
  });
}

class FamilyLedgerApp extends ConsumerWidget {
  const FamilyLedgerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(isLoggedInProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'FamilyLedger',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
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
      initialRoute: isLoggedIn ? AppRouter.home : AppRouter.login,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
