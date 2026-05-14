import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/providers/dashboard_provider.dart';
import '../../sync/sync_engine.dart';
import 'widgets/dashboard_card.dart';

// ── Shared formatting helpers (used by multiple chart widgets) ──

/// Format cents as abbreviated yuan string for axis labels.
/// e.g. 1250000 → "1.3万", 80000 → "800", 50 → "1"
String _shortAmount(int cents) {
  final yuan = cents / 100;
  if (yuan.abs() >= 10000) return '${(yuan / 10000).toStringAsFixed(1)}万';
  if (yuan.abs() >= 1000) return '${(yuan / 1000).toStringAsFixed(0)}k';
  return yuan.toStringAsFixed(0);
}

/// Format cents as friendly yuan string for display / tooltips.
/// e.g. 1250000 → "1.25万", 8000 → "80.00"
String _fmtYuan(int cents) {
  final yuan = cents / 100;
  if (yuan.abs() >= 10000) return '${(yuan / 10000).toStringAsFixed(2)}万';
  return yuan.toStringAsFixed(2);
}

const _kTrendMonthlyCount = 6;

/// Key identifiers for each dashboard section (used for reorder persistence)
enum DashboardSection {
  netWorth,
  assetComposition,
  incomeExpenseTrend,
  categoryBreakdown,
  budgetExecution,
  netWorthTrend,
  investmentTrend,
}

