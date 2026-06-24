import 'dart:async';
import 'dart:developer' as dev;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/app_constants.dart';
import 'core/router/router.dart';
import 'core/theme/app_theme.dart';
import 'data/local/secure_token_storage.dart';
import 'domain/providers/app_providers.dart';
import 'domain/providers/notification_service_provider.dart';
import 'domain/providers/theme_provider.dart';
import 'domain/services/notifications/local_notification_service.dart';
import 'sync/sync_engine.dart';
import 'data/remote/grpc_clients.dart';

void main() async {
  // Catch all synchronous Flutter framework errors
  FlutterError.onError = (details) {
    dev.log(
      'FlutterError: ${details.exceptionAsString()}',
      name: 'crash-guard',
      error: details.exception,
      stackTrace: details.stack,
    );
    // In debug mode, also dump to console for immediate visibility
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    }
  };

  // Catch unhandled async errors (platform-level).
  // Log with full context; always return true to mark as "handled".
  // runZonedGuarded below is the fallback zone — returning false here would
  // cause duplicate reporting (once here, once in the Zone handler).
  PlatformDispatcher.instance.onError = (error, stack) {
    dev.log(
      'PlatformDispatcher error: $error',
      name: 'crash-guard',
      error: error,
      stackTrace: stack,
    );
    // Always mark handled. In debug, dev.log already makes it visible;
    // in release, this prevents crash. Zone handler won't double-report.
    return true;
  };

  // Wrap everything in a guarded zone for belt-and-suspenders safety
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      final prefs = await SharedPreferences.getInstance();

      // Migrate tokens from SharedPreferences to secure storage (one-time)
      final tokenStorage = SecureTokenStorage(prefs);
      await tokenStorage.migrateIfNeeded();

      // Load TLS certificate for gRPC
      await loadTlsCertificate();

      // Initialize on-device notifications (budget/loan/reminder alerts).
      // Failure here must never block app start.
      final notificationService = FlutterLocalNotificationService();
      try {
        await notificationService.init();
      } catch (e, st) {
        dev.log(
          'LocalNotificationService init failed: $e',
          name: 'notifications',
          error: e,
          stackTrace: st,
        );
      }

      // Restore persisted family mode
      final savedFamilyId = prefs.getString(AppConstants.familyIdKey);

      runApp(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            secureTokenStorageProvider.overrideWithValue(tokenStorage),
            localNotificationServiceProvider.overrideWithValue(
              notificationService,
            ),
            if (savedFamilyId != null)
              currentFamilyIdProvider.overrideWith((ref) => savedFamilyId),
          ],
          child: const FamilyLedgerApp(),
        ),
      );
    },
    (error, stack) {
      dev.log(
        'Unhandled zone error: $error',
        name: 'crash-guard',
        error: error,
        stackTrace: stack,
      );
    },
  );
}

class FamilyLedgerApp extends ConsumerWidget {
  const FamilyLedgerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);

    return SyncLifecycleObserver(
      child: MaterialApp.router(
        title: '家庭账本',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
        locale: const Locale('zh', 'CN'),
        routerConfig: router,
      ),
    );
  }
}
