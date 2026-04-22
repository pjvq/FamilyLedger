import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart' as db;
import '../../domain/providers/app_providers.dart';
import '../../domain/providers/transaction_provider.dart';

/// Report page: date-range transactions with category filter and summary
class ReportPage extends ConsumerStatefulWidget {
  const ReportPage({super.key});

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {
  DateTimeRange? _dateRange;
  Set<String> _selectedCategoryIds = {};
  List<db.Transaction> _filteredTransactions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
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
    final allTxns = await database.getRecentTransactions(userId, 100000);

    final filtered = allTxns.where((t) {
      if (t.txnDate.isBefore(_dateRange!.start) ||
          t.txnDate.isAfter(
              _dateRange!.end.add(const Duration(days: 1)))) {
        return false;
      }
      if (_selectedCategoryIds.isNotEmpty &&
          !_selectedCategoryIds.contains(t.categoryId)) {
        return false;
      }
      return true;
    }).toList()
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

    // Compute summary
    int totalIncome = 0, totalExpense = 0;
    for (final t in _filteredTransactions) {
      if (t.type == 'income') {
        totalIncome += t.amountCny;
      } else {
        totalExpense += t.amountCny;
      }
    }
    final netAmount = totalIncome - totalExpense;

    // Group by date
    final grouped = <String, List<db.Transaction>>{};
    for (final t in _filteredTransactions) {
      final key =
          '${t.txnDate.year}-${t.txnDate.month.toString().padLeft(2, '0')}-${t.txnDate.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(t);
    }
    final dateKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: const Text('交易报表'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Date range selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: InkWell(
              onTap: _pickDateRange,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : AppColors.cardLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.1),
                  ),
                ),
                child: Semantics(
                  label: '选择时间范围',
                  button: true,
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 18,
                          color: isDark
                              ? AppColors.primaryDark
                              : AppColors.primary),
                      const SizedBox(width: 10),
                      Text(
                        _dateRange != null
                            ? '${_fmtDate(_dateRange!.start)} 至 ${_fmtDate(_dateRange!.end)}'
                            : '选择时间范围',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_drop_down_rounded,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Category filter chips
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                FilterChip(
                  label: const Text('全部'),
                  selected: _selectedCategoryIds.isEmpty,
                  onSelected: (_) {
                    setState(() => _selectedCategoryIds = {});
                    _loadData();
                  },
                ),
                const SizedBox(width: 6),
                ...allCats.map((cat) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        avatar: Text(cat.icon, style: const TextStyle(fontSize: 14)),
                        label: Text(cat.name),
                        selected: _selectedCategoryIds.contains(cat.id),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedCategoryIds.add(cat.id);
                            } else {
                              _selectedCategoryIds.remove(cat.id);
                            }
                          });
                          _loadData();
                        },
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Summary bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : AppColors.cardLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Semantics(
              label: '汇总：总收入${_fmtYuan(totalIncome)}，总支出${_fmtYuan(totalExpense)}，净额${_fmtYuan(netAmount)}',
              child: Row(
                children: [
                  _SummaryItem(
                    label: '收入',
                    value: totalIncome,
                    color: isDark ? AppColors.incomeDark : AppColors.income,
                  ),
                  _SummaryItem(
                    label: '支出',
                    value: totalExpense,
                    color: isDark ? AppColors.expenseDark : AppColors.expense,
                  ),
                  _SummaryItem(
                    label: '净额',
                    value: netAmount,
                    color: netAmount >= 0
                        ? (isDark ? AppColors.incomeDark : AppColors.income)
                        : (isDark ? AppColors.expenseDark : AppColors.expense),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Transaction list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTransactions.isEmpty
                    ? Center(
                        child: Text(
                          '该时间段暂无交易记录',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.4),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        itemCount: dateKeys.length,
                        itemBuilder: (context, i) {
                          final dateStr = dateKeys[i];
                          final txns = grouped[dateStr]!;
                          final dayTotal = txns.fold<int>(0, (sum, t) {
                            return sum +
                                (t.type == 'income'
                                    ? t.amountCny
                                    : -t.amountCny);
                          });

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Date header
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Text(
                                      dateStr,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${dayTotal >= 0 ? "+" : ""}${_fmtYuan(dayTotal)}',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: dayTotal >= 0
                                            ? (isDark
                                                ? AppColors.incomeDark
                                                : AppColors.income)
                                            : (isDark
                                                ? AppColors.expenseDark
                                                : AppColors.expense),
                                        fontFeatures: const [
                                          FontFeature.tabularFigures()
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Transactions for this date
                              ...txns.map((t) {
                                final cat = catMap[t.categoryId];
                                return _TransactionRow(
                                  transaction: t,
                                  categoryName: cat?.name ?? '未知',
                                  categoryIcon: cat?.icon ?? '📦',
                                  isDark: isDark,
                                  theme: theme,
                                );
                              }),
                            ],
                          );
                        },
                      ),
          ),
        ],
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
      setState(() => _dateRange = picked);
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

class _SummaryItem extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '¥${_fmtYuan(value)}',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

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
                if (transaction.note.isNotEmpty)
                  Text(
                    transaction.note,
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
