import 'dart:ui' show FontFeature;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart' as db;
import '../../domain/providers/app_providers.dart';
import '../../domain/providers/family_provider.dart';
import '../../domain/providers/transaction_provider.dart';

// ── Quick date range presets ──

enum _DatePreset {
  thisMonth('本月'),
  lastMonth('上月'),
  last30('近30天'),
  last90('近90天'),
  thisQuarter('本季度'),
  thisYear('本年'),
  all('所有'),
  custom('自定义');

  final String label;
  const _DatePreset(this.label);
}

DateTimeRange _presetRange(_DatePreset p) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 23, 59, 59);
  switch (p) {
    case _DatePreset.thisMonth:
      return DateTimeRange(
          start: DateTime(now.year, now.month, 1), end: today);
    case _DatePreset.lastMonth:
      final start = DateTime(now.year, now.month - 1, 1);
      final end = DateTime(now.year, now.month, 0, 23, 59, 59);
      return DateTimeRange(start: start, end: end);
    case _DatePreset.last30:
      return DateTimeRange(
          start: today.subtract(const Duration(days: 29)), end: today);
    case _DatePreset.last90:
      return DateTimeRange(
          start: today.subtract(const Duration(days: 89)), end: today);
    case _DatePreset.thisQuarter:
      final qStart = DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1, 1);
      return DateTimeRange(start: qStart, end: today);
    case _DatePreset.thisYear:
      return DateTimeRange(start: DateTime(now.year, 1, 1), end: today);
    case _DatePreset.all:
      return DateTimeRange(start: DateTime(2000, 1, 1), end: today);
    case _DatePreset.custom:
      return DateTimeRange(
          start: DateTime(now.year, now.month, 1), end: today);
  }
}

// ── Pie chart colors ──

const _chartColors = [
  Color(0xFFFF6384),
  Color(0xFF36A2EB),
  Color(0xFFFFCE56),
  Color(0xFF4BC0C0),
  Color(0xFF9966FF),
  Color(0xFFFF9F40),
  Color(0xFF8AC24A),
  Color(0xFFE91E63),
  Color(0xFF00BCD4),
  Color(0xFF795548),
  Color(0xFF607D8B),
  Color(0xFFCDDC39),
];

/// Report page with date presets, hierarchical category, and pie chart
class ReportPage extends ConsumerStatefulWidget {
  const ReportPage({super.key});

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage>
    with TickerProviderStateMixin {
  late TabController _tabController; // 支出 / 收入
  _DatePreset _preset = _DatePreset.thisMonth;
  DateTimeRange? _dateRange;

  // Monthly trend state
  int _trendTab = 0; // 0=支出, 1=收入, 2=结余
  int? _trendTouchedMonth; // 0-indexed month for tooltip

  // Top spending ranking state
  int _rankingTab = 0; // 0=支出, 1=收入
  List<db.Transaction> _filteredTransactions = [];
  bool _isLoading = false;

  // Category filter: null = all, otherwise a top-level (parent) category id
  String? _filterParentCatId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _dateRange = _presetRange(_preset);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_dateRange == null) return;
    setState(() => _isLoading = true);

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    final database = ref.read(databaseProvider);
    final familyId = ref.read(currentFamilyIdProvider);
    final allTxns = await database.getRecentTransactions(userId, 100000, familyId: familyId);

    final rangeStart = _dateRange!.start;
    final rangeEnd =
        _dateRange!.end.add(const Duration(days: 1)); // inclusive end

    final filtered = allTxns
        .where((t) =>
            !t.txnDate.isBefore(rangeStart) && t.txnDate.isBefore(rangeEnd))
        .toList()
      ..sort((a, b) => b.txnDate.compareTo(a.txnDate));

