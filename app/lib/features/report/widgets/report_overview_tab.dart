import 'dart:ui' show FontFeature;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/category_icon_widget.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/theme/tokens/semantic_theme_extension.dart';
import '../../../data/local/database.dart' as db;
import 'report_utils.dart';

/// 概览 Tab — 收支总览 + 饼图 + 月度趋势
class ReportOverviewTab extends StatefulWidget {
  final List<db.Transaction> transactions;
  final Map<String, db.Category> categoryMap;
  final bool isLoading;

  const ReportOverviewTab({
    super.key,
    required this.transactions,
    required this.categoryMap,
    required this.isLoading,
  });

  @override
  State<ReportOverviewTab> createState() => _ReportOverviewTabState();
}

class _ReportOverviewTabState extends State<ReportOverviewTab> {
  int _trendTab = 0; // 0=支出, 1=收入, 2=结余
  int? _trendTouchedMonth;
  int _pieTouchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = context.semanticColors;

    // Calculate totals
    int totalExpense = 0;
    int totalIncome = 0;
    for (final t in widget.transactions) {
      if (t.type == 'expense') {
        totalExpense += t.amountCny;
      } else if (t.type == 'income') {
        totalIncome += t.amountCny;
      }
    }
    final balance = totalIncome - totalExpense;

