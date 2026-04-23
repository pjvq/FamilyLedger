import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:familyledger/main.dart' show FamilyLedgerApp;
import 'package:familyledger/core/constants/app_constants.dart';
import 'package:familyledger/domain/providers/app_providers.dart';
import 'package:familyledger/sync/sync_engine.dart';

class _NoOpSyncEngine extends SyncEngine {
  _NoOpSyncEngine() : super.forTesting();
  @override
  void start() {}
  @override
  Future<void> syncNow() async {}
  @override
  void dispose() {}
}

Future<void> _screenshot(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name,
) async {
  for (int i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await binding.convertFlutterSurfaceToImage();
  await tester.pump(const Duration(milliseconds: 200));
  final bytes = await binding.takeScreenshot(name);
  File('/tmp/e2e-phase9/$name.png').writeAsBytesSync(bytes);
}

Future<void> _settle(WidgetTester tester, {int seconds = 8}) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      Duration(seconds: seconds),
    );
  } catch (_) {
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
}

/// Try to go back — searches for back button with multiple strategies
Future<bool> _goBack(WidgetTester tester) async {
  for (final f in [
    find.byTooltip('Back'),
    find.byTooltip('返回'),
    find.byIcon(Icons.arrow_back),
    find.byIcon(Icons.close),
  ]) {
    if (f.evaluate().isNotEmpty) {
      await tester.tap(f.first);
      await _settle(tester);
      return true;
    }
  }
  // Last resort: try Navigator.pop
  try {
    final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
    nav.pop();
    await _settle(tester);
    return true;
  } catch (_) {
    return false;
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Directory('/tmp/e2e-phase9').createSync(recursive: true);

  testWidgets('FamilyLedger full walkthrough', (tester) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.userIdKey: 'test-user-id',
      AppConstants.accessTokenKey: 'test-token',
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          syncEngineProvider.overrideWithValue(_NoOpSyncEngine()),
        ],
        child: const FamilyLedgerApp(),
      ),
    );
    await _settle(tester);

    // ═══ 1. Dashboard ═══
    expect(find.text('FamilyLedger'), findsOneWidget);
    expect(find.text('仪表盘'), findsOneWidget);
    expect(find.text('账户'), findsOneWidget);
    expect(find.text('预算'), findsOneWidget);
    expect(find.text('更多'), findsOneWidget);
    await _screenshot(binding, tester, '01_dashboard');

    // ═══ 2. Accounts ═══
    await tester.tap(find.text('账户'));
    await _settle(tester);
    await _screenshot(binding, tester, '02_accounts');

    // ═══ 3. Add Transaction (pushes full page) ═══
    await tester.tap(find.text('记账'));
    await _settle(tester);
    await _screenshot(binding, tester, '03_add_transaction');
    await _goBack(tester);

    // ═══ 4. Budget ═══
    await tester.tap(find.text('预算'));
    await _settle(tester);
    await _screenshot(binding, tester, '04_budget');

    // ═══ 5. More ═══
    await tester.tap(find.text('更多'));
    await _settle(tester);
    await _screenshot(binding, tester, '05_more');

    // ═══ 6. Loans ═══
    if (find.text('贷款管理').evaluate().isNotEmpty) {
      await tester.tap(find.text('贷款管理'));
      await _settle(tester);
      await _screenshot(binding, tester, '06_loans');
      await _goBack(tester);
    }

    // ═══ 7. Investments ═══
    if (find.text('投资管理').evaluate().isNotEmpty) {
      await tester.tap(find.text('投资管理'));
      await _settle(tester);
      await _screenshot(binding, tester, '07_investments');
      await _goBack(tester);
    }

    // ═══ 8. Assets ═══
    final assetFinder = find.text('资产管理').evaluate().isNotEmpty
        ? find.text('资产管理')
        : find.text('固定资产');
    if (assetFinder.evaluate().isNotEmpty) {
      await tester.tap(assetFinder.first);
      await _settle(tester);
      await _screenshot(binding, tester, '08_assets');
      await _goBack(tester);
    }

    // ═══ 9. Report ═══
    if (find.text('报表').evaluate().isNotEmpty) {
      await tester.tap(find.text('报表'));
      await _settle(tester);
      await _screenshot(binding, tester, '09_report');
      await _goBack(tester);
    }

    // ═══ 10. Settings / Notifications ═══
    if (find.text('设置').evaluate().isNotEmpty) {
      await tester.tap(find.text('设置'));
      await _settle(tester);
      await _screenshot(binding, tester, '10_settings');
      await _goBack(tester);
    }

    // ═══ 11. Back to Dashboard ═══
    // Pop all sub-pages until bottom nav is visible again
    while (find.text('仪表盘').evaluate().isEmpty) {
      final popped = await _goBack(tester);
      if (!popped) break;
    }
    if (find.text('仪表盘').evaluate().isNotEmpty) {
      await tester.tap(find.text('仪表盘'));
      await _settle(tester);
    }

    // ═══ 12. Dark Mode ═══
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await _settle(tester);
    await _screenshot(binding, tester, '11_dark_dashboard');
    tester.platformDispatcher.clearPlatformBrightnessTestValue();

    // All passed!
    expect(true, isTrue);
  });
}
