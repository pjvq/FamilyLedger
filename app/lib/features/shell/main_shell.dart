import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/design_tokens.dart';
import '../../domain/providers/family_provider.dart';
import '../transaction/widgets/quick_add_sheet.dart';

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

    // Map visual index (5 items) to branch index (4 branches)
    // Visual: 0=overview, 1=flow, 2=add(fake), 3=assets, 4=mine
    // Branch: 0=overview, 1=flow, 2=assets, 3=mine
    int visualIndex = navigationShell.currentIndex;
    // Shift indices >= 2 to account for the fake center tab
    if (visualIndex >= 2) visualIndex += 1;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: visualIndex,
        onDestinationSelected: (index) {
          if (index == 2) {
            // Center tab: open quick-add sheet
            if (!canCreate) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('当前角色无记账权限')),
              );
              return;
            }
            QuickAddSheet.show(context);
            return;
          }
          // Map visual index back to branch index
          final branchIndex = index > 2 ? index - 1 : index;
          navigationShell.goBranch(branchIndex);
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
          NavigationDestination(
            icon: Semantics(
              label: '记账',
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? ColorTokens.primaryLight : ColorTokens.primary,
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
              ),
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
}
