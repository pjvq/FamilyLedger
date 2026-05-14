import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:grpc/grpc.dart';
import '../../data/local/database.dart' as db;
import '../../data/remote/grpc_clients.dart';
import '../../generated/proto/dashboard.pb.dart' as pb;
import '../../generated/proto/dashboard.pbgrpc.dart';
import '../../generated/proto/investment.pb.dart' as inv_pb;
import '../../generated/proto/investment.pbgrpc.dart';
import 'app_providers.dart';

// ── Display models ──

class NetWorthData {
  final int total; // 分
  final int cashAndBank;
  final int investmentValue;
  final int fixedAssetValue;
  final int loanBalance; // 负数
  final int changeFromLastMonth;
  final double changePercent;
  final List<AssetCompositionItem> composition;

  const NetWorthData({
    this.total = 0,
    this.cashAndBank = 0,
    this.investmentValue = 0,
    this.fixedAssetValue = 0,
    this.loanBalance = 0,
    this.changeFromLastMonth = 0,
    this.changePercent = 0.0,
    this.composition = const [],
  });
}

class AssetCompositionItem {
  final String category;
  final String label;
  final int value;
  final double weight;

  const AssetCompositionItem({
    required this.category,
    required this.label,
    required this.value,
    required this.weight,
  });
}

class TrendPointData {
  final String label;
  final int income;
  final int expense;
  final int net;

  const TrendPointData({
    required this.label,
    required this.income,
    required this.expense,
    required this.net,
  });
}

class CategoryBreakdownItem {
  final String categoryId;
  final String categoryName;
  final String iconKey;
  final int amount;
  final double weight;
  final List<CategoryBreakdownItem> children;

  const CategoryBreakdownItem({
    required this.categoryId,
    required this.categoryName,
    this.iconKey = '',
    required this.amount,
    required this.weight,
    this.children = const [],
  });
}

class BudgetSummaryData {
  final int totalBudget;
  final int totalSpent;
  final double executionRate;

  const BudgetSummaryData({
    this.totalBudget = 0,
    this.totalSpent = 0,
    this.executionRate = 0.0,
  });
}

// ── State ──

class DashboardState {
  final NetWorthData netWorth;
  final List<TrendPointData> incomeExpenseTrend;
  final List<CategoryBreakdownItem> categoryBreakdown;
  final int categoryBreakdownTotal;
  final BudgetSummaryData budgetSummary;
  final List<TrendPointData> netWorthTrend;
  final List<TrendPointData> investmentTrend;
  final bool isLoading;
  final String? error;
  final String trendPeriod; // 'monthly' | 'yearly'
  final String categoryBreakdownPeriod; // 'monthly' | 'yearly'
  final String netWorthTrendPeriod; // 'monthly' | 'yearly'

  const DashboardState({
    this.netWorth = const NetWorthData(),
    this.incomeExpenseTrend = const [],
    this.categoryBreakdown = const [],
    this.categoryBreakdownTotal = 0,
    this.budgetSummary = const BudgetSummaryData(),
    this.netWorthTrend = const [],
    this.investmentTrend = const [],
    this.isLoading = false,
    this.error,
    this.trendPeriod = 'monthly',
    this.categoryBreakdownPeriod = 'monthly',
    this.netWorthTrendPeriod = 'monthly',
  });

  DashboardState copyWith({
    NetWorthData? netWorth,
    List<TrendPointData>? incomeExpenseTrend,
    List<CategoryBreakdownItem>? categoryBreakdown,
    int? categoryBreakdownTotal,
    BudgetSummaryData? budgetSummary,
    List<TrendPointData>? netWorthTrend,
    List<TrendPointData>? investmentTrend,
    bool? isLoading,
    String? error,
    String? trendPeriod,
    String? categoryBreakdownPeriod,
    String? netWorthTrendPeriod,
    bool clearError = false,
  }) =>
      DashboardState(
        netWorth: netWorth ?? this.netWorth,
        incomeExpenseTrend: incomeExpenseTrend ?? this.incomeExpenseTrend,
        categoryBreakdown: categoryBreakdown ?? this.categoryBreakdown,
        categoryBreakdownTotal:
            categoryBreakdownTotal ?? this.categoryBreakdownTotal,
        budgetSummary: budgetSummary ?? this.budgetSummary,
        netWorthTrend: netWorthTrend ?? this.netWorthTrend,
        investmentTrend: investmentTrend ?? this.investmentTrend,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        trendPeriod: trendPeriod ?? this.trendPeriod,
        categoryBreakdownPeriod:
            categoryBreakdownPeriod ?? this.categoryBreakdownPeriod,
        netWorthTrendPeriod:
            netWorthTrendPeriod ?? this.netWorthTrendPeriod,
      );
}

