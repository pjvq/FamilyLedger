import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart';
import '../../domain/providers/account_provider.dart';
import '../../domain/providers/app_providers.dart';
import '../../domain/providers/auth_provider.dart';
import '../../domain/providers/family_provider.dart';
import '../../domain/providers/transaction_provider.dart';
import '../../sync/sync_engine.dart';
import 'widgets/balance_card.dart';
import 'widgets/transaction_list_item.dart';

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

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _DashboardTab(),
          _AccountsTab(),
          SizedBox(), // placeholder for FAB center
          _StatsTab(),
          _SettingsTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex == 2 ? 0 : _currentIndex, // FAB center doesn't select
        onDestinationSelected: (index) {
          if (index == 2) {
            // Center: 记一笔
            Navigator.of(context).pushNamed(AppRouter.addTransaction);
            return;
          }
          setState(() => _currentIndex = index);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_rounded),
            selectedIcon: Icon(Icons.home_rounded),
            label: '首页',
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
            icon: Icon(Icons.bar_chart_rounded),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: '统计',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: '设置',
          ),
        ],
      ),
    );
  }
}

// ────────── Dashboard Tab (the original Home) ──────────

class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txnState = ref.watch(transactionProvider);
    final familyState = ref.watch(familyProvider);
    final familyId = ref.watch(currentFamilyIdProvider);
    final theme = Theme.of(context);

    final hasFamily = familyState.currentFamily != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FamilyLedger'),
        centerTitle: false,
      ),
      body: txnState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await ref.read(syncEngineProvider).syncNow();
              },
              child: CustomScrollView(
                slivers: [
                  // Personal ↔ Family switcher
                  if (hasFamily)
                    SliverToBoxAdapter(
                      child: _ModeSwitcher(
                        isFamilyMode: familyId != null,
                        familyName: familyState.currentFamily!.name,
                        onToggle: (isFamily) {
                          ref.read(currentFamilyIdProvider.notifier).state =
                              isFamily
                                  ? familyState.currentFamily!.id
                                  : null;
                        },
                      ),
                    ),
                  // Balance card
                  SliverToBoxAdapter(
                    child: BalanceCard(
                      totalBalance: txnState.totalBalance,
                      todayExpense: txnState.todayExpense,
                      monthExpense: txnState.monthExpense,
                    ),
                  ),
                  // Section header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                      child: Text(
                        '最近交易',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  // Transaction list
                  if (txnState.transactions.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _TransactionEmptyState(theme: theme),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final txn = txnState.transactions[index];
                          final allCats = [
                            ...txnState.expenseCategories,
                            ...txnState.incomeCategories,
                          ];
                          final cat = allCats
                              .where((c) => c.id == txn.categoryId)
                              .firstOrNull;
                          return TransactionListItem(
                            transaction: txn,
                            categoryName: cat?.name ?? '未知',
                            categoryIcon: cat?.icon ?? '📦',
                          );
                        },
                        childCount: txnState.transactions.length,
                      ),
                    ),
                ],
              ),
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

// ────────── Placeholder tabs ──────────

class _AccountsTab extends ConsumerWidget {
  const _AccountsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reuse the AccountsPage but embedded (no separate scaffold push)
    return const _EmbeddedAccountsTab();
  }
}

class _EmbeddedAccountsTab extends ConsumerWidget {
  const _EmbeddedAccountsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Import and use inline — avoiding circular issues
    // We just push the accounts route
    return Scaffold(
      appBar: AppBar(title: const Text('账户')),
      body: Builder(
        builder: (context) {
          // Use a redirect to the accounts page
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // This is a bit of a hack — let's just build inline
          });
          return const _AccountsInline();
        },
      ),
    );
  }
}

class _AccountsInline extends ConsumerWidget {
  const _AccountsInline();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Inline version of accounts — reuse the provider
    final accountState = ref.watch(accountProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (accountState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (accountState.accounts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_wallet_rounded,
              size: 80,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 16),
            Text(
              '还没有账户',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击下方按钮添加第一个账户',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRouter.addAccount),
              icon: const Icon(Icons.add_rounded),
              label: const Text('添加账户'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(accountProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          // Total
          _InlineTotalCard(
            total: accountState.totalBalance,
            count: accountState.accounts.length,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          ...accountState.accounts.map((acc) => _InlineAccountTile(
                account: acc,
                theme: theme,
                isDark: isDark,
              )),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRouter.transfer),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('转账'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRouter.addAccount),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('添加'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineTotalCard extends StatelessWidget {
  final int total;
  final int count;
  final bool isDark;

  const _InlineTotalCard({
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

class _InlineAccountTile extends StatelessWidget {
  final Account account;
  final ThemeData theme;
  final bool isDark;

  const _InlineAccountTile({
    required this.account,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
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
                child: Text(account.icon,
                    style: const TextStyle(fontSize: 20)),
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
    );
  }

  String _fmt(int cents) {
    final yuan = cents / 100;
    if (yuan == yuan.truncateToDouble()) return yuan.toInt().toString();
    return yuan.toStringAsFixed(2);
  }
}

class _StatsTab extends StatelessWidget {
  const _StatsTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('统计')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 80,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 16),
            Text(
              '统计功能开发中',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '敬请期待',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context) {
    // We can't directly import SettingsPage here because it's already a full Scaffold
    // So we push to the route
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Builder(
        builder: (context) {
          // Inline settings — redirect to settings page content
          return const _InlineSettingsContent();
        },
      ),
    );
  }
}

/// Inline settings content mirroring SettingsPage but embedded in the tab
class _InlineSettingsContent extends ConsumerWidget {
  const _InlineSettingsContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Push to the full settings page
    // This is cleaner than duplicating all the settings UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // No-op — we'll just build the settings inline
    });

    final authState = ref.watch(authProvider);
    final familyState = ref.watch(familyProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // User info card
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: isDark
                      ? AppColors.primaryDark.withValues(alpha: 0.2)
                      : AppColors.primary.withValues(alpha: 0.1),
                  child: Icon(
                    Icons.person_rounded,
                    size: 28,
                    color: isDark ? AppColors.primaryDark : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '我的账号',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        authState.userId ?? '',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Navigate to full settings page for family management
        _SettingListTile(
          icon: Icons.family_restroom_rounded,
          title: familyState.currentFamily != null
              ? familyState.currentFamily!.name
              : '家庭管理',
          subtitle: familyState.currentFamily != null
              ? '${familyState.members.length} 位成员'
              : '创建或加入家庭',
          onTap: () =>
              Navigator.of(context).pushNamed(AppRouter.settings),
        ),
        _SettingListTile(
          icon: Icons.logout_rounded,
          title: '退出登录',
          isDestructive: true,
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('退出登录'),
                content: const Text('确定要退出登录吗？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.expense,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('退出'),
                  ),
                ],
              ),
            );
            if (confirmed == true && context.mounted) {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil(AppRouter.login, (_) => false);
              }
            }
          },
        ),
      ],
    );
  }
}

class _SettingListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool isDestructive;
  final VoidCallback onTap;

  const _SettingListTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        isDestructive ? AppColors.expense : theme.colorScheme.onSurface;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: ListTile(
        leading: Icon(icon, color: color.withValues(alpha: 0.7)),
        title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        subtitle: subtitle != null
            ? Text(subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ))
            : null,
        trailing: Icon(Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: onTap,
      ),
    );
  }
}

// ────────── Transaction Empty State ──────────

class _TransactionEmptyState extends StatelessWidget {
  final ThemeData theme;
  const _TransactionEmptyState({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 80,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 16),
          Text(
            '还没有交易记录',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方 "记账" 按钮开始',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}
