import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/design_tokens.dart';
import '../../domain/providers/family_provider.dart';

/// Main shell — provides the bottom navigation bar wrapping all tab branches.
///
/// Branch indices: 0=overview, 1=transactions, 2=assets, 3=mine
/// Nav indices:    0=overview, 1=transactions, 2=FAB(skip), 3=assets, 4=mine
class MainShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final canCreate = ref.watch(canCreateProvider);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _mapBranchToNav(navigationShell.currentIndex),
        onDestinationSelected: (index) {
          if (index == 2) {
            // FAB center — navigate to add transaction (modal route)
            if (!canCreate) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('当前角色无记账权限')),
              );
              return;
            }
            context.push('/add-transaction');
            return;
          }
          navigationShell.goBranch(_mapNavToBranch(index));
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: '概览',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: '流水',
          ),
          // FAB center placeholder
          NavigationDestination(
            icon: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isDark
                    ? ColorTokens.primaryLight
                    : ColorTokens.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded,
                  color: Colors.white, size: 24),
            ),
            label: '记账',
          ),
          const NavigationDestination(
            icon: Icon(Icons.account_balance_outlined),
            selectedIcon: Icon(Icons.account_balance_rounded),
            label: '资产',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: '我的',
          ),
        ],
      ),
    );
  }

  /// Maps router branch index to NavigationBar index (skipping FAB at 2).
  int _mapBranchToNav(int branch) => branch >= 2 ? branch + 1 : branch;

  /// Maps NavigationBar index to router branch index (skipping FAB at 2).
  int _mapNavToBranch(int nav) => nav >= 3 ? nav - 1 : nav;
}
