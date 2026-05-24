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
import '../../features/account/transfer_page.dart';
import '../../features/budget/budget_page.dart';
import '../../features/notification/notifications_page.dart';
import '../../features/notification/notification_settings_page.dart';
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
import '../../features/transaction/transaction_history_page.dart';
import '../../features/transaction/transaction_detail_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/settings/family_members_page.dart';
import '../../features/settings/category_manage_page.dart';
import '../router/app_router.dart';

// Navigation keys for StatefulShellRoute branches
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _overviewNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'overview');
final _transactionsNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'transactions');
final _assetsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'assets');
final _mineNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'mine');

/// go_router provider — manages all app routing with auth redirect.
final routerProvider = Provider<GoRouter>((ref) {
  final isLoggedIn = ref.watch(isLoggedInProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/overview',
    redirect: (context, state) {
      final loggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isLoggedIn && !loggingIn) return '/login';
      if (isLoggedIn && loggingIn) return '/overview';
      return null;
    },
    routes: [
      // ── Auth routes (no shell) ──
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterPage(),
      ),

      // ── Main shell with bottom nav ──
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Overview (Dashboard)
          StatefulShellBranch(
            navigatorKey: _overviewNavigatorKey,
            routes: [
              GoRoute(
                path: '/overview',
                builder: (_, __) => const OverviewPage(),
              ),
            ],
          ),
          // Branch 1: Transactions (Flow)
          StatefulShellBranch(
            navigatorKey: _transactionsNavigatorKey,
            routes: [
              GoRoute(
                path: '/transactions',
                builder: (_, __) => const TransactionFlowPage(),
                routes: [
                  GoRoute(
                    path: 'detail',
                    builder: (context, state) {
                      final args = state.extra as TransactionDetailArgs;
                      return TransactionDetailPage(args: args);
                    },
                  ),
                ],
              ),
            ],
          ),
          // Branch 2: Assets
          StatefulShellBranch(
            navigatorKey: _assetsNavigatorKey,
            routes: [
              GoRoute(
                path: '/assets',
                builder: (_, __) => const AssetsTabPage(),
                routes: [
                  GoRoute(
                    path: 'accounts/add',
                    builder: (_, __) => const AddAccountPage(),
                  ),
                  GoRoute(
                    path: 'transfer',
                    builder: (_, __) => const TransferPage(),
                  ),
                  GoRoute(
                    path: 'loans',
                    builder: (_, __) => const LoansPage(),
                    routes: [
                      GoRoute(
                        path: 'add',
                        builder: (_, __) => const AddLoanPage(),
                      ),
                      GoRoute(
                        path: ':loanId',
                        builder: (context, state) => LoanDetailPage(
                          loanId: state.pathParameters['loanId']!,
                        ),
                        routes: [
                          GoRoute(
                            path: 'prepayment',
                            builder: (context, state) => PrepaymentPage(
                              loanId: state.pathParameters['loanId']!,
                            ),
                          ),
                        ],
                      ),
                      GoRoute(
                        path: 'group/:groupId',
                        builder: (context, state) => LoanGroupDetailPage(
                          groupId: state.pathParameters['groupId']!,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'investments',
                    builder: (_, __) => const InvestmentsPage(),
                    routes: [
                      GoRoute(
                        path: 'add',
                        builder: (_, __) => const AddInvestmentPage(),
                      ),
                      GoRoute(
                        path: ':investmentId',
                        builder: (context, state) => InvestmentDetailPage(
                          investmentId:
                              state.pathParameters['investmentId']!,
                        ),
                        routes: [
                          GoRoute(
                            path: 'trade',
                            builder: (context, state) => TradePage(
                              investmentId:
                                  state.pathParameters['investmentId']!,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'fixed',
                    builder: (_, __) => const AssetsPage(),
                    routes: [
                      GoRoute(
                        path: 'add',
                        builder: (_, __) => const AddAssetPage(),
                      ),
                      GoRoute(
                        path: ':assetId',
                        builder: (context, state) => AssetDetailPage(
                          assetId: state.pathParameters['assetId']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // Branch 3: Mine
          StatefulShellBranch(
            navigatorKey: _mineNavigatorKey,
            routes: [
              GoRoute(
                path: '/mine',
                builder: (_, __) => const MorePage(),
                routes: [
                  GoRoute(
                    path: 'settings',
                    builder: (_, __) => const SettingsPage(),
                    routes: [
                      GoRoute(
                        path: 'members',
                        builder: (_, __) => const FamilyMembersPage(),
                      ),
                      GoRoute(
                        path: 'categories',
                        builder: (_, __) => const CategoryManagePage(),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'notifications',
                    builder: (_, __) => const NotificationsPage(),
                    routes: [
                      GoRoute(
                        path: 'settings',
                        builder: (_, __) =>
                            const NotificationSettingsPage(),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'budget',
                    builder: (_, __) => const BudgetPage(),
                  ),
                  GoRoute(
                    path: 'report',
                    builder: (_, __) => const ReportPage(),
                  ),
                  GoRoute(
                    path: 'export',
                    builder: (_, __) => const ExportPage(),
                  ),
                  GoRoute(
                    path: 'import',
                    builder: (_, __) => const ImportPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // ── Modal routes (outside shell, slide up) ──
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/add-transaction',
        pageBuilder: (context, state) {
          final txn = state.extra as Transaction?;
          return CustomTransitionPage(
            child: AddTransactionPage(existingTransaction: txn),
            transitionsBuilder: (context, animation, _, child) =>
                SlideTransition(
              position: Tween(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
            transitionDuration: const Duration(milliseconds: 350),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/transfer',
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            child: const TransferPage(),
            transitionsBuilder: (context, animation, _, child) =>
                SlideTransition(
              position: Tween(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
            transitionDuration: const Duration(milliseconds: 350),
          );
        },
      ),
    ],
  );
});
