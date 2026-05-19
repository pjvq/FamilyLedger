import 'dart:async';

import 'package:familyledger/domain/entities/entities.dart';
import 'package:familyledger/domain/interfaces/interfaces.dart';

/// In-memory implementation of [ITransactionRepository] for unit testing.
///
/// Thread-safe for single-isolate tests. No Drift/SQLite dependency.
/// Simulates real DB behavior including soft-delete filtering and sync status.
class InMemoryTransactionRepository implements ITransactionRepository {
  final List<TransactionEntity> _store = [];
  final StreamController<List<TransactionEntity>> _watchController =
      StreamController<List<TransactionEntity>>.broadcast();

  /// Expose store for test assertions.
  List<TransactionEntity> get store => List.unmodifiable(_store);

  /// Optionally inject seed data.
  void seed(List<TransactionEntity> transactions) {
    _store
      ..clear()
      ..addAll(transactions);
    _notify();
  }

  @override
  Future<void> insert(TransactionEntity entity) async {
    // Reject duplicates (idempotent: last-write-wins).
    _store.removeWhere((t) => t.id == entity.id);
    _store.add(entity);
    _notify();
  }

  @override
  Future<void> softDelete(String id) async {
    final idx = _store.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final old = _store[idx];
    _store[idx] = TransactionEntity(
      id: old.id,
      userId: old.userId,
      accountId: old.accountId,
      categoryId: old.categoryId,
      amount: old.amount,
      amountCny: old.amountCny,
      type: old.type,
      note: old.note,
      txnDate: old.txnDate,
      syncStatus: old.syncStatus,
      deletedAt: DateTime.now(),
      createdAt: old.createdAt,
      updatedAt: DateTime.now(),
    );
    _notify();
  }

  @override
  Future<void> hardDelete(String id) async {
    _store.removeWhere((t) => t.id == id);
    _notify();
  }

  @override
  Future<TransactionEntity?> getById(String id) async {
    try {
      return _active.firstWhere((t) => t.id == id);
    } on StateError {
      return null;
    }
  }

  @override
  Future<List<TransactionEntity>> getRecent(
    String userId,
    int limit, {
    String? familyId,
  }) async {
    final filtered = _active.where((t) => t.userId == userId).toList()
      ..sort((a, b) => b.txnDate.compareTo(a.txnDate));
    return filtered.take(limit).toList();
  }

  @override
  Stream<List<TransactionEntity>> watch(String userId, {String? familyId}) {
    // Emit current state immediately, then updates.
    return _watchController.stream.map(
      (all) => all
          .where((t) => t.userId == userId && t.deletedAt == null)
          .toList(),
    );
  }

  @override
  Future<void> batchUpsert(List<TransactionEntity> transactions) async {
    for (final txn in transactions) {
      _store.removeWhere((t) => t.id == txn.id);
      _store.add(txn);
    }
    _notify();
  }

  @override
  Future<void> batchHardDelete(List<String> ids) async {
    _store.removeWhere((t) => ids.contains(t.id));
    _notify();
  }

  @override
  Future<void> markSynced(List<String> ids) async {
    for (int i = 0; i < _store.length; i++) {
      if (ids.contains(_store[i].id)) {
        final old = _store[i];
        _store[i] = TransactionEntity(
          id: old.id,
          userId: old.userId,
          accountId: old.accountId,
          categoryId: old.categoryId,
          amount: old.amount,
          amountCny: old.amountCny,
          type: old.type,
          note: old.note,
          txnDate: old.txnDate,
          syncStatus: 'synced',
          deletedAt: old.deletedAt,
          createdAt: old.createdAt,
          updatedAt: DateTime.now(),
        );
      }
    }
    _notify();
  }

  @override
  Future<void> markFailed(List<String> ids) async {
    for (int i = 0; i < _store.length; i++) {
      if (ids.contains(_store[i].id)) {
        final old = _store[i];
        _store[i] = TransactionEntity(
          id: old.id,
          userId: old.userId,
          accountId: old.accountId,
          categoryId: old.categoryId,
          amount: old.amount,
          amountCny: old.amountCny,
          type: old.type,
          note: old.note,
          txnDate: old.txnDate,
          syncStatus: 'failed',
          deletedAt: old.deletedAt,
          createdAt: old.createdAt,
          updatedAt: DateTime.now(),
        );
      }
    }
    _notify();
  }

  @override
  Future<int> getTodayExpense(String userId) async {
    final now = DateTime.now();
    return _active
        .where((t) =>
            t.userId == userId &&
            t.type == 'expense' &&
            t.txnDate.year == now.year &&
            t.txnDate.month == now.month &&
            t.txnDate.day == now.day)
        .fold<int>(0, (sum, t) => sum + t.amountCny);
  }

  @override
  Future<int> getMonthExpense(String userId) async {
    final now = DateTime.now();
    return _active
        .where((t) =>
            t.userId == userId &&
            t.type == 'expense' &&
            t.txnDate.year == now.year &&
            t.txnDate.month == now.month)
        .fold<int>(0, (sum, t) => sum + t.amountCny);
  }

  @override
  Future<int> getTotalBalance(String userId) async {
    return _active.where((t) => t.userId == userId).fold<int>(0, (sum, t) {
      return sum + (t.type == 'income' ? t.amountCny : -t.amountCny);
    });
  }

  void dispose() {
    _watchController.close();
  }

  // ─── Private ─────────────────────────────────────────────────────────

  List<TransactionEntity> get _active =>
      _store.where((t) => t.deletedAt == null).toList();

  void _notify() {
    if (!_watchController.isClosed) {
      _watchController.add(List.unmodifiable(_store));
    }
  }
}
