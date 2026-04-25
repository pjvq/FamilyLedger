import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/category_icons.dart';
import '../../data/local/database.dart' as db;
import '../../data/remote/grpc_clients.dart';
import '../../domain/providers/app_providers.dart';
import '../../generated/proto/transaction.pb.dart';
import '../../generated/proto/transaction.pbgrpc.dart';
import '../transaction/widgets/icon_picker_sheet.dart';

class CategoryManagePage extends ConsumerStatefulWidget {
  const CategoryManagePage({super.key});

  @override
  ConsumerState<CategoryManagePage> createState() => _CategoryManagePageState();
}

class _CategoryManagePageState extends ConsumerState<CategoryManagePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Category> _expenseCategories = [];
  List<Category> _incomeCategories = [];
  final Set<String> _expandedIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _loading = true);
    try {
      final client = ref.read(transactionClientProvider);
      final expResp = await client.getCategories(
          GetCategoriesRequest(type: TransactionType.TRANSACTION_TYPE_EXPENSE));
      final incResp = await client.getCategories(
          GetCategoriesRequest(type: TransactionType.TRANSACTION_TYPE_INCOME));

      // Merge locally-created categories (from import) that server doesn't know about
      final database = ref.read(databaseProvider);
      final localExp = await database.getCategoriesByType('expense');
      final localInc = await database.getCategoriesByType('income');

      // Collect all server category names (including children) to deduplicate
      final serverExpNames = _collectAllNames(expResp.categories);
      final serverIncNames = _collectAllNames(incResp.categories);

      // Build trees from local-only categories (not on server by name)
      final localOnlyExp = _buildProtoTree(
          localExp.where((c) => c.parentId == null && !serverExpNames.contains(c.name)).toList(), localExp);
      final localOnlyInc = _buildProtoTree(
          localInc.where((c) => c.parentId == null && !serverIncNames.contains(c.name)).toList(), localInc);

      setState(() {
        _expenseCategories = [...expResp.categories, ...localOnlyExp];
        _incomeCategories = [...incResp.categories, ...localOnlyInc];
        _loading = false;
      });
      // Sync server categories to local DB for offline access
      _syncCategoriesToLocal([...expResp.categories, ...incResp.categories]);
    } catch (e) {
      // Fallback to local DB
      try {
        final database = ref.read(databaseProvider);
        final localExp = await database.getCategoriesByType('expense');
        final localInc = await database.getCategoriesByType('income');
        setState(() {
          _expenseCategories = _buildProtoTree(localExp, localExp);
          _incomeCategories = _buildProtoTree(localInc, localInc);
          _loading = false;
        });
      } catch (_) {
        setState(() => _loading = false);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载分类失败: $e')),
        );
      }
    }
  }

  /// Recursively collect all category names from a proto tree.
  Set<String> _collectAllNames(List<Category> cats) {
    final names = <String>{};
    void walk(List<Category> list) {
      for (final c in list) {
        names.add(c.name);
        if (c.children.isNotEmpty) walk(c.children);
      }
    }
    walk(cats);
    return names;
  }

  /// Build proto Category tree from flat local DB categories.
  /// [candidates] are the categories to include; [allOfType] is the full list for parent lookup.
  List<Category> _buildProtoTree(List<db.Category> candidates, List<db.Category> allOfType) {
    // Only include top-level categories from candidates (children will be nested)
    final roots = candidates.where((c) => c.parentId == null).toList();
    final childMap = <String, List<db.Category>>{};
    for (final c in allOfType) {
      if (c.parentId != null) {
        childMap.putIfAbsent(c.parentId!, () => []).add(c);
      }
    }

    Category toProto(db.Category c) {
      final children = childMap[c.id] ?? [];
      return Category(
        id: c.id,
        name: c.name,
        icon: c.icon,
        iconKey: c.iconKey,
        type: c.type == 'income'
            ? TransactionType.TRANSACTION_TYPE_INCOME
            : TransactionType.TRANSACTION_TYPE_EXPENSE,
        isPreset: c.isPreset,
        sortOrder: c.sortOrder,
        parentId: c.parentId ?? '',
        children: children.map(toProto),
      );
    }

    return roots.map(toProto).toList();
  }

  List<Category> get _currentCategories =>
      _tabController.index == 0 ? _expenseCategories : _incomeCategories;

  TransactionType get _currentType => _tabController.index == 0
      ? TransactionType.TRANSACTION_TYPE_EXPENSE
      : TransactionType.TRANSACTION_TYPE_INCOME;

  Future<void> _addCategory({String? parentId}) async {
    final result = await _showCategoryEditor(context);
    if (result == null) return;

    try {
      final client = ref.read(transactionClientProvider);
      await client.createCategory(CreateCategoryRequest(
        name: result.name,
        iconKey: result.iconKey,
        type: _currentType,
        parentId: parentId ?? '',
      ));
      await _loadCategories();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e')),
        );
      }
    }
  }

  Future<void> _editCategory(Category cat) async {
    final result = await _showCategoryEditor(
      context,
      initialName: cat.name,
      initialIconKey: cat.iconKey,
    );
    if (result == null) return;

    try {
      final client = ref.read(transactionClientProvider);
      await client.updateCategory(UpdateCategoryRequest(
        categoryId: cat.id,
        name: result.name,
        iconKey: result.iconKey,
      ));
      await _loadCategories();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败: $e')),
        );
      }
    }
  }

  void _syncCategoriesToLocal(List<Category> cats) {
    final db = ref.read(databaseProvider);
    for (final cat in cats) {
      db.upsertCategory(
        id: cat.id,
        name: cat.name,
        icon: cat.icon,
        iconKey: cat.iconKey,
        type: cat.type == TransactionType.TRANSACTION_TYPE_INCOME ? 'income' : 'expense',
        isPreset: cat.isPreset,
        sortOrder: cat.sortOrder,
        parentId: cat.parentId.isEmpty ? null : cat.parentId,
      );
      // Also sync children
      for (final child in cat.children) {
        db.upsertCategory(
          id: child.id,
          name: child.name,
          icon: child.icon,
          iconKey: child.iconKey,
          type: cat.type == TransactionType.TRANSACTION_TYPE_INCOME ? 'income' : 'expense',
          isPreset: child.isPreset,
          sortOrder: child.sortOrder,
          parentId: cat.id,
        );
      }
    }
  }

  Future<void> _deleteCategory(Category cat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除分类「${cat.name}」吗？\n相关交易不会被删除，但分类标签会消失。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final client = ref.read(transactionClientProvider);
      await client.deleteCategory(
          DeleteCategoryRequest(categoryId: cat.id));
      await _loadCategories();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('分类管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加主分类',
            onPressed: () => _addCategory(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          onTap: (_) => setState(() {}),
          tabs: const [
            Tab(text: '支出'),
            Tab(text: '收入'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCategoryList(_expenseCategories, theme),
                _buildCategoryList(_incomeCategories, theme),
              ],
            ),
    );
  }

  Widget _buildCategoryList(List<Category> cats, ThemeData theme) {
    if (cats.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.category_outlined,
                size: 64, color: theme.colorScheme.onSurface.withOpacity(0.2)),
            const SizedBox(height: 12),
            Text('暂无分类',
                style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.4))),
            const SizedBox(height: 4),
            Text('点击右上角 + 添加',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.3))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: cats.length,
      itemBuilder: (context, index) {
        final cat = cats[index];
        return _buildMainCategoryTile(cat, theme);
      },
    );
  }

  Widget _buildMainCategoryTile(Category cat, ThemeData theme) {
    final iconKey = cat.iconKey.isNotEmpty ? cat.iconKey : 'other';
    final color = CategoryIcons.getColor(iconKey);
    final hasChildren = cat.children.isNotEmpty;
    final isExpanded = _expandedIds.contains(cat.id);

    return Column(
      children: [
        // 主分类行
        Dismissible(
          key: ValueKey('cat_${cat.id}'),
          direction: cat.isPreset
              ? DismissDirection.none
              : DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.red,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (_) async {
            await _deleteCategory(cat);
            return false;
          },
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(CategoryIcons.getIcon(iconKey), color: color, size: 22),
            ),
            title: Row(
              children: [
                Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                if (cat.isPreset) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('预设',
                        style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.primary.withOpacity(0.6))),
                  ),
                ],
              ],
            ),
            trailing: hasChildren
                ? AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more,
                        color: theme.colorScheme.onSurface.withOpacity(0.4)),
                  )
                : null,
            onTap: hasChildren
                ? () => setState(() {
                      if (isExpanded) {
                        _expandedIds.remove(cat.id);
                      } else {
                        _expandedIds.add(cat.id);
                      }
                    })
                : null,
            onLongPress: cat.isPreset ? null : () => _editCategory(cat),
          ),
        ),
        // 子分类列表
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            children: [
              ...cat.children.map((child) =>
                  _buildSubcategoryTile(child, theme)),
              // 添加子分类按钮
              Padding(
                padding: const EdgeInsets.only(left: 56),
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.add_circle_outline,
                      size: 20,
                      color: theme.colorScheme.primary.withOpacity(0.6)),
                  title: Text('添加子分类',
                      style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.primary.withOpacity(0.6))),
                  onTap: () => _addCategory(parentId: cat.id),
                ),
              ),
            ],
          ),
          crossFadeState:
              isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
        if (!hasChildren || !isExpanded)
          Divider(
              height: 1,
              indent: 72,
              color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
      ],
    );
  }

  Widget _buildSubcategoryTile(Category cat, ThemeData theme) {
    final iconKey = cat.iconKey.isNotEmpty ? cat.iconKey : 'other';
    final color = CategoryIcons.getColor(iconKey);

    return Padding(
      padding: const EdgeInsets.only(left: 56),
      child: Dismissible(
        key: ValueKey('subcat_${cat.id}'),
        direction:
            cat.isPreset ? DismissDirection.none : DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: Colors.red,
          child: const Icon(Icons.delete, color: Colors.white, size: 20),
        ),
        confirmDismiss: (_) async {
          await _deleteCategory(cat);
          return false;
        },
        child: ListTile(
          dense: true,
          visualDensity: const VisualDensity(vertical: -2),
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(CategoryIcons.getIcon(iconKey), color: color, size: 16),
          ),
          title: Row(
            children: [
              Text(cat.name, style: const TextStyle(fontSize: 14)),
              if (cat.isPreset) ...[
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text('预设',
                      style: TextStyle(
                          fontSize: 9,
                          color: theme.colorScheme.primary.withOpacity(0.5))),
                ),
              ],
            ],
          ),
          onLongPress: cat.isPreset ? null : () => _editCategory(cat),
        ),
      ),
    );
  }

  Future<_CategoryEditResult?> _showCategoryEditor(
    BuildContext context, {
    String? initialName,
    String? initialIconKey,
  }) async {
    String name = initialName ?? '';
    String iconKey = initialIconKey ?? 'other';
    final nameController = TextEditingController(text: name);

    return showModalBottomSheet<_CategoryEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) {
          final theme = Theme.of(ctx);
          final bottom = MediaQuery.of(ctx).viewInsets.bottom;
          final color = CategoryIcons.getColor(iconKey);

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: 16 + bottom + MediaQuery.of(ctx).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 拖拽条
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(initialName != null ? '编辑分类' : '新建分类',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                // 图标选择
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        showIconPickerSheet(ctx,
                            selectedKey: iconKey, onSelect: (key) {
                          setLocalState(() => iconKey = key);
                        });
                      },
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: color.withOpacity(0.3), width: 1.5),
                        ),
                        child: Icon(CategoryIcons.getIcon(iconKey),
                            color: color, size: 28),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.edit, size: 14,
                        color: theme.colorScheme.onSurface.withOpacity(0.3)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: nameController,
                        maxLength: 15,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: '输入分类名称',
                          counterText: '${nameController.text.length}/15',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                        onChanged: (v) {
                          setLocalState(() => name = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // 确认按钮
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: name.trim().isEmpty
                        ? null
                        : () => Navigator.pop(ctx,
                            _CategoryEditResult(name: name.trim(), iconKey: iconKey)),
                    child: Text(initialName != null ? '保存' : '添加'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CategoryEditResult {
  final String name;
  final String iconKey;
  _CategoryEditResult({required this.name, required this.iconKey});
}