/// Dashboard page — the main overview tab
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  /// Card ordering (persisted to SharedPreferences)
  late List<DashboardSection> _cardOrder;

  /// Expanded state per card
  final Map<DashboardSection, bool> _expanded = {};

  static const _orderKey = 'dashboard_card_order';

  @override
  void initState() {
    super.initState();
    _cardOrder = DashboardSection.values.toList();
    for (final s in DashboardSection.values) {
      _expanded[s] = true; // default all expanded
    }
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_orderKey);
    if (saved != null && saved.length == DashboardSection.values.length) {
      try {
        final order = saved
            .map((s) => DashboardSection.values.firstWhere((e) => e.name == s))
            .toList();
        if (mounted) setState(() => _cardOrder = order);
      } catch (_) {}
    }
  }

  Future<void> _saveOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _orderKey, _cardOrder.map((s) => s.name).toList());
  }

  @override
  Widget build(BuildContext context) {
    final dashState = ref.watch(dashboardProvider);
    final theme = Theme.of(context);

    return dashState.isLoading && dashState.netWorth.total == 0
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: () async {
              await ref.read(syncEngineProvider).forcePull();
              await ref.read(dashboardProvider.notifier).loadAll();
            },
            child: ReorderableListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 100),
              buildDefaultDragHandles: false,
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    final t = Curves.easeInOut.transform(animation.value);
                    final elevation = 4.0 + t * 8;
                    return Material(
                      elevation: elevation,
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.transparent,
                      child: child,
                    );
                  },
                  child: child,
                );
              },
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = _cardOrder.removeAt(oldIndex);
                  _cardOrder.insert(newIndex, item);
                });
                _saveOrder();
              },
              itemCount: _cardOrder.length,
              itemBuilder: (context, index) {
                final section = _cardOrder[index];
                return _buildCard(
                  key: ValueKey(section),
                  index: index,
                  section: section,
                  dashState: dashState,
                  theme: theme,
                );
              },
            ),
          );
  }

  Widget _buildCard({
    required Key key,
    required int index,
    required DashboardSection section,
    required DashboardState dashState,
    required ThemeData theme,
  }) {
    final isExp = _expanded[section] ?? true;
    final isDark = theme.brightness == Brightness.dark;

    switch (section) {
      case DashboardSection.netWorth:
        return _NetWorthCard(
          key: key,
          index: index,
          data: dashState.netWorth,
          isExpanded: isExp,
          onToggle: () => _toggle(section),
          isDark: isDark,
          theme: theme,
        );
      case DashboardSection.assetComposition:
        return DashboardCard(
          key: key,
          title: '资产构成',
          icon: Icons.donut_large_rounded,
          isExpanded: isExp,
          onToggle: () => _toggle(section),
          trailing: ReorderableDragStartListener(
            index: index,
            child: Icon(Icons.drag_handle_rounded, size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
          ),
          child: RepaintBoundary(
            child: _AssetPieChart(
              composition: dashState.netWorth.composition,
              isDark: isDark,
              theme: theme,
            ),
          ),
        );
      case DashboardSection.incomeExpenseTrend:
        return DashboardCard(
          key: key,
          title: '收支趋势',
          icon: Icons.show_chart_rounded,
          isExpanded: isExp,
          onToggle: () => _toggle(section),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PeriodToggle(
                period: dashState.trendPeriod,
                onChanged: (p) =>
                    ref.read(dashboardProvider.notifier).loadTrend(p, _kTrendMonthlyCount),
              ),
              const SizedBox(width: 4),
              ReorderableDragStartListener(
                index: index,
                child: Icon(Icons.drag_handle_rounded, size: 20,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
              ),
            ],
          ),
          child: RepaintBoundary(
            child: _IncomeExpenseChart(
              points: dashState.incomeExpenseTrend,
              isDark: isDark,
              theme: theme,
            ),
          ),
        );
      case DashboardSection.categoryBreakdown:
        return DashboardCard(
          key: key,
          title: '分类支出',
          icon: Icons.pie_chart_outline_rounded,
          isExpanded: isExp,
          onToggle: () => _toggle(section),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PeriodToggle(
                period: dashState.categoryBreakdownPeriod,
                onChanged: (p) => ref
                    .read(dashboardProvider.notifier)
                    .loadCategoryBreakdownByPeriod(p),
              ),
              const SizedBox(width: 4),
              ReorderableDragStartListener(
                index: index,
                child: Icon(Icons.drag_handle_rounded, size: 20,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
              ),
            ],
          ),
          child: RepaintBoundary(
            child: _CategoryPieChart(
              items: dashState.categoryBreakdown,
              total: dashState.categoryBreakdownTotal,
              isDark: isDark,
              theme: theme,
            ),
          ),
        );
      case DashboardSection.budgetExecution:
        return DashboardCard(
          key: key,
          title: '预算执行',
          icon: Icons.track_changes_rounded,
          isExpanded: isExp,
          onToggle: () => _toggle(section),
          trailing: ReorderableDragStartListener(
            index: index,
            child: Icon(Icons.drag_handle_rounded, size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
          ),
          child: RepaintBoundary(
            child: _BudgetMiniCard(
              data: dashState.budgetSummary,
              isDark: isDark,
              theme: theme,
            ),
          ),
        );
      case DashboardSection.netWorthTrend:
        return DashboardCard(
          key: key,
          title: '净资产趋势',
          icon: Icons.trending_up_rounded,
          isExpanded: isExp,
          onToggle: () => _toggle(section),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PeriodToggle(
                period: dashState.netWorthTrendPeriod,
                onChanged: (p) =>
                    ref.read(dashboardProvider.notifier).loadNetWorthTrend(p),
              ),
              const SizedBox(width: 4),
              ReorderableDragStartListener(
                index: index,
                child: Icon(Icons.drag_handle_rounded, size: 20,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
              ),
            ],
          ),
          child: RepaintBoundary(
            child: _NetWorthTrendChart(
              points: dashState.netWorthTrend,
              isDark: isDark,
              theme: theme,
            ),
          ),
        );
      case DashboardSection.investmentTrend:
        return DashboardCard(
          key: key,
          title: '投资收益',
          icon: Icons.insights_rounded,
          isExpanded: isExp,
          onToggle: () => _toggle(section),
          trailing: ReorderableDragStartListener(
            index: index,
            child: Icon(Icons.drag_handle_rounded, size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
          ),
          child: RepaintBoundary(
            child: _InvestmentTrendPlaceholder(
              netWorth: dashState.netWorth,
              isDark: isDark,
              theme: theme,
            ),
          ),
        );
    }
  }

  void _toggle(DashboardSection section) {
    setState(() {
      _expanded[section] = !(_expanded[section] ?? true);
    });
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Section 1: Net Worth Card (special — gradient bg, not using DashboardCard)
// ──────────────────────────────────────────────────────────────────────────────

class _NetWorthCard extends StatelessWidget {
  final int index;
  final NetWorthData data;
  final bool isExpanded;
  final VoidCallback onToggle;
  final bool isDark;
  final ThemeData theme;

  const _NetWorthCard({
    super.key,
    required this.index,
    required this.data,
    required this.isExpanded,
    required this.onToggle,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final isUp = data.changeFromLastMonth >= 0;
    final changeColor = isUp
        ? (isDark ? AppColors.incomeDark : AppColors.income)
        : (isDark ? AppColors.expenseDark : AppColors.expense);

    return Semantics(
      label: '净资产 ${_fmtYuan(data.total)}元，'
          '较上月${isUp ? "增长" : "减少"}${_fmtYuan(data.changeFromLastMonth.abs())}元',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1A2A4A), const Color(0xFF0F1A2F)]
                : [const Color(0xFF5B6EF5), const Color(0xFF3D50E0)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : AppColors.primary)
                  .withValues(alpha: isDark ? 0.3 : 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            // Main content
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '净资产',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        ReorderableDragStartListener(
                          index: index,
                          child: Icon(Icons.drag_handle_rounded,
                              size: 20,
                              color: Colors.white.withValues(alpha: 0.4)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '¥ ${_fmtYuan(data.total)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (data.changeFromLastMonth != 0 ||
                            data.changePercent != 0) ...[
                          Icon(
                            isUp
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            size: 14,
                            color: changeColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '¥${_fmtYuan(data.changeFromLastMonth.abs())}',
                            style: TextStyle(
                              color: changeColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                          if (data.changePercent != 0) ...[
                            const SizedBox(width: 6),
                            Text(
                              '${data.changePercent >= 0 ? "+" : ""}${data.changePercent.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: changeColor.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(width: 6),
                          Text(
                            '较上月',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                            ),
                          ),
                        ],
                        const Spacer(),
                        AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white.withValues(alpha: 0.5),
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Expandable: asset composition detail
            AnimatedCrossFade(
              firstChild: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  children: [
                    Divider(color: Colors.white.withValues(alpha: 0.1)),
                    const SizedBox(height: 8),
                    _AssetDetailRow(
                        label: '现金银行', value: data.cashAndBank, icon: '💵'),
                    _AssetDetailRow(
                        label: '投资', value: data.investmentValue, icon: '📈'),
                    _AssetDetailRow(
                        label: '固定资产',
                        value: data.fixedAssetValue,
                        icon: '🏠'),
                    _AssetDetailRow(
                        label: '贷款',
                        value: data.loanBalance,
                        icon: '🏦',
                        isNegative: true),
                  ],
                ),
              ),
              secondChild: const SizedBox.shrink(),
              crossFadeState: isExpanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 250),
              sizeCurve: Curves.easeInOutCubic,
            ),
          ],
        ),
      ),
    );
  }
}

