import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/local/database.dart';

class TransactionListItem extends StatelessWidget {
  final Transaction transaction;
  final String categoryName;
  final String categoryIcon;

  const TransactionListItem({
    super.key,
    required this.transaction,
    required this.categoryName,
    required this.categoryIcon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isExpense = transaction.type == 'expense';
    final amountColor = isExpense
        ? (isDark ? AppColors.expenseDark : AppColors.expense)
        : (isDark ? AppColors.incomeDark : AppColors.income);
    final sign = isExpense ? '-' : '+';
    final amount = (transaction.amountCny / 100).toStringAsFixed(2);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Category icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: amountColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    categoryIcon,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Category name + note
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoryName,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (transaction.note.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        transaction.note,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Amount + date
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$sign¥$amount',
                    style: TextStyle(
                      color: amountColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(transaction.txnDate),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final txnDay = DateTime(date.year, date.month, date.day);

    if (txnDay == today) return '今天 ${DateFormat.Hm().format(date)}';
    if (txnDay == today.subtract(const Duration(days: 1))) {
      return '昨天 ${DateFormat.Hm().format(date)}';
    }
    if (date.year == now.year) {
      return DateFormat('M/d HH:mm').format(date);
    }
    return DateFormat('yyyy/M/d').format(date);
  }
}
