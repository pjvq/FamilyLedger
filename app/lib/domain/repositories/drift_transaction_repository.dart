import 'package:drift/drift.dart';

import '../../data/local/database.dart';
import '../entities/entities.dart';
import '../interfaces/interfaces.dart';
import 'transaction_repository.dart' show TransactionUpsertParams;

/// Drift-backed implementation of [ITransactionRepository].
///
/// Adapter between the domain interface contract and the Drift ORM layer.
/// Production code uses this; tests use InMemoryTransactionRepository.
class DriftTransactionRepository implements ITransactionRepository {
  final AppDatabase _db;

  DriftTransactionRepository(this._db);

  @override
  Future<void> insert(TransactionEntity entity) async {
    final companion = TransactionsCompanion.insert(
      id: entity.id,
      userId: entity.userId,
      accountId: entity.accountId,
      categoryId: entity.categoryId,
      amount: entity.amount,
      amountCny: entity.amountCny,
      type: entity.type,
      note: Value(entity.note),
      txnDate: entity.txnDate,
    );
    await _db.insertTransaction(companion);
  }

  @override
  Future<void> softDelete(String id) => _db.softDeleteTransaction(id);

  @override
  Future<void> hardDelete(String id) => _db.hardDeleteTransaction(id);

  @override
  Future<TransactionEntity?> getById(String id) async {
    final row = await _db.getTransactionById(id);
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<List<TransactionEntity>> getRecent(
    String userId,
    int limit, {
    String? familyId,
  }) async {
    final rows = await _db.getTransactionPage(
      userId,
      familyId: familyId,
      limit: limit,
      offset: 0,
    );
    return rows.map(_toEntity).toList();
  }

  @override
  Stream<List<TransactionEntity>> watch(String userId, {String? familyId}) {
    return _db
        .watchTransactions(userId, familyId: familyId)
        .map((rows) => rows.map(_toEntity).toList());
  }

  @override
  Future<void> batchUpsert(List<TransactionEntity> transactions) async {
    final params = transactions
        .map((t) => TransactionUpsertParams(
              id: t.id,
              userId: t.userId,
              accountId: t.accountId,
              categoryId: t.categoryId,
              amount: t.amount,
              amountCny: t.amountCny,
              type: t.type,
              note: t.note,
              txnDate: t.txnDate,
            ))
        .toList();
    await _db.batchUpsertTransactions(params);
  }

  @override
  Future<void> batchHardDelete(List<String> ids) async {
    if (ids.isEmpty) return;
    await _db.batchHardDeleteTransactions(ids);
  }

  @override
  Future<void> markSynced(List<String> ids) => _db.markTransactionsSynced(ids);

  @override
  Future<void> markFailed(List<String> ids) => _db.markTransactionsFailed(ids);

  @override
  Future<int> getTodayExpense(String userId) => _db.getTodayExpense(userId);

  @override
  Future<int> getMonthExpense(String userId) => _db.getMonthExpense(userId);

  @override
  Future<int> getTotalBalance(String userId) => _db.getTotalBalance(userId);

  // ─── Private ─────────────────────────────────────────────────────────

  TransactionEntity _toEntity(Transaction row) {
    return TransactionEntity(
      id: row.id,
      userId: row.userId,
      accountId: row.accountId,
      categoryId: row.categoryId,
      amount: row.amount,
      amountCny: row.amountCny,
      type: row.type,
      note: row.note,
      txnDate: row.txnDate,
      syncStatus: row.syncStatus,
      deletedAt: row.deletedAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
