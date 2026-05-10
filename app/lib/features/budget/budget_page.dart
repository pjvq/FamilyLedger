import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart' show Category;
import '../../domain/providers/budget_provider.dart';
import '../../sync/sync_engine.dart';
import '../../domain/providers/family_provider.dart';
import '../../domain/providers/transaction_provider.dart';
import 'budget_execution_card.dart';
import 'set_budget_sheet.dart';

class BudgetPage extends ConsumerWidget {
  const BudgetPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetState = ref.watch(budgetProvider);
    final txnState = ref.watch(transactionProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: Text('${now.month}月预算'),
        centerTitle: false,
      ),
      floatingActionButton: ref.watch(canEditProvider)
          ? FloatingActionButton.extended(
        onPressed: () => _showSetBudgetSheet(context),
        icon: const Icon(Icons.edit_rounded),
        label: Text(budgetState.currentBudget != null ? '编辑预算' : '设置预算'),
      )
          : null,
      body: budgetState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : budgetState.currentBudget == null
              ? _EmptyBudgetState(
                  theme: theme,
                  onSetBudget: ref.watch(canEditProvider)
                      ? () => _showSetBudgetSheet(context)
                      : null,
                )
              : RefreshIndicator(
                  onRefresh: () async {
                      await ref.read(syncEngineProvider).forcePull();
                      await ref.read(budgetProvider.notifier).loadCurrentMonth();
                  },
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 100),
                    children: [
                      // Execution ring card
                      if (budgetState.execution != null)
                        BudgetExecutionCard(
                          executionRate:
                              budgetState.execution!.executionRate,
                          totalBudget:
                              budgetState.execution!.totalBudget,
                          totalSpent: budgetState.execution!.totalSpent,
                        ),

                      // Category budget list header
                      if (budgetState.execution != null &&
                          budgetState.execution!.categoryExecutions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                          child: Text(
                            '分类预算',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                      // Category budget items — grouped by parent
                      if (budgetState.execution != null)
                        ..._buildGroupedCategoryTiles(
                          budgetState.execution!.categoryExecutions,
                          txnState,
                          isDark,
                          theme,
                        ),
                    ],
                  ),
                ),
    );
  }

  /// Build category execution tiles grouped by parent category.
  List<Widget> _buildGroupedCategoryTiles(
    List<CategoryExecutionData> executions,
    dynamic txnState,
    bool isDark,
    ThemeData theme,
  ) {
    final allCats = <String, Category>{};
    for (final c in [...txnState.expenseCategories, ...txnState.incomeCategories]) {
      allCats[c.id] = c;
    }

    // Build a map: categoryId → execution
    final execMap = <String, CategoryExecutionData>{};
    for (final ce in executions) {
      execMap[ce.categoryId] = ce;
    }

    // Find parent categories that have budget entries (either directly or via children)
    final parentIds = <String>{}; // ordered set
    final childExecs = <String, List<CategoryExecutionData>>{}; // parentId → children
    final parentExecs = <String, CategoryExecutionData>{}; // parentId → parent exec

    for (final ce in executions) {
      final cat = allCats[ce.categoryId];
      if (cat == null) continue;
      if (cat.parentId == null) {
        // This is a parent category
        parentIds.add(ce.categoryId);
        parentExecs[ce.categoryId] = ce;
      } else {
        // This is a child category
        final pid = cat.parentId!;
        parentIds.add(pid);
        childExecs.putIfAbsent(pid, () => []).add(ce);
      }
    }

    final widgets = <Widget>[];
    for (final pid in parentIds) {
      final parentExec = parentExecs[pid];
      final children = childExecs[pid] ?? [];
      final parentCat = allCats[pid];

      // Parent tile
      if (parentExec != null) {
        widgets.add(_CategoryBudgetTile(
          categoryName: parentExec.categoryName,
          categoryIcon: parentCat?.icon ?? '📦',
          budgetAmount: parentExec.budgetAmount,
          spentAmount: parentExec.spentAmount,
          executionRate: parentExec.executionRate,
          isDark: isDark,
          theme: theme,
          isParent: true,
        ));
      } else if (parentCat != null) {
        // Parent has no budget but has children with budgets
        widgets.add(Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(
            children: [
              Text(parentCat.icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Text(
                parentCat.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ));
      }

      // Child tiles (indented)
      for (final ce in children) {
        widgets.add(_CategoryBudgetTile(
          categoryName: ce.categoryName,
          categoryIcon: _getCategoryIcon(ce.categoryId, txnState),
          budgetAmount: ce.budgetAmount,
          spentAmount: ce.spentAmount,
          executionRate: ce.executionRate,
          isDark: isDark,
          theme: theme,
          isParent: false,
        ));
      }
    }
    return widgets;
  }

  String _getCategoryIcon(String categoryId, dynamic txnState) {
    final allCats = [
      ...txnState.expenseCategories,
      ...txnState.incomeCategories,
    ];
    final cat = allCats.where((c) => c.id == categoryId).firstOrNull;
    return cat?.icon ?? '📦';
  }

  void _showSetBudgetSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SetBudgetSheet(),
    );
  }
}

