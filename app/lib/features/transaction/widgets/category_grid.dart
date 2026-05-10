import 'package:flutter/material.dart';
import '../../../core/constants/category_icon_widget.dart';
import '../../../core/constants/category_icons.dart';
import '../../../data/local/database.dart';

/// 两级分类选择器
/// 第一级: 主分类网格
/// 选中主分类后，如果有子分类，底部展开子分类横向列表
class CategoryGrid extends StatefulWidget {
  final List<Category> categories; // 所有分类（flat list from Drift）
  final String? selectedId;
  final ValueChanged<String> onSelect;

  const CategoryGrid({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  State<CategoryGrid> createState() => _CategoryGridState();
}

class _CategoryGridState extends State<CategoryGrid> {
  String? _expandedParentId; // 当前展开的主分类

  @override
  void initState() {
    super.initState();
    // 如果已选分类是子分类，自动展开其父分类
    if (widget.selectedId != null) {
      final selected = widget.categories
          .where((c) => c.id == widget.selectedId)
          .firstOrNull;
      if (selected != null && selected.parentId != null) {
        _expandedParentId = selected.parentId;
      } else if (selected != null) {
        // 已选的是主分类，查看它是否有子分类
        final hasChildren = widget.categories.any((c) => c.parentId == selected.id);
        if (hasChildren) {
          _expandedParentId = selected.id;
        }
      }
    }
  }

  List<Category> get _mainCategories =>
      widget.categories.where((c) => c.parentId == null && c.deletedAt == null).toList();

  List<Category> _getChildren(String parentId) =>
      widget.categories.where((c) => c.parentId == parentId && c.deletedAt == null).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mainCats = _mainCategories;

    return Column(
      children: [
        // 主分类网格
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.8,
            ),
            itemCount: mainCats.length,
            itemBuilder: (context, index) {
              final cat = mainCats[index];
              final isSelected = cat.id == widget.selectedId ||
                  cat.id == _expandedParentId;
              final hasChildren = widget.categories.any((c) => c.parentId == cat.id);
              final iconKey = cat.iconKey.isNotEmpty ? cat.iconKey : 'other';

              return _MainCategoryItem(
                iconKey: iconKey,
                name: cat.name,
                isSelected: isSelected,
                hasChildren: hasChildren,
                onTap: () {
                  if (hasChildren) {
                    setState(() {
                      _expandedParentId =
                          _expandedParentId == cat.id ? null : cat.id;
                    });
                    // 如果没展开子分类，直接选主分类
                    if (_expandedParentId == null) {
                      widget.onSelect(cat.id);
                    }
                  } else {
                    setState(() => _expandedParentId = null);
                    widget.onSelect(cat.id);
                  }
                },
                theme: theme,
              );
            },
          ),
        ),
        // 子分类横向列表
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: _expandedParentId != null
              ? _SubcategoryBar(
                  children: _getChildren(_expandedParentId!),
                  selectedId: widget.selectedId,
                  onSelect: widget.onSelect,
                  parentId: _expandedParentId!,
                  onSelectParent: () => widget.onSelect(_expandedParentId!),
                  theme: theme,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// 主分类 Item
class _MainCategoryItem extends StatelessWidget {
  final String iconKey;
  final String name;
  final bool isSelected;
  final bool hasChildren;
  final VoidCallback onTap;
  final ThemeData theme;

  const _MainCategoryItem({
    required this.iconKey,
    required this.name,
    required this.isSelected,
    required this.hasChildren,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final color = CategoryIcons.getColor(iconKey);

    return Semantics(
      label: name,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: CategoryIconWidget(
                      iconKey: iconKey, size: 22, showBackground: false),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected
                            ? color
                            : theme.colorScheme.onSurface.withOpacity(0.6),
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasChildren)
                    Icon(
                      isSelected
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 12,
                      color: isSelected
                          ? color
                          : theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 子分类横向滚动条
class _SubcategoryBar extends StatelessWidget {
  final List<Category> children;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final String parentId;
  final VoidCallback onSelectParent;
  final ThemeData theme;

  const _SubcategoryBar({
    required this.children,
    required this.selectedId,
    required this.onSelect,
    required this.parentId,
    required this.onSelectParent,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: children.length + 1, // +1 for "全部" chip
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            // "全部"（选择主分类本身）
            final isSelected = selectedId == parentId;
            return _SubcategoryChip(
              label: '全部',
              isSelected: isSelected,
              onTap: onSelectParent,
              theme: theme,
            );
          }
          final child = children[index - 1];
          final isSelected = child.id == selectedId;
          final iconKey = child.iconKey.isNotEmpty ? child.iconKey : 'other';
          final color = CategoryIcons.getColor(iconKey);

          return _SubcategoryChip(
            label: child.name,
            icon: CategoryIcons.getIcon(iconKey),
            iconColor: color,
            isSelected: isSelected,
            onTap: () => onSelect(child.id),
            theme: theme,
          );
        },
      ),
    );
  }
}

class _SubcategoryChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? iconColor;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;

  const _SubcategoryChip({
    required this.label,
    this.icon,
    this.iconColor,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.12)
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: iconColor ?? theme.colorScheme.primary),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withOpacity(0.7),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
