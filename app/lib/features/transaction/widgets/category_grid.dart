import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/category_icon_widget.dart';
import '../../../core/constants/category_icons.dart';
import '../../../data/local/database.dart';

// ─── Layout Constants ────────────────────────────────────────────────────────

/// Maximum height of the expanded subcategory panel as a fraction of screen height.
const double _kExpandedPanelMaxHeightFraction = 0.35;

/// Number of columns in the expanded subcategory grid.
const int _kExpandedGridColumns = 4;

/// Height of the collapsed subcategory bar.
const double _kCollapsedBarHeight = 52.0;

/// Duration for expand/collapse animations.
const Duration _kAnimationDuration = Duration(milliseconds: 250);

/// Curve for expand/collapse animations.
const Curve _kAnimationCurve = Curves.easeOutCubic;

// ─── CategoryGrid ────────────────────────────────────────────────────────────

/// 两级分类选择器
///
/// 第一级: 主分类网格（5列）
/// 选中主分类后，底部展开子分类区域：
/// - 默认：横向滚动条（chip 形式）
/// - 点击展开按钮后：网格面板（4列），方便在子分类多时快速定位
class CategoryGrid extends StatefulWidget {
  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final ValueChanged<String?>? onAddCategory;

  const CategoryGrid({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelect,
    this.onAddCategory,
  });

  @override
  State<CategoryGrid> createState() => _CategoryGridState();
}

class _CategoryGridState extends State<CategoryGrid> {
  String? _expandedParentId;
  bool _isSubcategoryPanelExpanded = false;

  @override
  void initState() {
    super.initState();
    _restoreExpansionFromSelection();
  }

  /// If the current selection is a subcategory, auto-expand its parent.
  void _restoreExpansionFromSelection() {
    if (widget.selectedId == null) return;
    final selected = widget.categories
        .where((c) => c.id == widget.selectedId)
        .firstOrNull;
    if (selected == null) return;

    if (selected.parentId != null) {
      _expandedParentId = selected.parentId;
    } else {
      final hasChildren =
          widget.categories.any((c) => c.parentId == selected.id);
      if (hasChildren) _expandedParentId = selected.id;
    }
  }

  List<Category> get _mainCategories => widget.categories
      .where((c) => c.parentId == null && c.deletedAt == null)
      .toList();

  List<Category> _getChildren(String parentId) => widget.categories
      .where((c) => c.parentId == parentId && c.deletedAt == null)
      .toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  void _handleMainCategoryTap(Category cat) {
    final hasChildren =
        widget.categories.any((c) => c.parentId == cat.id);
    final canExpand = hasChildren || widget.onAddCategory != null;

    setState(() {
      if (canExpand) {
        final wasExpanded = _expandedParentId == cat.id;
        _expandedParentId = wasExpanded ? null : cat.id;
        // Collapse panel when switching parent category
        _isSubcategoryPanelExpanded = false;
      } else {
        _expandedParentId = null;
        _isSubcategoryPanelExpanded = false;
      }
    });
    widget.onSelect(cat.id);
  }

  void _handleSubcategorySelect(String id) {
    widget.onSelect(id);
    // Auto-collapse panel after selection
    if (_isSubcategoryPanelExpanded) {
      setState(() => _isSubcategoryPanelExpanded = false);
    }
  }