class _AssetDetailRow extends StatelessWidget {
  final String label;
  final int value;
  final String icon;
  final bool isNegative;

  const _AssetDetailRow({
    required this.label,
    required this.value,
    required this.icon,
    this.isNegative = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            '¥ ${_fmtYuan(value)}',
            style: TextStyle(
              color: isNegative
                  ? AppColors.expenseDark.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Section 2: Asset Composition Pie Chart
// ──────────────────────────────────────────────────────────────────────────────

class _AssetPieChart extends StatefulWidget {
  final List<AssetCompositionItem> composition;
  final bool isDark;
  final ThemeData theme;

  const _AssetPieChart({
    required this.composition,
    required this.isDark,
    required this.theme,
  });

  @override
  State<_AssetPieChart> createState() => _AssetPieChartState();
}

class _AssetPieChartState extends State<_AssetPieChart> {
  int? _touchedIndex;

  static const _colors = [
    Color(0xFF007AFF), // cash - blue
    Color(0xFFAF52DE), // investment - purple
    Color(0xFF5AC8FA), // fixed asset - cyan
    Color(0xFFFF6B6B), // loan - red
  ];

  @override
  Widget build(BuildContext context) {
    final composition = widget.composition;
    final theme = widget.theme;

    if (composition.isEmpty ||
        composition.every((c) => c.value == 0)) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            '暂无资产数据',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),
      );
    }

    return Semantics(
      label: '资产构成饼图',
      child: SizedBox(
        height: 200,
        child: Row(
          children: [
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
                      setState(() => _touchedIndex =
                          response.touchedSection!.touchedSectionIndex);
                    },
                  ),
                  sections: composition.asMap().entries.map((e) {
                    final i = e.key;
                    final c = e.value;
                    final isTouched = _touchedIndex == i;
                    return PieChartSectionData(
                      color: _colors[i % _colors.length],
                      value: c.value.abs().toDouble(),
                      title: isTouched
                          ? '${(c.weight * 100).toStringAsFixed(1)}%'
                          : '',
                      radius: isTouched ? 60.0 : 50.0,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                  centerSpaceRadius: 32,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: composition.asMap().entries.map((e) {
                  final i = e.key;
                  final c = e.value;
                  final isTouched = _touchedIndex == i;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _colors[i % _colors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            c.label,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight:
                                  isTouched ? FontWeight.w700 : FontWeight.w400,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isTouched)
                          Text(
                            '¥${_fmtShort(c.value)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtShort(int cents) {
    final yuan = cents / 100;
    if (yuan.abs() >= 10000) return '${(yuan / 10000).toStringAsFixed(1)}万';
    return yuan.toStringAsFixed(0);
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Section 3: Income / Expense Trend Line Chart
// ──────────────────────────────────────────────────────────────────────────────

class _PeriodToggle extends StatelessWidget {
  final String period;
  final ValueChanged<String> onChanged;

  const _PeriodToggle({required this.period, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'monthly', label: Text('月')),
        ButtonSegment(value: 'yearly', label: Text('年')),
      ],
      selected: {period},
      onSelectionChanged: (s) => onChanged(s.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 8)),
        textStyle:
            WidgetStateProperty.all(const TextStyle(fontSize: 11)),
      ),
    );
  }
}

class _IncomeExpenseChart extends StatelessWidget {
  final List<TrendPointData> points;
  final bool isDark;
  final ThemeData theme;

  const _IncomeExpenseChart({
    required this.points,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Text(
            '暂无趋势数据',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),
      );
    }

    final maxVal = points.fold<double>(0, (m, p) {
      final mv = math.max(p.income.toDouble(), p.expense.toDouble());
      return math.max(m, mv);
    });
    final maxY = maxVal > 0 ? maxVal * 1.2 : 100;

    return Semantics(
      label: '收支趋势折线图',
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY / 4,
              getDrawingHorizontalLine: (value) => FlLine(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    if (value == 0) return const SizedBox.shrink();
                    return Text(
                      _shortAmount(value.toInt()),
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.4),
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= points.length) {
                      return const SizedBox.shrink();
                    }
                    final label = points[i].label;
                    // "2025-01" → "1月", "2025" → "2025"
                    String short;
                    if (label.length >= 7) {
                      final monthNum = int.tryParse(label.substring(5)) ?? 0;
                      short = '$monthNum月';
                    } else {
                      short = label;
                    }
                    return Text(
                      short,
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                      ),
                    );
                  },
                ),
              ),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            minY: 0,
            maxY: maxY.toDouble(),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) {
                  return spots.map((spot) {
                    final isIncome = spot.barIndex == 0;
                    return LineTooltipItem(
                      '${isIncome ? "收入" : "支出"}: ¥${_fmtYuan(spot.y.toInt())}',
                      TextStyle(
                        color: isIncome ? AppColors.income : AppColors.expense,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }).toList();
                },
              ),
            ),
            lineBarsData: [
              // Income line
              LineChartBarData(
                spots: points
                    .asMap()
                    .entries
                    .map((e) => FlSpot(
                        e.key.toDouble(), e.value.income.toDouble()))
                    .toList(),
                isCurved: true,
                curveSmoothness: 0.25,
                color: isDark ? AppColors.incomeDark : AppColors.income,
                barWidth: 2.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) =>
                      FlDotCirclePainter(
                    radius: 3,
                    color: isDark ? AppColors.incomeDark : AppColors.income,
                    strokeWidth: 0,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: (isDark ? AppColors.incomeDark : AppColors.income)
                      .withValues(alpha: 0.08),
                ),
              ),
              // Expense line
              LineChartBarData(
                spots: points
                    .asMap()
                    .entries
                    .map((e) => FlSpot(
                        e.key.toDouble(), e.value.expense.toDouble()))
                    .toList(),
                isCurved: true,
                curveSmoothness: 0.25,
                color: isDark ? AppColors.expenseDark : AppColors.expense,
                barWidth: 2.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) =>
                      FlDotCirclePainter(
                    radius: 3,
                    color: isDark ? AppColors.expenseDark : AppColors.expense,
                    strokeWidth: 0,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: (isDark ? AppColors.expenseDark : AppColors.expense)
                      .withValues(alpha: 0.08),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Section 4: Category Breakdown Pie Chart
// ──────────────────────────────────────────────────────────────────────────────

class _CategoryPieChart extends StatefulWidget {
  final List<CategoryBreakdownItem> items;
  final int total;
  final bool isDark;
  final ThemeData theme;

  const _CategoryPieChart({
    required this.items,
    required this.total,
    required this.isDark,
    required this.theme,
  });

  @override
  State<_CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<_CategoryPieChart> {
  int? _touchedIndex;
  int? _expandedIndex;  // legend item with children expanded

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final theme = widget.theme;

    if (items.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            '当月暂无支出',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),
      );
    }

    return Semantics(
      label: '分类支出饼图，共${items.length}个分类',
      child: SizedBox(
        height: 220,
        child: Row(
          children: [
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
                      setState(() => _touchedIndex =
                          response.touchedSection!.touchedSectionIndex);
                    },
                  ),
                  sections: items.asMap().entries.map((e) {
                    final i = e.key;
                    final item = e.value;
                    final isTouched = _touchedIndex == i;
                    return PieChartSectionData(
                      color: AppColors.chartPalette[i % AppColors.chartPalette.length],
                      value: item.amount.toDouble(),
                      title: isTouched
                          ? '${item.categoryName}\n${(item.weight * 100).toStringAsFixed(1)}%'
                          : '',
                      radius: isTouched ? 60.0 : 50.0,
                      titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                  centerSpaceRadius: 32,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: items.asMap().entries.take(8).expand((e) {
                    final i = e.key;
                    final item = e.value;
                    final isTouched = _touchedIndex == i;
                    final isExpanded = _expandedIndex == i;
                    final hasChildren = item.children.isNotEmpty;
                    return [
                      GestureDetector(
                        onTap: hasChildren
                            ? () => setState(() {
                                  _expandedIndex = isExpanded ? null : i;
                                })
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: AppColors.chartPalette[
                                      i % AppColors.chartPalette.length],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  item.categoryName,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: isTouched
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    fontSize: isTouched ? 12 : 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (hasChildren)
                                Icon(
                                  isExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  size: 14,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.4),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (isExpanded)
                        ...item.children.map((child) => Padding(
                              padding: const EdgeInsets.only(
                                  left: 22, top: 1, bottom: 1),
                              child: Text(
                                '${child.categoryName}  ¥${(child.amount / 100).toStringAsFixed(0)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 10,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            )),
                    ];
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Section 5: Budget Execution Mini Card
// ──────────────────────────────────────────────────────────────────────────────

class _BudgetMiniCard extends StatelessWidget {
  final BudgetSummaryData data;
  final bool isDark;
  final ThemeData theme;

  const _BudgetMiniCard({
    required this.data,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (data.totalBudget == 0) {
      return SizedBox(
        height: 60,
        child: Center(
          child: Text(
            '本月暂未设置预算',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),
      );
    }

    final rate = data.executionRate.clamp(0.0, 2.0);
    final pct = (rate * 100).toStringAsFixed(0);
    Color rateColor;
    if (rate >= 0.8) {
      rateColor = AppColors.expense;
    } else if (rate >= 0.6) {
      rateColor = const Color(0xFFFF9500);
    } else {
      rateColor = AppColors.income;
    }

    return Semantics(
      label: '预算执行率 $pct%，已用 ${_fmtYuan(data.totalSpent)}，预算 ${_fmtYuan(data.totalBudget)}',
      child: Row(
        children: [
          // Ring
          SizedBox(
            width: 80,
            height: 80,
            child: CustomPaint(
              painter: _MiniRingPainter(
                progress: rate.clamp(0.0, 1.0),
                color: rateColor,
                bgColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
              ),
              child: Center(
                child: Text(
                  '$pct%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: rateColor,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '已用 ¥${_fmtYuan(data.totalSpent)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '预算 ¥${_fmtYuan(data.totalBudget)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: rate.clamp(0.0, 1.0),
                    backgroundColor:
                        theme.colorScheme.onSurface.withValues(alpha: 0.06),
                    color: rateColor,
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color bgColor;

  _MiniRingPainter({
    required this.progress,
    required this.color,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - 8) / 2;
    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_MiniRingPainter old) =>
      old.progress != progress || old.color != color;
}

// ──────────────────────────────────────────────────────────────────────────────
// Section 6: Net Worth Trend Line
// ──────────────────────────────────────────────────────────────────────────────

class _NetWorthTrendChart extends StatelessWidget {
  final List<TrendPointData> points;
  final bool isDark;
  final ThemeData theme;

  const _NetWorthTrendChart({
    required this.points,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            '暂无净资产趋势',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),
      );
    }

    final vals = points.map((p) => p.net.toDouble()).toList();
    final minV = vals.reduce(math.min);
    final maxV = vals.reduce(math.max);
    final range = maxV - minV;
    final padding = range > 0 ? range * 0.1 : 100;
    final yRange = (maxV + padding) - (minV - padding);
    final yInterval = (yRange > 0 ? yRange / 4 : 100).toDouble();

    return Semantics(
      label: '净资产趋势折线图，最近${points.length}个${points.isNotEmpty && points.first.label.length <= 4 ? "年" : "月"}',
      child: SizedBox(
        height: 180,
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: yInterval,
              getDrawingHorizontalLine: (value) => FlLine(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 48, // TODO: revisit for i18n / large negative values
                  interval: yInterval,
                  getTitlesWidget: (value, meta) {
                    // Skip min/max edge labels to avoid clipping
                    if (value <= minV - padding + yInterval * 0.1 ||
                        value >= maxV + padding - yInterval * 0.1) {
                      return const SizedBox.shrink();
                    }
                    return Text(
                      _shortAmount(value.toInt()),
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.4),
                      ),
                    );
                  },
                ),
              ),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: (points.length / 4).ceilToDouble().clamp(1, 6),
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= points.length) {
                      return const SizedBox.shrink();
                    }
                    final label = points[i].label;
                    String short;
                    if (label.length >= 7) {
                      final monthNum = int.tryParse(label.substring(5)) ?? 0;
                      short = '$monthNum月';
                    } else {
                      short = label;
                    }
                    return Text(
                      short,
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.4),
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            minY: minV - padding,
            maxY: maxV + padding,
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) {
                  return spots.map((spot) {
                    return LineTooltipItem(
                      '¥${_fmtYuan(spot.y.toInt())}',
                      TextStyle(
                        color: isDark ? AppColors.primaryDark : AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }).toList();
                },
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: points
                    .asMap()
                    .entries
                    .map((e) =>
                        FlSpot(e.key.toDouble(), e.value.net.toDouble()))
                    .toList(),
                isCurved: true,
                curveSmoothness: 0.25,
                color: isDark ? AppColors.primaryDark : AppColors.primary,
                barWidth: 2.5,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      (isDark ? AppColors.primaryDark : AppColors.primary)
                          .withValues(alpha: 0.15),
                      (isDark ? AppColors.primaryDark : AppColors.primary)
                          .withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Section 7: Investment Trend Placeholder
// ──────────────────────────────────────────────────────────────────────────────

class _InvestmentTrendPlaceholder extends StatelessWidget {
  final NetWorthData netWorth;
  final bool isDark;
  final ThemeData theme;

  const _InvestmentTrendPlaceholder({
    required this.netWorth,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (netWorth.investmentValue == 0) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text(
            '暂无投资数据',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),
      );
    }

    // Simple display: investment total + cost basis info from net worth
    return Semantics(
      label: '投资组合市值 ${_fmtYuan(netWorth.investmentValue)}',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (isDark ? AppColors.incomeDark : AppColors.income)
              .withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Text('📈', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '投资组合市值',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '¥ ${_fmtYuan(netWorth.investmentValue)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: isDark ? AppColors.incomeDark : AppColors.income,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
