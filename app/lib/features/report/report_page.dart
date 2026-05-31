import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart' as db;
import '../../domain/providers/app_providers.dart';
import '../../domain/providers/transaction_provider.dart';
import 'widgets/report_category_tab.dart';
import 'widgets/report_overview_tab.dart';
import 'widgets/report_ranking_tab.dart';
import 'widgets/report_utils.dart';

/// 交易报表页面 — 3 Tab 结构：概览 / 分类排行 / 单笔排行
class ReportPage extends ConsumerStatefulWidget {
  const ReportPage({super.key});

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  DatePreset _preset = DatePreset.thisMonth;
  DateTimeRange? _dateRange;
  List<db.Transaction> _filteredTransactions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _dateRange = presetRange(_preset);
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
    final allTxns =
        await database.getRecentTransactions(userId, 100000, familyId: familyId);

    final rangeStart = _dateRange!.start;
    final rangeEnd = _dateRange!.end.add(const Duration(days: 1));

    final filtered = allTxns
        .where(
            (t) => !t.txnDate.isBefore(rangeStart) && t.txnDate.isBefore(rangeEnd))
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
    final txnState = ref.watch(transactionProvider);
    final allCats = [
      ...txnState.expenseCategories,
      ...txnState.incomeCategories,
    ];
    final catMap = {for (final c in allCats) c.id: c};

    return Scaffold(
      appBar: AppBar(
        title: const Text('交易报表'),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '概览'),
            Tab(text: '分类'),
            Tab(text: '排行'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Date selector ──
          _buildDateSelector(theme),

          // ── Tab content ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                ReportOverviewTab(
                  transactions: _filteredTransactions,
                  categoryMap: catMap,
                  isLoading: _isLoading,
                ),
                ReportCategoryTab(
                  transactions: _filteredTransactions,
                  categoryMap: catMap,
                  isLoading: _isLoading,
                ),
                ReportRankingTab(
                  transactions: _filteredTransactions,
                  categoryMap: catMap,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector(ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: DatePreset.values.map((p) {
              final selected = _preset == p;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(p.label),
                  selected: selected,
                  onSelected: (_) async {
                    if (p == DatePreset.custom) {
                      await _pickDateRange();
                    } else {
                      setState(() {
                        _preset = p;
                        _dateRange = presetRange(p);
                      });
                      _loadData();
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _dateRange != null
                  ? '${fmtDate(_dateRange!.start)} 至 ${fmtDate(_dateRange!.end)}'
                  : '',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
        ),
      ],
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
        _preset = DatePreset.custom;
        _dateRange = picked;
      });
      _loadData();
    }
  }
}
