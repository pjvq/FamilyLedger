import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../data/local/database.dart';
import '../../domain/providers/account_provider.dart';

/// 资产 Tab 页 — 合并展示银行账户、贷款、投资、固定资产。
class AssetsTabPage extends ConsumerWidget {
  const AssetsTabPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accountState = ref.watch(accountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('资产'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: '添加账户',
            onPressed: () => context.push('/assets/accounts/add'),
          ),
        ],
      ),
      body: accountState.isLoading
          ? const SkeletonList(count: 5, itemHeight: 72)
          : accountState.error != null
              ? ErrorState(
                  message: accountState.error!,
                  onRetry: () =>
                      ref.read(accountProvider.notifier).refresh(),
                )
              : _buildBody(context, ref, accountState, isDark),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AccountState accountState,
    bool isDark,
  ) {
    final accounts = accountState.accounts;

    if (accounts.isEmpty) {
      return EmptyState(
        icon: Icons.account_balance_wallet_rounded,
        title: '暂无账户',
        subtitle: '添加你的第一个账户开始管理资产',
        actionLabel: '添加账户',
        onAction: () => context.push('/assets/accounts/add'),
      );
    }

    final totalBalance = accounts.fold<int>(0, (sum, a) => sum + a.balance);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(accountProvider.notifier).refresh();
      },
      child: ListView(
        padding: const EdgeInsets.all(SpacingTokens.base),
        children: [
          // Total card
          _TotalCard(total: totalBalance, count: accounts.length, isDark: isDark),
          const SizedBox(height: SpacingTokens.base),

          // Quick actions
          _QuickActions(isDark: isDark),
          const SizedBox(height: SpacingTokens.base),

          // Account list
          ...accounts.map((account) => _AccountTile(
                account: account,
                isDark: isDark,
                onTap: () => context.push(AppRouter.accountDetail(account.id)),
              )),
        ],
      ),
    );
  }
}

// ─── Total Card ───

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
      padding: const EdgeInsets.all(SpacingTokens.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [DarkCardGradients.netWorthStart, DarkCardGradients.netWorthEnd]
              : [context.semanticColors.income, GradientTokens.incomeGradientEnd],
        ),
        borderRadius: BorderRadius.circular(RadiusTokens.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '总资产',
            style: TypographyTokens.bodySm(color: Colors.white70),
          ),
          const SizedBox(height: SpacingTokens.sm),
          Text(
            '¥ ${formatCentsCompact(total)}',
            style: TypographyTokens.displayMd(color: Colors.white),
          ),
          const SizedBox(height: SpacingTokens.xs),
          Text(
            '共 $count 个账户',
            style: TypographyTokens.caption(color: Colors.white60),
          ),
        ],
      ),
    );
  }

}

// ─── Quick Actions ───

class _QuickActions extends StatelessWidget {
  final bool isDark;

  const _QuickActions({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionChip(
          icon: Icons.swap_horiz_rounded,
          label: '转账',
          onTap: () => context.push('/transfer'),
          isDark: isDark,
        ),
        const SizedBox(width: SpacingTokens.sm),
        _ActionChip(
          icon: Icons.account_balance_rounded,
          label: '贷款',
          onTap: () => context.push('/assets/loans'),
          isDark: isDark,
        ),
        const SizedBox(width: SpacingTokens.sm),
        _ActionChip(
          icon: Icons.trending_up_rounded,
          label: '投资',
          onTap: () => context.push('/assets/investments'),
          isDark: isDark,
        ),
        const SizedBox(width: SpacingTokens.sm),
        _ActionChip(
          icon: Icons.home_work_rounded,
          label: '固定资产',
          onTap: () => context.push('/assets/fixed'),
          isDark: isDark,
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(RadiusTokens.md),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            color: isDark
                ? NeutralColorsDark.neutral2
                : NeutralColorsLight.neutral2,
            borderRadius: BorderRadius.circular(RadiusTokens.md),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(RadiusTokens.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: SpacingTokens.md,
              ),
              child: Column(
                children: [
                  Icon(icon, size: IconSizeTokens.md,
                    color: ColorTokens.primary),
                  const SizedBox(height: SpacingTokens.xs),
                  Text(
                    label,
                    style: TypographyTokens.caption(),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Account Tile ───

class _AccountTile extends StatelessWidget {
  final Account account;
  final bool isDark;
  final VoidCallback? onTap;

  const _AccountTile({
    required this.account,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = account.balance >= 0;
    final amountColor = isPositive
        ? context.semanticColors.income
        : context.semanticColors.expense;

    return Card(
      margin: const EdgeInsets.only(bottom: SpacingTokens.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.base,
            vertical: SpacingTokens.md,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark
                      ? NeutralColorsDark.neutral2
                      : NeutralColorsLight.neutral2,
                  borderRadius: BorderRadius.circular(RadiusTokens.md),
                ),
                child: Center(
                  child: Text(account.icon,
                      style: const TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: SpacingTokens.md),
              Expanded(
                child: Text(
                  account.name,
                  style: TypographyTokens.bodyMd().copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '¥ ${formatCentsCompact(account.balance)}',
                style: TypographyTokens.amount(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: amountColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
