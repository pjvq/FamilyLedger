import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/local/database.dart';
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

/// Account map built from account state.
final flowAccountMapProvider = Provider<Map<String, Account>>((ref) {
  final accountState = ref.watch(accountProvider);
  final map = <String, Account>{};
  for (final a in accountState.accounts) {
    map[a.id] = a;
  }
  return map;
});

/// Filtered transactions based on search query.
final flowFilteredTransactionsProvider = Provider<List<Transaction>>((ref) {
  final txnState = ref.watch(transactionProvider);
  final flowState = ref.watch(transactionFlowProvider);
  final categoryMap = ref.watch(flowCategoryMapProvider);
  final accountMap = ref.watch(flowAccountMapProvider);

  final txnList = txnState.transactions;
  final query = flowState.searchQuery;

  if (query.isEmpty) return txnList;

  final q = query.toLowerCase();
  return txnList.where((t) {
    final cat = categoryMap[t.categoryId];
    final catName = cat?.name.toLowerCase() ?? '';
    final note = t.note.toLowerCase();
    final acct = accountMap[t.accountId]?.name.toLowerCase() ?? '';
    return catName.contains(q) || note.contains(q) || acct.contains(q);
  }).toList();
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
  final sortedKeys = groups.keys.toList()
    ..sort((a, b) {
      final sumA = groups[a]!.fold<int>(0, (s, t) => s + t.amount.abs());
      final sumB = groups[b]!.fold<int>(0, (s, t) => s + t.amount.abs());
      return sumB.compareTo(sumA);
    });
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
