import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/category_icon_widget.dart';
import '../../../core/constants/category_icons.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/local/database.dart';
import '../../../data/remote/grpc_clients.dart';
import '../../../domain/providers/category_recommend_provider.dart';
import '../../../domain/providers/transaction_provider.dart';
import '../../../domain/services/smart_category/category_recommender.dart';
import '../../../generated/proto/transaction.pb.dart' as pb;
import '../../../generated/proto/transaction.pbenum.dart' as pbe;
import 'icon_picker_sheet.dart';

/// P2-2: 两级分类选择器
///
/// - 顶部：最近使用分类（横向滚动 chips）
/// - 主体：父级分类网格（5 列 icon + 文字）
/// - 子分类：点击有子分类的父级，弹出 ActionSheet
class QuickCategorySelector extends ConsumerWidget {
  final int typeIndex; // 0=支出, 1=收入
  final String? selectedCategoryId;
  final ValueChanged<String> onSelected;

  const QuickCategorySelector({
    super.key,
    required this.typeIndex,
    this.selectedCategoryId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allCategories = typeIndex == 0
        ? ref.watch(transactionProvider.select((s) => s.expenseCategories))
        : ref.watch(transactionProvider.select((s) => s.incomeCategories));

    // Extract recent transaction category IDs separately (pure selector)
    final recentTxnCategoryIds = ref.watch(
      transactionProvider.select((s) {
        final seen = <String>{};
        final ids = <String>[];
        for (final txn in s.transactions) {
          if (seen.add(txn.categoryId)) ids.add(txn.categoryId);
          if (ids.length >= 10) break; // grab more than needed, filter below
        }
        return ids;
      }),
    );

    // Watch recommendation results
    final recommendationsAsync = ref.watch(categoryRecommendProvider);

    if (allCategories.isEmpty) {
      return Center(
        child: Text(
          '暂无分类',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      );
    }

    // Pre-compute: active categories set (excludes deleted)
    final activeSet = <String>{};
    for (final c in allCategories) {
      if (c.deletedAt == null) activeSet.add(c.id);
    }

    // Pre-compute: children map (O(n) once, not O(n²) per grid item)
    final childrenMap = <String, List<Category>>{};
    for (final c in allCategories) {
      if (c.parentId != null && c.deletedAt == null) {
        (childrenMap[c.parentId!] ??= []).add(c);
      }
    }
    // Sort children by sortOrder
    for (final list in childrenMap.values) {
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    // Parents: top-level, active
    final parents = allCategories
        .where((c) => c.parentId == null && c.deletedAt == null)
        .toList();

    // Recommended top 5 categories (fallback to recent if no recommendations)
    final categoryById = {for (final c in allCategories) c.id: c};
    final recommendations = recommendationsAsync.when(
      data: (recs) => recs,
      loading: () => <CategoryRecommendation>[],
      error: (_, __) => <CategoryRecommendation>[],
    );

    // Sort parents by recommendation score if available, fallback to sortOrder
    if (recommendations.isNotEmpty) {
      final scoreMap = {
        for (final r in recommendations) r.categoryId: r.score,
      };
      parents.sort((a, b) {
        final sa = scoreMap[a.id] ?? -1.0;
        final sb = scoreMap[b.id] ?? -1.0;
        if (sa != sb) return sb.compareTo(sa); // desc by score
        return a.sortOrder.compareTo(b.sortOrder); // tie-break
      });
    } else {
      parents.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    final List<Category> topCategories;
    if (recommendations.isNotEmpty) {
      // Use recommendation order
      topCategories = recommendations
          .take(5)
          .map((r) => categoryById[r.categoryId])
          .whereType<Category>()
          .where((c) => c.deletedAt == null)
          .toList();
    } else {
      // Fallback: recent
      topCategories = <Category>[];
      for (final id in recentTxnCategoryIds) {
        if (topCategories.length >= 5) break;
        final cat = categoryById[id];
        if (cat != null && cat.deletedAt == null) {
          topCategories.add(cat);
        }
      }
    }
    final bool useRecommend = recommendations.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recommended / Recently used row
        if (topCategories.isNotEmpty) ...[
          _RecentCategoryRow(
            categories: topCategories,
            selectedId: selectedCategoryId,
            onSelected: (id) => _handleSelection(context, id),
            label: useRecommend ? '✨ 推荐' : '最近',
          ),
          const SizedBox(height: SpacingTokens.sm),
        ],

        // Main category grid
        Expanded(
          child: _CategoryGrid(
            parents: parents,
            childrenMap: childrenMap,
            selectedId: selectedCategoryId,
            onSelected: (id) => _handleSelection(context, id),
            onParentWithChildren: (parent, children) =>
                _showSubcategorySheet(context, ref, parent, children),
            onAddCategory: () => _showQuickAddCategory(context, ref),
          ),
        ),
      ],
    );
  }

  void _handleSelection(BuildContext context, String categoryId) {
    HapticFeedback.selectionClick();
    onSelected(categoryId);
  }

  void _showSubcategorySheet(
      BuildContext context, WidgetRef ref, Category parent, List<Category> children) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SubcategorySheet(
        parent: parent,
        children: children,
        selectedId: selectedCategoryId,
        onSelected: (id) {
          onSelected(id);
          Navigator.of(ctx).pop();
        },
        onAddSubcategory: () {
          Navigator.of(ctx).pop();
          _showQuickAddCategory(context, ref, parentId: parent.id);
        },
      ),
    );
  }

