import 'package:familyledger/domain/interfaces/interfaces.dart';

/// Interface-based [BalanceCalculator] for testing without Drift/SQLite.
///
/// Mirrors production BalanceCalculator behavior but accepts
/// [ITransactionRepository] instead of concrete TransactionRepository.
/// This enables pure-logic testing with in-memory mocks.
class BalanceCalculatorTestable {
  final ITransactionRepository _repo;

  BalanceCalculatorTestable(this._repo);

  /// Compute all summary values for a user in one parallel call.
  Future<BalanceSummaryResult> compute(String userId) async {
    final (totalBalance, todayExpense, monthExpense) = await (
      _repo.getTotalBalance(userId),
      _repo.getTodayExpense(userId),
      _repo.getMonthExpense(userId),
    ).wait;
    return BalanceSummaryResult(
      totalBalance: totalBalance,
      todayExpense: todayExpense,
      monthExpense: monthExpense,
    );
  }
}

/// Immutable snapshot of balance summary values (all in CNY cents).
class BalanceSummaryResult {
  final int totalBalance;
  final int todayExpense;
  final int monthExpense;

  const BalanceSummaryResult({
    required this.totalBalance,
    required this.todayExpense,
    required this.monthExpense,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BalanceSummaryResult &&
          other.totalBalance == totalBalance &&
          other.todayExpense == todayExpense &&
          other.monthExpense == monthExpense);

  @override
  int get hashCode => Object.hash(totalBalance, todayExpense, monthExpense);

  @override
  String toString() =>
      'BalanceSummary(total=$totalBalance, today=$todayExpense, month=$monthExpense)';
}
