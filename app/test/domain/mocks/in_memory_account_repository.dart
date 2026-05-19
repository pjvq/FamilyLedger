import 'package:familyledger/domain/entities/entities.dart';
import 'package:familyledger/domain/interfaces/interfaces.dart';

/// In-memory implementation of [IAccountRepository] for unit testing.
///
/// Simulates account CRUD and balance adjustments without any database.
class InMemoryAccountRepository implements IAccountRepository {
  final List<AccountEntity> _store = [];

  /// Expose store for test assertions.
  List<AccountEntity> get store => List.unmodifiable(_store);

  /// Inject seed data.
  void seed(List<AccountEntity> accounts) {
    _store
      ..clear()
      ..addAll(accounts);
  }

  @override
  Future<List<AccountEntity>> getActive(String userId) async {
    return _store
        .where((a) => a.userId == userId && (a.familyId == null || a.familyId!.isEmpty))
        .toList();
  }

  @override
  Future<List<AccountEntity>> getByFamily(String familyId) async {
    return _store.where((a) => a.familyId == familyId).toList();
  }

  @override
  Future<AccountEntity?> getById(String id) async {
    try {
      return _store.firstWhere((a) => a.id == id);
    } on StateError {
      return null;
    }
  }

  @override
  Future<void> upsert(AccountEntity entity) async {
    _store.removeWhere((a) => a.id == entity.id);
    _store.add(entity);
  }

  @override
  Future<void> adjustBalance(String accountId, int delta) async {
    final idx = _store.indexWhere((a) => a.id == accountId);
    if (idx == -1) return;
    final old = _store[idx];
    _store[idx] = AccountEntity(
      id: old.id,
      userId: old.userId,
      name: old.name,
      type: old.type,
      balance: old.balance + delta,
      currency: old.currency,
      familyId: old.familyId,
    );
  }

  @override
  Future<void> delete(String id) async {
    _store.removeWhere((a) => a.id == id);
  }
}
