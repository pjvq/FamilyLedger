import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/format.dart';
import '../../../domain/providers/dashboard_provider.dart';
import 'overview_card_container.dart';

/// Monthly income/expense summary with a mini donut chart.
///
/// Hidden when no trend data available.
class MonthlySummaryCard extends ConsumerWidget {
  const MonthlySummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trend = ref.watch(dashboardProvider.select((s) => s.incomeExpenseTrend));
    final colors = context.semanticColors;

    // Hide when no data
    if (trend.isEmpty) return const SizedBox.shrink();

    final current = trend.last;
    final income = current.income;
    final expense = current.expense;
    final net = income - expense;

    return OverviewCardContainer(
      margin: const EdgeInsets.symmetric(horizontal: SpacingTokens.base),
      child: Row(
        children: [
          // Donut chart
          SizedBox(
            width: 64,
            height: 64,
            child: income == 0 && expense == 0
                ? Center(
                    child: Icon(Icons.pie_chart_outline_rounded,
                        size: IconSizeTokens.xl,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
                  )
                : PieChart(
                    PieChartData(
                      sections: [
                        PieChartSectionData(
                          color: colors.income,
                          value: income.toDouble(),
                          title: '',
                          radius: 10,
                        ),
                        PieChartSectionData(
                          color: colors.expense,
                          value: expense.toDouble(),
                          title: '',
                          radius: 10,
                        ),
                      ],
                      centerSpaceRadius: 20,
                      sectionsSpace: 2,
                      startDegreeOffset: -90,
                    ),
                  ),
          ),
          const SizedBox(width: SpacingTokens.base),
          // Text info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '本月收支',
                  style: TypographyTokens.bodySm(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: SpacingTokens.sm),
                Row(
                  children: [
                    _AmountDot(label: '收入', amount: income, color: colors.income),
                    const SizedBox(width: SpacingTokens.md),
                    _AmountDot(label: '支出', amount: expense, color: colors.expense),
                  ],
                ),
                const SizedBox(height: SpacingTokens.xs),
                Text(
                  '结余 ¥${formatCentsDisplay(net)}',
                  style: TypographyTokens.caption(
                    color: net >= 0 ? colors.income : colors.expense,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountDot extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;

  const _AmountDot({required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: SpacingTokens.sm,
          height: SpacingTokens.sm,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: SpacingTokens.xs),
        Text(
          '$label ¥${formatCentsMini(amount)}',
          style: TypographyTokens.bodySm().copyWith(
            fontWeight: FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