    setState(() {
      _filteredTransactions = filtered;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final txnState = ref.watch(transactionProvider);
    final allCats = [
      ...txnState.expenseCategories,
      ...txnState.incomeCategories,
    ];
    final catMap = {for (final c in allCats) c.id: c};

    // Current tab type
    final isExpenseTab = _tabController.index == 0;
    final typeFilter = isExpenseTab ? 'expense' : 'income';

    // Filter by type
    final typeTxns =
        _filteredTransactions.where((t) => t.type == typeFilter).toList();

    // Total
    int totalAmount = 0;
    for (final t in typeTxns) {
      totalAmount += t.amountCny;
    }

    // Build parent categories for this type
    final parentCats = allCats
        .where((c) =>
            c.type == typeFilter &&
            (c.parentId == null || c.parentId!.isEmpty))
        .toList();

    // Aggregate by parent category (sum up children)
    final parentAmounts = <String, int>{}; // parentCatId → total cents
    for (final t in typeTxns) {
      final cat = catMap[t.categoryId];
      final parentId =
          (cat?.parentId != null && cat!.parentId!.isNotEmpty)
              ? cat.parentId!
              : t.categoryId;
      parentAmounts[parentId] = (parentAmounts[parentId] ?? 0) + t.amountCny;
    }

    // Sort by amount desc
    final sortedParentIds = parentAmounts.keys.toList()
      ..sort((a, b) => parentAmounts[b]!.compareTo(parentAmounts[a]!));

    // Filtered view (by parent category)
    List<db.Transaction> displayTxns;
    if (_filterParentCatId != null) {
      // Show txns where category is the parent itself or a child of it
      displayTxns = typeTxns.where((t) {
        if (t.categoryId == _filterParentCatId) return true;
        final cat = catMap[t.categoryId];
        return cat?.parentId == _filterParentCatId;
      }).toList();
    } else {
      displayTxns = typeTxns;
    }

    // Sub-category breakdown for selected parent
    Map<String, int>? subCatAmounts;
    if (_filterParentCatId != null) {
      subCatAmounts = <String, int>{};
      for (final t in displayTxns) {
        subCatAmounts[t.categoryId] =
            (subCatAmounts[t.categoryId] ?? 0) + t.amountCny;
      }
    }
    final sortedSubCatIds = subCatAmounts?.keys.toList()
      ?..sort(
          (a, b) => subCatAmounts![b]!.compareTo(subCatAmounts[a]!));

    return Scaffold(
      appBar: AppBar(
        title: const Text('交易报表'),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: '支出'), Tab(text: '收入')],
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          // ── Date presets ──
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _DatePreset.values.map((p) {
                final selected = _preset == p;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(p.label),
                    selected: selected,
                    onSelected: (_) async {
                      if (p == _DatePreset.custom) {
                        await _pickDateRange();
                      } else {
                        setState(() {
                          _preset = p;
                          _dateRange = _presetRange(p);
                          _filterParentCatId = null;
                        });
                        _loadData();
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          // Show date range text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _dateRange != null
                    ? '${_fmtDate(_dateRange!.start)} 至 ${_fmtDate(_dateRange!.end)}'
                    : '',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),

          // ── Summary ──
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : AppColors.cardLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  isExpenseTab ? '总支出' : '总收入',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '¥${_fmtYuan(totalAmount)}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isExpenseTab
                        ? (isDark
                            ? AppColors.expenseDark
                            : AppColors.expense)
                        : (isDark
                            ? AppColors.incomeDark
                            : AppColors.income),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),

          // ── Content ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : sortedParentIds.isEmpty
                    ? Center(
                        child: Text('暂无数据',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.4),
                            )))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                        children: [
                          // ── Pie chart ──
                          if (sortedParentIds.isNotEmpty && totalAmount > 0)
                            _buildPieChart(
                              sortedParentIds,
                              parentAmounts,
                              catMap,
                              totalAmount,
                              isDark,
                              theme,
                            ),
                          const SizedBox(height: 12),

                          // ── Monthly trend chart ──
                          _buildMonthlyTrend(isDark, theme),
                          const SizedBox(height: 12),

                          // ── Top spending/income ranking ──
                          _buildTopRanking(catMap, isDark, theme),
                          const SizedBox(height: 12),

                          // ── Category ranking ──
                          Text(
                            _filterParentCatId != null
                                ? '${catMap[_filterParentCatId]?.icon ?? ""} ${catMap[_filterParentCatId]?.name ?? ""} 明细'
                                : '分类排行',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (_filterParentCatId != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: GestureDetector(
                                onTap: () => setState(
                                    () => _filterParentCatId = null),
                                child: Text('← 返回全部分类',
                                    style:
                                        theme.textTheme.bodySmall?.copyWith(
                                      color: isDark
                                          ? AppColors.primaryDark
                                          : AppColors.primary,
                                    )),
                              ),
                            ),
                          const SizedBox(height: 8),

                          // Category bars
                          if (_filterParentCatId == null)
                            ...sortedParentIds.map((pid) =>
                                _buildCategoryBar(
                                  catId: pid,
                                  amount: parentAmounts[pid]!,
                                  total: totalAmount,
                                  catMap: catMap,
                                  isDark: isDark,
                                  theme: theme,
                                  onTap: () => setState(
                                      () => _filterParentCatId = pid),
                                )),
                          if (_filterParentCatId != null &&
                              sortedSubCatIds != null)
                            ...sortedSubCatIds.map((cid) =>
                                _buildCategoryBar(
                                  catId: cid,
                                  amount: subCatAmounts![cid]!,
                                  total: parentAmounts[
                                          _filterParentCatId!] ??
                                      1,
                                  catMap: catMap,
                                  isDark: isDark,
                                  theme: theme,
                                  showParentName: true,
                                )),

                          const SizedBox(height: 16),

                          // ── Transaction list ──
                          if (displayTxns.isNotEmpty) ...[
                            Text('交易明细 (${displayTxns.length})',
                                style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            ...displayTxns.map((t) {
                              final cat = catMap[t.categoryId];
                              final parentCat = cat?.parentId != null &&
                                      cat!.parentId!.isNotEmpty
                                  ? catMap[cat.parentId!]
                                  : null;
                              final catName = parentCat != null
                                  ? '${parentCat.name}-${cat?.name ?? ""}'
                                  : (cat?.name ?? '未知');
                              return _TransactionRow(
                                transaction: t,
                                categoryName: catName,
                                categoryIcon: cat?.icon ?? '📦',
                                isDark: isDark,
                                theme: theme,
                              );
                            }),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  // ── Monthly trend chart ──

  Widget _buildMonthlyTrend(bool isDark, ThemeData theme) {
    // Aggregate all transactions by month (full year)
    final monthlyExpense = List.filled(12, 0);
    final monthlyIncome = List.filled(12, 0);

    for (final t in _filteredTransactions) {
      final month = t.txnDate.month - 1;
      if (month < 0 || month > 11) continue;
      if (t.type == 'expense') {
        monthlyExpense[month] += t.amountCny;
      } else if (t.type == 'income') {
        monthlyIncome[month] += t.amountCny;
      }
    }

    final monthlyBalance = List.generate(
        12, (i) => monthlyIncome[i] - monthlyExpense[i]);

    List<int> data;
    switch (_trendTab) {
      case 1:
        data = monthlyIncome;
        break;
      case 2:
        data = monthlyBalance;
        break;
      default:
        data = monthlyExpense;
    }

    final maxVal = data.fold(0, (int a, int b) => a > b.abs() ? a : b.abs());
    final maxY = maxVal > 0 ? maxVal.toDouble() * 1.2 : 100.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('每月支出趋势',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              _buildSegment(['支出', '收入', '结余'], _trendTab, (i) {
                setState(() {
                  _trendTab = i;
                  _trendTouchedMonth = null;
                });
              }, theme, isDark),
            ],
          ),
          if (_trendTouchedMonth != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_trendTouchedMonth! + 1}月 ${_trendTab == 1 ? "收入" : _trendTab == 2 ? "结余" : "支出"} ¥${_fmtYuan(data[_trendTouchedMonth!].abs())}',
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
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
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
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.06),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(12, (i) {
                  final val = data[i].toDouble();
                  final color = _trendTab == 2
                      ? (val >= 0
                          ? (isDark
                              ? AppColors.incomeDark
                              : AppColors.income)
                          : (isDark
                              ? AppColors.expenseDark
                              : AppColors.expense))
                      : (_trendTab == 1
                          ? (isDark
                              ? AppColors.incomeDark
                              : AppColors.income)
                          : (isDark
                              ? AppColors.expenseDark
                              : AppColors.primary));
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: _trendTab == 2 ? val : val.abs(),
                        fromY: _trendTab == 2 && val < 0 ? val : 0,
                        color: i == _trendTouchedMonth
                            ? color.withValues(alpha: 0.9)
                            : color.withValues(alpha: 0.7),
                        width: 14,
                        borderRadius: const BorderRadius.vertical(
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

  // ── Top ranking ──

  Widget _buildTopRanking(
      Map<String, db.Category> catMap, bool isDark, ThemeData theme) {
    final type = _rankingTab == 0 ? 'expense' : 'income';
    final typeTxns = _filteredTransactions
        .where((t) => t.type == type)
        .toList()
      ..sort((a, b) => b.amountCny.compareTo(a.amountCny));

    final top = typeTxns.take(20).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('单笔支出排行',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              _buildSegment(['支出', '收入'], _rankingTab, (i) {
                setState(() => _rankingTab = i);
              }, theme, isDark),
            ],
          ),
          const SizedBox(height: 12),
          if (top.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('暂无数据',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.4),
                    )),
              ),
            )
          else
            ...List.generate(top.length, (i) {
              final t = top[i];
              final cat = catMap[t.categoryId];
              final parentCat = cat?.parentId != null &&
                      cat!.parentId!.isNotEmpty
                  ? catMap[cat.parentId!]
                  : null;
              final catName = parentCat != null
                  ? parentCat.name
                  : (cat?.name ?? '未知');
              final firstChar = catName.isNotEmpty ? catName[0] : '?';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: i < 3
                              ? (isDark
                                  ? AppColors.primaryDark
                                  : AppColors.primary)
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _chartColors[i % _chartColors.length]
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        firstChar,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _chartColors[i % _chartColors.length],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            catName,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (t.note.isNotEmpty)
                            Text(
                              t.note,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.4),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '¥${_fmtYuan(t.amountCny)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded,
                        size: 16,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.3)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── Segment control helper ──

  Widget _buildSegment(
      List<String> labels, int selected, ValueChanged<int> onTap,
      ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(labels.length, (i) {
          final isSelected = i == selected;
          return GestureDetector(
            onTap: () => onTap(i),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? AppColors.cardDark : Colors.white)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 2,
                        )
                      ]
                    : null,
              ),
              child: Text(
                labels[i],
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface
                          .withValues(alpha: 0.5),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Pie chart ──

  Widget _buildPieChart(
    List<String> sortedIds,
    Map<String, int> amounts,
    Map<String, db.Category> catMap,
    int total,
    bool isDark,
    ThemeData theme,
  ) {
    final sections = <PieChartSectionData>[];
    for (int i = 0; i < sortedIds.length; i++) {
      final id = sortedIds[i];
      final amt = amounts[id]!;
      final pct = amt / total * 100;
      final cat = catMap[id];
      final color = _chartColors[i % _chartColors.length];

      sections.add(PieChartSectionData(
        color: color,
        value: amt.toDouble(),
        title: pct >= 5 ? '${pct.toStringAsFixed(0)}%' : '',
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        radius: 50,
        badgeWidget: pct >= 8
            ? Text(cat?.icon ?? '📦', style: const TextStyle(fontSize: 16))
            : null,
        badgePositionPercentageOffset: 1.3,
      ));
    }

    return SizedBox(
      height: 200,
      child: Row(
        children: [
          // Pie
          Expanded(
            flex: 3,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 30,
                sectionsSpace: 2,
              ),
            ),
          ),
          // Legend
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0;
                      i < sortedIds.length && i < 8;
                      i++) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _chartColors[i % _chartColors.length],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              catMap[sortedIds[i]]?.name ?? '未知',
                              style: theme.textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (sortedIds.length > 8)
                    Text('...等${sortedIds.length - 8}项',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4),
                        )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Category bar ──

  Widget _buildCategoryBar({
    required String catId,
    required int amount,
    required int total,
    required Map<String, db.Category> catMap,
    required bool isDark,
    required ThemeData theme,
    VoidCallback? onTap,
    bool showParentName = false,
  }) {
    final cat = catMap[catId];
    final pct = total > 0 ? amount / total : 0.0;
    String name;
    if (showParentName && cat?.parentId != null && cat!.parentId!.isNotEmpty) {
      final parent = catMap[cat.parentId!];
      name = parent != null ? '${parent.name}-${cat.name}' : cat.name;
    } else {
      name = cat?.name ?? '未知';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text(cat?.icon ?? '📦',
                      style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    '¥${_fmtYuan(amount)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 42,
                    child: Text(
                      '${(pct * 100).toStringAsFixed(1)}%',
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded,
                        size: 18,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.3)),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 5,
                  backgroundColor: theme.colorScheme.onSurface
                      .withValues(alpha: 0.06),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _dateRange,
      locale: const Locale('zh', 'CN'),
    );
    if (picked != null) {
      setState(() {
        _preset = _DatePreset.custom;
        _dateRange = picked;
        _filterParentCatId = null;
      });
      _loadData();
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtYuan(int cents) {
    final yuan = cents / 100;
    if (yuan.abs() >= 10000) return '${(yuan / 10000).toStringAsFixed(2)}万';
    return yuan.toStringAsFixed(2);
  }
}

class _TransactionRow extends StatelessWidget {
  final db.Transaction transaction;
  final String categoryName;
  final String categoryIcon;
  final bool isDark;
  final ThemeData theme;

  const _TransactionRow({
    required this.transaction,
    required this.categoryName,
    required this.categoryIcon,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == 'income';
    final amountColor = isIncome
        ? (isDark ? AppColors.incomeDark : AppColors.income)
        : (isDark ? AppColors.expenseDark : AppColors.expense);
    final d = transaction.txnDate;
    final dateStr = '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(categoryIcon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  categoryName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  transaction.note.isNotEmpty
                      ? '$dateStr · ${transaction.note}'
                      : dateStr,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            '${isIncome ? "+" : "-"}¥${_fmtYuan(transaction.amountCny)}',
            style: TextStyle(
              color: amountColor,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtYuan(int cents) {
    final yuan = cents / 100;
    return yuan.toStringAsFixed(2);
  }
}
