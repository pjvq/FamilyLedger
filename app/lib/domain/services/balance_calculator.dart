import '../repositories/transaction_repository.dart';

/// Computes balance summaries (total, today, month) from the repository.
///
/// Pure computation service — no side effects, no network, no state mutation.
/// Extracted from TransactionNotifier to enable:
/// - Independent testing without UI framework
/// - Reuse in dashboard, reports, widgets
/// - Potential caching layer insertion without touching UI code
class BalanceCalculator {
  final TransactionRepository _repo;

  BalanceCalculator(this._repo);

  /// Compute all summary values for a user in one call.
  /// Returns a value object — no mutable state.
  Future<BalanceSummary> compute(String userId) async {
    final (totalBalance, todayExpense, monthExpense) = await (
      _repo.getTotalBalance(userId),
      _repo.getTodayExpense(userId),
      _repo.getMonthExpense(userId),
    ).wait;
    return BalanceSummary(
      totalBalance: totalBalance,
      todayExpense: todayExpense,
      monthExpense: monthExpense,
    );
  }
}

/// Immutable snapshot of balance summary values (all in CNY cents).
class BalanceSummary {
  final int totalBalance;
  final int todayExpense;
  final int monthExpense;

  const BalanceSummary({
    required this.totalBalance,
    required this.todayExpense,
    required this.monthExpense,
  });

  static const zero = BalanceSummary(
    totalBalance: 0,
    todayExpense: 0,
    monthExpense: 0,
  );
}