// ── Notifier ──

class DashboardNotifier extends StateNotifier<DashboardState> {
  final db.AppDatabase _db;
  final DashboardServiceClient _client;
  final MarketDataServiceClient _marketClient;
  final String? _userId;
  final String? _familyId;

  DashboardNotifier(this._db, this._client, this._marketClient, this._userId, this._familyId)
      : super(const DashboardState()) {
    if (_userId != null) {
      loadAll();
    }
  }

  /// gRPC call timeout — fail fast to local fallback
  static const _grpcTimeout = Duration(seconds: 3);

  CallOptions get _callOpts => CallOptions(timeout: _grpcTimeout);

  /// Refresh market quotes for investments so local net worth calc has prices.
  Future<void> _refreshInvestmentQuotes(List<db.Investment> investments) async {
    try {
      final requests = investments.map((inv) => inv_pb.GetQuoteRequest()
        ..symbol = inv.symbol
        ..marketType = _toProtoMarketType(inv.marketType));
      final resp = await _marketClient.batchGetQuotes(
        inv_pb.BatchGetQuotesRequest()..requests.addAll(requests),
        options: _callOpts,
      );
      for (final q in resp.quotes) {
        final mt = _fromProtoMarketType(q.marketType);
        await _db.upsertMarketQuote(db.MarketQuotesCompanion.insert(
          symbol: q.symbol,
          marketType: mt,
          name: Value(q.name),
          currentPrice: Value(q.currentPrice.toInt()),
          changeAmount: Value(q.change.toInt()),
          changePercent: Value(q.changePercent),
          updatedAt: Value(DateTime.now()),
        ));
      }
    } catch (e) {
      // Offline: local cache will be used as-is
    }
  }

  static const _toProtoMap = <String, inv_pb.MarketType>{
    'a_share': inv_pb.MarketType.MARKET_TYPE_A_SHARE,
    'hk_stock': inv_pb.MarketType.MARKET_TYPE_HK_STOCK,
    'us_stock': inv_pb.MarketType.MARKET_TYPE_US_STOCK,
    'crypto': inv_pb.MarketType.MARKET_TYPE_CRYPTO,
    'fund': inv_pb.MarketType.MARKET_TYPE_FUND,
    'precious_metal': inv_pb.MarketType.MARKET_TYPE_PRECIOUS_METAL,
  };

  static const _fromProtoMap = <inv_pb.MarketType, String>{
    inv_pb.MarketType.MARKET_TYPE_A_SHARE: 'a_share',
    inv_pb.MarketType.MARKET_TYPE_HK_STOCK: 'hk_stock',
    inv_pb.MarketType.MARKET_TYPE_US_STOCK: 'us_stock',
    inv_pb.MarketType.MARKET_TYPE_CRYPTO: 'crypto',
    inv_pb.MarketType.MARKET_TYPE_FUND: 'fund',
    inv_pb.MarketType.MARKET_TYPE_PRECIOUS_METAL: 'precious_metal',
  };

  static inv_pb.MarketType _toProtoMarketType(String type) =>
      _toProtoMap[type] ?? inv_pb.MarketType.MARKET_TYPE_A_SHARE;

  static String _fromProtoMarketType(inv_pb.MarketType type) =>
      _fromProtoMap[type] ?? 'a_share';

