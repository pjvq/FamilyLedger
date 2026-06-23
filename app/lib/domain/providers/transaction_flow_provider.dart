import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/local/database.dart';
import 'app_providers.dart';
import 'transaction_provider.dart';
import 'account_provider.dart';

// ─── View Mode ─────────────────────────────────────────────────────────────

/// 流水视图模式。
enum FlowViewMode {
  /// 按时间分组。
  byTime,

  /// 按分类分组。
  byCategory,

  /// 按账户分组。
  byAccount,
}

// ─── State ─────────────────────────────────────────────────────────────────

class TransactionFlowState {
  final FlowViewMode viewMode;
  final String searchQuery;
  final int displayCount;
  final bool showSearch;

  const TransactionFlowState({
    this.viewMode = FlowViewMode.byTime,
    this.searchQuery = '',
    this.displayCount = 50,
    this.showSearch = false,
  });

  TransactionFlowState copyWith({
    FlowViewMode? viewMode,
    String? searchQuery,
    int? displayCount,
    bool? showSearch,
  }) {
    return TransactionFlowState(
      viewMode: viewMode ?? this.viewMode,
      searchQuery: searchQuery ?? this.searchQuery,
      displayCount: displayCount ?? this.displayCount,
      showSearch: showSearch ?? this.showSearch,
    );
  }
}

// ─── Grouped Data ──────────────────────────────────────────────────────────

class GroupedTransactions {
  final Map<String, List<Transaction>> groups;
  final List<String> sortedKeys;

  const GroupedTransactions({
    this.groups = const {},
    this.sortedKeys = const [],
  });
}

// ─── Notifier ──────────────────────────────────────────────────────────────

class TransactionFlowNotifier extends StateNotifier<TransactionFlowState> {
  /// Initial page size — balances smooth scrolling with memory usage.
  /// 50 items ≈ 3-4 screens on standard devices.
  static const _pageSize = 50;

  TransactionFlowNotifier() : super(const TransactionFlowState());

  void setViewMode(FlowViewMode mode) {
    state = state.copyWith(viewMode: mode);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query, displayCount: _pageSize);
  }

  void toggleSearch() {
    final newShow = !state.showSearch;
    state = state.copyWith(
      showSearch: newShow,
      searchQuery: newShow ? state.searchQuery : '',
      displayCount: _pageSize,
    );
  }

  void loadMore(int totalCount) {
    if (state.displayCount < totalCount) {
      state = state.copyWith(displayCount: state.displayCount + _pageSize);
    }
  }

  void resetPagination() {
    state = state.copyWith(displayCount: _pageSize);
  }
}

// ─── Providers ─────────────────────────────────────────────────────────────

final transactionFlowProvider =
    StateNotifierProvider<TransactionFlowNotifier, TransactionFlowState>(
      (ref) => TransactionFlowNotifier(),
    );

/// Category map built from transaction state.
final flowCategoryMapProvider = Provider<Map<String, Category>>((ref) {
  final state = ref.watch(transactionProvider);
  final map = <String, Category>{};
  for (final c in state.expenseCategories) {
    map[c.id] = c;
  }
  for (final c in state.incomeCategories) {
    map[c.id] = c;
  }
  return map;
});

/// Reverse index: category name → Category (for icon lookup in category view).
final flowCategoryByNameProvider = Provider<Map<String, Category>>((ref) {
  final categoryMap = ref.watch(flowCategoryMapProvider);
  final byName = <String, Category>{};
  for (final c in categoryMap.values) {
    byName[c.name] = c;
  }
  return byName;
});

/// Account map built from account state.
final flowAccountMapProvider = Provider<Map<String, Account>>((ref) {
  final accountState = ref.watch(accountProvider);
  final map = <String, Account>{};
  for (final a in accountState.accounts) {
    map[a.id] = a;
  }
  return map;
});

/// 全量搜索结果（直接查 DB，不受流水页分页加载影响）。
///
/// 修复：右上角搜索原本只对已加载进内存的分页数据做过滤，未加载
/// 的记录搜不到。现在改为查 DB 全量。query 为空时返回空结果。
final flowSearchResultsProvider = FutureProvider<TransactionSearchResult>((
  ref,
) async {
  final query = ref.watch(transactionFlowProvider).searchQuery;
  if (query.isEmpty) {
    return const TransactionSearchResult(items: [], truncated: false);
  }
  final repo = ref.watch(transactionRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);
  final familyId = ref.watch(currentFamilyIdProvider);
  if (userId == null || userId.isEmpty) {
    return const TransactionSearchResult(items: [], truncated: false);
  }
  return repo.search(userId, query, familyId: familyId);
});

