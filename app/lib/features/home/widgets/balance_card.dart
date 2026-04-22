import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class BalanceCard extends StatelessWidget {
  final int totalBalance; // 分
  final int todayExpense; // 分
  final int monthExpense; // 分

  const BalanceCard({
    super.key,
    required this.totalBalance,
    required this.todayExpense,
    required this.monthExpense,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF2C2C4A), const Color(0xFF1C1C3E)]
              : [AppColors.primary, const Color(0xFF4A5AF0)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '总余额',
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
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _SummaryItem(
                label: '今日支出',
                amount: todayExpense,
                color: AppColors.expense,
              ),
              const SizedBox(width: 32),
              _SummaryItem(
                label: '本月支出',
                amount: monthExpense,
                color: const Color(0xFFFFB74D),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatAmount(int cents) {
    final yuan = cents / 100;
    if (yuan == yuan.truncateToDouble()) {
      return yuan.toInt().toString();
    }
    return yuan.toStringAsFixed(2);
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '¥ ${(amount / 100).toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
