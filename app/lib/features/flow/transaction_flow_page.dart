import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/category_icon_widget.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/creator_name.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../data/local/database.dart';
import '../../domain/providers/transaction_flow_provider.dart';
import '../../domain/providers/transaction_provider.dart';
import '../transaction/transaction_detail_page.dart';
import 'widgets/date_header.dart';
import 'widgets/transaction_tile.dart';
import 'widgets/view_mode_bar.dart';

/// Net amount for a list of transactions (income positive, expense negative).
extension TransactionListX on Iterable<Transaction> {
  int get netAmount => fold<int>(
      0, (sum, t) => sum + (t.type == 'income' ? t.amount : -t.amount));
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

      // 搜索模式下结果来自 DB 全量查询（flowSearchResultsProvider），
      // 分页只是客户端 displayCount 截断，无需再去 DB 分页加载主列表。
      final flowState = ref.read(transactionFlowProvider);
      if (flowState.searchQuery.isNotEmpty) return;

      // 无搜索时：耗尽当前内存数据则从 DB 加载下一页。
      final txnState = ref.read(transactionProvider);
      if (txnState.hasMore && flowState.displayCount >= txnState.transactions.length) {
        ref.read(transactionProvider.notifier).loadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final txnState = ref.watch(transactionProvider);
    final flowState = ref.watch(transactionFlowProvider);
    final grouped = ref.watch(flowGroupedTransactionsProvider);
    final categoryMap = ref.watch(flowCategoryMapProvider);
    final accountMap = ref.watch(flowAccountMapProvider);
    final isSearching = flowState.searchQuery.isNotEmpty;
    final searchLoading = ref.watch(flowSearchLoadingProvider);
    final searchTruncated = ref.watch(flowSearchTruncatedProvider);

    return Scaffold(
      appBar: AppBar(
        title: flowState.showSearch ? _buildSearchField() : const Text('流水'),
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
          // 搜索结果被截断提示（review 🟡：避免静默丢弃较早记录）。
          if (isSearching && searchTruncated)
            _SearchTruncatedBanner(
              count: ref.watch(flowFilteredTransactionsProvider).length,
            ),
          Expanded(
            child: _buildBody(
              txnState: txnState,
              isSearching: isSearching,
              searchLoading: searchLoading,
              grouped: grouped,
              categoryMap: categoryMap,
              accountMap: accountMap,
              viewMode: flowState.viewMode,
            ),
          ),
        ],
      ),
    );
  }

  /// 主体区域：区分初始加载 / 搜索加载 / 空结果 / 列表几种状态。
  Widget _buildBody({
    required TransactionState txnState,
    required bool isSearching,
    required bool searchLoading,
    required GroupedTransactions grouped,
    required Map<String, Category> categoryMap,
    required Map<String, Account> accountMap,
    required FlowViewMode viewMode,
  }) {
    // 非搜索首次加载：骨架屏。
    if (!isSearching && txnState.isLoading) {
      return const SkeletonList(count: 8, itemHeight: 64);
    }
    // 搜索首次加载（还没结果）：显示加载指示，而不是一份不完整结果
    // （review #3：避免降级态误导用户“就这几条”）。
    if (isSearching && searchLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    // 空结果：区分“搜索无匹配”与“本来就没记账”。
    if (grouped.sortedKeys.isEmpty) {
      if (isSearching) {
        return const EmptyState(
          icon: Icons.search_off_outlined,
          title: '未找到匹配的记录',
          subtitle: '试试其他关键词',
        );
      }
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: '暂无交易记录',
        subtitle: '点击底部 ➕ 开始记账',
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(transactionProvider.notifier).reload();
      },
      child: _buildList(grouped, categoryMap, accountMap, viewMode),
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

    final txnState = ref.watch(transactionProvider);
    final flowState = ref.watch(transactionFlowProvider);
    // 搜索模式下结果已是 DB 全量，底部 spinner 取决于还有未显示的
    // 搜索结果（displayCount < 总数）；非搜索才看主列表 hasMore。
    final hasMore = flowState.searchQuery.isNotEmpty
        ? flowState.displayCount <
            ref.watch(flowFilteredTransactionsProvider).length
        : txnState.hasMore;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: SpacingTokens.xl4),
      itemCount: sortedKeys.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= sortedKeys.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final dateKey = sortedKeys[index];
        final items = groups[dateKey]!;
        final date = DateTime.parse(dateKey);
        final dayTotal = items.netAmount;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DateHeader(date: date, dayTotal: dayTotal),
            for (final (i, txn) in items.indexed)
              SlideInItem(
                index: i,
                child: TransactionTile(
                  transaction: txn,
                  category: categoryMap[txn.categoryId],
                  account: accountMap[txn.accountId],
                  creatorName: creatorDisplayName(ref, txn.userId, fallback: (_) => null),
                  onTap: () => _openDetail(txn, categoryMap[txn.categoryId]),
                ),
              ),
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
        final total = items.netAmount;

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
          children: [
            for (final (i, txn) in items.indexed)
              SlideInItem(
                index: i,
                child: TransactionTile(
                  transaction: txn,
                  category: categoryMap[txn.categoryId],
                  account: accountMap[txn.accountId],
                  creatorName: creatorDisplayName(ref, txn.userId, fallback: (_) => null),
                  onTap: () => _openDetail(txn, categoryMap[txn.categoryId]),
                ),
              ),
          ],
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
        final total = items.netAmount;

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
          children: [
            for (final (i, txn) in items.indexed)
              SlideInItem(
                index: i,
                child: TransactionTile(
                  transaction: txn,
                  category: categoryMap[txn.categoryId],
                  account: accountMap[txn.accountId],
                  creatorName: creatorDisplayName(ref, txn.userId, fallback: (_) => null),
                  onTap: () => _openDetail(txn, categoryMap[txn.categoryId]),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _categoryIcon(
    BuildContext context,
    String catName,
    Map<String, Category> catByName,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cat = catByName[catName];
    if (cat != null) {
      return CategoryIconWidget(iconKey: cat.iconKey, size: 36);
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: isDark
          ? NeutralColorsDark.neutral2
          : NeutralColorsLight.neutral2,
      child: const Icon(Icons.category_outlined, size: 18),
    );
  }

  void _openDetail(Transaction t, Category? cat) {
    context.push(
      AppRouter.transactionDetail,
      extra: TransactionDetailArgs(transaction: t, category: cat),
    );
  }
}

/// 搜索结果超过展示上限时的提示条。
class _SearchTruncatedBanner extends StatelessWidget {
  final int count;
  const _SearchTruncatedBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.secondaryContainer,
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.base,
        vertical: SpacingTokens.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              size: 16, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: SpacingTokens.sm),
          Expanded(
            child: Text(
              '匹配记录较多，仅显示最近 $count 条，请缩小关键词',
              style: TypographyTokens.bodySm(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
