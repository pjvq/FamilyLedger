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
    _store.removeWhere((t) => t.id == entity.id);
    _store.add(entity);
    _notify();
  }

  @override
  Future<void> softDelete(String id) async {
    final idx = _store.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    _store[idx] = _store[idx].copyWith(
      deletedAt: DateTime.now(),
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
    for (final t in _store) {
      if (t.id == id && t.deletedAt == null) return t;
    }
    return null;
  }

  @override
  Future<List<TransactionEntity>> getRecent(
    String userId,
    int limit, {
    String? familyId,
  }) async {
    final filtered = <TransactionEntity>[];
    for (final t in _store) {
      if (t.userId == userId && t.deletedAt == null) {
        filtered.add(t);
      }
    }
    filtered.sort((a, b) => b.txnDate.compareTo(a.txnDate));
    return filtered.take(limit).toList();
  }

  @override
  Stream<List<TransactionEntity>> watch(String userId, {String? familyId}) {
    return _watchController.stream.map(
      (all) => [
        for (final t in all)
          if (t.userId == userId && t.deletedAt == null) t,
      ],
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
    final idSet = ids.toSet();
    for (int i = 0; i < _store.length; i++) {
      if (idSet.contains(_store[i].id)) {
        _store[i] = _store[i].copyWith(
          syncStatus: 'synced',
          updatedAt: DateTime.now(),
        );
      }
    }
    _notify();
  }

  @override
  Future<void> markFailed(List<String> ids) async {
    final idSet = ids.toSet();
    for (int i = 0; i < _store.length; i++) {
      if (idSet.contains(_store[i].id)) {
        _store[i] = _store[i].copyWith(
          syncStatus: 'failed',
          updatedAt: DateTime.now(),
        );
      }
    }
    _notify();
  }

  @override
  Future<int> getTodayExpense(String userId) async {
    final now = DateTime.now();
    int sum = 0;
    for (final t in _store) {
      if (t.deletedAt != null) continue;
      if (t.userId != userId) continue;
      if (t.type != 'expense') continue;
      if (t.txnDate.year == now.year &&
          t.txnDate.month == now.month &&
          t.txnDate.day == now.day) {
        sum += t.amountCny;
      }
    }
    return sum;
  }

  @override
  Future<int> getMonthExpense(String userId) async {
    final now = DateTime.now();
    int sum = 0;
    for (final t in _store) {
      if (t.deletedAt != null) continue;
      if (t.userId != userId) continue;
      if (t.type != 'expense') continue;
      if (t.txnDate.year == now.year && t.txnDate.month == now.month) {
        sum += t.amountCny;
      }
    }
    return sum;
  }

  @override
  Future<int> getTotalBalance(String userId) async {
    int sum = 0;
    for (final t in _store) {
      if (t.deletedAt != null) continue;
      if (t.userId != userId) continue;
      sum += (t.type == 'income' ? t.amountCny : -t.amountCny);
    }
    return sum;
  }

  void dispose() {
    _watchController.close();
  }

  // ─── Private ─────────────────────────────────────────────────────────

  void _notify() {
    if (!_watchController.isClosed) {
      _watchController.add(List.unmodifiable(_store));
    }
  }
}
