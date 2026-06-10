import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../data/local/database.dart';
import '../entities/entities.dart';
import '../interfaces/interfaces.dart';

/// Default page size for transaction queries.
const int kTransactionPageSize = 200;

/// Pure data-access layer for transactions.
///
/// Responsibilities:
/// - Local CRUD against Drift (SQLite)
/// - Balance delta computation + account balance updates
/// - No network calls, no sync logic, no UI state
///
/// All methods are idempotent where possible (upsert semantics).
/// Callers handle gRPC coordination and offline queue.
///
/// Also implements [ITransactionRepository] for DIP compatibility.
/// Methods with differing signatures delegate to the interface-compliant version.
class TransactionRepository implements ITransactionRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  TransactionRepository(this._db);

  // ─── Reads ───────────────────────────────────────────────────────────

  /// Watch transactions with pagination (default 200).
  Stream<List<Transaction>> watchAll(
    String userId, {
    String? familyId,
    int limit = kTransactionPageSize,
    int offset = 0,
  }) {
    return _db.watchTransactions(userId, familyId: familyId, limit: limit, offset: offset);
  }

  /// Load a page of transactions (non-reactive, for infinite scroll).
  Future<List<Transaction>> getPage(
    String userId, {
    String? familyId,
    required int limit,
    required int offset,
  }) {
    return _db.getTransactionPage(userId, familyId: familyId, limit: limit, offset: offset);
  }

  /// 全量搜索交易（非分页）——按备注 / 分类名 / 账户名模糊匹配。
  /// 用于流水页右上角搜索，直接查 DB 全量，不受分页加载状态影响。
  /// 返回 [TransactionSearchResult]，含 truncated 标志（结果超过 limit 被截断）。
  Future<TransactionSearchResult> search(
    String userId,
    String query, {
    String? familyId,
    int limit = 1000,
  }) {
    return _db.searchTransactions(userId, query, familyId: familyId, limit: limit);
  }

  /// Get raw Drift Transaction by ID (legacy callers).
  Future<Transaction?> getTransactionById(String id) => _db.getTransactionById(id);

  /// ITransactionRepository: returns domain entity.
  @override
  Future<TransactionEntity?> getById(String id) async {
    final row = await _db.getTransactionById(id);
    return row == null ? null : _toEntity(row);
  }

  Future<List<Category>> getCategoriesByType(String type, {required String userId}) {
    return _db.getCategoriesByType(type, userId: userId);
  }

  // ─── Balance Queries ─────────────────────────────────────────────────

  @override
  Future<int> getTotalBalance(String userId) => _db.getTotalBalance(userId);
  @override
  Future<int> getTodayExpense(String userId) => _db.getTodayExpense(userId);
  @override
  Future<int> getMonthExpense(String userId) => _db.getMonthExpense(userId);

  // ─── Writes ──────────────────────────────────────────────────────────

  /// Generate a client-side UUID for offline-first transaction IDs.
  String generateId() => _uuid.v4();

  /// Insert a transaction and adjust the account balance atomically.
  ///
  /// [amountCny] is the canonical amount in CNY cents used for balance.
  /// [type] must be 'income' or 'expense'.
  ///
  /// Legacy named-parameter API. For interface-compliant usage, see [insert].
  Future<void> insertWithBalance({
    required String id,
    required String userId,
    required String accountId,
    required String categoryId,
    required int amount,
    required int amountCny,
    required String type,
    required DateTime txnDate,
    String note = '',
    String currency = 'CNY',
    String tags = '',
    String imageUrls = '',
  }) async {
    final companion = TransactionsCompanion.insert(
      id: id,
      userId: userId,
      accountId: accountId,
      categoryId: categoryId,
      amount: amount,
      amountCny: amountCny,
      type: type,
      note: Value(note),
      tags: Value(tags),
      imageUrls: Value(imageUrls),
      txnDate: txnDate,
    );
    await _db.insertTransaction(companion);
    await _adjustBalance(accountId, type, amountCny);
  }

  /// ITransactionRepository: insert from entity.
  @override
  Future<void> insert(TransactionEntity entity) async {
    await insertWithBalance(
      id: entity.id,
      userId: entity.userId,
      accountId: entity.accountId,
      categoryId: entity.categoryId,
      amount: entity.amount,
      amountCny: entity.amountCny,
      type: entity.type,
      txnDate: entity.txnDate,
      note: entity.note,
      currency: entity.currency,
      tags: entity.tags,
      imageUrls: entity.imageUrls,
    );
  }

  /// Update specific fields of a transaction.
  /// Returns the old transaction for balance reversal (null if not found).
  Future<Transaction?> update({
    required String id,
    String? categoryId,
    int? amount,
    int? amountCny,
    String? type,
    String? note,
    String? currency,
    String? tags,
    String? imageUrls,
    DateTime? txnDate,
    String? accountId,
  }) async {
    final oldTxn = await _db.getTransactionById(id);
    if (oldTxn == null) return null;

    final companion = TransactionsCompanion(
      categoryId: categoryId != null ? Value(categoryId) : const Value.absent(),
      amount: amount != null ? Value(amount) : const Value.absent(),
      amountCny: amountCny != null
          ? Value(amountCny)
          : (amount != null ? Value(amount) : const Value.absent()),
      type: type != null ? Value(type) : const Value.absent(),
      note: note != null ? Value(note) : const Value.absent(),
      currency: currency != null ? Value(currency) : const Value.absent(),
      tags: tags != null ? Value(tags) : const Value.absent(),
      imageUrls: imageUrls != null ? Value(imageUrls) : const Value.absent(),
      txnDate: txnDate != null ? Value(txnDate) : const Value.absent(),
      accountId: accountId != null ? Value(accountId) : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    );
    await _db.updateTransactionFields(id, companion);

    // Recompute balance delta
    final effectiveNewAmountCny = amountCny ?? amount ?? oldTxn.amountCny;
    final effectiveNewType = type ?? oldTxn.type;
    final oldDelta = oldTxn.type == 'income' ? oldTxn.amountCny : -oldTxn.amountCny;
    final newDelta = effectiveNewType == 'income'
        ? effectiveNewAmountCny
        : -effectiveNewAmountCny;

    if (accountId != null && accountId != oldTxn.accountId) {
      // Account changed: reverse from old, apply to new
      if (oldDelta != 0) {
        await _db.updateAccountBalance(oldTxn.accountId, -oldDelta);
      }
      if (newDelta != 0) {
        await _db.updateAccountBalance(accountId, newDelta);
      }
    } else {
      // Same account: just apply difference
      final balanceDiff = newDelta - oldDelta;
      if (balanceDiff != 0) {
        await _db.updateAccountBalance(oldTxn.accountId, balanceDiff);
      }
    }

    return oldTxn;
  }

  /// Soft-delete a transaction and reverse its balance impact.
  /// Returns the deleted transaction (null if not found).
  Future<Transaction?> softDeleteWithBalance(String id) async {
    final txn = await _db.getTransactionById(id);
    if (txn == null) return null;

    await _db.softDeleteTransaction(id);
    final delta = txn.type == 'income' ? -txn.amountCny : txn.amountCny;
    await _db.updateAccountBalance(txn.accountId, delta);
    return txn;
  }

  /// ITransactionRepository: soft-delete without returning the transaction.
  @override
  Future<void> softDelete(String id) async {
    await softDeleteWithBalance(id);
  }

  /// Batch soft-delete transactions and reverse their balance impacts.
  /// All operations run inside a single DB transaction — atomic commit.
  /// Returns the count of actually deleted transactions.
  Future<int> batchSoftDelete(List<String> ids) async {
    if (ids.isEmpty) return 0;
    return _db.transaction(() async {
      int count = 0;
      for (final id in ids) {
        final txn = await _db.getTransactionById(id);
        if (txn == null) continue;
        await _db.softDeleteTransaction(id);
        final delta = txn.type == 'income' ? -txn.amountCny : txn.amountCny;
        await _db.updateAccountBalance(txn.accountId, delta);
        count++;
      }
      return count;
    });
  }

  // ─── Category Persistence ────────────────────────────────────────────

  /// Upsert a category (including children recursively).
  Future<void> upsertCategoryTree(
    String categoryId,
    String name,
    String type,
    int sortOrder,
    String? parentId,
    String? iconKey,
    String userId,
    List<CategoryChild> children,
  ) async {
    await _db.into(_db.categories).insertOnConflictUpdate(
      CategoriesCompanion.insert(
        id: categoryId,
        name: name,
        type: type,
        isPreset: const Value(true),
        sortOrder: Value(sortOrder),
        parentId: Value(parentId),
        iconKey: Value(iconKey ?? ''),
        userId: Value(userId),
      ),
    );
    for (final child in children) {
      await upsertCategoryTree(
        child.id, child.name, type, child.sortOrder,
        categoryId, child.iconKey, userId, child.children,
      );
    }
  }

  // ─── Bulk Operations (Sync) ──────────────────────────────────────────

  /// Batch upsert transactions from remote sync.
  /// Legacy batch upsert using [TransactionUpsertParams].
  Future<void> batchUpsertParams(List<TransactionUpsertParams> params) async {
    if (params.isEmpty) return;
    await _db.batchUpsertTransactions(params);
  }

  /// ITransactionRepository: batch upsert from entities.
  @override
  Future<void> batchUpsert(List<TransactionEntity> transactions) async {
    if (transactions.isEmpty) return;
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

  /// Batch hard-delete by IDs (for sync tombstones).
  @override
  Future<void> batchHardDelete(List<String> ids) async {
    if (ids.isEmpty) return;
    await _db.batchHardDeleteTransactions(ids);
  }

  // ─── Family Sync Bookkeeping ─────────────────────────────────────────

  Future<DateTime?> getFamilySyncTime(String familyId) =>
      _db.getFamilySyncTime(familyId);

  Future<void> setFamilySyncTime(String familyId, DateTime time) =>
      _db.setFamilySyncTime(familyId, time);

  Future<void> clearFamilySyncTime(String familyId) =>
      _db.clearFamilySyncTime(familyId);

  // ─── Default Account ─────────────────────────────────────────────────

  Future<Account?> getDefaultAccount(String userId, {String? familyId}) =>
      _db.getDefaultAccount(userId, familyId: familyId);

  // ─── Private ─────────────────────────────────────────────────────────

  Future<void> _adjustBalance(String accountId, String type, int amountCny) async {
    final delta = type == 'income' ? amountCny : -amountCny;
    await _db.updateAccountBalance(accountId, delta);
  }

  // ─── ITransactionRepository Interface Implementation ─────────────────
  // These methods fulfill the domain interface contract.
  // Legacy callers continue using the named-parameter versions above.

  @override
  Future<void> hardDelete(String id) => _db.hardDeleteTransaction(id);

  @override
  Future<void> markSynced(List<String> ids) => _db.markTransactionsSynced(ids);

  @override
  Future<void> markFailed(List<String> ids) => _db.markTransactionsFailed(ids);

  @override
  Future<List<TransactionEntity>> getRecent(
    String userId,
    int limit, {
    String? familyId,
  }) async {
    final rows = await _db.getTransactionPage(userId, familyId: familyId, limit: limit, offset: 0);
    return rows.map(_toEntity).toList();
  }

  @override
  Stream<List<TransactionEntity>> watch(String userId, {String? familyId}) {
    return _db
        .watchTransactions(userId, familyId: familyId)
        .map((rows) => rows.map(_toEntity).toList());
  }

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
      currency: row.currency,
      tags: row.tags,
      imageUrls: row.imageUrls,
      txnDate: row.txnDate,
      syncStatus: row.syncStatus,
      deletedAt: row.deletedAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}

/// Parameters for batch upserting transactions from server sync.
class TransactionUpsertParams {
  final String id;
  final String userId;
  final String accountId;
  final String categoryId;
  final int amount;
  final int amountCny;
  final String type;
  final String note;
  final DateTime txnDate;

  const TransactionUpsertParams({
    required this.id,
    required this.userId,
    required this.accountId,
    required this.categoryId,
    required this.amount,
    required this.amountCny,
    required this.type,
    required this.note,
    required this.txnDate,
  });
}

/// Minimal child category representation for recursive tree upsert.
class CategoryChild {
  final String id;
  final String name;
  final int sortOrder;
  final String? iconKey;
  final List<CategoryChild> children;

  const CategoryChild({
    required this.id,
    required this.name,
    this.sortOrder = 0,
    this.iconKey,
    this.children = const [],
  });
}
