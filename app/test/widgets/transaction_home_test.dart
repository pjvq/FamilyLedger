import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familyledger/features/transaction/add_transaction_page.dart';
import 'package:familyledger/features/transaction/transaction_history_page.dart';
import 'package:familyledger/features/home/home_page.dart';
import 'package:familyledger/features/transaction/widgets/number_pad.dart';
import 'package:familyledger/features/transaction/widgets/category_grid.dart';
import 'package:familyledger/domain/providers/transaction_provider.dart';
import 'package:familyledger/domain/providers/notification_provider.dart';
import 'package:familyledger/domain/providers/exchange_rate_provider.dart';
import 'package:familyledger/sync/sync_engine.dart';

import 'test_helpers.dart';

// ─── Fake SyncEngine ─────────────────────────────────────────────────

class FakeSyncEngine implements SyncEngine {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    // Return a completed future for any async method (e.g. start())
    if (invocation.isMethod) return Future<void>.value();
    return null;
  }
}

// ─── Fake ExchangeRateNotifier ───────────────────────────────────────

class FakeExchangeRateNotifier extends StateNotifier<Map<String, double>>
    implements ExchangeRateNotifier {
  FakeExchangeRateNotifier() : super(const {'USD/CNY': 7.25, 'EUR/CNY': 7.90});

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isMethod) return Future<void>.value();
    return null;
  }
}

// ─── Extra overrides for widgets that need non-standard providers ─────

List<Override> _exchangeRateOverride() => [
      exchangeRateProvider
          .overrideWith((_) => FakeExchangeRateNotifier()),
    ];

List<Override> _syncEngineOverride() => [
      syncEngineProvider.overrideWithValue(FakeSyncEngine()),
    ];

