import 'package:familyledger/domain/interfaces/interfaces.dart';
import 'package:familyledger/domain/services/balance_calculator.dart';

/// Interface-based [BalanceCalculator] for testing without Drift/SQLite.
///
/// Mirrors production BalanceCalculator behavior but accepts
/// [ITransactionRepository] instead of concrete TransactionRepository.
/// This enables pure-logic testing with in-memory mocks.
///
/// Uses the production [BalanceSummary] value object — no test-only
/// duplicate needed.
class BalanceCalculatorTestable {
  final ITransactionRepository _repo;

  BalanceCalculatorTestable(this._repo);

  /// Compute all summary values for a user in one parallel call.
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
