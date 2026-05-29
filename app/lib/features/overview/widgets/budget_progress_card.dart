import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../domain/providers/budget_provider.dart';
import 'overview_card_container.dart';

/// Budget progress card — shows top 3 category budgets with linear progress bars.
///
/// Hidden when no budget is configured.
class BudgetProgressCard extends ConsumerWidget {
  const BudgetProgressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final execution = ref.watch(budgetProvider.select((s) => s.execution));
    if (execution == null || execution.totalBudget == 0) {
      return const SizedBox.shrink();
    }

    final colors = context.semanticColors;

    // Sort by execution rate descending, take top 3
    final categoriesByRate = [...execution.categoryExecutions]
      ..sort((a, b) => b.executionRate.compareTo(a.executionRate));
    final top3 = categoriesByRate.take(3).toList();

    if (top3.isEmpty) return const SizedBox.shrink();

    return OverviewCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.track_changes_rounded,
                  size: IconSizeTokens.xs, color: colors.warning),
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
                colors: colors,
              )),
        ],
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
  final AppSemanticColors colors;

  const _BudgetCategoryRow({
    required this.name,
    required this.rate,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = BudgetProgressCard._rateColor(rate, colors);

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
          const SizedBox(height: SpacingTokens.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(RadiusTokens.sm / 2),
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