  /// Load all dashboard data: local-first, then background refresh via gRPC.
  Future<void> loadAll() async {
    if (_userId == null) return;
    state = state.copyWith(isLoading: true, clearError: true);

    // Phase 1: instant local data (milliseconds)
    await Future.wait([
      _computeLocalNetWorth(),
      _computeLocalTrend('monthly', 6),
      _computeLocalCategoryBreakdown(
          DateTime.now().year, DateTime.now().month),
      _computeLocalBudgetSummary(),
    ]);
    state = state.copyWith(isLoading: false);

    // Phase 2: background gRPC refresh (non-blocking)
    unawaited(Future.wait([
      _refreshNetWorthRemote(),
      _refreshTrendRemote('monthly', 6),
      _refreshCategoryBreakdownRemote(
          DateTime.now().year, DateTime.now().month, 'expense'),
      _refreshBudgetSummaryRemote(),
      _refreshNetWorthTrendRemote(12, 'monthly'),
    ]));
  }

  /// Public refresh: local first, then remote.
  Future<void> refreshNetWorth() async {
    await _computeLocalNetWorth();
    await _refreshNetWorthRemote();
  }

  /// gRPC refresh — silent, merges with local state.
  Future<void> _refreshNetWorthRemote() async {
    if (_userId == null) return;
    try {
      final resp = await _client.getNetWorth(
        pb.GetNetWorthRequest()..familyId = _familyId ?? '',
        options: _callOpts,
      );
      final local = state.netWorth;
      // Merge: prefer remote value, but keep local investment value only when
      // remote returns 0 AND local DB still has active investments (not cleared).
      // This prevents stale values when user truly liquidates all positions.
      int investmentValue = resp.investmentValue.toInt();
      if (investmentValue == 0 && local.investmentValue != 0) {
        final investments = await _db.getInvestments(_userId, familyId: _familyId);
        if (investments.isNotEmpty) {
          // Still have holdings → server likely missing market data
          investmentValue = local.investmentValue;
        }
      }
      final cashAndBank = resp.cashAndBank.toInt();
      final fixedAssetValue = resp.fixedAssetValue.toInt();
      final loanBalance = resp.loanBalance.toInt();
      final total = cashAndBank + investmentValue + fixedAssetValue + loanBalance;

      state = state.copyWith(
        netWorth: NetWorthData(
          total: total,
          cashAndBank: cashAndBank,
          investmentValue: investmentValue,
          fixedAssetValue: fixedAssetValue,
          loanBalance: loanBalance,
          changeFromLastMonth: resp.changeFromLastMonth.toInt(),
          changePercent: resp.changePercent,
          composition: resp.composition
              .map((c) {
                if (c.category == 'investment' && c.value.toInt() == 0 && investmentValue != 0) {
                  return AssetCompositionItem(
                    category: c.category,
                    label: c.label,
                    value: investmentValue,
                    weight: c.weight,
                  );
                }
                return AssetCompositionItem(
                  category: c.category,
                  label: c.label,
                  value: c.value.toInt(),
                  weight: c.weight,
                );
              })
              .toList(),
        ),
      );
    } catch (_) {
      // Local data already displayed, silently ignore remote failure
    }
  }

  /// Compute net worth from local data
  Future<void> _computeLocalNetWorth() async {
    if (_userId == null) return;

    // Cash & bank = sum of account balances
    final List<db.Account> accounts;
    if (_familyId != null && _familyId.isNotEmpty) {
      accounts = await _db.getAccountsByFamily(_familyId);
    } else {
      accounts = await _db.getActiveAccounts(_userId);
    }
    final cashAndBank =
        accounts.fold<int>(0, (sum, a) => sum + a.balance);

    // Investment value — refresh quotes first so we have current prices
    final investments = await _db.getInvestments(_userId, familyId: _familyId);
    if (investments.isNotEmpty) {
      await _refreshInvestmentQuotes(investments);
    }
    int investmentValue = 0;
    for (final inv in investments) {
      final quote = await _db.getMarketQuote(inv.symbol, inv.marketType);
      final price = quote?.currentPrice ?? 0;
      // Fallback: if no market price, use cost basis as estimated value
      final value = price > 0
          ? (inv.quantity * price).round()
          : inv.costBasis;
      investmentValue += value;
    }

    // Fixed asset value
    final assets = await _db.getFixedAssets(_userId, familyId: _familyId);
    final fixedAssetValue =
        assets.fold<int>(0, (sum, a) => sum + a.currentValue);

    // Loan balance (negative)
    final loans = await _db.getLoans(_userId, familyId: _familyId);
    final loanBalance =
        -loans.fold<int>(0, (sum, l) => sum + l.remainingPrincipal);

    final total = cashAndBank + investmentValue + fixedAssetValue + loanBalance;

    // Build composition
    final totalAbs = cashAndBank.abs() +
        investmentValue.abs() +
        fixedAssetValue.abs() +
        loanBalance.abs();
    double w(int v) => totalAbs > 0 ? v.abs() / totalAbs : 0.0;

    state = state.copyWith(
      netWorth: NetWorthData(
        total: total,
        cashAndBank: cashAndBank,
        investmentValue: investmentValue,
        fixedAssetValue: fixedAssetValue,
        loanBalance: loanBalance,
        changeFromLastMonth: 0, // Can't compute without history
        changePercent: 0.0,
        composition: [
          AssetCompositionItem(
              category: 'cash', label: '现金银行', value: cashAndBank, weight: w(cashAndBank)),
          AssetCompositionItem(
              category: 'investment', label: '投资', value: investmentValue, weight: w(investmentValue)),
          AssetCompositionItem(
              category: 'fixed_asset', label: '固定资产', value: fixedAssetValue, weight: w(fixedAssetValue)),
          AssetCompositionItem(
              category: 'loan', label: '贷款', value: loanBalance, weight: w(loanBalance)),
        ],
      ),
    );
  }

