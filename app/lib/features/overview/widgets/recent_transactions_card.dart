import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/format.dart';
import '../../../data/local/database.dart';
import '../../../domain/models/transaction_model.dart';
import '../../../domain/providers/transaction_provider.dart';
import 'overview_card_container.dart';

/// Recent transactions card — shows last 5 transactions.
///
/// Hidden when no transactions exist.
class RecentTransactionsCard extends ConsumerWidget {
  const RecentTransactionsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch full recent transactions — 5 items rebuild cost is negligible.
    final recent = ref.watch(recentTransactionsProvider);
    if (recent.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return OverviewCardContainer(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
                SpacingTokens.base, SpacingTokens.md,
                SpacingTokens.base, SpacingTokens.xs),
            child: Row(
              children: [
                Icon(Icons.receipt_long_rounded,
                    size: IconSizeTokens.xs,
                    color: isDark ? ColorTokens.primaryLight : ColorTokens.primary),
                const SizedBox(width: SpacingTokens.xs),
                Text(
                  '最近交易',
                  style: TypographyTokens.bodySm().copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(RadiusTokens.sm),
                  onTap: () => context.push(AppRouter.transactionHistory),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SpacingTokens.sm,
                      vertical: SpacingTokens.xs,
                    ),
                    child: Text(
                      '查看全部',
                      style: TypographyTokens.caption(
                        color: isDark ? ColorTokens.primaryLight : ColorTokens.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Transaction list
          ...recent.map((txn) => _TransactionItem(transaction: txn)),
          const SizedBox(height: SpacingTokens.sm),
        ],
      ),
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final Transaction transaction;

  const _TransactionItem({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final isExpense = transaction.type == TransactionType.expense.name;
    final isTransfer = transaction.type == TransactionType.transfer.name;
    final color = isExpense
        ? colors.expense
        : isTransfer
            ? colors.info
            : colors.income;
    final sign = isExpense ? '-' : isTransfer ? '' : '+';

    final date = transaction.txnDate;
    final dateStr = '${date.month}/${date.day}';

    // Display note, or fallback to localized type label
    final displayLabel = transaction.note.isNotEmpty
        ? transaction.note
        : _typeLabel(transaction.type);

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => context.push(
          '${AppRouter.transactionDetail}/${transaction.id}',
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.base,
            vertical: SpacingTokens.sm,
          ),
          child: Row(
            children: [
              // Type icon
              Container(
                width: IconSizeTokens.xl,
                height: IconSizeTokens.xl,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(RadiusTokens.sm),
                ),
                child: Icon(
                  isExpense
                      ? Icons.arrow_downward_rounded
                      : isTransfer
                          ? Icons.swap_horiz_rounded
                          : Icons.arrow_upward_rounded,
                  size: IconSizeTokens.xs,
                  color: color,
                ),
              ),
              const SizedBox(width: SpacingTokens.md),
              // Note + date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayLabel,
                      style: TypographyTokens.bodyMd().copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      dateStr,
                      style: TypographyTokens.caption(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              // Amount
              Text(
                '$sign¥${formatCentsDisplay(transaction.amountCny)}',
                style: TypographyTokens.bodyMd().copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Map transaction type string to user-facing Chinese label.
String _typeLabel(String type) {
  if (type == TransactionType.expense.name) return '支出';
  if (type == TransactionType.income.name) return '收入';
  if (type == TransactionType.transfer.name) return '转账';
  return '交易';
}
