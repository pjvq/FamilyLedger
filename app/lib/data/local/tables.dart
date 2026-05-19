/// Drift table definitions — split by domain for maintainability.
///
/// Domain modules:
///   - core_tables.dart: Users, Accounts, Categories, Transactions, Transfers
///   - family_tables.dart: Families, FamilyMembers
///   - loan_tables.dart: LoanGroups, Loans, LoanSchedules, LoanRateChanges
///   - finance_tables.dart: Investments, InvestmentTrades, MarketQuotes, FixedAssets, AssetValuations, DepreciationRules
///   - support_tables.dart: Budgets, CategoryBudgets, Notifications, NotificationSettings, SyncQueue, ExchangeRates
export 'tables/core_tables.dart';
export 'tables/family_tables.dart';
export 'tables/loan_tables.dart';
export 'tables/finance_tables.dart';
export 'tables/support_tables.dart';