  /// Public: load trend local-first, then remote.
  Future<void> loadTrend(String period, int count) async {
    if (_userId == null) return;
    state = state.copyWith(trendPeriod: period);
    await _computeLocalTrend(period, count);
    await _refreshTrendRemote(period, count);
  }

  Future<void> _refreshTrendRemote(String period, int count) async {
    if (_userId == null) return;
    try {
      final resp = await _client.getIncomeExpenseTrend(
        pb.TrendRequest()
          ..userId = _userId
          ..familyId = _familyId ?? ''
          ..period = period
          ..count = count,
        options: _callOpts,
      );
      // Always use gRPC response (server properly filters by familyId)
      state = state.copyWith(
        incomeExpenseTrend: resp.points
            .map((p) => TrendPointData(
                  label: p.label,
                  income: p.income.toInt(),
                  expense: p.expense.toInt(),
                  net: p.net.toInt(),
                ))
            .toList(),
      );
    } catch (_) {}
  }

  Future<void> _computeLocalTrend(String period, int count) async {
    if (_userId == null) return;

    final now = DateTime.now();
    final points = <TrendPointData>[];
    final allTxns = await _db.getRecentTransactions(_userId, 10000,
        familyId: _familyId);

    for (int i = count - 1; i >= 0; i--) {
      DateTime start;
      DateTime end;
      String label;

      if (period == 'yearly') {
        final year = now.year - i;
        start = DateTime(year, 1, 1);
        end = DateTime(year + 1, 1, 1).subtract(const Duration(milliseconds: 1));
        label = '$year';
      } else {
        final month = DateTime(now.year, now.month - i, 1);
        start = month;
        end = DateTime(month.year, month.month + 1, 1)
            .subtract(const Duration(milliseconds: 1));
        label =
            '${month.year}-${month.month.toString().padLeft(2, '0')}';
      }

      final filtered = allTxns.where(
          (t) => !t.txnDate.isBefore(start) && !t.txnDate.isAfter(end));

      int income = 0, expense = 0;
      for (final t in filtered) {
        if (t.type == 'income') {
          income += t.amountCny;
        } else {
          expense += t.amountCny;
        }
      }

      points.add(TrendPointData(
        label: label,
        income: income,
        expense: expense,
        net: income - expense,
      ));
    }

    state = state.copyWith(incomeExpenseTrend: points);
  }

  /// Public: load category breakdown local-first, then remote.
  Future<void> loadCategoryBreakdown(int year, int month, String type) async {
    if (_userId == null) return;
    await _computeLocalCategoryBreakdown(year, month);
    await _refreshCategoryBreakdownRemote(year, month, type);
  }

