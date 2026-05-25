import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/category_icon_widget.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../data/local/database.dart';
import '../../domain/providers/transaction_provider.dart';
import '../../domain/providers/account_provider.dart';
import '../transaction/transaction_detail_page.dart';

/// 流水视图模式。
enum FlowViewMode {
  /// 按时间分组。
  byTime,

  /// 按分类分组。
  byCategory,

  /// 按账户分组。
  byAccount,
}

/// 流水页 — Tab 级全量交易列表。
///
/// 支持三种视图切换（时间 / 分类 / 账户）和搜索筛选。
class TransactionFlowPage extends ConsumerStatefulWidget {
  const TransactionFlowPage({super.key});

  @override
  ConsumerState<TransactionFlowPage> createState() =>
      _TransactionFlowPageState();
}

class _TransactionFlowPageState extends ConsumerState<TransactionFlowPage> {
  static const _scrollThreshold = 200.0;
  static const _pageSize = 50;

  FlowViewMode _viewMode = FlowViewMode.byTime;
  int _displayCount = _pageSize;
  late final ScrollController _scrollController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showSearch = false;

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
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - _scrollThreshold) {
      final state = ref.read(transactionProvider);
      if (_displayCount < state.transactions.length) {
        setState(() => _displayCount += _pageSize);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(transactionProvider);

    // Build category map for display
    final categoryMap = <String, Category>{};
    for (final c in state.expenseCategories) {
      categoryMap[c.id] = c;
    }
    for (final c in state.incomeCategories) {
      categoryMap[c.id] = c;
    }

    // Build account map
    final accountState = ref.watch(accountProvider);
    final accountMap = <String, Account>{};
    for (final a in accountState.accounts) {
      accountMap[a.id] = a;
    }

    // Filter by search
    var transactions = state.transactions;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      transactions = transactions.where((t) {
        final cat = categoryMap[t.categoryId];
        final catName = cat?.name.toLowerCase() ?? '';
        final note = t.note.toLowerCase();
        final acct = accountMap[t.accountId]?.name.toLowerCase() ?? '';
        return catName.contains(q) || note.contains(q) || acct.contains(q);
      }).toList();
    }

    final visible = transactions.take(_displayCount).toList();

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? _buildSearchField()
            : const Text('流水'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // View mode tabs
          _ViewModeBar(
            current: _viewMode,
            onChanged: (mode) => setState(() => _viewMode = mode),
          ),
          // Content
          Expanded(
            child: state.isLoading
                ? const SkeletonList(count: 8, itemHeight: 64)
                : visible.isEmpty
                    ? const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: '暂无交易记录',
                        subtitle: '点击底部 ➕ 开始记账',
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          await ref
                              .read(transactionProvider.notifier)
                              .reload();
                        },
                        child: _buildList(
                          visible, categoryMap, accountMap, isDark),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      decoration: InputDecoration(
        hintText: '搜索分类、备注、账户…',
        border: InputBorder.none,
        hintStyle: TypographyTokens.bodyMd(
          color: Theme.of(context).brightness == Brightness.light
              ? NeutralColorsLight.neutral4
              : NeutralColorsDark.neutral4,
        ),
      ),
      style: TypographyTokens.bodyLg(),
      onChanged: (v) => setState(() => _searchQuery = v.trim()),
    );
  }

  Widget _buildList(
    List<Transaction> transactions,
    Map<String, Category> categoryMap,
    Map<String, Account> accountMap,
    bool isDark,
  ) {
    switch (_viewMode) {
      case FlowViewMode.byTime:
        return _buildByTimeList(transactions, categoryMap, accountMap, isDark);
      case FlowViewMode.byCategory:
        return _buildByCategoryList(
            transactions, categoryMap, accountMap, isDark);
      case FlowViewMode.byAccount:
        return _buildByAccountList(
            transactions, categoryMap, accountMap, isDark);
    }
  }

  // ─── By Time (default, grouped by date) ───

  Widget _buildByTimeList(
    List<Transaction> transactions,
    Map<String, Category> categoryMap,
    Map<String, Account> accountMap,
    bool isDark,
  ) {
    // Group by date
    final groups = <String, List<Transaction>>{};
    for (final t in transactions) {
      final key = DateFormat('yyyy-MM-dd').format(t.txnDate);
      groups.putIfAbsent(key, () => []).add(t);
    }
    final sortedKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: SpacingTokens.xl4),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final dateKey = sortedKeys[index];
        final items = groups[dateKey]!;
        final date = DateTime.parse(dateKey);
        final dayTotal = items.fold<int>(0, (sum, t) => sum + t.amount);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DateHeader(date: date, dayTotal: dayTotal, isDark: isDark),
            ...items.map((t) => _TransactionTile(
                  transaction: t,
                  category: categoryMap[t.categoryId],
                  account: accountMap[t.accountId],
                  isDark: isDark,
                  onTap: () => _openDetail(t, categoryMap[t.categoryId]),
                )),
          ],
        );
      },
    );
  }

  // ─── By Category ───

  Widget _buildByCategoryList(
    List<Transaction> transactions,
    Map<String, Category> categoryMap,
    Map<String, Account> accountMap,
    bool isDark,
  ) {
    // Build name→category lookup for O(1) icon resolution
    final catByName = <String, Category>{};
    for (final c in categoryMap.values) {
      catByName[c.name] = c;
    }

    // Group by category
    final groups = <String, List<Transaction>>{};
    for (final t in transactions) {
      final catName = categoryMap[t.categoryId]?.name ?? '未分类';
      groups.putIfAbsent(catName, () => []).add(t);
    }
    final sortedKeys = groups.keys.toList()
      ..sort((a, b) {
        final sumA = groups[a]!.fold<int>(0, (s, t) => s + t.amount.abs());
        final sumB = groups[b]!.fold<int>(0, (s, t) => s + t.amount.abs());
        return sumB.compareTo(sumA); // by total amount desc
      });

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: SpacingTokens.xl4),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final catName = sortedKeys[index];
        final items = groups[catName]!;
        final total = items.fold<int>(0, (s, t) => s + t.amount);

        return ExpansionTile(
          leading: _categoryIcon(catName, catByName, isDark),
          title: Text(catName, style: TypographyTokens.titleMd()),
          subtitle: Text(
            '${items.length} 笔  ${formatCents(total, showSign: true)}',
            style: TypographyTokens.bodySm(
              color: isDark
                  ? NeutralColorsDark.neutral5
                  : NeutralColorsLight.neutral5,
            ),
          ),
          children: items
              .map((t) => _TransactionTile(
                    transaction: t,
                    category: categoryMap[t.categoryId],
                    account: accountMap[t.accountId],
                    isDark: isDark,
                    onTap: () => _openDetail(t, categoryMap[t.categoryId]),
                  ))
              .toList(),
        );
      },
    );
  }

  // ─── By Account ───

  Widget _buildByAccountList(
    List<Transaction> transactions,
    Map<String, Category> categoryMap,
    Map<String, Account> accountMap,
    bool isDark,
  ) {
    // Group by account
    final groups = <String, List<Transaction>>{};
    for (final t in transactions) {
      final acctName = accountMap[t.accountId]?.name ?? '未知账户';
      groups.putIfAbsent(acctName, () => []).add(t);
    }
    final sortedKeys = groups.keys.toList()..sort();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: SpacingTokens.xl4),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final acctName = sortedKeys[index];
        final items = groups[acctName]!;
        final total = items.fold<int>(0, (s, t) => s + t.amount);

        return ExpansionTile(
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: isDark
                ? NeutralColorsDark.neutral2
                : NeutralColorsLight.neutral2,
            child: Text(
              acctName.isNotEmpty ? acctName.characters.first : '?',
              style: TypographyTokens.titleMd(),
            ),
          ),
          title: Text(acctName, style: TypographyTokens.titleMd()),
          subtitle: Text(
            '${items.length} 笔  ${formatCents(total, showSign: true)}',
            style: TypographyTokens.bodySm(
              color: isDark
                  ? NeutralColorsDark.neutral5
                  : NeutralColorsLight.neutral5,
            ),
          ),
          children: items
              .map((t) => _TransactionTile(
                    transaction: t,
                    category: categoryMap[t.categoryId],
                    account: accountMap[t.accountId],
                    isDark: isDark,
                    onTap: () => _openDetail(t, categoryMap[t.categoryId]),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _categoryIcon(
      String catName, Map<String, Category> catByName, bool isDark) {
    final cat = catByName[catName];
    if (cat != null) {
      return CategoryIconWidget(iconKey: cat.iconKey, size: 36);
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor:
          isDark ? NeutralColorsDark.neutral2 : NeutralColorsLight.neutral2,
      child: const Icon(Icons.category_outlined, size: 18),
    );
  }

  void _openDetail(Transaction t, Category? cat) {
    context.push(AppRouter.transactionDetail, extra: TransactionDetailArgs(
      transaction: t,
      category: cat,
    ));
  }

}

// ─── View Mode Bar ───

class _ViewModeBar extends StatelessWidget {
  static final _pillRadius = BorderRadius.circular(RadiusTokens.full);

  final FlowViewMode current;
  final ValueChanged<FlowViewMode> onChanged;

  const _ViewModeBar({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.base,
        vertical: SpacingTokens.sm,
      ),
      child: Row(
        children: FlowViewMode.values.map((mode) {
          final isSelected = mode == current;
          return Padding(
            padding: const EdgeInsets.only(right: SpacingTokens.sm),
            child: Material(
              color: Colors.transparent,
              borderRadius: _pillRadius,
              clipBehavior: Clip.antiAlias,
              child: Ink(
                decoration: BoxDecoration(
                  color: isSelected
                      ? ColorTokens.primaryLight
                      : (isDark
                          ? NeutralColorsDark.neutral2
                          : NeutralColorsLight.neutral2),
                  borderRadius: _pillRadius,
                ),
                child: InkWell(
                  borderRadius: _pillRadius,
                  onTap: () => onChanged(mode),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SpacingTokens.md,
                      vertical: SpacingTokens.sm,
                    ),
                    child: Text(
                      _modeLabel(mode),
                      style: TypographyTokens.bodySm(
                        color: isSelected
                            ? ColorTokens.primary
                            : (isDark
                                ? NeutralColorsDark.neutral5
                                : NeutralColorsLight.neutral5),
                      ).copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _modeLabel(FlowViewMode mode) {
    switch (mode) {
      case FlowViewMode.byTime:
        return '按时间';
      case FlowViewMode.byCategory:
        return '按分类';
      case FlowViewMode.byAccount:
        return '按账户';
    }
  }
}

// ─── Date Header ───

class _DateHeader extends StatelessWidget {
  final DateTime date;
  final int dayTotal;
  final bool isDark;

  const _DateHeader({
    required this.date,
    required this.dayTotal,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;

    String label;
    if (isToday) {
      label = '今天';
    } else if (isYesterday) {
      label = '昨天';
    } else if (date.year == now.year) {
      label = DateFormat('M月d日 E', 'zh_CN').format(date);
    } else {
      label = DateFormat('yyyy年M月d日').format(date);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpacingTokens.base, SpacingTokens.md, SpacingTokens.base, SpacingTokens.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TypographyTokens.bodySm(
              color: isDark
                  ? NeutralColorsDark.neutral5
                  : NeutralColorsLight.neutral5,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            formatCents(dayTotal, showSign: true),
            style: TypographyTokens.bodySm(
              color: dayTotal >= 0
                  ? (isDark
                      ? SemanticColorsDark.income
                      : SemanticColorsLight.income)
                  : (isDark
                      ? SemanticColorsDark.expense
                      : SemanticColorsLight.expense),
            ),
          ),
        ],
      ),
    );
  }

}

// ─── Transaction Tile ───

class _TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final Category? category;
  final Account? account;
  final bool isDark;
  final VoidCallback onTap;

  const _TransactionTile({
    required this.transaction,
    required this.category,
    required this.account,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.amount > 0;
    final amountColor = isIncome
        ? (isDark ? SemanticColorsDark.income : SemanticColorsLight.income)
        : (isDark ? SemanticColorsDark.expense : SemanticColorsLight.expense);

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.base,
      ),
      leading: category != null
          ? CategoryIconWidget(iconKey: category!.iconKey, size: 40)
          : CircleAvatar(
              radius: 20,
              backgroundColor: isDark
                  ? NeutralColorsDark.neutral2
                  : NeutralColorsLight.neutral2,
              child: const Icon(Icons.receipt_outlined, size: 20),
            ),
      title: Text(
        category?.name ?? '未分类',
        style: TypographyTokens.bodyMd(),
      ),
      subtitle: Text(
        [
          if (transaction.note.isNotEmpty)
            transaction.note,
          if (account != null) account!.name,
        ].join(' · '),
        style: TypographyTokens.caption(
          color: isDark
              ? NeutralColorsDark.neutral4
              : NeutralColorsLight.neutral4,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        formatCents(transaction.amount, showSign: true),
        style: TypographyTokens.amount(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: amountColor,
        ),
      ),
    );
  }

}
