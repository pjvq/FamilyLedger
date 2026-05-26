import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/design_tokens.dart';
import '../../domain/providers/family_provider.dart';

/// Main shell — provides bottom navigation + centered FAB for all tab branches.
///
/// Branch indices: 0=overview, 1=transactions, 2=assets, 3=mine
/// Navigation uses [NavigationBar] with 4 real destinations.
/// The FAB floats above the bar (centerFloat) to avoid hit-area overlap.
///
/// **Invariant**: NavigationBar destination order must match
/// [StatefulShellRoute.branches] order in router.dart.
class MainShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final canCreate = ref.watch(canCreateProvider);

    assert(
      navigationShell.route.branches.length == 4,
      'MainShell expects exactly 4 branches matching 4 NavigationBar destinations',
    );

    return Scaffold(
      body: navigationShell,
      floatingActionButton: FloatingActionButton(
        heroTag: 'main_add_transaction',
        tooltip: '记一笔',
        onPressed: () {
          if (!canCreate) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('当前角色无记账权限')),
            );
            return;
          }
          context.push('/add-transaction');
        },
        elevation: isDark ? 4 : 2,
        backgroundColor:
            isDark ? ColorTokens.primaryLight : ColorTokens.primary,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded,
            color: Colors.white, size: IconSizeTokens.md),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: '概览',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: '流水',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_outlined),
            selectedIcon: Icon(Icons.account_balance_rounded),
            label: '资产',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