    // Expense by parent category (for pie chart)
    final parentAmounts = <String, int>{};
    for (final t in widget.transactions.where((t) => t.type == 'expense')) {
      final cat = widget.categoryMap[t.categoryId];
      final parentId =
          (cat?.parentId != null && cat!.parentId!.isNotEmpty)
              ? cat.parentId!
              : t.categoryId;
      parentAmounts[parentId] = (parentAmounts[parentId] ?? 0) + t.amountCny;
    }
    final sortedExpenseIds = parentAmounts.keys.toList()
      ..sort((a, b) => parentAmounts[b]!.compareTo(parentAmounts[a]!));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      children: [
        // ── Summary card ──
        _buildSummaryCard(
            theme, isDark, colors, totalExpense, totalIncome, balance),
        const SizedBox(height: 16),

        // ── Pie chart (expense breakdown) ──
        if (sortedExpenseIds.isNotEmpty && totalExpense > 0) ...[
          _buildSectionTitle(theme, '支出构成'),
          const SizedBox(height: 8),
          _buildPieChart(sortedExpenseIds, parentAmounts, totalExpense,
              isDark, theme),
          const SizedBox(height: 16),
        ],

        // ── Monthly trend ──
        _buildSectionTitle(theme, '月度趋势'),
        const SizedBox(height: 8),
        _buildMonthlyTrend(isDark, theme, colors),
      ],
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _buildSummaryCard(ThemeData theme, bool isDark, AppSemanticColors colors,
      int expense, int income, int balance) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? NeutralColorsDark.neutral2 : NeutralColorsLight.neutral0,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _summaryItem('支出', expense, colors.expense, theme),
          ),
          Container(
            width: 1,
            height: 40,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
          ),
          Expanded(
            child: _summaryItem('收入', income, colors.income, theme),
          ),
          Container(
            width: 1,
            height: 40,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
          ),
          Expanded(
            child: _summaryItem(
                '结余', balance, balance >= 0 ? colors.income : colors.expense, theme),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, int cents, Color color, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Text(label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              )),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '¥${fmtYuan(cents.abs())}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(
    List<String> sortedIds,
    Map<String, int> amounts,
    int total,
    bool isDark,
    ThemeData theme,
  ) {
    // Top 5 + others
    final displayIds = sortedIds.take(5).toList();
    int othersAmount = 0;
    if (sortedIds.length > 5) {
      for (int i = 5; i < sortedIds.length; i++) {
        othersAmount += amounts[sortedIds[i]]!;
      }
    }

    final sections = <PieChartSectionData>[];
    for (int i = 0; i < displayIds.length; i++) {
      final id = displayIds[i];
      final amt = amounts[id]!;
      final pct = amt / total * 100;
      final cat = widget.categoryMap[id];
      final color = chartColors[i % chartColors.length];
      final isTouched = i == _pieTouchedIndex;

      sections.add(PieChartSectionData(
        color: color,
        value: amt.toDouble(),
        title: isTouched
            ? '¥${fmtYuan(amt)}'
            : (pct >= 5 ? '${pct.toStringAsFixed(0)}%' : ''),
        titleStyle: TextStyle(
          fontSize: isTouched ? 12 : 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        radius: isTouched ? 58 : 50,
        badgeWidget: pct >= 8 && !isTouched
            ? CategoryIconWidget(
                iconKey: cat?.iconKey, size: 14, showBackground: false)
            : null,
        badgePositionPercentageOffset: 1.3,
      ));
    }

    if (othersAmount > 0) {
      final pct = othersAmount / total * 100;
      final isTouched = displayIds.length == _pieTouchedIndex;
      sections.add(PieChartSectionData(
        color: Colors.grey,
        value: othersAmount.toDouble(),
        title: isTouched
            ? '¥${fmtYuan(othersAmount)}'
            : (pct >= 5 ? '${pct.toStringAsFixed(0)}%' : ''),
        titleStyle: TextStyle(
          fontSize: isTouched ? 12 : 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        radius: isTouched ? 58 : 50,
      ));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? NeutralColorsDark.neutral2 : NeutralColorsLight.neutral0,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: PieChart(
              key: ValueKey(sections.where((s) => s.badgeWidget != null).length),
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          pieTouchResponse == null ||
                          pieTouchResponse.touchedSection == null) {
                        _pieTouchedIndex = -1;
                        return;
                      }
                      _pieTouchedIndex = pieTouchResponse
                          .touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
                sections: sections,
                centerSpaceRadius: 36,
                sectionsSpace: 2,
              ),
              swapAnimationDuration: const Duration(milliseconds: 300),
              swapAnimationCurve: Curves.easeOutCubic,
            ),
          ),
          const SizedBox(height: 12),
          // Legend row
          Wrap(
            spacing: 12,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (int i = 0; i < displayIds.length; i++)
                _legendItem(
                  chartColors[i % chartColors.length],
                  widget.categoryMap[displayIds[i]]?.name ?? '未知',
                  theme,
                ),
              if (othersAmount > 0) _legendItem(Colors.grey, '其他', theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _buildMonthlyTrend(bool isDark, ThemeData theme, AppSemanticColors colors) {
    final monthlyExpense = List.filled(12, 0);
    final monthlyIncome = List.filled(12, 0);

    for (final t in widget.transactions) {
      final month = t.txnDate.month - 1;
      if (month < 0 || month > 11) continue;
      if (t.type == 'expense') {
        monthlyExpense[month] += t.amountCny;
      } else if (t.type == 'income') {
        monthlyIncome[month] += t.amountCny;
      }
    }

    final monthlyBalance =
        List.generate(12, (i) => monthlyIncome[i] - monthlyExpense[i]);

    List<int> data;
    switch (_trendTab) {
      case 1:
        data = monthlyIncome;
      case 2:
        data = monthlyBalance;
      default:
        data = monthlyExpense;
    }

    final maxVal = data.fold(0, (int a, int b) => a > b.abs() ? a : b.abs());
    final maxY = maxVal > 0 ? maxVal.toDouble() * 1.2 : 100.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? NeutralColorsDark.neutral2 : NeutralColorsLight.neutral0,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Spacer(),
              MiniSegment(
                labels: const ['支出', '收入', '结余'],
                selected: _trendTab,
                onTap: (i) => setState(() {
                  _trendTab = i;
                  _trendTouchedMonth = null;
                }),
              ),
            ],
          ),
          if (_trendTouchedMonth != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_trendTouchedMonth! + 1}月 ${_trendTab == 1 ? "收入" : _trendTab == 2 ? "结余" : "支出"} ${_trendTab == 2 && data[_trendTouchedMonth!] < 0 ? "-" : ""}¥${fmtYuan(data[_trendTouchedMonth!].abs())}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                minY: _trendTab == 2 ? -maxY : 0,
                barTouchData: BarTouchData(
                  touchCallback: (event, response) {
                    if (response?.spot != null) {
                      setState(() => _trendTouchedMonth =
                          response!.spot!.touchedBarGroupIndex);
                    }
                  },
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.transparent,
                    getTooltipItem: (_, __, ___, ____) => null,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, _) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${val.toInt() + 1}月',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY > 0 ? maxY / 3 : 1,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(12, (i) {
                  final val = data[i].toDouble();
                  final color = _trendTab == 2
                      ? (val >= 0 ? colors.income : colors.expense)
                      : (_trendTab == 1
                          ? colors.income
                          : (isDark ? colors.expense : ColorTokens.primary));
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: _trendTab == 2 ? (val >= 0 ? val : 0) : val.abs(),
                        fromY: _trendTab == 2 && val < 0 ? val : 0,
                        color: i == _trendTouchedMonth
                            ? color.withValues(alpha: 0.9)
                            : color.withValues(alpha: 0.7),
                        width: 14,
                        borderRadius: _trendTab == 2 && val < 0
                            ? const BorderRadius.vertical(
                                bottom: Radius.circular(4))
                            : const BorderRadius.vertical(
                                top: Radius.circular(4)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