  void _showQuickAddCategory(BuildContext context, WidgetRef ref, {String? parentId}) {
    final type = typeIndex == 0 ? 'expense' : 'income';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QuickAddCategorySheet(
        type: type,
        parentId: parentId,
        onCreated: (categoryId) async {
          await ref.read(transactionProvider.notifier).syncAndReloadCategories();
          onSelected(categoryId);
        },
      ),
    );
  }
}

/// 最近使用分类行 — "最近" label + 横向 chips
class _RecentCategoryRow extends StatelessWidget {
  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final String label;

  const _RecentCategoryRow({
    required this.categories,
    this.selectedId,
    required this.onSelected,
    this.label = '最近',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: 36,
      child: Row(
        children: [
          // Fixed "最近" label
          Padding(
            padding: const EdgeInsets.only(left: SpacingTokens.md, right: SpacingTokens.sm),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Scrollable chips
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: SpacingTokens.md),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: SpacingTokens.sm),
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isSelected = cat.id == selectedId;
                return _MiniCategoryChip(
                  category: cat,
                  isSelected: isSelected,
                  isDark: isDark,
                  onTap: () => onSelected(cat.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 迷你分类 chip（最近使用行）
class _MiniCategoryChip extends StatelessWidget {
  final Category category;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _MiniCategoryChip({
    required this.category,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? ColorTokens.primary.withValues(alpha: 0.12)
              : (isDark ? NeutralColorsDark.neutral2 : NeutralColorsLight.neutral1),
          borderRadius: BorderRadius.circular(RadiusTokens.full),
          border: Border.all(
            color: isSelected ? ColorTokens.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CategoryIconWidget(iconKey: category.iconKey, size: 16, showBackground: false),
            const SizedBox(width: 4),
            Text(
              category.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? ColorTokens.primary
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 主分类网格 — 5 列 icon + 文字，末尾带"添加"按钮
class _CategoryGrid extends StatelessWidget {
  final List<Category> parents;
  final Map<String, List<Category>> childrenMap;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final void Function(Category parent, List<Category> children) onParentWithChildren;
  final VoidCallback? onAddCategory;

  const _CategoryGrid({
    required this.parents,
    required this.childrenMap,
    this.selectedId,
    required this.onSelected,
    required this.onParentWithChildren,
    this.onAddCategory,
  });

  @override
  Widget build(BuildContext context) {
    final itemCount = parents.length + (onAddCategory != null ? 1 : 0);
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.sm),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: SpacingTokens.sm,
        crossAxisSpacing: SpacingTokens.xs,
        childAspectRatio: 0.85,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Last item: add button
        if (onAddCategory != null && index == parents.length) {
          return _AddCategoryButton(onTap: onAddCategory!);
        }
        final cat = parents[index];
        final children = childrenMap[cat.id] ?? const [];
        final isSelected = cat.id == selectedId ||
            children.any((c) => c.id == selectedId);

        return _CategoryGridItem(
          category: cat,
          hasChildren: children.isNotEmpty,
          isSelected: isSelected,
          onTap: () {
            if (children.isNotEmpty) {
              onParentWithChildren(cat, children);
            } else {
              onSelected(cat.id);
            }
          },
          onLongPress: () => onParentWithChildren(cat, children),
        );
      },
    );
  }
}

/// 添加分类按钮 — 网格末尾的 "+" 按钮
class _AddCategoryButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddCategoryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                width: 1.5,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: Icon(
              Icons.add_rounded,
              size: 24,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '添加',
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// 单个分类格子 — 圆形 icon + 文字
class _CategoryGridItem extends StatelessWidget {
  final Category category;
  final bool hasChildren;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _CategoryGridItem({
    required this.category,
    required this.hasChildren,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon circle
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? ColorTokens.primary.withValues(alpha: 0.12)
                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: Border.all(
                color: isSelected ? ColorTokens.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                CategoryIconWidget(
                  iconKey: category.iconKey,
                  size: 24,
                  showBackground: false,
                ),
                // Indicator dot for "has children"
                if (hasChildren)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ColorTokens.primary.withValues(alpha: 0.6),
                        border: Border.all(
                          color: theme.colorScheme.surface,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Label
          Text(
            category.name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected
                  ? ColorTokens.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// 子分类选择 ActionSheet — spring 动画弹出
class _SubcategorySheet extends StatelessWidget {
  final Category parent;
  final List<Category> children;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final VoidCallback? onAddSubcategory;

  const _SubcategorySheet({
    required this.parent,
    required this.children,
    this.selectedId,
    required this.onSelected,
    this.onAddSubcategory,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      decoration: BoxDecoration(
        color: isDark ? NeutralColorsDark.neutral1 : NeutralColorsLight.neutral0,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fixed header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SpacingTokens.base,
              SpacingTokens.md,
              SpacingTokens.base,
              0,
            ),
            child: Column(
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: SpacingTokens.md),
                // Parent label row
                Row(
                  children: [
                    CategoryIconWidget(
                        iconKey: parent.iconKey, size: 20, showBackground: false),
                    const SizedBox(width: SpacingTokens.sm),
                    Text(
                      parent.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => onSelected(parent.id),
                      child: Text(
                        '选择「${parent.name}」',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.md),
              ],
            ),
          ),

          // Scrollable subcategory grid
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                SpacingTokens.base,
                0,
                SpacingTokens.base,
                SpacingTokens.xl,
              ),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: SpacingTokens.md,
                  crossAxisSpacing: SpacingTokens.sm,
                  childAspectRatio: 1.0,
                ),
                itemCount: children.length + (onAddSubcategory != null ? 1 : 0),
                itemBuilder: (context, index) {
                  if (onAddSubcategory != null && index == children.length) {
                    return _AddCategoryButton(onTap: onAddSubcategory!);
                  }
                  final cat = children[index];
                  final isSelected = cat.id == selectedId;
                  return _CategoryGridItem(
                    category: cat,
                    hasChildren: false,
                    isSelected: isSelected,
                    onTap: () => onSelected(cat.id),
                  );
                },
              ),
            ),
          ),

          // Safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

/// 快速新建分类 — 输入名称 + 选图标即可创建
class _QuickAddCategorySheet extends ConsumerStatefulWidget {
  final String type; // 'expense' | 'income'
  final String? parentId;
  final Future<void> Function(String) onCreated;

  const _QuickAddCategorySheet({
    required this.type,
    this.parentId,
    required this.onCreated,
  });

  @override
  ConsumerState<_QuickAddCategorySheet> createState() =>
      _QuickAddCategorySheetState();
}

class _QuickAddCategorySheetState
    extends ConsumerState<_QuickAddCategorySheet> {
  final _nameController = TextEditingController();
  String _iconKey = 'other';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      final client = ref.read(transactionClientProvider);
      final resp = await client.createCategory(pb.CreateCategoryRequest(
        name: name,
        iconKey: _iconKey,
        type: widget.type == 'income'
            ? pbe.TransactionType.TRANSACTION_TYPE_INCOME
            : pbe.TransactionType.TRANSACTION_TYPE_EXPENSE,
        parentId: widget.parentId ?? '',
      ));
      if (mounted) {
        Navigator.of(context).pop();
        await widget.onCreated(resp.category.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败，请重试')),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final color = CategoryIcons.getColor(_iconKey);

    return Container(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 16,
        bottom: 16 + bottom + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.parentId != null ? '新建子分类' : '新建分类',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  showIconPickerSheet(context,
                      selectedKey: _iconKey,
                      onSelect: (key) => setState(() => _iconKey = key));
                },
                child: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.12),
                  ),
                  child: Center(
                    child: CategoryIconWidget(
                      iconKey: _iconKey, size: 28, showBackground: false,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _nameController,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: '分类名称',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('创建'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
