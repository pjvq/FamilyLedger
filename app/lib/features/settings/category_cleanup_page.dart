import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/category_icon_widget.dart';
import '../../data/local/database.dart';
import '../../domain/providers/app_providers.dart';
import '../../domain/providers/category_merge_provider.dart';
import '../../domain/services/smart_category/category_merge_detector.dart';
import '../../domain/services/smart_category/category_merge_executor.dart';

/// 所有分类的 FutureProvider（用于建议卡片中查询父/子分类信息）
final _allCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getAllCategories();
});

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
    final allCatsAsync = ref.watch(_allCategoriesProvider);

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
          final allCats = allCatsAsync.valueOrNull ?? [];
          return _buildSuggestionCards(suggestions, allCats);
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
          Text('没有发现需要合并的相似分类', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildSuggestionCards(
    List<MergeSuggestion> suggestions,
    List<Category> allCats,
  ) {
    _currentIndex = max(0, min(_currentIndex, suggestions.length - 1));
    final suggestion = suggestions[_currentIndex];

    // Build lookup maps
    final categoryMap = {for (final c in allCats) c.id: c};
    final childrenMap = <String, List<Category>>{};
    for (final c in allCats) {
      if (c.parentId != null && c.deletedAt == null) {
        childrenMap.putIfAbsent(c.parentId!, () => []).add(c);
      }
    }

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
              categoryMap: categoryMap,
              childrenMap: childrenMap,
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
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await actions.merge(
        sourceCategoryId: suggestion.categoryB.id,
        targetCategoryId: suggestion.categoryA.id,
        mergeType: MergeType.fromPairType(suggestion.pairType),
      );

      if (mounted) {
        final undoActions = ref.read(categoryMergeActionsProvider.notifier);
        messenger.showSnackBar(
          SnackBar(
            content: Text('已合并，${result.affectedTransactions} 笔交易已更新'),
            action: SnackBarAction(
              label: '撤销',
              onPressed: () async {
                try {
                  await undoActions.undo(result.mergeLogId);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('已撤销合并')),
                  );
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('撤销失败: $e')));
                }
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('合并失败: $e')));
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
  final Map<String, Category> categoryMap;
  final Map<String, List<Category>> childrenMap;
  final VoidCallback onMerge;
  final VoidCallback onDismiss;
  final VoidCallback onSkip;

  const _SuggestionCard({
    required this.suggestion,
    required this.categoryMap,
    required this.childrenMap,
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
                const Text(
                  '建议合并',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton(onPressed: onSkip, child: const Text('跳过')),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),

            // 两个分类
            Row(
              children: [
                Expanded(
                  child: _CategoryInfoTile(
                    category: catB,
                    label: '删除',
                    categoryMap: categoryMap,
                    childrenMap: childrenMap,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, color: Colors.grey),
                ),
                Expanded(
                  child: _CategoryInfoTile(
                    category: catA,
                    label: '保留',
                    categoryMap: categoryMap,
                    childrenMap: childrenMap,
                  ),
                ),
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
                  Icon(
                    Icons.lightbulb_outline,
                    size: 16,
                    color: Colors.amber[700],
                  ),
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
                Text(
                  '置信度: ',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
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

/// 分类信息 Tile — 显示层级（一级/二级）+ 子分类展开
class _CategoryInfoTile extends StatelessWidget {
  final Category category;
  final String label;
  final Map<String, Category> categoryMap;
  final Map<String, List<Category>> childrenMap;

  const _CategoryInfoTile({
    required this.category,
    required this.label,
    required this.categoryMap,
    required this.childrenMap,
  });

  bool get _isSubcategory => category.parentId != null;

  String? get _parentName {
    if (category.parentId == null) return null;
    return categoryMap[category.parentId]?.name;
  }

  List<Category> get _children => childrenMap[category.id] ?? [];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        CategoryIconWidget(iconKey: category.iconKey, size: 40),
        const SizedBox(height: 4),
        Text(
          category.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),

        // 层级标签
        if (_isSubcategory && _parentName != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$_parentName ›',
              style: TextStyle(fontSize: 10, color: theme.colorScheme.primary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer.withValues(
                alpha: 0.5,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '一级分类',
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.secondary,
              ),
            ),
          ),

        // 一级分类：展示子分类数量，可点击查看
        if (!_isSubcategory && _children.isNotEmpty) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => _showChildrenSheet(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.subdirectory_arrow_right,
                  size: 12,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 2),
                Text(
                  '${_children.length} 个子分类',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }

  void _showChildrenSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) =>
          _ChildCategoriesSheet(parentName: category.name, children: _children),
    );
  }
}

/// 子分类列表 Sheet
class _ChildCategoriesSheet extends StatelessWidget {
  final String parentName;
  final List<Category> children;

  const _ChildCategoriesSheet({
    required this.parentName,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '「$parentName」的子分类',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: children.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final child = children[index];
                return ListTile(
                  leading: CategoryIconWidget(iconKey: child.iconKey, size: 32),
                  title: Text(child.name),
                  dense: true,
                );
              },
            ),
          ),
        ],
      ),
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
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
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
          const Text(
            '可撤销的合并',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: logsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
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
                        .inDays
                        .clamp(0, 7);
                    return ListTile(
                      title: Text(
                        '「${log.sourceCategoryName}」→ 已合并',
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        '${log.affectedCount} 笔交易 · 剩余 $daysLeft 天可撤销',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      trailing: TextButton(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final actions = ref.read(
                            categoryMergeActionsProvider.notifier,
                          );
                          Navigator.pop(context);
                          try {
                            await actions.undo(log.id);
                            messenger.showSnackBar(
                              const SnackBar(content: Text('已撤销')),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('撤销失败: $e')),
                            );
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
