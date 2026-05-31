import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../../../core/constants/category_icon_widget.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/theme/tokens/semantic_theme_extension.dart';
import '../../../data/local/database.dart' as db;
import 'report_utils.dart';

/// 单笔排行 Tab
class ReportRankingTab extends StatefulWidget {
  final List<db.Transaction> transactions;
  final Map<String, db.Category> categoryMap;
  final bool isLoading;

  const ReportRankingTab({
    super.key,
    required this.transactions,
    required this.categoryMap,
    required this.isLoading,
  });

  @override
  State<ReportRankingTab> createState() => _ReportRankingTabState();
}

class _ReportRankingTabState extends State<ReportRankingTab> {
  int _typeTab = 0; // 0=支出, 1=收入

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = context.semanticColors;

    final type = _typeTab == 0 ? 'expense' : 'income';
    final typeTxns = widget.transactions.where((t) => t.type == type).toList()
      ..sort((a, b) => b.amountCny.compareTo(a.amountCny));
    final top = typeTxns.take(20).toList();

    return Column(
      children: [
        // Segment
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(
                'Top ${top.length}',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              MiniSegment(
                labels: const ['支出', '收入'],
                selected: _typeTab,
                onTap: (i) => setState(() => _typeTab = i),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: top.isEmpty
              ? Center(
                  child: Text('暂无数据',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.4),
                      )))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: top.length,
                  itemBuilder: (context, index) {
                    final t = top[index];
                    final cat = widget.categoryMap[t.categoryId];
                    final parentCat =
                        cat?.parentId != null && cat!.parentId!.isNotEmpty
                            ? widget.categoryMap[cat.parentId!]
                            : null;
                    final catName = parentCat != null
                        ? '${parentCat.name} · ${cat?.name ?? ""}'
                        : (cat?.name ?? '未知');

                    final amountColor =
                        _typeTab == 0 ? colors.expense : colors.income;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          // Rank number
                          SizedBox(
                            width: 24,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: index < 3
                                    ? (isDark
                                        ? ColorTokens.primaryLight
                                        : ColorTokens.primary)
                                    : theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Icon
                          CategoryIconWidget(
                              iconKey: cat?.iconKey, size: 32),
                          const SizedBox(width: 10),
                          // Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  catName,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Row(
                                  children: [
                                    if (t.note.isNotEmpty)
                                      Expanded(
                                        child: Text(
                                          t.note,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme
                                                .colorScheme.onSurface
                                                .withValues(alpha: 0.4),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      )
                                    else
                                      Expanded(
                                        child: Text(
                                          _fmtDate(t.txnDate),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme
                                                .colorScheme.onSurface
                                                .withValues(alpha: 0.4),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Amount
                          Text(
                            '¥${fmtYuan(t.amountCny)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: amountColor,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.month}/${d.day}';
}