  /// Load category breakdown with period toggle (monthly/yearly).
  Future<void> loadCategoryBreakdownByPeriod(String period) async {
    if (_userId == null) return;
    final now = DateTime.now();
    state = state.copyWith(categoryBreakdownPeriod: period);
    if (period == 'yearly') {
      await _computeLocalCategoryBreakdownYear(now.year);
    } else {
      await _computeLocalCategoryBreakdown(now.year, now.month);
    }
  }

  Future<void> _refreshCategoryBreakdownRemote(
      int year, int month, String type) async {
    if (_userId == null) return;
    try {
      final resp = await _client.getCategoryBreakdown(
        pb.CategoryBreakdownRequest()
          ..userId = _userId
          ..familyId = _familyId ?? ''
          ..year = year
          ..month = month
          ..type = type,
        options: _callOpts,
      );
      // Always use gRPC response (server properly filters by familyId)
      state = state.copyWith(
        categoryBreakdown: resp.items
            .map((c) => CategoryBreakdownItem(
                  categoryId: c.categoryId,
                  categoryName: c.categoryName,
                  iconKey: c.iconKey,
                  amount: c.amount.toInt(),
                  weight: c.weight,
                  children: c.children
                      .map((ch) => CategoryBreakdownItem(
                            categoryId: ch.categoryId,
                            categoryName: ch.categoryName,
                            iconKey: ch.iconKey,
                            amount: ch.amount.toInt(),
                            weight: ch.weight,
                          ))
                      .toList(),
                ))
            .toList(),
        categoryBreakdownTotal: resp.total.toInt(),
      );
    } catch (_) {}
  }

  Future<void> _computeLocalCategoryBreakdown(int year, int month) async {
    if (_userId == null) return;
    final expenses = await _db.getMonthCategoryExpenses(_userId, year, month,
        familyId: _familyId);
    await _aggregateCategoryBreakdown(expenses);
  }

  Future<void> _computeLocalCategoryBreakdownYear(int year) async {
    if (_userId == null) return;
    final expenses = await _db.getYearCategoryExpenses(_userId, year,
        familyId: _familyId);
    await _aggregateCategoryBreakdown(expenses);
  }

  Future<void> _aggregateCategoryBreakdown(Map<String, int> expenses) async {
    final categories = await _db.getAllCategories();
    final catMap = {for (final c in categories) c.id: c};

    // Aggregate subcategory amounts into parent categories
    final parentAmounts = <String, int>{};
    final childrenMap = <String, List<CategoryBreakdownItem>>{};
    final topLevelDirect = <String, int>{};

    for (final entry in expenses.entries) {
      final cat = catMap[entry.key];
      final parentId = cat?.parentId;
      if (parentId != null && parentId.isNotEmpty) {
        // Subcategory: aggregate to parent
        parentAmounts[parentId] = (parentAmounts[parentId] ?? 0) + entry.value;
        childrenMap.putIfAbsent(parentId, () => []);
        childrenMap[parentId]!.add(CategoryBreakdownItem(
          categoryId: entry.key,
          categoryName: cat?.name ?? '未知',
          iconKey: cat?.iconKey ?? '',
          amount: entry.value,
          weight: 0, // computed later
        ));
      } else {
        // Top-level category
        topLevelDirect[entry.key] = entry.value;
      }
    }

    // Build top-level items
    final allTopIds = {...topLevelDirect.keys, ...parentAmounts.keys};
    var total = 0;
    final items = <CategoryBreakdownItem>[];

    for (final id in allTopIds) {
      final directAmt = topLevelDirect[id] ?? 0;
      final subAmt = parentAmounts[id] ?? 0;
      final totalAmt = directAmt + subAmt;
      total += totalAmt;

      final cat = catMap[id];
      final children = childrenMap[id] ?? [];
      children.sort((a, b) => b.amount.compareTo(a.amount));

      items.add(CategoryBreakdownItem(
        categoryId: id,
        categoryName: cat?.name ?? '未知',
        iconKey: cat?.iconKey ?? '',
        amount: totalAmt,
        weight: 0, // computed below
        children: children,
      ));
    }

    // Compute weights
    for (final item in items) {
      final updatedChildren = item.children.map((ch) => CategoryBreakdownItem(
        categoryId: ch.categoryId,
        categoryName: ch.categoryName,
        iconKey: ch.iconKey,
        amount: ch.amount,
        weight: item.amount > 0 ? ch.amount / item.amount : 0.0,
      )).toList();
      // Replace with weight-computed version
      items[items.indexOf(item)] = CategoryBreakdownItem(
        categoryId: item.categoryId,
        categoryName: item.categoryName,
        iconKey: item.iconKey,
        amount: item.amount,
        weight: total > 0 ? item.amount / total : 0.0,
        children: updatedChildren,
      );
    }

    items.sort((a, b) => b.amount.compareTo(a.amount));

    state = state.copyWith(
      categoryBreakdown: items,
      categoryBreakdownTotal: total,
    );
  }

