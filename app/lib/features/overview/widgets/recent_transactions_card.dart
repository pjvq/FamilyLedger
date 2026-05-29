import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/local/database.dart';
import '../../../domain/providers/transaction_provider.dart';

/// Recent transactions card — shows last 5 transactions.
class RecentTransactionsCard extends ConsumerWidget {
  const RecentTransactionsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(
        transactionProvider.select((s) => s.transactions));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = context.semanticColors;

    // Take at most 5 most recent
    final recent = transactions.take(5).toList();
    if (recent.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          SpacingTokens.base, SpacingTokens.sm, SpacingTokens.base, SpacingTokens.sm),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? NeutralColorsDark.neutral2 : NeutralColorsLight.neutral1,
          borderRadius: BorderRadius.circular(RadiusTokens.lg),
          border: Border.all(
            color: isDark ? NeutralColorsDark.neutral3 : NeutralColorsLight.neutral3,
            width: 0.5,
          ),
        ),
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
                      size: 16,
                      color: isDark ? ColorTokens.primaryLight : ColorTokens.primary),
                  const SizedBox(width: SpacingTokens.xs),
                  Text(
                    '最近交易',
                    style: TypographyTokens.bodySm().copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.push(AppRouter.transactionHistory),
                    child: Text(
                      '查看全部',
                      style: TypographyTokens.caption(
                        color: isDark ? ColorTokens.primaryLight : ColorTokens.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Transaction list
            ...recent.map((txn) => _TransactionItem(
                  transaction: txn,
                  colors: colors,
                )),
            const SizedBox(height: SpacingTokens.sm),
          ],
        ),
      ),
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final Transaction transaction;
  final AppSemanticColors colors;

  const _TransactionItem({required this.transaction, required this.colors});

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == 'expense';
    final isTransfer = transaction.type == 'transfer';
    final color = isExpense
        ? colors.expense
        : isTransfer
            ? colors.info
            : colors.income;
    final sign = isExpense ? '-' : isTransfer ? '' : '+';
    final yuan = transaction.amountCny / 100;
    final display = yuan.abs() >= 10000
        ? '${(yuan / 10000).toStringAsFixed(2)}万'
        : yuan.toStringAsFixed(2);

    final date = transaction.txnDate;
    final dateStr = '${date.month}/${date.day}';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.base,
        vertical: SpacingTokens.xs + 2,
      ),
      child: Row(
        children: [
          // Icon placeholder
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isExpense
                  ? Icons.arrow_downward_rounded
                  : isTransfer
                      ? Icons.swap_horiz_rounded
                      : Icons.arrow_upward_rounded,
              size: 16,
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
                  transaction.note.isEmpty ? transaction.type : transaction.note,
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
            '$sign¥$display',
            style: TypographyTokens.bodyMd().copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
