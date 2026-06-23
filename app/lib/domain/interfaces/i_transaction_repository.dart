import '../entities/entities.dart';

/// Contract for transaction data access.
///
/// Abstracts local DB operations — domain layer has zero knowledge of Drift.
/// Implementations: [TransactionRepository] (production), mock (testing).
abstract interface class ITransactionRepository {
  /// Insert or replace a transaction.
  Future<void> insert(TransactionEntity entity);

  /// Soft-delete a transaction by setting `deleted_at`.
  Future<void> softDelete(String id);

  /// Hard-delete a transaction permanently.
  Future<void> hardDelete(String id);

  /// Get a single transaction by ID.
  Future<TransactionEntity?> getById(String id);

  /// Get recent transactions for a user, optionally filtered by family.
  Future<List<TransactionEntity>> getRecent(
    String userId,
    int limit, {
    String? familyId,
  });

  /// Watch all transactions (reactive stream).
  Stream<List<TransactionEntity>> watch(String userId, {String? familyId});

  /// Batch upsert transactions (for sync pull).
  Future<void> batchUpsert(List<TransactionEntity> transactions);

  /// Batch hard-delete by IDs.
  Future<void> batchHardDelete(List<String> ids);

  /// Mark transactions as synced.
  Future<void> markSynced(List<String> ids);

  /// Mark transactions as sync-failed.
  Future<void> markFailed(List<String> ids);

  /// Get today's total expense for a user (in 分).
  Future<int> getTodayExpense(String userId);

  /// Get this month's total expense for a user (in 分).
  Future<int> getMonthExpense(String userId);

  /// Get total balance (income - expense) for a user (in 分).
  Future<int> getTotalBalance(String userId);
}