  void _togglePanel() {
    HapticFeedback.selectionClick();
    setState(() => _isSubcategoryPanelExpanded = !_isSubcategoryPanelExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mainCats = _mainCategories;
    final children = _expandedParentId != null
        ? _getChildren(_expandedParentId!)
        : <Category>[];
    // Only show expand button when there are enough subcategories to warrant it
    final showExpandButton = children.length > 3;

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
            itemCount:
                mainCats.length + (widget.onAddCategory != null ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == mainCats.length) {
                return _AddCategoryButton(
                  label: '新分类',
                  onTap: () => widget.onAddCategory?.call(null),
                  theme: theme,
                );
              }
              final cat = mainCats[index];
              final isSelected =
                  cat.id == widget.selectedId || cat.id == _expandedParentId;
              final hasChildren =
                  widget.categories.any((c) => c.parentId == cat.id);
              final canExpand = hasChildren || widget.onAddCategory != null;
              final iconKey =
                  cat.iconKey.isNotEmpty ? cat.iconKey : 'other';

              return _MainCategoryItem(
                iconKey: iconKey,
                name: cat.name,
                isSelected: isSelected,
                hasChildren: canExpand,
                onTap: () => _handleMainCategoryTap(cat),
                theme: theme,
              );
            },
          ),
        ),
        // 子分类区域（横向条 or 展开面板）
        AnimatedSize(
          duration: _kAnimationDuration,
          curve: _kAnimationCurve,
          child: _expandedParentId != null
              ? _isSubcategoryPanelExpanded
                  ? _SubcategoryExpandedPanel(
                      parentName: _mainCategories
                              .where((c) => c.id == _expandedParentId)
                              .firstOrNull
                              ?.name ??
                          '',
                      children: children,
                      selectedId: widget.selectedId,
                      parentId: _expandedParentId!,
                      onSelect: _handleSubcategorySelect,
                      onSelectParent: () =>
                          _handleSubcategorySelect(_expandedParentId!),
                      onCollapse: _togglePanel,
                      onAddSubcategory: widget.onAddCategory != null
                          ? () => widget.onAddCategory
                              ?.call(_expandedParentId)
                          : null,
                      theme: theme,
                    )
                  : _SubcategoryBar(
                      children: children,
                      selectedId: widget.selectedId,
                      parentId: _expandedParentId!,
                      onSelect: _handleSubcategorySelect,
                      onSelectParent: () =>
                          _handleSubcategorySelect(_expandedParentId!),
                      onExpand: showExpandButton ? _togglePanel : null,
                      onAddSubcategory: widget.onAddCategory != null
                          ? () => widget.onAddCategory
                              ?.call(_expandedParentId)
                          : null,
                      theme: theme,
                    )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ─── Main Category Item ──────────────────────────────────────────────────────

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
            color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
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
                  color: color.withValues(alpha: 0.08),
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
                            : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasChildren)
                    Icon(
                      isSelected ? Icons.expand_less : Icons.expand_more,
                      size: 12,
                      color: isSelected
                          ? color
                          : theme.colorScheme.onSurface.withValues(alpha: 0.4),
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

// ─── Subcategory Bar (collapsed) ─────────────────────────────────────────────

/// Collapsed horizontal chip bar for subcategories.
///
/// Shows an optional expand button (⊞) on the left when [onExpand] is provided.
class _SubcategoryBar extends StatelessWidget {
  final List<Category> children;
  final String? selectedId;
  final String parentId;
  final ValueChanged<String> onSelect;
  final VoidCallback onSelectParent;
  final VoidCallback? onExpand;
  final VoidCallback? onAddSubcategory;
  final ThemeData theme;

  const _SubcategoryBar({
    required this.children,
    required this.selectedId,
    required this.parentId,
    required this.onSelect,
    required this.onSelectParent,
    this.onExpand,
    this.onAddSubcategory,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty && onAddSubcategory == null) {
      return const SizedBox.shrink();
    }

    // +1 for "全部" chip, +1 for add button (if callback provided)
    final extraCount = 1 + (onAddSubcategory != null ? 1 : 0);

    return Container(
      height: _kCollapsedBarHeight,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          // Expand button
          if (onExpand != null)
            _ExpandButton(onTap: onExpand!, theme: theme),
          // Chip list
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.fromLTRB(
                onExpand != null ? 4 : 12,
                8,
                12,
                8,
              ),
              itemCount: children.length + extraCount,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _SubcategoryChip(
                    label: '全部',
                    isSelected: selectedId == parentId,
                    onTap: onSelectParent,
                    theme: theme,
                  );
                }
                if (index == children.length + 1 &&
                    onAddSubcategory != null) {
                  return _SubcategoryChip(
                    label: '+ 新分类',
                    isSelected: false,
                    onTap: onAddSubcategory!,
                    theme: theme,
                    isAddButton: true,
                  );
                }
                final child = children[index - 1];
                final iconKey =
                    child.iconKey.isNotEmpty ? child.iconKey : 'other';
                return _SubcategoryChip(
                  label: child.name,
                  iconKey: iconKey,
                  isSelected: child.id == selectedId,
                  onTap: () => onSelect(child.id),
                  theme: theme,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Expand Button ───────────────────────────────────────────────────────────

class _ExpandButton extends StatelessWidget {
  final VoidCallback onTap;
  final ThemeData theme;

  const _ExpandButton({required this.onTap, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '展开子分类面板',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: _kCollapsedBarHeight,
          alignment: Alignment.center,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.grid_view_rounded,
              size: 16,
              color: theme.colorScheme.primary.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Subcategory Expanded Panel ──────────────────────────────────────────────

/// Expanded grid panel for subcategories.
///
/// Displays subcategories in a 4-column grid, making it easy to find the
/// desired subcategory without horizontal scrolling.
class _SubcategoryExpandedPanel extends StatelessWidget {
  final String parentName;
  final List<Category> children;
  final String? selectedId;
  final String parentId;
  final ValueChanged<String> onSelect;
  final VoidCallback onSelectParent;
  final VoidCallback onCollapse;
  final VoidCallback? onAddSubcategory;
  final ThemeData theme;

  const _SubcategoryExpandedPanel({
    required this.parentName,
    required this.children,
    required this.selectedId,
    required this.parentId,
    required this.onSelect,
    required this.onSelectParent,
    required this.onCollapse,
    this.onAddSubcategory,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxPanelHeight = screenHeight * _kExpandedPanelMaxHeightFraction;

    // +1 for "全部", +1 for "新分类" button (if provided)
    final itemCount =
        children.length + 1 + (onAddSubcategory != null ? 1 : 0);
    // Estimate content height: header (40) + grid rows
    final gridRows = (itemCount / _kExpandedGridColumns).ceil();
    const itemHeight = 48.0;
    const gridSpacing = 8.0;
    final contentHeight =
        40 + 8 + gridRows * itemHeight + (gridRows - 1) * gridSpacing + 12;
    final panelHeight = contentHeight.clamp(0.0, maxPanelHeight);

    return Container(
      height: panelHeight,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Column(
        children: [
          // Header
          _PanelHeader(
            parentName: parentName,
            onCollapse: onCollapse,
            theme: theme,
          ),
          // Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _kExpandedGridColumns,
                mainAxisSpacing: gridSpacing,
                crossAxisSpacing: gridSpacing,
                childAspectRatio: 2.2,
              ),
              itemCount: itemCount,
              itemBuilder: (context, index) {
                // First item: "全部"
                if (index == 0) {
                  return _SubcategoryGridItem(
                    label: '全部',
                    isSelected: selectedId == parentId,
                    onTap: onSelectParent,
                    theme: theme,
                  );
                }
                // Last item: add button
                if (index == itemCount - 1 && onAddSubcategory != null) {
                  return _SubcategoryGridItem(
                    label: '+ 新分类',
                    isSelected: false,
                    onTap: onAddSubcategory!,
                    theme: theme,
                    isAddButton: true,
                  );
                }
                final child = children[index - 1];
                final iconKey =
                    child.iconKey.isNotEmpty ? child.iconKey : 'other';
                return _SubcategoryGridItem(
                  label: child.name,
                  iconKey: iconKey,
                  isSelected: child.id == selectedId,
                  onTap: () => onSelect(child.id),
                  theme: theme,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Panel Header ────────────────────────────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  final String parentName;
  final VoidCallback onCollapse;
  final ThemeData theme;

  const _PanelHeader({
    required this.parentName,
    required this.onCollapse,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          Text(
            '$parentName · 子分类',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const Spacer(),
          Semantics(
            label: '收起子分类面板',
            button: true,
            child: GestureDetector(
              onTap: onCollapse,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '收起',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.primary.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: theme.colorScheme.primary.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Subcategory Grid Item (expanded panel) ──────────────────────────────────

class _SubcategoryGridItem extends StatelessWidget {
  final String label;
  final String? iconKey;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;
  final bool isAddButton;

  const _SubcategoryGridItem({
    required this.label,
    this.iconKey,
    required this.isSelected,
    required this.onTap,
    required this.theme,
    this.isAddButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isAddButton
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                : isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.12)
                    : theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isAddButton
                  ? theme.colorScheme.primary.withValues(alpha: 0.3)
                  : isSelected
                      ? theme.colorScheme.primary
                      : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (iconKey != null) ...[
                CategoryIconWidget(
                    iconKey: iconKey!, size: 16, showBackground: false),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: isAddButton
                        ? theme.colorScheme.primary
                        : isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: isSelected || isAddButton
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Subcategory Chip (collapsed bar) ────────────────────────────────────────

class _SubcategoryChip extends StatelessWidget {
  final String label;
  final String? iconKey;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;
  final bool isAddButton;

  const _SubcategoryChip({
    required this.label,
    this.iconKey,
    required this.isSelected,
    required this.onTap,
    required this.theme,
    this.isAddButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isAddButton
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
              : isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.12)
                  : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isAddButton
                ? theme.colorScheme.primary.withValues(alpha: 0.3)
                : isSelected
                    ? theme.colorScheme.primary
                    : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconKey != null) ...[
              CategoryIconWidget(
                  iconKey: iconKey!, size: 16, showBackground: false),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isAddButton
                    ? theme.colorScheme.primary
                    : isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontWeight: isSelected || isAddButton
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Add Category Button (main grid) ─────────────────────────────────────────

class _AddCategoryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final ThemeData theme;

  const _AddCategoryButton({
    required this.label,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
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
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_rounded,
                size: 22,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
