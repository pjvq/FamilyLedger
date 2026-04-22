import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/providers/investment_provider.dart';

/// Portfolio allocation pie chart
class PortfolioChart extends ConsumerStatefulWidget {
  const PortfolioChart({super.key});

  @override
  ConsumerState<PortfolioChart> createState() => _PortfolioChartState();
}

class _PortfolioChartState extends ConsumerState<PortfolioChart> {
  int? _touchedIndex;

  static const _chartColors = [
    Color(0xFF5B6EF5), // primary
    Color(0xFF34C759), // green
    Color(0xFFFF9500), // orange
    Color(0xFFFF6B6B), // red
    Color(0xFFAF52DE), // purple
    Color(0xFF5AC8FA), // blue
    Color(0xFFFFCC00), // yellow
    Color(0xFFFF2D55), // pink
    Color(0xFF64D2FF), // light blue
    Color(0xFF30D158), // light green
  ];

  @override
  Widget build(BuildContext context) {
    final invState = ref.watch(investmentProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final portfolio = invState.portfolio;

    if (portfolio.holdings.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            '暂无持仓数据',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '持仓分布',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              label: '持仓分布饼图，共${portfolio.holdings.length}个持仓',
              child: SizedBox(
                height: 220,
                child: Row(
                  children: [
                    // Pie chart
                    Expanded(
                      flex: 3,
                      child: PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback: (event, response) {
                              if (!event.isInterestedForInteractions ||
                                  response == null ||
                                  response.touchedSection == null) {
                                setState(() => _touchedIndex = null);
                                return;
                              }
                              setState(() => _touchedIndex = response
                                  .touchedSection!.touchedSectionIndex);
                            },
                          ),
                          sections: _buildSections(portfolio, isDark),
                          centerSpaceRadius: 36,
                          sectionsSpace: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Legend
                    Expanded(
                      flex: 2,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: portfolio.holdings
                            .asMap()
                            .entries
                            .map((e) => _LegendItem(
                                  color:
                                      _chartColors[e.key % _chartColors.length],
                                  label: e.value.symbol,
                                  percent: e.value.weight * 100,
                                  isHighlighted: _touchedIndex == e.key,
                                  theme: theme,
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Touched detail
            if (_touchedIndex != null &&
                _touchedIndex! < portfolio.holdings.length)
              _HoldingDetail(
                holding: portfolio.holdings[_touchedIndex!],
                color: _chartColors[_touchedIndex! % _chartColors.length],
                isDark: isDark,
                theme: theme,
              ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildSections(
      PortfolioSummary portfolio, bool isDark) {
    return portfolio.holdings.asMap().entries.map((e) {
      final index = e.key;
      final holding = e.value;
      final isTouched = _touchedIndex == index;
      final radius = isTouched ? 60.0 : 50.0;
      final fontSize = isTouched ? 14.0 : 11.0;
      final color = _chartColors[index % _chartColors.length];

      return PieChartSectionData(
        color: color,
        value: holding.weight * 100,
        title: isTouched
            ? '${(holding.weight * 100).toStringAsFixed(1)}%'
            : '',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        badgePositionPercentageOffset: 0.98,
      );
    }).toList();
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final double percent;
  final bool isHighlighted;
  final ThemeData theme;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.percent,
    required this.isHighlighted,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w400,
                fontSize: isHighlighted ? 12 : 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${percent.toStringAsFixed(1)}%',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _HoldingDetail extends StatelessWidget {
  final HoldingDisplayItem holding;
  final Color color;
  final bool isDark;
  final ThemeData theme;

  const _HoldingDetail({
    required this.holding,
    required this.color,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = holding.returnRate >= 0;
    final retColor = isPositive
        ? (isDark ? AppColors.incomeDark : AppColors.income)
        : (isDark ? AppColors.expenseDark : AppColors.expense);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${holding.name} (${holding.symbol})',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '持仓 ${_fmtQty(holding.quantity)} · 占比 ${(holding.weight * 100).toStringAsFixed(1)}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '¥${_fmtYuan(holding.currentValue)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '${isPositive ? "+" : ""}${(holding.returnRate * 100).toStringAsFixed(2)}%',
                style: TextStyle(
                  color: retColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtQty(double qty) {
    if (qty == qty.truncateToDouble()) return qty.toInt().toString();
    return qty.toStringAsFixed(4);
  }

  String _fmtYuan(int cents) {
    final yuan = cents / 100;
    if (yuan.abs() >= 10000) {
      return '${(yuan / 10000).toStringAsFixed(2)}万';
    }
    return yuan.toStringAsFixed(2);
  }
}
