import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/local/database.dart';
import '../../domain/providers/app_providers.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/register_page.dart';
import '../../features/overview/overview_page.dart';
import '../../features/flow/transaction_flow_page.dart';
import '../../features/more/more_page.dart';
import '../../features/shell/main_shell.dart';
import '../../features/account/add_account_page.dart';
import '../../features/account/account_detail_page.dart';
import '../../features/account/transfer_page.dart';
import '../../features/budget/budget_page.dart';
import '../../features/notification/notifications_page.dart';
import '../../features/notification/notification_settings_page.dart';
import '../../features/settings/backup_page.dart';
import '../../features/loan/loans_page.dart';
import '../../features/loan/add_loan_page.dart';
import '../../features/loan/loan_detail_page.dart';
import '../../features/loan/loan_group_detail_page.dart';
import '../../features/loan/prepayment_page.dart';
import '../../features/investment/investments_page.dart';
import '../../features/investment/add_investment_page.dart';
import '../../features/investment/investment_detail_page.dart';
import '../../features/investment/trade_page.dart';
import '../../features/asset/assets_page.dart';
import '../../features/assets/assets_tab_page.dart';
import '../../features/asset/add_asset_page.dart';
import '../../features/asset/asset_detail_page.dart';
import '../../features/report/report_page.dart';
import '../../features/report/export_page.dart';
import '../../features/import/import_page.dart';
import '../../features/transaction/add_transaction_page.dart';
import '../../features/transaction/transaction_detail_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/settings/family_members_page.dart';
import '../../features/settings/category_manage_page.dart';

