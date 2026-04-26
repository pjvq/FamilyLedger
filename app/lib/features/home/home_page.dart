import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart';
import '../../domain/providers/account_provider.dart';
import '../account/add_account_page.dart';
import '../../domain/providers/app_providers.dart';
import '../../domain/providers/family_provider.dart';
import '../../domain/providers/notification_provider.dart';
import '../../sync/sync_engine.dart';
import '../../core/widgets/sync_status_indicator.dart';
import '../../core/widgets/widgets.dart';
import '../budget/budget_page.dart';
import '../dashboard/dashboard_page.dart';
import '../more/more_page.dart';

/// Main shell with bottom navigation
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncEngineProvider).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final familyState = ref.watch(familyProvider);
    final familyId = ref.watch(currentFamilyIdProvider);
    final notifState = ref.watch(notificationProvider);
    final hasFamily = familyState.currentFamily != null;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _DashboardShell(
            hasFamily: hasFamily,
            isFamilyMode: familyId != null,
            familyName: familyState.currentFamily?.name ?? '',
            unreadCount: notifState.unreadCount,
          ),
          const _AccountsTab(),
          const SizedBox(), // placeholder for FAB center
          const BudgetPage(),
          const MorePage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex == 2 ? 0 : _currentIndex,
        onDestinationSelected: (index) {
          if (index == 2) {
            if (!ref.read(canCreateProvider)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('当前角色无记账权限')),
              );
              return;
            }
            Navigator.of(context).pushNamed(AppRouter.addTransaction);
            return;
          }
          setState(() => _currentIndex = index);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: '仪表盘',
          ),
          const NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: '账户',
          ),
          NavigationDestination(
            icon: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isDark ? AppColors.primaryDark : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
            ),
            label: '记账',
          ),
          const NavigationDestination(
            icon: Icon(Icons.savings_outlined),
            selectedIcon: Icon(Icons.savings_rounded),
            label: '预算',
          ),
          const NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded),
            selectedIcon: Icon(Icons.more_horiz_rounded),
            label: '更多',
          ),
        ],
      ),
    );
  }
}

// ────────── Dashboard Shell (AppBar + family switcher + DashboardPage) ──────

class _DashboardShell extends ConsumerWidget {
  final bool hasFamily;
  final bool isFamilyMode;
  final String familyName;
  final int unreadCount;

  const _DashboardShell({
    required this.hasFamily,
    required this.isFamilyMode,
    required this.familyName,
    required this.unreadCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FamilyLedger'),
        centerTitle: false,
        actions: [
          const SyncStatusIndicator(),
          IconButton(
            onPressed: () => Navigator.of(context)
                .pushNamed(AppRouter.transactionHistory),
            tooltip: '交易记录',
            icon: const Icon(Icons.receipt_long_outlined),
          ),
          _NotificationBell(
            unreadCount: unreadCount,
            onTap: () =>
                Navigator.of(context).pushNamed(AppRouter.notifications),
          ),
        ],
      ),
      body: Column(
        children: [
          // Personal ↔ Family switcher
          if (hasFamily)
            _ModeSwitcher(
              isFamilyMode: isFamilyMode,
              familyName: familyName,
              onToggle: (isFamily) {
                final familyState = ref.read(familyProvider);
                final newId = isFamily ? familyState.currentFamily?.id : null;
                ref.read(currentFamilyIdProvider.notifier).state = newId;
                final prefs = ref.read(sharedPreferencesProvider);
                if (newId != null) {
                  prefs.setString(AppConstants.familyIdKey, newId);
                } else {
                  prefs.remove(AppConstants.familyIdKey);
                }
              },
            ),
          const Expanded(child: DashboardPage()),
        ],
      ),
    );
  }
}

// ────────── Mode Switcher ──────────

class _ModeSwitcher extends StatelessWidget {
  final bool isFamilyMode;
  final String familyName;
  final ValueChanged<bool> onToggle;