// ────────── Empty State ──────────

class _EmptyBudgetState extends StatelessWidget {
  final ThemeData theme;
  final VoidCallback? onSetBudget;

  const _EmptyBudgetState({required this.theme, this.onSetBudget});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.savings_rounded,
            size: 80,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 16),
          Text(
            '还没有设置预算',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '设置每月预算，掌控支出',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 24),
          if (onSetBudget != null)
          FilledButton.icon(
            onPressed: onSetBudget,
            icon: const Icon(Icons.add_rounded),
            label: const Text('设置预算'),
          ),
        ],
      ),
    );
  }
}

// ────────── Category Budget Tile ──────────

class _CategoryBudgetTile extends StatelessWidget {
  final String categoryName;
  final String categoryIcon;
  final int budgetAmount;
  final int spentAmount;
  final double executionRate;
  final bool isDark;
  final ThemeData theme;
  final bool isParent;

  const _CategoryBudgetTile({
    required this.categoryName,
    required this.categoryIcon,
    required this.budgetAmount,
    required this.spentAmount,
    required this.executionRate,
    required this.isDark,
    required this.theme,
    this.isParent = true,
  });

  Color _rateColor(double rate) {
    if (rate >= 0.8) return AppColors.expense;
    if (rate >= 0.6) return const Color(0xFFFF9500);
    return AppColors.income;
  }

  String _formatAmount(int cents) {
    final yuan = cents / 100;
    final str = yuan.toStringAsFixed(2);
    final parts = str.split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    final buffer = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buffer.write(',');
      buffer.write(intPart[i]);
    }
    return '¥${buffer.toString()}.$decPart';
  }

  @override
  Widget build(BuildContext context) {
    final color = _rateColor(executionRate);
    final pct = '${(executionRate * 100).clamp(0, 999).toStringAsFixed(0)}%';

    return Semantics(
      label: '$categoryName，已用 ${_formatAmount(spentAmount)}，'
          '预算 ${_formatAmount(budgetAmount)}，执行率 $pct',
      child: Container(
        margin: EdgeInsets.only(
          left: isParent ? 16 : 40,
          right: 16,
          top: 4,
          bottom: 4,
        ),
        padding: EdgeInsets.all(isParent ? 16 : 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(categoryIcon,
                    style: TextStyle(fontSize: isParent ? 24 : 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    categoryName,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight:
                          isParent ? FontWeight.w600 : FontWeight.w400,
                      fontSize: isParent ? null : 14,
                    ),
                  ),
                ),
                Text(
                  '${_formatAmount(spentAmount)} / ${_formatAmount(budgetAmount)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: executionRate.clamp(0.0, 1.0),
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