/// go_router provider — manages all app routing with auth redirect.
///
/// Uses [ref.read] inside redirect to avoid rebuilding the entire GoRouter
/// instance on auth state changes. Instead, [refreshListenable] triggers
/// redirect re-evaluation without destroying navigation state.
final routerProvider = AutoDisposeProvider<GoRouter>((ref) {
  // Kept alive for the entire app lifecycle. Disposed when ProviderContainer is destroyed.
  ref.keepAlive();

  // Navigation keys scoped to provider lifecycle (safe for hot reload + tests)
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  final overviewNavigatorKey = GlobalKey<NavigatorState>(
    debugLabel: 'overview',
  );
  final transactionsNavigatorKey = GlobalKey<NavigatorState>(
    debugLabel: 'transactions',
  );
  final assetsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'assets');
  final mineNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'mine');

  // Create a listenable that fires when auth state changes.
  final authNotifier = _AuthChangeNotifier(ref);
  ref.onDispose(authNotifier.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/overview',
    refreshListenable: authNotifier,
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('页面不存在')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('请求的页面不存在'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/overview'),
              child: const Text('返回首页'),
            ),
          ],
        ),
      ),
    ),
    redirect: (context, state) {
      final isLoggedIn = ref.read(isLoggedInProvider);
      final loggingIn =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isLoggedIn && !loggingIn) return '/login';
      if (isLoggedIn && loggingIn) return '/overview';
      return null;
    },
    routes: [
      // ── Auth routes (no shell) ──
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),

      // ── Main shell with bottom nav ──
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Overview (Dashboard)
          StatefulShellBranch(
            navigatorKey: overviewNavigatorKey,
            routes: [
              GoRoute(
                path: '/overview',
                builder: (_, __) => const OverviewPage(),
              ),
            ],
          ),
          // Branch 1: Transactions (Flow)
          StatefulShellBranch(
            navigatorKey: transactionsNavigatorKey,
            routes: [
              GoRoute(
                path: '/transactions',
                builder: (_, __) => const TransactionFlowPage(),
              ),
            ],
          ),
          // Branch 2: Assets
          StatefulShellBranch(
            navigatorKey: assetsNavigatorKey,
            routes: [
              GoRoute(
                path: '/assets',
                builder: (_, __) => const AssetsTabPage(),
              ),
            ],
          ),
          // Branch 3: Mine
          StatefulShellBranch(
            navigatorKey: mineNavigatorKey,
            routes: [
              GoRoute(path: '/mine', builder: (_, __) => const MorePage()),
            ],
          ),
        ],
      ),

      // ── Full-screen routes (no tab bar) ──

      // Transaction detail
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/transactions/detail',
        builder: (context, state) {
          final args = state.extra;
          if (args is! TransactionDetailArgs) {
            return const Scaffold(body: Center(child: Text('交易详情不可用')));
          }
          return TransactionDetailPage(args: args);
        },
      ),

      // Accounts
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/assets/accounts/add',
        builder: (_, __) => const AddAccountPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/assets/accounts/detail/:accountId',
        redirect: (context, state) {
          final id = state.pathParameters['accountId'];
          if (id == null || id.isEmpty) return '/assets';
          return null;
        },
        builder: (context, state) =>
            AccountDetailPage(accountId: state.pathParameters['accountId']!),
      ),

      // Loans
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/assets/loans',
        builder: (_, __) => const LoansPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/assets/loans/add',
        builder: (_, __) => const AddLoanPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/assets/loans/:loanId',
        builder: (context, state) =>
            LoanDetailPage(loanId: state.pathParameters['loanId'] ?? ''),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/assets/loans/:loanId/prepayment',
        builder: (context, state) =>
            PrepaymentPage(loanId: state.pathParameters['loanId'] ?? ''),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/assets/loans/group/:groupId',
        builder: (context, state) =>
            LoanGroupDetailPage(groupId: state.pathParameters['groupId'] ?? ''),
      ),

      // Investments
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/assets/investments',
        builder: (_, __) => const InvestmentsPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/assets/investments/add',
        builder: (_, __) => const AddInvestmentPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/assets/investments/:investmentId',
        builder: (context, state) => InvestmentDetailPage(
          investmentId: state.pathParameters['investmentId'] ?? '',
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/assets/investments/:investmentId/trade',
        builder: (context, state) =>
            TradePage(investmentId: state.pathParameters['investmentId'] ?? ''),
      ),

      // Fixed assets
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/assets/fixed',
        builder: (_, __) => const AssetsPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/assets/fixed/add',
        builder: (_, __) => const AddAssetPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/assets/fixed/:assetId',
        builder: (context, state) =>
            AssetDetailPage(assetId: state.pathParameters['assetId'] ?? ''),
      ),

      // Mine sub-pages
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/mine/settings',
        builder: (_, __) => const SettingsPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/mine/settings/members',
        builder: (_, __) => const FamilyMembersPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/mine/settings/categories',
        builder: (_, __) => const CategoryManagePage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/mine/notifications',
        builder: (_, __) => const NotificationsPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/mine/notifications/settings',
        builder: (_, __) => const NotificationSettingsPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/mine/settings/backup',
        builder: (_, __) => const BackupPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/mine/budget',
        builder: (_, __) => const BudgetPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/mine/report',
        builder: (_, __) => const ReportPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/mine/export',
        builder: (_, __) => const ExportPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/mine/import',
        builder: (_, __) => const ImportPage(),
      ),

      // ── Modal routes (slide up) ──
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/add-transaction',
        pageBuilder: (context, state) {
          final txn = state.extra as Transaction?;
          return _slideUpPage(AddTransactionPage(existingTransaction: txn));
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/transfer',
        pageBuilder: (context, state) {
          return _slideUpPage(const TransferPage());
        },
      ),
    ],
  );
});

// ─── Slide-up modal page transition helper ───

CustomTransitionPage<void> _slideUpPage(Widget child) {
  return CustomTransitionPage(
    child: child,
    transitionsBuilder: (context, animation, _, page) => SlideTransition(
      position: Tween(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: page,
    ),
    transitionDuration: const Duration(milliseconds: 350),
  );
}

// ─── Auth Change Notifier for GoRouter refreshListenable ───

class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(this._ref) {
    try {
      _sub = _ref.listen(isLoggedInProvider, (prev, next) {
        if (!_disposed) notifyListeners();
      });
    } catch (_) {
      // Provider already disposed during construction (hot restart edge case)
    }
  }

  final Ref _ref;
  ProviderSubscription<bool>? _sub;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _sub?.close();
    _sub = null;
    super.dispose();
  }
}