  /// Public: load budget summary local-first, then remote.
  Future<void> loadBudgetSummary() async {
    await _computeLocalBudgetSummary();
    await _refreshBudgetSummaryRemote();
  }

  Future<void> _refreshBudgetSummaryRemote() async {
    if (_userId == null) return;
    final now = DateTime.now();
    try {
      final resp = await _client.getBudgetSummary(
        pb.BudgetSummaryRequest()
          ..familyId = _familyId ?? ''
          ..year = now.year
          ..month = now.month,
        options: _callOpts,
      );
      // Always use gRPC response (server properly filters by familyId)
      state = state.copyWith(
        budgetSummary: BudgetSummaryData(
          totalBudget: resp.totalBudget.toInt(),
          totalSpent: resp.totalSpent.toInt(),
          executionRate: resp.executionRate,
        ),
      );
    } catch (_) {}
  }

  Future<void> _computeLocalBudgetSummary() async {
    if (_userId == null) return;
    final now = DateTime.now();
    final budget = await _db.getBudgetByMonth(_userId, now.year, now.month,
        familyId: _familyId ?? '');
    if (budget != null) {
      final expenses =
          await _db.getMonthCategoryExpenses(_userId, now.year, now.month,
              familyId: _familyId);
      final totalSpent = expenses.values.fold<int>(0, (sum, v) => sum + v);
      final rate =
          budget.totalAmount > 0 ? totalSpent / budget.totalAmount : 0.0;
      state = state.copyWith(
        budgetSummary: BudgetSummaryData(
          totalBudget: budget.totalAmount,
          totalSpent: totalSpent,
          executionRate: rate,
        ),
      );
    }
  }

  /// Public: load net worth trend with period toggle.
  Future<void> loadNetWorthTrend(String period, [int count = 12]) async {
    state = state.copyWith(netWorthTrendPeriod: period);
    final effectiveCount = period == 'yearly' ? 5 : count;
    await _refreshNetWorthTrendRemote(effectiveCount, period);
  }

  Future<void> _refreshNetWorthTrendRemote(int count, [String period = 'monthly']) async {
    if (_userId == null) return;
    try {
      final resp = await _client.getNetWorthTrend(
        pb.TrendRequest()
          ..userId = _userId
          ..familyId = _familyId ?? ''
          ..period = period
          ..count = count,
        options: _callOpts,
      );
      // Always use gRPC response (server properly filters by familyId)
      state = state.copyWith(
        netWorthTrend: resp.points
            .map((p) => TrendPointData(
                  label: p.label,
                  income: p.income.toInt(),
                  expense: p.expense.toInt(),
                  net: p.net.toInt(),
                ))
            .toList(),
      );
    } catch (_) {
      // Fallback: approximate with current net worth
      final nw = state.netWorth.total;
      final now = DateTime.now();
      final points = <TrendPointData>[];
      for (int i = count - 1; i >= 0; i--) {
        String label;
        if (period == 'yearly') {
          label = '${now.year - i}';
        } else {
          final month = DateTime(now.year, now.month - i, 1);
          label = '${month.year}-${month.month.toString().padLeft(2, '0')}';
        }
        points.add(TrendPointData(
          label: label,
          income: 0,
          expense: 0,
          net: nw,
        ));
      }
      state = state.copyWith(netWorthTrend: points);
    }
  }
}

// ── Provider ──

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  final database = ref.watch(databaseProvider);
  final client = ref.watch(dashboardClientProvider);
  final marketClient = ref.watch(marketDataClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  final familyId = ref.watch(currentFamilyIdProvider);
  return DashboardNotifier(database, client, marketClient, userId, familyId);
});
