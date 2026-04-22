import 'package:flutter/material.dart';

/// 通用空状态组件
///
/// 显示大图标 + 标题 + 引导文案 + 可选操作按钮。
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double iconSize;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconSize = 80,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                height: 1.4,
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ────────── 各页面预设空状态 ──────────

class TransactionEmptyState extends StatelessWidget {
  final VoidCallback? onAdd;
  const TransactionEmptyState({super.key, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.receipt_long_rounded,
      title: '还没有记账哦',
      subtitle: '点击下方按钮记录第一笔',
      actionLabel: '记一笔',
      onAction: onAdd,
    );
  }
}

class LoanEmptyState extends StatelessWidget {
  final VoidCallback? onAdd;
  const LoanEmptyState({super.key, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.home_rounded,
      title: '暂无贷款记录',
      subtitle: '添加贷款开始跟踪还款进度',
      actionLabel: '添加贷款',
      onAction: onAdd,
    );
  }
}

class InvestmentEmptyState extends StatelessWidget {
  final VoidCallback? onAdd;
  const InvestmentEmptyState({super.key, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.trending_up_rounded,
      title: '还没有投资',
      subtitle: '添加投资品种开始跟踪收益',
      actionLabel: '添加投资',
      onAction: onAdd,
    );
  }
}

class AssetEmptyState extends StatelessWidget {
  final VoidCallback? onAdd;
  const AssetEmptyState({super.key, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.domain_rounded,
      title: '暂无固定资产',
      subtitle: '记录您的房产、车辆等大额资产',
      actionLabel: '添加资产',
      onAction: onAdd,
    );
  }
}

class BudgetEmptyState extends StatelessWidget {
  final VoidCallback? onAdd;
  const BudgetEmptyState({super.key, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.savings_rounded,
      title: '还没有设置预算',
      subtitle: '设置月度预算控制支出',
      actionLabel: '设置预算',
      onAction: onAdd,
    );
  }
}

class NotificationEmptyState extends StatelessWidget {
  const NotificationEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.notifications_none_rounded,
      title: '暂无通知',
      subtitle: '一切正常，稍后再来看看',
    );
  }
}

class AccountEmptyState extends StatelessWidget {
  final VoidCallback? onAdd;
  const AccountEmptyState({super.key, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.account_balance_wallet_rounded,
      title: '还没有账户',
      subtitle: '点击下方按钮添加第一个账户',
      actionLabel: '添加账户',
      onAction: onAdd,
    );
  }
}
