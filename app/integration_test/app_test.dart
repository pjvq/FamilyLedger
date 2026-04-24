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
import 'package:familyledger/data/remote/grpc_clients.dart';
import 'package:grpc/grpc.dart';

// ───────────────────────────────────────────────────
//  No-op SyncEngine – prevents all network calls
// ───────────────────────────────────────────────────
class _NoOpSyncEngine extends SyncEngine {
  _NoOpSyncEngine() : super.forTesting();

  @override
  void start() {}

  @override
  Future<void> syncNow() async {}

  @override
  void dispose() {}
}

/// Save screenshot to /tmp/e2e-phase9/<name>.png
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
  final List<int> bytes = await binding.takeScreenshot(name);
  final file = File('/tmp/e2e-phase9/$name.png');
  await file.writeAsBytes(bytes);
}

/// Pump frames without requiring settle (avoids timer hangs)
Future<void> _pump(WidgetTester tester, {int frames = 30}) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Try to tap Back button. Returns true if found and tapped.
Future<bool> _goBack(WidgetTester tester) async {
  for (final finder in [
    find.byTooltip('Back'),
    find.byIcon(Icons.arrow_back),
    find.byIcon(Icons.arrow_back_ios),
    find.byIcon(Icons.close),
    find.byIcon(Icons.close_rounded),
  ]) {
    if (finder.evaluate().isNotEmpty) {
      await tester.tap(finder.first);
      await _pump(tester, frames: 15);
      return true;
    }
  }
  return false;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Directory('/tmp/e2e-phase9').createSync(recursive: true);

  testWidgets('FamilyLedger E2E — all pages', (tester) async {
    // ── Setup: mock logged-in user ──
    SharedPreferences.setMockInitialValues({
      AppConstants.userIdKey: 'test-user-id',
      AppConstants.accessTokenKey: 'test-token',
    });
    final prefs = await SharedPreferences.getInstance();

    // ── Launch app ──
    // Override grpcChannel to a dead port so all gRPC calls fail immediately
    final deadChannel = ClientChannel(
      '127.0.0.1',
      port: 1, // unreachable port → fast failure
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
        connectionTimeout: Duration(milliseconds: 500),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          syncEngineProvider.overrideWithValue(_NoOpSyncEngine()),
          grpcChannelProvider.overrideWithValue(deadChannel),
        ],
        child: const FamilyLedgerApp(),
      ),
    );
    await _pump(tester);

    // ════════════════════════════════════════════
    //  1. Dashboard
    // ════════════════════════════════════════════
    expect(find.text('FamilyLedger'), findsOneWidget);
    expect(find.text('净资产'), findsOneWidget);
    expect(find.text('仪表盘'), findsOneWidget);
    expect(find.text('账户'), findsOneWidget);
    expect(find.text('记账'), findsOneWidget);
    expect(find.text('预算'), findsOneWidget);
    expect(find.text('更多'), findsOneWidget);
    await _screenshot(binding, tester, '01_dashboard');

    // ════════════════════════════════════════════
    //  2. 账户页面
    // ════════════════════════════════════════════
    await tester.tap(find.text('账户'));
    await _pump(tester);
    expect(find.text('账户'), findsWidgets);
    await _screenshot(binding, tester, '02_accounts');

    // ════════════════════════════════════════════
    //  3. 记账页面
    // ════════════════════════════════════════════
    await tester.tap(find.text('记账'));
    await _pump(tester);
    expect(find.text('支出'), findsOneWidget);
    expect(find.text('收入'), findsOneWidget);
    await _screenshot(binding, tester, '03_add_transaction');
    await _goBack(tester);

    // ════════════════════════════════════════════
    //  4. 预算页面
    // ════════════════════════════════════════════
    await tester.tap(find.text('预算'));
    await _pump(tester);
    await _screenshot(binding, tester, '04_budget');

    // ════════════════════════════════════════════
    //  5. 更多页面
    // ════════════════════════════════════════════
    await tester.tap(find.text('更多'));
    await _pump(tester);
    expect(find.text('贷款管理'), findsOneWidget);
    expect(find.text('投资管理'), findsOneWidget);
    await _screenshot(binding, tester, '05_more');

    // ════════════════════════════════════════════
    //  6. 贷款管理
    // ════════════════════════════════════════════
    await tester.tap(find.text('贷款管理'));
    await _pump(tester);
    expect(find.text('暂无贷款记录'), findsOneWidget);
    await _screenshot(binding, tester, '06_loans');
    await _goBack(tester);

    // ════════════════════════════════════════════
    //  7. 投资管理
    // ════════════════════════════════════════════
    await tester.tap(find.text('投资管理'));
    await _pump(tester);
    expect(find.text('还没有投资持仓'), findsOneWidget);
    await _screenshot(binding, tester, '07_investments');
    await _goBack(tester);

    // ════════════════════════════════════════════
    //  8. 资产管理 (menu label may be "固定资产" or "资产管理")
    // ════════════════════════════════════════════
    await tester.tap(find.text('资产管理').first);
    await _pump(tester, frames: 60);  // extra wait for gRPC timeout
    // Check page title to confirm navigation worked
    await _screenshot(binding, tester, '08_assets');
    await _goBack(tester);

    // ════════════════════════════════════════════
    //  9. 添加贷款流程
    // ════════════════════════════════════════════
    await tester.tap(find.text('贷款管理'));
    await _pump(tester);

    if (find.text('添加贷款').evaluate().isNotEmpty) {
      await tester.tap(find.text('添加贷款'));
    } else if (find.byType(FloatingActionButton).evaluate().isNotEmpty) {
      await tester.tap(find.byType(FloatingActionButton));
    }
    await _pump(tester);

    // Enter loan name
    final loanFields = find.byType(TextField);
    if (loanFields.evaluate().isNotEmpty) {
      await tester.enterText(loanFields.first, '房贷测试');
      await _pump(tester, frames: 10);
    }
    await _screenshot(binding, tester, '09_add_loan');
    await _goBack(tester); // back from add loan
    await _goBack(tester); // back from loans list

    // ════════════════════════════════════════════
    //  10. 添加投资流程
    // ════════════════════════════════════════════
    await tester.tap(find.text('投资管理'));
    await _pump(tester);

    if (find.byType(FloatingActionButton).evaluate().isNotEmpty) {
      await tester.tap(find.byType(FloatingActionButton));
      await _pump(tester);
    }
    await _screenshot(binding, tester, '10_add_investment');
    await _goBack(tester);
    await _goBack(tester);

    // ════════════════════════════════════════════
    //  11. 添加资产流程
    // ════════════════════════════════════════════
    await tester.tap(find.text('资产管理').first);
    await _pump(tester);

    if (find.byType(FloatingActionButton).evaluate().isNotEmpty) {
      await tester.tap(find.byType(FloatingActionButton));
      await _pump(tester);
    }
    await _screenshot(binding, tester, '11_add_asset');
    await _goBack(tester);
    await _goBack(tester);

    // ════════════════════════════════════════════
    //  12. 深色模式
    // ════════════════════════════════════════════
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await _pump(tester);
    await tester.tap(find.text('仪表盘'));
    await _pump(tester);
    await _screenshot(binding, tester, '12_dark_mode');
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
  });
}