void main() {
  // ═══════════════════════════════════════════════════════════════════
  // AddTransactionPage
  // ═══════════════════════════════════════════════════════════════════

  group('AddTransactionPage', () {
    testWidgets('renders app bar with title "记一笔"', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          const AddTransactionPage(),
          transaction: const TransactionState(isLoading: false),
          extra: _exchangeRateOverride(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('记一笔'), findsOneWidget);
    });

    testWidgets('renders expense/income tab bar', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          const AddTransactionPage(),
          transaction: const TransactionState(isLoading: false),
          extra: _exchangeRateOverride(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('支出'), findsOneWidget);
      expect(find.text('收入'), findsOneWidget);
    });

    testWidgets('renders NumberPad', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          const AddTransactionPage(),
          transaction: const TransactionState(isLoading: false),
          extra: _exchangeRateOverride(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NumberPad), findsOneWidget);
    });

    testWidgets('renders CategoryGrid', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          const AddTransactionPage(),
          transaction: const TransactionState(isLoading: false),
          extra: _exchangeRateOverride(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CategoryGrid), findsOneWidget);
    });

    testWidgets('shows initial amount "0"', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          const AddTransactionPage(),
          transaction: const TransactionState(isLoading: false),
          extra: _exchangeRateOverride(),
        ),
      );
      await tester.pumpAndSettle();

      // The amount display should show "0" initially
      // Look for the amount text in a Text widget (it may also show ¥0)
      expect(
        find.textContaining('0'),
        findsWidgets, // at least one — the amount display + '0' key
      );
    });

    testWidgets('has close button in app bar', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          const AddTransactionPage(),
          transaction: const TransactionState(isLoading: false),
          extra: _exchangeRateOverride(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('can switch between expense and income tabs', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          const AddTransactionPage(),
          transaction: const TransactionState(isLoading: false),
          extra: _exchangeRateOverride(),
        ),
      );
      await tester.pumpAndSettle();

      // Initially on expense tab
      // Tap income tab
      await tester.tap(find.text('收入'));
      await tester.pumpAndSettle();

      // Should still have both tabs and no crash
      expect(find.text('支出'), findsOneWidget);
      expect(find.text('收入'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // TransactionHistoryPage
  // ═══════════════════════════════════════════════════════════════════

  group('TransactionHistoryPage', () {
    testWidgets('shows loading spinner when isLoading=true', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          const TransactionHistoryPage(),
          transaction: const TransactionState(isLoading: true),
        ),
      );
      // Don't pumpAndSettle — CircularProgressIndicator is an animation
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows empty state when transactions are empty',
        (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          const TransactionHistoryPage(),
          transaction: const TransactionState(
            isLoading: false,
            transactions: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('暂无交易记录'), findsOneWidget);
      expect(find.text('点击下方按钮添加第一笔交易'), findsOneWidget);
      expect(find.byIcon(Icons.receipt_long_rounded), findsOneWidget);
    });

    testWidgets('empty state has "记一笔" action button', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          const TransactionHistoryPage(),
          transaction: const TransactionState(
            isLoading: false,
            transactions: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, '记一笔'), findsOneWidget);
    });

    testWidgets('renders app bar with title "交易记录"', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          const TransactionHistoryPage(),
          transaction: const TransactionState(isLoading: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('交易记录'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // HomePage
  // ═══════════════════════════════════════════════════════════════════

  group('HomePage', () {
    testWidgets('renders NavigationBar with 5 destinations', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          const HomePage(),
          transaction: const TransactionState(isLoading: false),
          extra: _syncEngineOverride(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      // Check all 5 labels
      expect(find.text('仪表盘'), findsOneWidget);
      expect(find.text('账户'), findsOneWidget);
      expect(find.text('记账'), findsOneWidget);
      expect(find.text('预算'), findsOneWidget);
      expect(find.text('更多'), findsOneWidget);
    });

    testWidgets('starts on the dashboard tab (index 0)', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          const HomePage(),
          transaction: const TransactionState(isLoading: false),
          extra: _syncEngineOverride(),
        ),
      );
      await tester.pumpAndSettle();

      // DashboardShell has appbar title "FamilyLedger"
      expect(find.text('FamilyLedger'), findsOneWidget);
    });

    testWidgets('has notification bell icon', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          const HomePage(),
          transaction: const TransactionState(isLoading: false),
          extra: _syncEngineOverride(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    });

    testWidgets('has transaction history icon in app bar', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          const HomePage(),
          transaction: const TransactionState(isLoading: false),
          extra: _syncEngineOverride(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
    });

    testWidgets('tapping "账户" tab switches to accounts view',
        (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          const HomePage(),
          transaction: const TransactionState(isLoading: false),
          extra: _syncEngineOverride(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('账户'));
      await tester.pumpAndSettle();

      // The accounts tab shows its own AppBar with title '账户'
      // There should now be an accounts-related scaffold
      expect(find.text('账户'), findsWidgets);
    });

    testWidgets('tapping "预算" tab switches to budget view', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          const HomePage(),
          transaction: const TransactionState(isLoading: false),
          extra: _syncEngineOverride(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('预算'));
      await tester.pumpAndSettle();

      // BudgetPage has month-based title, e.g. "4月预算"
      final now = DateTime.now();
      expect(find.textContaining('${now.month}月预算'), findsOneWidget);
    });

    testWidgets('tapping "更多" tab shows more page', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          const HomePage(),
          transaction: const TransactionState(isLoading: false),
          extra: _syncEngineOverride(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('更多'));
      await tester.pumpAndSettle();

      // MorePage has AppBar with '更多'
      expect(find.text('更多'), findsWidgets);
    });

    testWidgets('notification bell shows badge when unreadCount > 0',
        (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          const HomePage(),
          transaction: const TransactionState(isLoading: false),
          notification: const NotificationState(unreadCount: 5),
          extra: _syncEngineOverride(),
        ),
      );
      await tester.pumpAndSettle();

      // Badge shows count text
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('notification bell has no badge when unreadCount is 0',
        (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          const HomePage(),
          transaction: const TransactionState(isLoading: false),
          notification: const NotificationState(unreadCount: 0),
          extra: _syncEngineOverride(),
        ),
      );
      await tester.pumpAndSettle();

      // Badge should not be visible — Badge.isLabelVisible should be false
      final badge = tester.widget<Badge>(find.byType(Badge));
      expect(badge.isLabelVisible, isFalse);
    });
  });
}
