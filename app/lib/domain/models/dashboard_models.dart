/// Dashboard display models — immutable data classes for UI consumption.
///
/// Extracted from dashboard_provider.dart (M5) to separate data shapes
/// from business logic. These are pure value objects with no dependencies.
library;

/// Net worth summary — all amounts in 分 (cents).
class NetWorthData {
  final int total;
  final int cashAndBank;
  final int investmentValue;
  final int fixedAssetValue;
  final int loanBalance; // negative
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

/// A single slice in the asset composition pie chart.
class AssetCompositionItem {
  final String category;
  final String label;
  final int value;
  final double weight; // 0.0–1.0

  const AssetCompositionItem({
    required this.category,
    required this.label,
    required this.value,
    required this.weight,
  });
}

/// A single data point in income/expense/net-worth trend charts.
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

/// Category breakdown item — recursive (children for subcategories).
class CategoryBreakdownItem {
  final String categoryId;
  final String categoryName;
  final String iconKey;
  final int amount;
  final double weight; // 0.0–1.0
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

/// Budget execution summary for the current period.
class BudgetSummaryData {
  final int totalBudget;
  final int totalSpent;
  final double executionRate; // 0.0–1.0+

  const BudgetSummaryData({
    this.totalBudget = 0,
    this.totalSpent = 0,
    this.executionRate = 0.0,
  });
}
