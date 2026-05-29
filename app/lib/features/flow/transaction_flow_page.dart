import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/category_icon_widget.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../data/local/database.dart';
import '../../domain/providers/transaction_flow_provider.dart';
import '../../domain/providers/transaction_provider.dart';
import '../transaction/transaction_detail_page.dart';
import 'widgets/date_header.dart';
import 'widgets/transaction_tile.dart';
import 'widgets/view_mode_bar.dart';

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

  late final ScrollController _scrollController;
  final TextEditingController _searchController = TextEditingController();

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
      final filtered = ref.read(flowFilteredTransactionsProvider);
      ref.read(transactionFlowProvider.notifier).loadMore(filtered.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final txnState = ref.watch(transactionProvider);
    final flowState = ref.watch(transactionFlowProvider);
    final grouped = ref.watch(flowGroupedTransactionsProvider);
    final categoryMap = ref.watch(flowCategoryMapProvider);
    final accountMap = ref.watch(flowAccountMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: flowState.showSearch
            ? _buildSearchField()
            : const Text('流水'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(flowState.showSearch ? Icons.close : Icons.search),
            onPressed: () {
              final wasSearching = flowState.showSearch;
              ref.read(transactionFlowProvider.notifier).toggleSearch();
              if (wasSearching) {
                _searchController.clear();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          ViewModeBar(
            current: flowState.viewMode,
            onChanged: (mode) =>
                ref.read(transactionFlowProvider.notifier).setViewMode(mode),
          ),
          Expanded(
            child: txnState.isLoading
                ? const SkeletonList(count: 8, itemHeight: 64)
                : grouped.sortedKeys.isEmpty
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
                          grouped, categoryMap, accountMap,
                          flowState.viewMode),
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
      onChanged: (v) =>
          ref.read(transactionFlowProvider.notifier).setSearchQuery(v.trim()),
    );
  }

  Widget _buildList(
    GroupedTransactions grouped,
    Map<String, Category> categoryMap,
    Map<String, Account> accountMap,
    FlowViewMode viewMode,
  ) {
    switch (viewMode) {
      case FlowViewMode.byTime:
        return _buildByTimeList(grouped, categoryMap, accountMap);
      case FlowViewMode.byCategory:
        return _buildByCategoryList(grouped, categoryMap, accountMap);
      case FlowViewMode.byAccount:
        return _buildByAccountList(grouped, categoryMap, accountMap);
    }
  }

  // ─── By Time (default, grouped by date) ───

  Widget _buildByTimeList(
    GroupedTransactions grouped,
    Map<String, Category> categoryMap,
    Map<String, Account> accountMap,
  ) {
    final groups = grouped.groups;
    final sortedKeys = grouped.sortedKeys;

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
            DateHeader(date: date, dayTotal: dayTotal),
            ...items.asMap().entries.map((e) => SlideInItem(
                  index: e.key,
                  child: TransactionTile(
                    transaction: e.value,
                    category: categoryMap[e.value.categoryId],
                    account: accountMap[e.value.accountId],
                    onTap: () => _openDetail(e.value, categoryMap[e.value.categoryId]),
                  ),
                )),
          ],
        );
      },
    );
  }

  // ─── By Category ───

  Widget _buildByCategoryList(
    GroupedTransactions grouped,
    Map<String, Category> categoryMap,
    Map<String, Account> accountMap,
  ) {
    final catByName = ref.watch(flowCategoryByNameProvider);

    final groups = grouped.groups;
    final sortedKeys = grouped.sortedKeys;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: SpacingTokens.xl4),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final catName = sortedKeys[index];
        final items = groups[catName]!;
        final total = items.fold<int>(0, (s, t) => s + t.amount);

        return ExpansionTile(
          leading: _categoryIcon(context, catName, catByName),
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
              .asMap().entries.map((e) => SlideInItem(index: e.key, child: TransactionTile(
                    transaction: e.value,
                    category: categoryMap[e.value.categoryId],
                    account: accountMap[e.value.accountId],
                    onTap: () => _openDetail(e.value, categoryMap[e.value.categoryId]),
                  )))
              .toList(),
        );
      },
    );
  }

  // ─── By Account ───

  Widget _buildByAccountList(
    GroupedTransactions grouped,
    Map<String, Category> categoryMap,
    Map<String, Account> accountMap,
  ) {
    final groups = grouped.groups;
    final sortedKeys = grouped.sortedKeys;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: SpacingTokens.xl4),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
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
              .asMap().entries.map((e) => SlideInItem(index: e.key, child: TransactionTile(
                    transaction: e.value,
                    category: categoryMap[e.value.categoryId],
                    account: accountMap[e.value.accountId],
                    onTap: () => _openDetail(e.value, categoryMap[e.value.categoryId]),
                  )))
              .toList(),
        );
      },
    );
  }

  Widget _categoryIcon(
      BuildContext context, String catName, Map<String, Category> catByName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
