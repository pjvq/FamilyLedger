import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart';
import '../../domain/providers/transaction_provider.dart';
import '../../domain/providers/dashboard_provider.dart';
import '../../domain/providers/account_provider.dart';
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

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
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
    // Reset display count and let the provider stream refresh naturally.
    setState(() => _displayCount = _pageSize);
  }

  // ── Build grouped items (date headers + transaction rows) ──

  List<_ListItem> _buildItems(List<Transaction> transactions) {
    final visible = transactions.take(_displayCount).toList();
    if (visible.isEmpty) return [];

    final items = <_ListItem>[];
    DateTime? lastDate;

    for (final txn in visible) {
      final date = DateTime(txn.txnDate.year, txn.txnDate.month, txn.txnDate.day);
      if (lastDate == null || date != lastDate) {
        items.add(_DateHeaderItem(date));
        lastDate = date;
      }
      items.add(_TransactionItem(txn));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Build a category lookup map (id → Category)
    final categoryMap = <String, Category>{};
    for (final c in state.expenseCategories) {
      categoryMap[c.id] = c;
    }
    for (final c in state.incomeCategories) {
      categoryMap[c.id] = c;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('交易记录'),
        centerTitle: false,
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.transactions.isEmpty
              ? _EmptyState(isDark: isDark)
              : _buildList(state, categoryMap, theme, isDark),
    );
  }

  Widget _buildList(
    TransactionState state,
    Map<String, Category> categoryMap,
    ThemeData theme,
    bool isDark,
  ) {
    final items = _buildItems(state.transactions);
    final hasMore = _displayCount < state.transactions.length;

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 80),
        // We can't use a single itemExtent because date headers differ in
        // height from transaction rows. Instead we rely on
        // ListView.builder's efficient creation and the constant-height
        // rows for excellent scroll performance.
        itemCount: items.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            // Loading indicator at bottom
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          final item = items[index];
          if (item is _DateHeaderItem) {
            return _DateHeader(date: item.date, isDark: isDark);
          }
          final txnItem = item as _TransactionItem;
          final txnCategory = categoryMap[txnItem.transaction.categoryId];
          return _TransactionRow(
            transaction: txnItem.transaction,
            category: txnCategory,
            isDark: isDark,
            onTap: () {
              Navigator.of(context).pushNamed(
                AppRouter.transactionDetail,
                arguments: TransactionDetailArgs(
                  transaction: txnItem.transaction,
                  category: txnCategory,
                ),
              );
            },
            onDelete: () => _deleteTransaction(txnItem.transaction),
            onEdit: () {
              Navigator.of(context).pushNamed(
                AppRouter.addTransaction,
                arguments: txnItem.transaction,
              );
            },
          );
        },
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

// ── List item sealed types ──

sealed class _ListItem {}

class _DateHeaderItem extends _ListItem {
  final DateTime date;
  _DateHeaderItem(this.date);
}

class _TransactionItem extends _ListItem {
  final Transaction transaction;
  _TransactionItem(this.transaction);
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

    return Container(
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
    );
  }
}

// ── Transaction row widget (constant height 72) ──

class _TransactionRow extends StatelessWidget {
  final Transaction transaction;
  final Category? category;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _TransactionRow({
    required this.transaction,
    required this.category,
    required this.isDark,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
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
    final categoryName = category?.name ?? '未分类';

    return Dismissible(
      key: ValueKey(transaction.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) {
            final yuan = transaction.amountCny / 100;
            final amt = yuan == yuan.truncateToDouble()
                ? '${yuan.toInt()}'
                : yuan.toStringAsFixed(2);
            return AlertDialog(
              title: const Text('确定删除这笔交易？'),
              content: Text(
                  '${transaction.type == 'income' ? '收入' : '支出'} ¥$amt'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('删除'),
                ),
              ],
            );
          },
        ) ?? false;
      },
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: isDark ? const Color(0xFFB22222) : Colors.red,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text('删除', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            SizedBox(width: 24),
          ],
        ),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
        height: 72,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Category icon
              Container(
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
                      transaction.note.isNotEmpty
                          ? '$timeText · ${transaction.note}'
                          : timeText,
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
              Text(
                '$prefix¥$amountText',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: amountColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

// ── Empty state ──

class _EmptyState extends StatelessWidget {
  final bool isDark;

  const _EmptyState({required this.isDark});

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
