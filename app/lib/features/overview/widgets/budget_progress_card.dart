import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../domain/providers/budget_provider.dart';

/// Budget progress card — shows top 3 category budgets with linear progress bars.
class BudgetProgressCard extends ConsumerWidget {
  const BudgetProgressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final execution = ref.watch(budgetProvider.select((s) => s.execution));
    if (execution == null || execution.totalBudget == 0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = context.semanticColors;

    // Sort by execution rate descending, take top 3
    final sorted = [...execution.categoryExecutions]
      ..sort((a, b) => b.executionRate.compareTo(a.executionRate));
    final top3 = sorted.take(3).toList();

    if (top3.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          SpacingTokens.base, SpacingTokens.sm, SpacingTokens.base, SpacingTokens.sm),
      child: Container(
        padding: const EdgeInsets.all(SpacingTokens.base),
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
            Row(
              children: [
                Icon(Icons.track_changes_rounded,
                    size: 16, color: colors.warning),
                const SizedBox(width: SpacingTokens.xs),
                Text(
                  '预算进度',
                  style: TypographyTokens.bodySm().copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${(execution.executionRate * 100).toInt()}%',
                  style: TypographyTokens.bodySm().copyWith(
                    fontWeight: FontWeight.w700,
                    color: _rateColor(execution.executionRate, colors),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.md),
            // Top 3 categories
            ...top3.map((cat) => _BudgetCategoryRow(
                  name: cat.categoryName,
                  rate: cat.executionRate,
                  spent: cat.spentAmount,
                  budget: cat.budgetAmount,
                  colors: colors,
                )),
          ],
        ),
      ),
    );
  }

  static Color _rateColor(double rate, AppSemanticColors colors) {
    if (rate >= 1.0) return colors.error;
    if (rate >= 0.8) return colors.warning;
    return colors.income;
  }
}

class _BudgetCategoryRow extends StatelessWidget {
  final String name;
  final double rate;
  final int spent;
  final int budget;
  final AppSemanticColors colors;

  const _BudgetCategoryRow({
    required this.name,
    required this.rate,
    required this.spent,
    required this.budget,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = rate >= 1.0
        ? colors.error
        : rate >= 0.8
            ? colors.warning
            : colors.income;

    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TypographyTokens.caption(),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${(rate * 100).toInt()}%',
                style: TypographyTokens.caption(color: barColor).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: rate.clamp(0.0, 1.0),
              backgroundColor:
                  Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
              color: barColor,
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}
