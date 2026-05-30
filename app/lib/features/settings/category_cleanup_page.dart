import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/category_icon_widget.dart';
import '../../domain/providers/category_merge_provider.dart';
import '../../domain/services/smart_category/category_merge_detector.dart';
import '../../domain/services/smart_category/category_merge_executor.dart';

/// 分类整理建议页面 — 卡片式逐条确认
class CategoryCleanupPage extends ConsumerStatefulWidget {
  const CategoryCleanupPage({super.key});

  @override
  ConsumerState<CategoryCleanupPage> createState() =>
      _CategoryCleanupPageState();
}

class _CategoryCleanupPageState extends ConsumerState<CategoryCleanupPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final suggestionsAsync = ref.watch(categoryMergeSuggestionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('分类整理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '合并历史',
            onPressed: () => _showMergeHistory(context),
          ),
        ],
      ),
      body: suggestionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (suggestions) {
          if (suggestions.isEmpty) {
            return _buildEmptyState();
          }
          return _buildSuggestionCards(suggestions);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.green[300]),
          const SizedBox(height: 16),
          const Text(
            '分类已整理完毕 ✨',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            '没有发现需要合并的相似分类',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCards(List<MergeSuggestion> suggestions) {
    // Clamp index
    if (_currentIndex >= suggestions.length) {
      _currentIndex = suggestions.length - 1;
    }

    final suggestion = suggestions[_currentIndex];

    return Column(
      children: [
        // 进度指示器
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${_currentIndex + 1} / ${suggestions.length}',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ),

        // 建议卡片
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _SuggestionCard(
              suggestion: suggestion,
              onMerge: () => _executeMerge(suggestion),
              onDismiss: () => _dismissSuggestion(suggestion),
              onSkip: () => _skipToNext(suggestions.length),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _executeMerge(MergeSuggestion suggestion) async {
    final actions = ref.read(categoryMergeActionsProvider.notifier);
    try {
      final result = await actions.merge(
        sourceCategoryId: suggestion.categoryB.id,
        targetCategoryId: suggestion.categoryA.id,
        mergeType: suggestion.pairType == PairType.sameParent
            ? MergeType.simple
            : MergeType.crossParent,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('已合并，${result.affectedTransactions} 笔交易已更新'),
            action: SnackBarAction(
              label: '撤销',
              onPressed: () => _undoMerge(result.mergeLogId),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('合并失败: $e')),
        );
      }
    }
  }

  Future<void> _undoMerge(String mergeLogId) async {
    final actions = ref.read(categoryMergeActionsProvider.notifier);
    try {
      await actions.undo(mergeLogId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已撤销合并')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('撤销失败: $e')),
        );
      }
    }
  }

  Future<void> _dismissSuggestion(MergeSuggestion suggestion) async {
    final actions = ref.read(categoryMergeActionsProvider.notifier);
    await actions.dismiss(suggestion.categoryA.id, suggestion.categoryB.id);
  }

  void _skipToNext(int total) {
    setState(() {
      _currentIndex = (_currentIndex + 1) % total;
    });
  }

  void _showMergeHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => const _MergeHistorySheet(),
    );
  }
}

/// 单条合并建议卡片
class _SuggestionCard extends StatelessWidget {
  final MergeSuggestion suggestion;
  final VoidCallback onMerge;
  final VoidCallback onDismiss;
  final VoidCallback onSkip;

  const _SuggestionCard({
    required this.suggestion,
    required this.onMerge,
    required this.onDismiss,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catA = suggestion.categoryA;
    final catB = suggestion.categoryB;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题行
            Row(
              children: [
                const Icon(Icons.merge_type, size: 20),
                const SizedBox(width: 8),
                const Text('建议合并',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(
                  onPressed: onSkip,
                  child: const Text('跳过'),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),

            // 两个分类
            Row(
              children: [
                Expanded(child: _CategoryChip(category: catB, label: '删除')),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, color: Colors.grey),
                ),
                Expanded(child: _CategoryChip(category: catA, label: '保留')),
              ],
            ),

            const SizedBox(height: 16),

            // 匹配原因
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline,
                      size: 16, color: Colors.amber[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      suggestion.reason,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 置信度
            Row(
              children: [
                Text('置信度: ',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                _ConfidenceBadge(confidence: suggestion.confidence),
              ],
            ),

            const Spacer(),

            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDismiss,
                    child: const Text('暂不处理'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onMerge,
                    icon: const Icon(Icons.merge, size: 18),
                    label: const Text('确认合并'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 分类标签
class _CategoryChip extends StatelessWidget {
  final dynamic category; // Category from Drift
  final String label;

  const _CategoryChip({required this.category, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CategoryIconWidget(iconKey: category.iconKey ?? '', size: 40),
        const SizedBox(height: 4),
        Text(
          category.name as String,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
      ],
    );
  }
}

/// 置信度标签
class _ConfidenceBadge extends StatelessWidget {
  final double confidence;

  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final percent = (confidence * 100).round();
    final color = confidence >= 0.8
        ? Colors.green
        : confidence >= 0.6
            ? Colors.orange
            : Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$percent%',
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// 合并历史 Sheet
class _MergeHistorySheet extends ConsumerWidget {
  const _MergeHistorySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(undoableMergeLogsProvider);

    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('可撤销的合并',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Flexible(
            child: logsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('加载失败: $e'),
              data: (logs) {
                if (logs.isEmpty) {
                  return const Center(child: Text('暂无可撤销的合并记录'));
                }
                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final daysLeft = log.expiresAt
                        .difference(DateTime.now())
                        .inDays;
                    return ListTile(
                      title: Text(
                        '「${log.sourceCategoryName}」→ 已合并',
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        '${log.affectedCount} 笔交易 · 剩余 $daysLeft 天可撤销',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600]),
                      ),
                      trailing: TextButton(
                        onPressed: () async {
                          final actions = ref.read(
                              categoryMergeActionsProvider.notifier);
                          try {
                            await actions.undo(log.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('已撤销')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('撤销失败: $e')),
                              );
                            }
                          }
                        },
                        child: const Text('撤销'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
