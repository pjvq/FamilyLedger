import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/design_tokens.dart';
import '../../domain/providers/family_provider.dart';

/// Main shell — provides bottom navigation + centered FAB for all tab branches.
///
/// Branch indices: 0=overview, 1=transactions, 2=assets, 3=mine
/// Navigation uses [NavigationBar] with 4 real destinations (no FAB placeholder).
/// The FAB is a separate [FloatingActionButton] docked to the bottom bar.
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (!canCreate) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('当前角色无记账权限')),
            );
            return;
          }
          context.push('/add-transaction');
        },
        elevation: 2,
        backgroundColor:
            isDark ? ColorTokens.primaryLight : ColorTokens.primary,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded,
            color: Colors.white, size: IconSizeTokens.md),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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
