import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart';
import '../../domain/providers/transaction_provider.dart';
import '../../domain/providers/dashboard_provider.dart';
import '../../domain/providers/account_provider.dart';
import '../../domain/providers/app_providers.dart';
import '../../domain/providers/family_provider.dart';
import '../../core/widgets/widgets.dart';
import 'transaction_detail_page.dart';

/// 交易历史页面 — 高性能分组列表，支持下拉刷新 / 上拉加载 / 滑动删除
class TransactionHistoryPage extends ConsumerStatefulWidget {
  const TransactionHistoryPage({super.key});

  @override
  ConsumerState<TransactionHistoryPage> createState() =>
      _TransactionHistoryPageState();
}

class _TransactionHistoryPageState
    extends ConsumerState<TransactionHistoryPage> {
  static const _pageSize = 50;

  int _displayCount = _pageSize;
  late final ScrollController _scrollController;
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    // Incremental sync is handled by TransactionNotifier._load() automatically.
    // No need to call reload() here — it would reset sync time and force full re-fetch.
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _batchDelete() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定删除选中的 $count 笔交易吗？\n删除后不可恢复。'),
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
    if (confirmed != true || !mounted) return;

    final ids = _selectedIds.toList();
    _exitSelectionMode();

    final deleted = await ref
        .read(transactionProvider.notifier)
        .batchDeleteTransactions(ids);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已删除 $deleted 笔交易'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    // 刷新 Dashboard + Account
    ref.invalidate(dashboardProvider);
    ref.invalidate(accountProvider);
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final cur = _scrollController.position.pixels;
    if (cur >= max - 200) {
      _loadMore();
    }
  }

  void _loadMore() {
    final total =
        ref.read(transactionProvider).transactions.length;
    if (_displayCount >= total) return;
    setState(() {
      _displayCount = (_displayCount + _pageSize).clamp(0, total);
    });
  }

  Future<void> _onRefresh() async {
    // Pull fresh data from server and reset display count
    await ref.read(transactionProvider.notifier).reload();
    setState(() => _displayCount = _pageSize);
  }

  // _buildItems is no longer used — VirtualList handles grouping via separatorBuilder

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final familyId = ref.watch(currentFamilyIdProvider);
    final isFamilyMode = familyId != null && familyId.isNotEmpty;

    // Build member name lookup for family mode
    Map<String, String> memberNameMap = {};
    if (isFamilyMode) {
      final familyState = ref.watch(familyProvider);
      for (final m in familyState.members) {
        final email = m.email;
        memberNameMap[m.userId] = email.contains('@') ? email.split('@').first : email;
      }
    }

    // Build a category lookup map (id → Category)
    final categoryMap = <String, Category>{};
    for (final c in state.expenseCategories) {
      categoryMap[c.id] = c;
    }
    for (final c in state.incomeCategories) {
      categoryMap[c.id] = c;
    }

    return Semantics(
      label: '交易记录页面',
      child: Scaffold(
        appBar: AppBar(
          leading: _selectionMode
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _exitSelectionMode,
                )
              : null,
          title: _selectionMode
              ? Text('已选择 ${_selectedIds.length} 笔')
              : const Text('交易记录'),
          centerTitle: false,
          actions: [
            if (_selectionMode && _selectedIds.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: _batchDelete,
              ),
            if (!_selectionMode && state.transactions.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.checklist),
                tooltip: '批量管理',
                onPressed: () => setState(() => _selectionMode = true),
              ),
          ],
        ),
        body: state.isLoading
            ? const SkeletonList(count: 6, itemHeight: 72)
            : state.error != null
                ? ErrorState(
                    message: state.error!,
                    onRetry: () => ref.read(transactionProvider.notifier).reload(),
                  )
                : state.transactions.isEmpty
                    ? _EmptyState(isDark: isDark, canCreate: ref.watch(canCreateProvider))
                    : _buildList(state, categoryMap, theme, isDark, memberNameMap),
      ),
    );
  }

  Widget _buildList(
    TransactionState state,
    Map<String, Category> categoryMap,
    ThemeData theme,
    bool isDark,
    Map<String, String> memberNameMap,
  ) {
    final visible = state.transactions.take(_displayCount).toList();
    final hasMore = _displayCount < state.transactions.length;

    return CustomRefreshIndicator(
      onRefresh: _onRefresh,
      child: Column(
        children: [
          Expanded(
            child: VirtualList<Transaction>(
              items: visible,
              itemExtent: 72,
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              bottomPadding: 80,
              separatorBuilder: (context, index) {
                // Show date header before first item, or when date changes
                if (index >= visible.length) return const SizedBox.shrink();
                final txn = visible[index];
                final date = DateTime(txn.txnDate.year, txn.txnDate.month, txn.txnDate.day);
                final bool showHeader;
                if (index == 0) {
                  showHeader = true;
                } else {
                  final prev = visible[index - 1];
                  final prevDate = DateTime(prev.txnDate.year, prev.txnDate.month, prev.txnDate.day);
                  showHeader = date != prevDate;
                }
                return showHeader
                    ? _DateHeader(date: date, isDark: isDark)
                    : const SizedBox.shrink();
              },
              itemBuilder: (context, txn, index) {
                final txnCategory = categoryMap[txn.categoryId];
                final txnParentCategory = txnCategory?.parentId != null && txnCategory!.parentId!.isNotEmpty
                    ? categoryMap[txnCategory.parentId!]
                    : null;
                return _TransactionRow(
                  transaction: txn,
                  category: txnCategory,
                  parentCategory: txnParentCategory,
                  isDark: isDark,
                  selectionMode: _selectionMode,
                  selected: _selectedIds.contains(txn.id),
                  creatorName: memberNameMap.isNotEmpty ? memberNameMap[txn.userId] : null,
                  onTap: _selectionMode
                      ? () => _toggleSelection(txn.id)
                      : () {
                          Navigator.of(context).pushNamed(
                            AppRouter.transactionDetail,
                            arguments: TransactionDetailArgs(
                              transaction: txn,
                              category: txnCategory,
                            ),
                          );
                        },
                  onLongPress: !_selectionMode
                      ? () {
                          setState(() => _selectionMode = true);
                          _toggleSelection(txn.id);
                        }
                      : null,
                  onDelete: ref.watch(canDeleteProvider)
                      ? () => _deleteTransaction(txn)
                      : null,
                  onEdit: ref.watch(canEditProvider)
                      ? () {
                    Navigator.of(context).pushNamed(
                      AppRouter.addTransaction,
                      arguments: txn,
                    );
                  }
                      : null,
                );
              },
            ),
          ),
          if (hasMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _deleteTransaction(Transaction txn) async {
    if (!mounted) return;
    await ref.read(transactionProvider.notifier).deleteTransaction(txn.id);
    // 刷新 Dashboard 和 Account
    ref.read(dashboardProvider.notifier).loadAll();
    ref.read(accountProvider.notifier).refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已删除 "${txn.note.isNotEmpty ? txn.note : '交易'}"'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ── Date header widget ──

class _DateHeader extends StatelessWidget {
  final DateTime date;
  final bool isDark;

  const _DateHeader({required this.date, required this.isDark});

  static const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    String label;
    if (date == today) {
      label = '今天';
    } else if (date == yesterday) {
      label = '昨天';
    } else {
      final weekday = _weekdays[date.weekday - 1];
      label = '${date.year}年${date.month}月${date.day}日 $weekday';
    }

    return Semantics(
      header: true,
      label: label,
      child: Container(
        height: 40,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Transaction row widget (constant height 72) ──

class _TransactionRow extends StatelessWidget {
  final Transaction transaction;
  final Category? category;
  final Category? parentCategory;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onLongPress;
  final bool selectionMode;
  final bool selected;
  final String? creatorName;

  const _TransactionRow({
    required this.transaction,
    required this.category,
    this.parentCategory,
    required this.isDark,
    required this.onTap,
    this.onDelete,
    this.onEdit,
    this.onLongPress,
    this.selectionMode = false,
    this.selected = false,
    this.creatorName,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == 'income';
    final amountColor = isIncome
        ? (isDark ? AppColors.incomeDark : AppColors.income)
        : (isDark ? AppColors.expenseDark : AppColors.expense);
    final prefix = isIncome ? '+' : '-';
    final yuan = transaction.amountCny / 100;
    final amountText = yuan == yuan.truncateToDouble()
        ? '${yuan.toInt()}'
        : yuan.toStringAsFixed(2);
    final timeText = DateFormat('HH:mm').format(transaction.txnDate);
    final icon = category?.icon ?? '📦';
    final catName = category?.name ?? '未分类';
    final categoryName = parentCategory != null ? '${parentCategory!.name}-$catName' : catName;

    final typeLabel = isIncome ? '收入' : '支出';

    final rowContent = GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
        height: 72,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              if (selectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    selected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: selected ? Theme.of(context).colorScheme.primary : Colors.grey,
                    size: 24,
                  ),
                ),
              // Category icon
              Semantics(
                label: '$categoryName 图标',
                child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF3A3A3C)
                      : const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(icon, style: const TextStyle(fontSize: 20)),
              ),
              ),
              const SizedBox(width: 12),
              // Name + note + time
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoryName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        timeText,
                        if (creatorName != null) creatorName!,
                        if (transaction.note.isNotEmpty) transaction.note,
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Amount
              Semantics(
                label: '金额 $amountText元',
                child: SharedElement(
                tag: HeroTags.transaction(transaction.id),
                child: Text(
                  '$prefix¥$amountText',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: amountColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selectionMode) {
      return Semantics(
        label: '$typeLabel $categoryName $amountText元 $timeText',
        child: rowContent,
      );
    }
    return Semantics(
      label: '$typeLabel $categoryName $amountText元 $timeText',
      child: SwipeToDelete(
        dismissKey: ValueKey(transaction.id),
        confirmMessage: '${transaction.type == 'income' ? '收入' : '支出'} ¥$amountText',
        onDelete: onDelete,
        child: rowContent,
      ),
    );
  }
}

// ── Empty state ──

class _EmptyState extends StatelessWidget {
  final bool isDark;
  final bool canCreate;

  const _EmptyState({required this.isDark, this.canCreate = true});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 80,
              color: isDark
                  ? AppColors.textSecondaryDark.withValues(alpha: 0.4)
                  : AppColors.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 20),
            Text(
              '暂无交易记录',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textPrimaryDark.withValues(alpha: 0.6)
                    : AppColors.textPrimary.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击下方按钮添加第一笔交易',
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 28),
            if (canCreate)
              FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRouter.addTransaction),
                icon: const Icon(Icons.add_rounded),
                label: const Text('记一笔'),
              ),
          ],
        ),
      ),
    );
  }
}
