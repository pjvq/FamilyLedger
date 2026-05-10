import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/category_icon_widget.dart';
import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart' show Category;
import '../../domain/providers/budget_provider.dart';
import '../../domain/providers/transaction_provider.dart';

/// Bottom sheet for setting monthly budget with total + per-category amounts.
class SetBudgetSheet extends ConsumerStatefulWidget {
  const SetBudgetSheet({super.key});

  @override
  ConsumerState<SetBudgetSheet> createState() => _SetBudgetSheetState();
}

class _SetBudgetSheetState extends ConsumerState<SetBudgetSheet> {
  final _totalController = TextEditingController();
  final Map<String, TextEditingController> _catControllers = {};
  bool _showCategories = false;
  bool _isSaving = false;
  final Set<String> _expandedParents = {};

  @override
  void initState() {
    super.initState();
    // Pre-fill if editing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final budgetState = ref.read(budgetProvider);
      if (budgetState.currentBudget != null) {
        _totalController.text =
            (budgetState.currentBudget!.totalAmount / 100).toStringAsFixed(0);
        for (final cb in budgetState.currentCategoryBudgets) {
          _catControllers[cb.categoryId] = TextEditingController(
            text: (cb.amount / 100).toStringAsFixed(0),
          );
        }
        setState(() {
          _showCategories = budgetState.currentCategoryBudgets.isNotEmpty;
        });
      }
    });
  }

  @override
  void dispose() {
    _totalController.dispose();
    for (final c in _catControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _getController(String catId) {
    return _catControllers.putIfAbsent(catId, () => TextEditingController());
  }

  /// Build category budget rows grouped by parent (1st level) → children (2nd level).
  List<Widget> _buildGroupedCategories(
      List<Category> allCats, ThemeData theme, bool isDark) {
    // Separate into parents (parentId == null) and children
    final parents = allCats.where((c) => c.parentId == null).toList();
    final childrenMap = <String, List<Category>>{};
    for (final c in allCats.where((c) => c.parentId != null)) {
      childrenMap.putIfAbsent(c.parentId!, () => []).add(c);
    }

    final widgets = <Widget>[];
    for (final parent in parents) {
      final children = childrenMap[parent.id] ?? [];
      final isExpanded = _expandedParents.contains(parent.id);

      // Parent row: icon + name + budget input + expand toggle
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: children.isNotEmpty
                    ? () => setState(() {
                          if (isExpanded) {
                            _expandedParents.remove(parent.id);
                          } else {
                            _expandedParents.add(parent.id);
                          }
                        })
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      CategoryIconWidget(
                          iconKey: parent.iconKey,
                          size: 20,
                          showBackground: true),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            Text(
                              parent.name,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (children.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Icon(
                                isExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 18,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: _buildBudgetInput(
                            parent.id, parent.name, theme, isDark),
                      ),
                    ],
                  ),
                ),
              ),
              // Children rows (indented)
              if (isExpanded && children.isNotEmpty)
                ...children.map((child) => Padding(
                      padding:
                          const EdgeInsets.only(left: 32, bottom: 2),
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            CategoryIconWidget(
                                iconKey: child.iconKey,
                                size: 16,
                                showBackground: true),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Text(
                                child.name,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color:
                                      theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: _buildBudgetInput(
                                  child.id, child.name, theme, isDark),
                            ),
                          ],
                        ),
                      ),
                    )),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _buildBudgetInput(
      String catId, String catName, ThemeData theme, bool isDark) {
    final controller = _getController(catId);
    return Semantics(
      label: '$catName分类预算金额',
      child: TextField(
        controller: controller,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.right,
        decoration: InputDecoration(
          prefixText: '¥ ',
          hintText: '0',
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          filled: true,
          fillColor: isDark ? AppColors.cardDark : AppColors.cardLight,
        ),
      ),
    );
  }

  Future<void> _save() async {
    final totalText = _totalController.text.trim();
    if (totalText.isEmpty) return;

    final totalYuan = double.tryParse(totalText);
    if (totalYuan == null || totalYuan <= 0) return;

    final totalCents = (totalYuan * 100).round();

    final categoryBudgets = <CategoryBudgetItem>[];
    for (final entry in _catControllers.entries) {
      final text = entry.value.text.trim();
      if (text.isNotEmpty) {
        final yuan = double.tryParse(text);
        if (yuan != null && yuan > 0) {
          categoryBudgets.add(CategoryBudgetItem(
            categoryId: entry.key,
            amount: (yuan * 100).round(),
          ));
        }
      }
    }

    setState(() => _isSaving = true);

    try {
      final budgetState = ref.read(budgetProvider);
      final now = DateTime.now();
      final notifier = ref.read(budgetProvider.notifier);

      // Pop immediately for responsive UX, then update in background
      if (mounted) Navigator.of(context).pop();

      if (budgetState.currentBudget != null) {
        await notifier.updateBudget(
              id: budgetState.currentBudget!.id,
              totalAmount: totalCents,
              categoryBudgets: categoryBudgets,
            );
      } else {
        await notifier.createBudget(
              year: now.year,
              month: now.month,
              totalAmount: totalCents,
              categoryBudgets: categoryBudgets,
            );
      }
    } catch (_) {
      // Already popped; error handled by provider
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final txnState = ref.watch(transactionProvider);
    final expenseCategories = txnState.expenseCategories;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              children: [
                // Handle bar
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.black.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text(
                        '设置预算',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        tooltip: '关闭',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Content
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      // Total budget input
                      Semantics(
                        label: '总预算金额',
                        child: TextField(
                          controller: _totalController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            labelText: '每月总预算',
                            prefixText: '¥ ',
                            prefixStyle:
                                theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.primaryDark
                                  : AppColors.primary,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            filled: true,
                            fillColor: isDark
                                ? AppColors.cardDark
                                : AppColors.cardLight,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Category budgets toggle
                      SwitchListTile(
                        title: const Text('分类预算'),
                        subtitle: const Text('为每个支出分类设置独立预算'),
                        value: _showCategories,
                        onChanged: (v) =>
                            setState(() => _showCategories = v),
                        contentPadding: EdgeInsets.zero,
                      ),

                      // Category budget list — grouped by parent
                      if (_showCategories) ...[
                        const SizedBox(height: 8),
                        ..._buildGroupedCategories(
                            expenseCategories, theme, isDark),
                      ],

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                // Save button
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              '保存',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600),
                            ),
                    ),
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
