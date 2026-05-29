import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../domain/models/dashboard_models.dart';
import '../../../domain/providers/dashboard_provider.dart';

/// Monthly income/expense summary with a mini donut chart.
class MonthlySummaryCard extends ConsumerWidget {
  const MonthlySummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trend = ref.watch(dashboardProvider.select((s) => s.incomeExpenseTrend));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = context.semanticColors;

    // Current month is the last point in trend data
    final current = trend.isNotEmpty ? trend.last : const TrendPointData(label: '', income: 0, expense: 0, net: 0);
    final income = current.income;
    final expense = current.expense;
    final net = income - expense;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.base),
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
        child: Row(
          children: [
            // Donut chart
            SizedBox(
              width: 64,
              height: 64,
              child: income == 0 && expense == 0
                  ? Center(
                      child: Icon(Icons.pie_chart_outline_rounded,
                          size: 32,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
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
                    style: TypographyTokens.bodySm().copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _AmountChip(
                        label: '收入',
                        amount: income,
                        color: colors.income,
                      ),
                      const SizedBox(width: 12),
                      _AmountChip(
                        label: '支出',
                        amount: expense,
                        color: colors.expense,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '结余 ¥${_fmtYuan(net)}',
                    style: TypographyTokens.caption(
                      color: net >= 0 ? colors.income : colors.expense,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtYuan(int cents) {
    final yuan = cents / 100;
    if (yuan.abs() >= 10000) return '${(yuan / 10000).toStringAsFixed(2)}万';
    return yuan.toStringAsFixed(2);
  }
}

class _AmountChip extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;

  const _AmountChip({required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    final yuan = amount / 100;
    final display = yuan.abs() >= 10000
        ? '${(yuan / 10000).toStringAsFixed(1)}万'
        : yuan.toStringAsFixed(0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label ¥$display',
          style: TypographyTokens.bodySm().copyWith(
            fontWeight: FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
