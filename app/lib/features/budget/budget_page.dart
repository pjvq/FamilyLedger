import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/category_icon_widget.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/budget_colors.dart';
import '../../data/local/database.dart' show Category;
import '../../domain/providers/app_providers.dart';
import '../../domain/providers/budget_provider.dart';
import '../../sync/sync_engine.dart';
import '../../domain/providers/family_provider.dart';
import '../../domain/providers/transaction_provider.dart';
import 'budget_execution_card.dart';
import 'set_budget_sheet.dart';

class BudgetPage extends ConsumerStatefulWidget {
  const BudgetPage({super.key});

  @override
  ConsumerState<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends ConsumerState<BudgetPage>
    with SingleTickerProviderStateMixin {
  final Set<String> _expandedParents = {};
  late TabController _viewTabController;
  List<int>? _yearlyMonthlySpent;

  @override
  void initState() {
    super.initState();
    _viewTabController = TabController(length: 2, vsync: this);
    _viewTabController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadYearlyData());
  }

  Future<void> _loadYearlyData() async {
    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) return;
      final db = ref.read(databaseProvider);
      final data = await db.getMonthlyExpensesForYear(userId, DateTime.now().year);
      if (mounted) setState(() => _yearlyMonthlySpent = data);
    } catch (_) {
      // Graceful fallback — yearly view will use zeroes
    }
  }

  @override
  void dispose() {
    _viewTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final budgetState = ref.watch(budgetProvider);
    final txnState = ref.watch(transactionProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('预算'),
        centerTitle: false,
        bottom: TabBar(
          controller: _viewTabController,
          tabs: const [
            Tab(text: '月预算'),
            Tab(text: '年预算'),
          ],
        ),
      ),
      floatingActionButton: ref.watch(canEditProvider)
          ? FloatingActionButton.extended(
              onPressed: () => _showSetBudgetSheet(context,
                  isAnnual: _viewTabController.index == 1),
              icon: const Icon(Icons.edit_rounded),
              label: Text(_viewTabController.index == 1
                  ? (budgetState.annualBudget != null ? '编辑年预算' : '设置年预算')
                  : (budgetState.currentBudget != null ? '编辑预算' : '设置预算')),
            )
          : null,
      body: TabBarView(
        controller: _viewTabController,
        children: [
          // ── Monthly tab ──
          _buildMonthlyTab(budgetState, txnState, theme, isDark, now),
          // ── Yearly tab ──
          _buildYearlyTab(budgetState, txnState, theme, isDark, now),
        ],
      ),
    );
  }

  /// Build category execution tiles grouped by parent category.
  ///
    Widget _buildMonthlyTab(BudgetState budgetState, TransactionState txnState,
      ThemeData theme, bool isDark, DateTime now) {
    if (budgetState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (budgetState.currentBudget == null) {
      return _EmptyBudgetState(
        theme: theme,
        onSetBudget: ref.watch(canEditProvider)
            ? () => _showSetBudgetSheet(context)
            : null,
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(syncEngineProvider).forcePull();
        await ref.read(budgetProvider.notifier).loadCurrentMonth();
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          if (budgetState.execution != null)
            BudgetExecutionCard(
              executionRate: budgetState.execution!.executionRate,
              totalBudget: budgetState.execution!.totalBudget,
              totalSpent: budgetState.execution!.totalSpent,
            ),
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
          if (budgetState.execution != null)
            ..._buildGroupedCategoryTiles(
              budgetState.execution!.categoryExecutions,
              txnState,
              isDark,
              theme,
            ),
        ],
      ),
    );
  }

  Widget _buildYearlyTab(BudgetState budgetState, TransactionState txnState,
      ThemeData theme, bool isDark, DateTime now) {
    if (budgetState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final annualBudget = budgetState.annualBudget;
    final annualExec = budgetState.annualExecution;

    if (annualBudget == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('尚未设置年预算',
                style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
            const SizedBox(height: 8),
            Text('点击右下角按钮设置${now.year}年预算',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
          ],
        ),
      );
    }

    final yearlyBudget = annualBudget.totalAmount;
    final yearlySpent = annualExec?.totalSpent ?? 0;
    final rate = yearlyBudget > 0 ? yearlySpent / yearlyBudget : 0.0;
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays + 1;
    final expectedRate = dayOfYear / 365;
    final remaining = yearlyBudget - yearlySpent;
    final colors = context.semanticColors;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        // Year summary card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark
                ? NeutralColorsDark.neutral2
                : NeutralColorsLight.neutral0,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${now.year}年预算概览',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              // Progress
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: rate.clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: theme.colorScheme.onSurface
                      .withValues(alpha: 0.06),
                  color: rate >= 1.0
                      ? colors.error
                      : rate >= 0.8
                          ? colors.warning
                          : colors.income,
                ),
              ),
              const SizedBox(height: 12),
              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _yearStat('年预算', yearlyBudget, theme),
                  _yearStat('已支出', yearlySpent, theme,
                      color: colors.expense),
                  _yearStat(
                      '剩余', remaining, theme,
                      color:
                          remaining >= 0 ? colors.income : colors.error),
                ],
              ),
              const SizedBox(height: 12),
              // Status
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (rate > expectedRate
                          ? colors.warning
                          : colors.income)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      rate > expectedRate
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline,
                      size: 16,
                      color: rate > expectedRate
                          ? colors.warning
                          : colors.income,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      rate > expectedRate
                          ? '支出进度超前 (${(rate * 100).toInt()}% vs 预期${(expectedRate * 100).toInt()}%)'
                          : '支出进度正常 (${(rate * 100).toInt()}% vs 预期${(expectedRate * 100).toInt()}%)',
                      style: TypographyTokens.bodySm().copyWith(
                        color: rate > expectedRate
                            ? colors.warning
                            : colors.income,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Monthly breakdown
        Text(
          '各月支出',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ..._buildMonthlyBreakdown(budgetState, txnState, theme, isDark, now),
      ],
    );
  }

  Widget _yearStat(String label, int cents, ThemeData theme, {Color? color}) {
    return Column(
      children: [
        Text(label, style: TypographyTokens.caption()),
        const SizedBox(height: 4),
        Text(
          '¥${(cents / 100).toStringAsFixed(0)}',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildMonthlyBreakdown(BudgetState budgetState, TransactionState txnState,
      ThemeData theme, bool isDark, DateTime now) {
    // Use pre-fetched full-year data from DB (not paginated txnState)
    final monthlySpent = _yearlyMonthlySpent ?? List.filled(12, 0);

    // Monthly budgets
    final monthlyBudgets = List.filled(12, 0);
    for (final b in budgetState.budgets) {
      if (b.year == now.year && b.month >= 1 && b.month <= 12) {
        monthlyBudgets[b.month - 1] = b.totalAmount;
      }
    }

    final widgets = <Widget>[];
    for (int i = 0; i < now.month; i++) {
      final budget = monthlyBudgets[i];
      final spent = monthlySpent[i];
      final rate = budget > 0 ? spent / budget : 0.0;
      final colors = context.semanticColors;

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? NeutralColorsDark.neutral2
                  : NeutralColorsLight.neutral0,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    '${i + 1}月',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: rate.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: theme.colorScheme.onSurface
                          .withValues(alpha: 0.06),
                      color: rate >= 1.0
                          ? colors.error
                          : rate >= 0.8
                              ? colors.warning
                              : colors.income,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 70,
                  child: Text(
                    '¥${(spent / 100).toStringAsFixed(0)}',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  /// Build category execution tiles grouped by parent category.
  ///
  /// Fixes:
  /// 1. Parent spent = own spent + sum of children spent
  /// 2. Parent name always shown (from category DB, not just execution data)
  /// 3. Collapsible: children hidden by default, tap parent to expand
  List<Widget> _buildGroupedCategoryTiles(
    List<CategoryExecutionData> executions,
    TransactionState txnState,
    bool isDark,
    ThemeData theme,
  ) {
    final allCats = <String, Category>{};
    for (final c in [
      ...txnState.expenseCategories,
      ...txnState.incomeCategories,
    ]) {
      allCats[c.id] = c;
    }

    // Separate into parent execs and child execs
    final parentOrder = <String>[]; // ordered unique parent ids
    final parentExecs =
        <String, CategoryExecutionData>{}; // parentId → exec
    final childExecs =
        <String, List<CategoryExecutionData>>{}; // parentId → children

    for (final ce in executions) {
      final cat = allCats[ce.categoryId];
      if (cat == null) continue;
      if (cat.parentId == null) {
        if (!parentOrder.contains(ce.categoryId)) {
          parentOrder.add(ce.categoryId);
        }
        parentExecs[ce.categoryId] = ce;
      } else {
        final pid = cat.parentId!;
        if (!parentOrder.contains(pid)) {
          parentOrder.add(pid);
        }
        childExecs.putIfAbsent(pid, () => []).add(ce);
      }
    }

    final widgets = <Widget>[];
    for (final pid in parentOrder) {
      final parentExec = parentExecs[pid];
      final children = childExecs[pid] ?? [];
      final parentCat = allCats[pid];
      final isExpanded = _expandedParents.contains(pid);
      final hasChildren = children.isNotEmpty;

      // Parent spent already includes all children (aggregated in provider)
      final parentSpent = parentExec?.spentAmount ?? 0;
      final parentBudget = parentExec?.budgetAmount ?? 0;
      final parentRate =
          parentBudget > 0 ? parentSpent / parentBudget : 0.0;

      // Parent category name (from DB, guaranteed not empty)
      final parentName =
          parentCat?.name ?? parentExec?.categoryName ?? '未知';

      // Parent tile (always visible, tappable to expand)
      widgets.add(
        GestureDetector(
          onTap: hasChildren
              ? () => setState(() {
                    if (isExpanded) {
                      _expandedParents.remove(pid);
                    } else {
                      _expandedParents.add(pid);
                    }
                  })
              : null,
          child: _CategoryBudgetTile(
            categoryName: parentName,
            iconKey: parentCat?.iconKey,
            budgetAmount: parentBudget,
            spentAmount: parentSpent,
            executionRate: parentRate,
            isDark: isDark,
            theme: theme,
            isParent: true,
            trailing: hasChildren
                ? Icon(
                    isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  )
                : null,
          ),
        ),
      );

      // Child tiles (only when expanded)
      if (isExpanded) {
        for (final ce in children) {
          widgets.add(_CategoryBudgetTile(
            categoryName: ce.categoryName,
            iconKey: _getCategoryIconKey(ce.categoryId, txnState),
            budgetAmount: ce.budgetAmount,
            spentAmount: ce.spentAmount,
            executionRate: ce.executionRate,
            isDark: isDark,
            theme: theme,
            isParent: false,
          ));
        }
      }
    }
    return widgets;
  }

  String? _getCategoryIconKey(String categoryId, TransactionState txnState) {
    final allCats = [
      ...txnState.expenseCategories,
      ...txnState.incomeCategories,
    ];
    final cat = allCats.where((c) => c.id == categoryId).firstOrNull;
    return cat?.iconKey;
  }

  void _showSetBudgetSheet(BuildContext context, {bool isAnnual = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SetBudgetSheet(isAnnual: isAnnual),
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
              color:
                  theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '设置每月预算，掌控支出',
            style: theme.textTheme.bodySmall?.copyWith(
              color:
                  theme.colorScheme.onSurface.withValues(alpha: 0.3),
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
  final String? iconKey;
  final int budgetAmount;
  final int spentAmount;
  final double executionRate;
  final bool isDark;
  final ThemeData theme;
  final bool isParent;
  final Widget? trailing;

  const _CategoryBudgetTile({
    required this.categoryName,
    this.iconKey,
    required this.budgetAmount,
    required this.spentAmount,
    required this.executionRate,
    required this.isDark,
    required this.theme,
    this.isParent = true,
    this.trailing,
  });

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
    final color = budgetRateColor(context, executionRate);
    final pct =
        '${(executionRate * 100).clamp(0, 999).toStringAsFixed(0)}%';

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
          color: isDark ? NeutralColorsDark.neutral2 : NeutralColorsLight.neutral0,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withValues(alpha: isDark ? 0.2 : 0.04),
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
                CategoryIconWidget(
                    iconKey: iconKey,
                    size: isParent ? 22 : 18,
                    showBackground: true),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    categoryName,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: isParent
                          ? FontWeight.w600
                          : FontWeight.w400,
                      fontSize: isParent ? null : 14,
                    ),
                  ),
                ),
                Text(
                  '${_formatAmount(spentAmount)} / ${_formatAmount(budgetAmount)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? NeutralColorsDark.neutral5
                        : NeutralColorsLight.neutral5,
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 4),
                  trailing!,
                ],
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
