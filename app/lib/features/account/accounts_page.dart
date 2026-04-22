import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart';
import '../../domain/providers/account_provider.dart';

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountState = ref.watch(accountProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('账户'),
      ),
      body: accountState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : accountState.accounts.isEmpty
              ? _EmptyState(theme: theme)
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(accountProvider.notifier).refresh(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    children: [
                      // Total balance summary
                      _TotalBalanceCard(
                        totalBalance: accountState.totalBalance,
                        accountCount: accountState.accounts.length,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 16),
                      // Account list
                      ...accountState.accounts.map(
                        (account) => _AccountCard(
                          account: account,
                          isDark: isDark,
                          theme: theme,
                        ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'transfer',
            onPressed: () {
              Navigator.of(context).pushNamed(AppRouter.transfer);
            },
            backgroundColor:
                isDark ? AppColors.cardDark : AppColors.cardLight,
            child: Icon(
              Icons.swap_horiz_rounded,
              color: isDark ? AppColors.primaryDark : AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'addAccount',
            onPressed: () {
              Navigator.of(context).pushNamed(AppRouter.addAccount);
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('添加账户'),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ThemeData theme;
  const _EmptyState({required this.theme});

  @override
  Widget build(BuildContext context) {
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
            '点击右下角按钮添加第一个账户',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalBalanceCard extends StatelessWidget {
  final int totalBalance;
  final int accountCount;
  final bool isDark;

  const _TotalBalanceCard({
    required this.totalBalance,
    required this.accountCount,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '总资产 ${_formatAmount(totalBalance)} 元，共 $accountCount 个账户',
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1A3A2A), const Color(0xFF0F2A1F)]
                : [AppColors.income, const Color(0xFF28B34A)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.income.withValues(alpha: isDark ? 0.15 : 0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '总资产',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '¥ ${_formatAmount(totalBalance)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '共 $accountCount 个账户',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatAmount(int cents) {
    final yuan = cents / 100;
    if (yuan == yuan.truncateToDouble()) return yuan.toInt().toString();
    return yuan.toStringAsFixed(2);
  }
}

class _AccountCard extends StatelessWidget {
  final Account account;
  final bool isDark;
  final ThemeData theme;

  const _AccountCard({
    required this.account,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final typeName = AccountTypeHelper.displayName(account.accountType);
    final typeIcon = account.icon;

    return Semantics(
      label: '${account.name}，$typeName，余额 ${_formatAmount(account.balance)} 元',
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF3A3A3C)
                      : const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(typeIcon, style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 14),
              // Name + type
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      typeName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              // Balance
              Text(
                '¥ ${_formatAmount(account.balance)}',
                style: theme.textTheme.titleMedium?.copyWith(
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

  String _formatAmount(int cents) {
    final yuan = cents / 100;
    if (yuan == yuan.truncateToDouble()) return yuan.toInt().toString();
    return yuan.toStringAsFixed(2);
  }
}