/// 搜索是否正在加载（且尚无可用结果）——用于页面显示加载指示而
/// 不是一份不完整的内存过滤结果（review #3：避免降级态误导用户）。
final flowSearchLoadingProvider = Provider<bool>((ref) {
  final flowState = ref.watch(transactionFlowProvider);
  if (flowState.searchQuery.isEmpty) return false;
  final searchAsync = ref.watch(flowSearchResultsProvider);
  // 首次加载（还没有任何结果）时才算 loading；重查期间保留旧结果不闪动。
  return searchAsync.isLoading && !searchAsync.hasValue;
});

/// 搜索结果是否被截断（超过展示上限）——用于 UI 提示“仅显示前 N 条”。
final flowSearchTruncatedProvider = Provider<bool>((ref) {
  final flowState = ref.watch(transactionFlowProvider);
  if (flowState.searchQuery.isEmpty) return false;
  return ref.watch(flowSearchResultsProvider).valueOrNull?.truncated ?? false;
});

/// Filtered transactions based on search query.
///
/// - 无搜索词：返回流水页分页加载的内存列表（保持原有无限滚动行为）。
/// - 有搜索词：使用 [flowSearchResultsProvider] 的 DB 全量结果。
///   首次加载中（还没结果）返回空列表，页面依 [flowSearchLoadingProvider]
///   显示加载指示；不再回退到“仅覆盖已加载分页”的不完整内存过滤
///   （那样会重现本 PR 要修的老行为，review #3）。
final flowFilteredTransactionsProvider = Provider<List<Transaction>>((ref) {
  final txnState = ref.watch(transactionProvider);
  final flowState = ref.watch(transactionFlowProvider);

  final query = flowState.searchQuery;
  if (query.isEmpty) return txnState.transactions;

  // 有结果（含重查期间保留的旧结果）则用全量 DB 结果；
  // 首次加载中返回空（页面显示 loading），不给不完整的内存过滤结果。
  return ref.watch(flowSearchResultsProvider).valueOrNull?.items ?? const [];
});

/// Visible (paginated) transactions.
final flowVisibleTransactionsProvider = Provider<List<Transaction>>((ref) {
  final filtered = ref.watch(flowFilteredTransactionsProvider);
  final flowState = ref.watch(transactionFlowProvider);
  return filtered.take(flowState.displayCount).toList();
});

/// Grouped transactions based on current view mode.
final flowGroupedTransactionsProvider = Provider<GroupedTransactions>((ref) {
  final visible = ref.watch(flowVisibleTransactionsProvider);
  final flowState = ref.watch(transactionFlowProvider);
  final categoryMap = ref.watch(flowCategoryMapProvider);
  final accountMap = ref.watch(flowAccountMapProvider);

  switch (flowState.viewMode) {
    case FlowViewMode.byTime:
      return _groupByTime(visible);
    case FlowViewMode.byCategory:
      return _groupByCategory(visible, categoryMap);
    case FlowViewMode.byAccount:
      return _groupByAccount(visible, accountMap);
  }
});

// ─── Grouping Logic ────────────────────────────────────────────────────────

GroupedTransactions _groupByTime(List<Transaction> transactions) {
  final groups = <String, List<Transaction>>{};
  for (final t in transactions) {
    final key = DateFormat('yyyy-MM-dd').format(t.txnDate);
    groups.putIfAbsent(key, () => []).add(t);
  }
  final sortedKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));
  return GroupedTransactions(groups: groups, sortedKeys: sortedKeys);
}

GroupedTransactions _groupByCategory(
  List<Transaction> transactions,
  Map<String, Category> categoryMap,
) {
  final groups = <String, List<Transaction>>{};
  for (final t in transactions) {
    final catName = categoryMap[t.categoryId]?.name ?? '未分类';
    groups.putIfAbsent(catName, () => []).add(t);
  }
  // Pre-compute sums for O(k log k) sort instead of O(k * n * log k)
  final sums = <String, int>{};
  for (final entry in groups.entries) {
    sums[entry.key] = entry.value.fold<int>(0, (s, t) => s + t.amount.abs());
  }
  final sortedKeys = groups.keys.toList()
    ..sort((a, b) => sums[b]!.compareTo(sums[a]!));
  return GroupedTransactions(groups: groups, sortedKeys: sortedKeys);
}

GroupedTransactions _groupByAccount(
  List<Transaction> transactions,
  Map<String, Account> accountMap,
) {
  final groups = <String, List<Transaction>>{};
  for (final t in transactions) {
    final acctName = accountMap[t.accountId]?.name ?? '未知账户';
    groups.putIfAbsent(acctName, () => []).add(t);
  }
  final sortedKeys = groups.keys.toList()..sort();
  return GroupedTransactions(groups: groups, sortedKeys: sortedKeys);
}