  const _ModeSwitcher({
    required this.isFamilyMode,
    required this.familyName,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      label: isFamilyMode ? '当前为家庭模式，点击切换到个人模式' : '当前为个人模式，点击切换到家庭模式',
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: _SwitcherButton(
                label: '个人',
                icon: Icons.person_rounded,
                isActive: !isFamilyMode,
                isDark: isDark,
                onTap: () => onToggle(false),
              ),
            ),
            Expanded(
              child: _SwitcherButton(
                label: familyName,
                icon: Icons.family_restroom_rounded,
                isActive: isFamilyMode,
                isDark: isDark,
                onTap: () => onToggle(true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitcherButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _SwitcherButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? AppColors.cardDark : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive
                  ? (isDark ? AppColors.primaryDark : AppColors.primary)
                  : (isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive
                      ? (isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimary)
                      : (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────── Notification Bell ──────────

class _NotificationBell extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onTap;

  const _NotificationBell({
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: unreadCount > 0 ? '通知，$unreadCount条未读' : '通知',
      button: true,
      child: IconButton(
        onPressed: onTap,
        tooltip: unreadCount > 0 ? '通知，$unreadCount条未读' : '通知',
        icon: Badge(
          isLabelVisible: unreadCount > 0,
          label: Text(
            unreadCount > 99 ? '99+' : '$unreadCount',
            style: const TextStyle(fontSize: 10, color: Colors.white),
          ),
          child: Icon(
            Icons.notifications_outlined,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

// ────────── Accounts Tab ──────────

class _AccountsTab extends ConsumerWidget {
  const _AccountsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountState = ref.watch(accountProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('账户')),
      body: accountState.isLoading
          ? const SkeletonList(count: 5, itemHeight: 72)
          : accountState.error != null
              ? ErrorState(
                  message: accountState.error!,
                  onRetry: () => ref.read(accountProvider.notifier).refresh(),
                )
              : accountState.accounts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 80,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.15),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '还没有账户',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '点击下方按钮添加第一个账户',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context)
                            .pushNamed(AppRouter.addAccount),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('添加账户'),
                      ),
                    ],
                  ),
                )
              : CustomRefreshIndicator(
                  onRefresh: () =>
                      ref.read(accountProvider.notifier).refresh(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    children: [
                      _TotalCard(
                        total: accountState.totalBalance,
                        count: accountState.accounts.length,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),
                      ...accountState.accounts.map((acc) => _AccountTile(
                            account: acc,
                            theme: theme,
                            isDark: isDark,
                          )),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.of(context)
                                  .pushNamed(AppRouter.transfer),
                              icon: const Icon(Icons.swap_horiz_rounded,
                                  size: 18),
                              label: const Text('转账'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => Navigator.of(context)
                                  .pushNamed(AppRouter.addAccount),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('添加'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final int total;
  final int count;
  final bool isDark;

  const _TotalCard({
    required this.total,
    required this.count,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A3A2A), const Color(0xFF0F2A1F)]
              : [AppColors.income, const Color(0xFF28B34A)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '总资产',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '¥ ${_fmt(total)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '共 $count 个账户',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(int cents) {
    final yuan = cents / 100;
    if (yuan == yuan.truncateToDouble()) return yuan.toInt().toString();
    return yuan.toStringAsFixed(2);
  }
}

class _AccountTile extends StatelessWidget {
  final Account account;
  final ThemeData theme;
  final bool isDark;

  const _AccountTile({
    required this.account,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (_) => AddAccountPage(existingAccount: account),
            ),
          );
        },
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF3A3A3C)
                    : const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child:
                    Text(account.icon, style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                account.name,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              '¥ ${_fmt(account.balance)}',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: account.balance >= 0
                    ? (isDark ? AppColors.incomeDark : AppColors.income)
                    : (isDark ? AppColors.expenseDark : AppColors.expense),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  String _fmt(int cents) {
    final yuan = cents / 100;
    if (yuan == yuan.truncateToDouble()) return yuan.toInt().toString();
    return yuan.toStringAsFixed(2);
  }
}
