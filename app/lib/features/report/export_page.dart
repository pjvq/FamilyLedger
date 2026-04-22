import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/providers/export_provider.dart';
import '../../domain/providers/transaction_provider.dart';

/// Export page: choose format, date range, category filter, then export/share
class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  String _selectedFormat = 'csv';
  DateTimeRange? _dateRange;
  Set<String> _selectedCategoryIds = {};

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
    final exportState = ref.watch(exportProvider);
    final txnState = ref.watch(transactionProvider);
    final allCats = [
      ...txnState.expenseCategories,
      ...txnState.incomeCategories,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('数据导出'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Format selection
          Text('导出格式', style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          )),
          const SizedBox(height: 8),
          Row(
            children: [
              _FormatCard(
                label: 'CSV',
                icon: Icons.table_chart_outlined,
                description: '通用表格格式',
                isSelected: _selectedFormat == 'csv',
                onTap: () => setState(() => _selectedFormat = 'csv'),
                isDark: isDark,
                theme: theme,
              ),
              const SizedBox(width: 8),
              _FormatCard(
                label: 'Excel',
                icon: Icons.grid_on_rounded,
                description: 'Excel 电子表格',
                isSelected: _selectedFormat == 'excel',
                onTap: () => setState(() => _selectedFormat = 'excel'),
                isDark: isDark,
                theme: theme,
              ),
              const SizedBox(width: 8),
              _FormatCard(
                label: 'PDF',
                icon: Icons.picture_as_pdf_rounded,
                description: '可打印报表',
                isSelected: _selectedFormat == 'pdf',
                onTap: () => setState(() => _selectedFormat = 'pdf'),
                isDark: isDark,
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Date range
          Text('时间范围', style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          )),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickDateRange,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : AppColors.cardLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.1),
                ),
              ),
              child: Semantics(
                label: '选择导出时间范围',
                button: true,
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 18,
                        color:
                            isDark ? AppColors.primaryDark : AppColors.primary),
                    const SizedBox(width: 10),
                    Text(
                      _dateRange != null
                          ? '${_fmtDate(_dateRange!.start)} 至 ${_fmtDate(_dateRange!.end)}'
                          : '选择时间范围',
                      style: theme.textTheme.bodyMedium,
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
          const SizedBox(height: 24),

          // Category filter
          Text('分类筛选', style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          )),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              FilterChip(
                label: const Text('全部'),
                selected: _selectedCategoryIds.isEmpty,
                onSelected: (_) =>
                    setState(() => _selectedCategoryIds = {}),
              ),
              ...allCats.map((cat) => FilterChip(
                    avatar: Text(cat.icon,
                        style: const TextStyle(fontSize: 14)),
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
                    },
                  )),
            ],
          ),
          const SizedBox(height: 32),

          // Error message
          if (exportState.error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.expense.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.expense, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      exportState.error!,
                      style: const TextStyle(
                          color: AppColors.expense, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Export button
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: exportState.isExporting ? null : _doExport,
              icon: exportState.isExporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.file_download_rounded),
              label: Text(exportState.isExporting ? '导出中...' : '导出'),
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

  Future<void> _doExport() async {
    if (_dateRange == null) return;

    final data = await ref.read(exportProvider.notifier).exportTransactions(
          format: _selectedFormat,
          startDate: _dateRange!.start,
          endDate: _dateRange!.end,
          categoryIds: _selectedCategoryIds.toList(),
        );

    if (data == null || !mounted) return;

    final exportState = ref.read(exportProvider);
    final filename = exportState.lastFilename ?? 'export.$_selectedFormat';

    // Save to temp and share
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(data);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'FamilyLedger 交易导出',
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
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _FormatCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;
  final ThemeData theme;

  const _FormatCard({
    required this.label,
    required this.icon,
    required this.description,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final selectedColor = isDark ? AppColors.primaryDark : AppColors.primary;

    return Expanded(
      child: Semantics(
        label: '$label格式${isSelected ? "，已选中" : ""}',
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected
                  ? selectedColor.withValues(alpha: 0.1)
                  : (isDark ? AppColors.cardDark : AppColors.cardLight),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? selectedColor
                    : theme.colorScheme.onSurface.withValues(alpha: 0.08),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(icon,
                    size: 28,
                    color: isSelected
                        ? selectedColor
                        : theme.colorScheme.onSurface
                            .withValues(alpha: 0.5)),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? selectedColor : null,
                  ),
                ),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.4),
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
