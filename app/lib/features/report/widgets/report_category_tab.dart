import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../../../core/constants/category_icon_widget.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/local/database.dart' as db;
import 'report_utils.dart';

/// 分类排行 Tab
class ReportCategoryTab extends StatefulWidget {
  final List<db.Transaction> transactions;
  final Map<String, db.Category> categoryMap;
  final bool isLoading;

  const ReportCategoryTab({
    super.key,
    required this.transactions,
    required this.categoryMap,
    required this.isLoading,
  });

  @override
  State<ReportCategoryTab> createState() => _ReportCategoryTabState();
}

class _ReportCategoryTabState extends State<ReportCategoryTab> {
  int _typeTab = 0; // 0=支出, 1=收入
  String? _expandedParentId; // expanded parent shows sub-categories inline

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final typeFilter = _typeTab == 0 ? 'expense' : 'income';
    final typeTxns =
        widget.transactions.where((t) => t.type == typeFilter).toList();

    int totalAmount = 0;
    for (final t in typeTxns) {
      totalAmount += t.amountCny;
    }

    // Aggregate by parent category
    final parentAmounts = <String, int>{};
    for (final t in typeTxns) {
      final cat = widget.categoryMap[t.categoryId];
      final parentId = (cat?.parentId != null && cat!.parentId!.isNotEmpty)
          ? cat.parentId!
          : t.categoryId;
      parentAmounts[parentId] = (parentAmounts[parentId] ?? 0) + t.amountCny;
    }

    final sortedParentIds = parentAmounts.keys.toList()
      ..sort((a, b) => parentAmounts[b]!.compareTo(parentAmounts[a]!));

    return Column(
      children: [
        // Segment
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(
                '总${_typeTab == 0 ? "支出" : "收入"}: ¥${fmtYuan(totalAmount)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              MiniSegment(
                labels: const ['支出', '收入'],
                selected: _typeTab,
                onTap: (i) => setState(() {
                  _typeTab = i;
                  _expandedParentId = null;
                }),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: sortedParentIds.isEmpty
              ? Center(
                  child: Text('暂无数据',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.4),
                      )))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: sortedParentIds.length,
                  itemBuilder: (context, index) {
                    final parentId = sortedParentIds[index];
                    final amount = parentAmounts[parentId]!;
                    final isExpanded = _expandedParentId == parentId;

                    return _buildCategoryItem(
                      parentId: parentId,
                      amount: amount,
                      total: totalAmount,
                      index: index,
                      isExpanded: isExpanded,
                      typeTxns: typeTxns,
                      isDark: isDark,
                      theme: theme,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryItem({
    required String parentId,
    required int amount,
    required int total,
    required int index,
    required bool isExpanded,
    required List<db.Transaction> typeTxns,
    required bool isDark,
    required ThemeData theme,
  }) {
    final cat = widget.categoryMap[parentId];
    final pct = total > 0 ? amount / total : 0.0;
    final name = cat?.name ?? '未知';
    final color = chartColors[index % chartColors.length];

    // Sub-categories if expanded
    Map<String, int>? subAmounts;
    if (isExpanded) {
      subAmounts = <String, int>{};
      for (final t in typeTxns) {
        if (t.categoryId == parentId) {
          subAmounts[t.categoryId] = (subAmounts[t.categoryId] ?? 0) + t.amountCny;
        } else {
          final c = widget.categoryMap[t.categoryId];
          if (c?.parentId == parentId) {
            subAmounts[t.categoryId] =
                (subAmounts[t.categoryId] ?? 0) + t.amountCny;
          }
        }
      }
    }

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() {
            _expandedParentId = isExpanded ? null : parentId;
          }),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color:
                  isDark ? NeutralColorsDark.neutral2 : NeutralColorsLight.neutral0,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CategoryIconWidget(
                        iconKey: cat?.iconKey, size: 22, showBackground: false),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      '¥${fmtYuan(amount)}',
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
                    const SizedBox(width: 4),
                    Icon(
                      isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 18,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 5,
                    color: color,
                    backgroundColor:
                        theme.colorScheme.onSurface.withValues(alpha: 0.06),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Sub-categories
        if (isExpanded && subAmounts != null && subAmounts.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.only(left: 24),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: () {
                final sortedSubIds = subAmounts!.keys.toList()
                  ..sort((a, b) => subAmounts![b]!.compareTo(subAmounts[a]!));
                return sortedSubIds.map((cid) {
                  final subCat = widget.categoryMap[cid];
                  final subAmt = subAmounts![cid]!;
                  final subPct = amount > 0 ? subAmt / amount : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        CategoryIconWidget(
                            iconKey: subCat?.iconKey,
                            size: 16,
                            showBackground: false),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            subCat?.name ?? '未知',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        Text(
                          '¥${fmtYuan(subAmt)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 38,
                          child: Text(
                            '${(subPct * 100).toStringAsFixed(0)}%',
                            textAlign: TextAlign.right,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.4),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList();
              }(),
            ),
          ),
        ],

        const SizedBox(height: 4),
      ],
    );
  }
}
