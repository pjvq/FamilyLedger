import 'package:drift/drift.dart';

import '../../data/local/database.dart';
import '../entities/entities.dart';
import '../interfaces/interfaces.dart';

/// Concrete implementation of [IAccountRepository] backed by Drift (SQLite).
///
/// Responsibilities:
/// - Local CRUD against Drift
/// - No network calls, no sync logic, no UI state
///
/// Callers handle gRPC coordination and offline queue.
class AccountRepository implements IAccountRepository {
  final AppDatabase _db;

  AccountRepository(this._db);

  @override
  Future<List<AccountEntity>> getActive(String userId) async {
    final rows = await _db.getActiveAccounts(userId);
    return rows.map(_toEntity).toList();
  }

  @override
  Future<List<AccountEntity>> getByFamily(String familyId) async {
    final rows = await _db.getAccountsByFamily(familyId);
    return rows.map(_toEntity).toList();
  }

  @override
  Future<AccountEntity?> getById(String id) async {
    final row = await _db.getAccountById(id);
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<void> upsert(AccountEntity entity) async {
    await _db.insertAccount(AccountsCompanion.insert(
      id: entity.id,
      userId: entity.userId,
      name: entity.name,
      balance: Value(entity.balance),
      familyId: Value(entity.familyId ?? ''),
      accountType: Value(entity.type),
    ));
  }

  @override
  Future<void> adjustBalance(String accountId, int delta) async {
    await _db.updateAccountBalance(accountId, delta);
  }

  @override
  Future<void> delete(String id) async {
    await (_db.update(_db.accounts)..where((a) => a.id.equals(id)))
        .write(const AccountsCompanion(isActive: Value(false)));
  }

  /// Convert Drift model to domain entity.
  static AccountEntity _toEntity(Account row) => AccountEntity(
        id: row.id,
        userId: row.userId,
        name: row.name,
        type: row.accountType,
        balance: row.balance,
        currency: row.currency,
        familyId: row.familyId.isNotEmpty ? row.familyId : null,
      );
}
