import '../../data/local/database.dart';

/// Contract for transaction data access.
///
/// Abstracts local DB operations so providers don't depend on Drift directly.
/// Implementations: [TransactionRepository] (production), mock (testing).
abstract interface class ITransactionRepository {
  /// Insert or replace a transaction (local DB).
  Future<int> insert(TransactionsCompanion entry);

  /// Soft-delete a transaction by setting `deleted_at`.
  Future<void> softDelete(String id);

  /// Hard-delete a transaction permanently.
  Future<void> hardDelete(String id);

  /// Get a single transaction by ID.
  Future<Transaction?> getById(String id);

  /// Get recent transactions for a user, optionally filtered by family.
  Future<List<Transaction>> getRecent(String userId, int limit, {String? familyId});

  /// Watch all transactions (reactive stream).
  Stream<List<Transaction>> watch(String userId, {String? familyId});

  /// Batch upsert transactions (for sync pull).
  Future<void> batchUpsert(List<dynamic> transactions);

  /// Batch hard-delete by IDs.
  Future<void> batchHardDelete(List<String> ids);

  /// Update specific fields on a transaction.
  Future<void> updateFields(String id, TransactionsCompanion entry);

  /// Mark transactions as synced.
  Future<void> markSynced(List<String> ids);

  /// Mark transactions as sync-failed.
  Future<void> markFailed(List<String> ids);

  /// Get today's total expense for a user.
  Future<int> getTodayExpense(String userId);

  /// Get this month's total expense for a user.
  Future<int> getMonthExpense(String userId);

  /// Get total balance (income - expense) for a user.
  Future<int> getTotalBalance(String userId);
}
