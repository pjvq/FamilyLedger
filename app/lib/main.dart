import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'domain/providers/app_providers.dart';
import 'domain/providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const FamilyLedgerApp(),
    ),
  );
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
      initialRoute: isLoggedIn ? AppRouter.home : AppRouter.login,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
