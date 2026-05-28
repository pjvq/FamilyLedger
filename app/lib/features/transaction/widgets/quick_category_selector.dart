import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../core/constants/category_icon_widget.dart';
import '../../../domain/providers/transaction_provider.dart';
import '../../../data/local/database.dart';

/// P2-2: 两级分类选择器
///
/// - 顶部：最近使用分类（横向滚动 chips）
/// - 主体：父级分类网格（5 列 icon + 文字）
/// - 子分类：点击有子分类的父级，弹出 ActionSheet
class QuickCategorySelector extends ConsumerStatefulWidget {
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
  ConsumerState<QuickCategorySelector> createState() =>
      _QuickCategorySelectorState();
}

class _QuickCategorySelectorState extends ConsumerState<QuickCategorySelector> {
  @override
  Widget build(BuildContext context) {
    final allCategories = widget.typeIndex == 0
        ? ref.watch(transactionProvider.select((s) => s.expenseCategories))
        : ref.watch(transactionProvider.select((s) => s.incomeCategories));

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

    // Separate parent and child categories
    final parents = allCategories
        .where((c) => c.parentId == null && c.deletedAt == null)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    // Recent categories: last 5 unique from transaction history
    final recentIds = ref.watch(transactionProvider.select((s) {
      final seen = <String>{};
      final recent = <String>[];
      for (final txn in s.transactions) {
        if (seen.add(txn.categoryId) && recent.length < 5) {
          // Only include categories matching current type
          final cat = allCategories.where((c) => c.id == txn.categoryId).firstOrNull;
          if (cat != null) recent.add(txn.categoryId);
        }
        if (recent.length >= 5) break;
      }
      return recent;
    }));

    final recentCategories = recentIds
        .map((id) => allCategories.where((c) => c.id == id).firstOrNull)
        .whereType<Category>()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recently used row
        if (recentCategories.isNotEmpty) ...[
          _RecentCategoryRow(
            categories: recentCategories,
            selectedId: widget.selectedCategoryId,
            onSelected: _handleSelection,
          ),
          const SizedBox(height: SpacingTokens.sm),
        ],

        // Main category grid
        Expanded(
          child: _CategoryGrid(
            parents: parents,
            allCategories: allCategories,
            selectedId: widget.selectedCategoryId,
            onSelected: _handleSelection,
            onParentWithChildren: _showSubcategorySheet,
          ),
        ),
      ],
    );
  }

  void _handleSelection(String categoryId) {
    HapticFeedback.selectionClick();
    widget.onSelected(categoryId);
  }

  void _showSubcategorySheet(Category parent, List<Category> children) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SubcategorySheet(
        parent: parent,
        children: children,
        selectedId: widget.selectedCategoryId,
        onSelected: (id) {
          _handleSelection(id);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }
}

/// 最近使用分类行 — 横向滚动 chips
class _RecentCategoryRow extends StatelessWidget {
  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  const _RecentCategoryRow({
    required this.categories,
    this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.md),
        itemCount: categories.length + 1, // +1 for "最近" label
        separatorBuilder: (_, __) => const SizedBox(width: SpacingTokens.sm),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.only(right: SpacingTokens.xs),
                child: Text(
                  '最近',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }
          final cat = categories[index - 1];
          final isSelected = cat.id == selectedId;
          return _MiniCategoryChip(
            category: cat,
            isSelected: isSelected,
            isDark: isDark,
            onTap: () => onSelected(cat.id),
          );
        },
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

/// 主分类网格 — 5 列 icon + 文字
class _CategoryGrid extends StatelessWidget {
  final List<Category> parents;
  final List<Category> allCategories;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final void Function(Category parent, List<Category> children) onParentWithChildren;

  const _CategoryGrid({
    required this.parents,
    required this.allCategories,
    this.selectedId,
    required this.onSelected,
    required this.onParentWithChildren,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.sm),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: SpacingTokens.sm,
        crossAxisSpacing: SpacingTokens.xs,
        childAspectRatio: 0.85,
      ),
      itemCount: parents.length,
      itemBuilder: (context, index) {
        final cat = parents[index];
        final children = allCategories
            .where((c) => c.parentId == cat.id && c.deletedAt == null)
            .toList();
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
        );
      },
    );
  }
}

/// 单个分类格子 — 圆形 icon + 文字
class _CategoryGridItem extends StatelessWidget {
  final Category category;
  final bool hasChildren;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryGridItem({
    required this.category,
    required this.hasChildren,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
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

  const _SubcategorySheet({
    required this.parent,
    required this.children,
    this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sorted = [...children]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return Container(
      decoration: BoxDecoration(
        color: isDark ? NeutralColorsDark.neutral1 : NeutralColorsLight.neutral0,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(
        SpacingTokens.base,
        SpacingTokens.md,
        SpacingTokens.base,
        SpacingTokens.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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

          // Parent label
          Row(
            children: [
              CategoryIconWidget(iconKey: parent.iconKey, size: 20, showBackground: false),
              const SizedBox(width: SpacingTokens.sm),
              Text(
                parent.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              // Option to select parent directly
              TextButton(
                onPressed: () => onSelected(parent.id),
                child: Text(
                  '选择「${parent.name}」',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.base),

          // Subcategory grid (4 columns)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: SpacingTokens.md,
              crossAxisSpacing: SpacingTokens.sm,
              childAspectRatio: 1.0,
            ),
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final cat = sorted[index];
              final isSelected = cat.id == selectedId;
              return _CategoryGridItem(
                category: cat,
                hasChildren: false,
                isSelected: isSelected,
                onTap: () => onSelected(cat.id),
              );
            },
          ),

          // Safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
