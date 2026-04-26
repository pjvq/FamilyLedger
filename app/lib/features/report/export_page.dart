import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart';
import '../../domain/providers/app_providers.dart';
import '../../domain/providers/family_provider.dart';
import '../../domain/providers/transaction_provider.dart';

/// Export page: choose date range, category filter, then export CSV
class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  DateTimeRange? _dateRange;
  Set<String> _selectedCategoryIds = {};
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final txnState = ref.watch(transactionProvider);

    // Build category tree: parent → children
    final allCats = [
      ...txnState.expenseCategories,
      ...txnState.incomeCategories,
    ];
    final parentCats = allCats.where((c) => c.parentId == null || c.parentId!.isEmpty).toList();
    final childrenMap = <String, List<Category>>{};
    for (final c in allCats) {
      if (c.parentId != null && c.parentId!.isNotEmpty) {
        childrenMap.putIfAbsent(c.parentId!, () => []).add(c);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('数据导出'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Date range
          Text('时间范围', style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          )),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickDateRange,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : AppColors.cardLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded,
                      size: 18,
                      color: isDark ? AppColors.primaryDark : AppColors.primary),
                  const SizedBox(width: 10),
                  Text(
                    _dateRange != null
                        ? '${_fmtDate(_dateRange!.start)} 至 ${_fmtDate(_dateRange!.end)}'
                        : '选择时间范围',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_drop_down_rounded,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Category filter — hierarchical
          Row(
            children: [
              Text('分类筛选', style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              )),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _selectedCategoryIds = {}),
                child: Text(
                  _selectedCategoryIds.isEmpty ? '已选全部' : '重置为全部',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (_selectedCategoryIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '已选 ${_selectedCategoryIds.length} 个分类',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.primaryDark : AppColors.primary,
                ),
              ),
            ),

          // Expense categories
          if (txnState.expenseCategories.any((c) => c.parentId == null || c.parentId!.isEmpty))
            _buildCategorySection('支出分类', parentCats.where((c) => c.type == 'expense').toList(), childrenMap, theme, isDark),
          const SizedBox(height: 8),
          // Income categories
          if (txnState.incomeCategories.any((c) => c.parentId == null || c.parentId!.isEmpty))
            _buildCategorySection('收入分类', parentCats.where((c) => c.type == 'income').toList(), childrenMap, theme, isDark),

          const SizedBox(height: 32),

          // Export button
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: _isExporting ? null : _doExport,
              icon: _isExporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.file_download_rounded),
              label: Text(_isExporting ? '导出中...' : '导出 CSV'),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    String title,
    List<Category> parents,
    Map<String, List<Category>> childrenMap,
    ThemeData theme,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          fontWeight: FontWeight.w600,
        )),
        const SizedBox(height: 4),
        ...parents.map((parent) {
          final children = childrenMap[parent.id] ?? [];
          final allIds = [parent.id, ...children.map((c) => c.id)];
          final allSelected = allIds.every((id) => _selectedCategoryIds.contains(id));
          final someSelected = allIds.any((id) => _selectedCategoryIds.contains(id));
          final isExpanded = children.isNotEmpty;

          if (!isExpanded) {
            // No children — simple checkbox
            return CheckboxListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              title: Text('${parent.icon} ${parent.name}', style: const TextStyle(fontSize: 14)),
              value: _selectedCategoryIds.contains(parent.id),
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selectedCategoryIds.add(parent.id);
                  } else {
                    _selectedCategoryIds.remove(parent.id);
                  }
                });
              },
            );
          }

          return ExpansionTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            tilePadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: Checkbox(
              value: allSelected ? true : (someSelected ? null : false),
              tristate: true,
              onChanged: (v) {
                setState(() {
                  if (allSelected) {
                    _selectedCategoryIds.removeAll(allIds);
                  } else {
                    _selectedCategoryIds.addAll(allIds);
                  }
                });
              },
            ),
            title: Text('${parent.icon} ${parent.name}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            trailing: Text('${children.length} 个子分类',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  fontSize: 11,
                )),
            children: children.map((child) {
              return CheckboxListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                contentPadding: const EdgeInsets.only(left: 56),
                title: Text('${child.icon} ${child.name}', style: const TextStyle(fontSize: 13)),
                value: _selectedCategoryIds.contains(child.id),
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selectedCategoryIds.add(child.id);
                    } else {
                      _selectedCategoryIds.remove(child.id);
                    }
                  });
                },
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  Future<void> _doExport() async {
    if (_dateRange == null) return;
    setState(() => _isExporting = true);

    try {
      final db = ref.read(databaseProvider);
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未登录')),
          );
        }
        return;
      }

      final allTxns = await db.getRecentTransactions(userId, 100000,
          familyId: ref.read(currentFamilyIdProvider));
      final categories = await db.getAllCategories();
      final catMap = {for (final c in categories) c.id: c};
      final familyId = ref.read(currentFamilyIdProvider);
      List<Account> accounts;
      if (familyId != null && familyId.isNotEmpty) {
        accounts = await db.getAccountsByFamily(familyId);
      } else {
        accounts = await db.getActiveAccounts(userId);
      }
      final accMap = {for (final a in accounts) a.id: a};

      // Filter
      final startDate = _dateRange!.start;
      final endDate = _dateRange!.end;
      final filtered = allTxns.where((t) {
        if (t.txnDate.isBefore(startDate) ||
            t.txnDate.isAfter(endDate.add(const Duration(days: 1)))) {
          return false;
        }
        if (_selectedCategoryIds.isNotEmpty && !_selectedCategoryIds.contains(t.categoryId)) {
          return false;
        }
        return true;
      }).toList();

      filtered.sort((a, b) => a.txnDate.compareTo(b.txnDate));

      // Build CSV
      final buffer = StringBuffer();
      buffer.writeln('日期时间,类型,一级分类,二级分类,金额(元),账户,备注');

      for (final t in filtered) {
        final cat = catMap[t.categoryId];
        Category? parentCat;
        String catName = cat?.name ?? '未知';
        String parentCatName = '';
        if (cat != null && cat.parentId != null && cat.parentId!.isNotEmpty) {
          parentCat = catMap[cat.parentId!];
          parentCatName = parentCat?.name ?? '';
        } else {
          parentCatName = catName;
          catName = '';
        }

        final datetime = '${t.txnDate.year}-'
            '${t.txnDate.month.toString().padLeft(2, '0')}-'
            '${t.txnDate.day.toString().padLeft(2, '0')} '
            '${t.txnDate.hour.toString().padLeft(2, '0')}:'
            '${t.txnDate.minute.toString().padLeft(2, '0')}:'
            '${t.txnDate.second.toString().padLeft(2, '0')}';
        final typeLabel = t.type == 'income' ? '收入' : '支出';
        final yuan = (t.amountCny / 100).toStringAsFixed(2);
        final accName = accMap[t.accountId]?.name ?? '未知';
        final note = _escapeCsv(t.note);

        buffer.writeln('$datetime,$typeLabel,${_escapeCsv(parentCatName)},${_escapeCsv(catName)},$yuan,${_escapeCsv(accName)},$note');
      }

      final csvBytes = utf8.encode(buffer.toString());
      final now = DateTime.now();
      final filename =
          '记账导出_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.csv';

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(csvBytes);

      if (mounted) {
        final box = context.findRenderObject() as RenderBox?;
        final origin = box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : Rect.fromLTWH(0, 0, MediaQuery.of(context).size.width, 100);
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: '家庭账本导出',
          sharePositionOrigin: origin,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String _escapeCsv(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
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
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
