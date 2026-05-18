import '../entities/entities.dart';

/// Contract for account data access.
abstract interface class IAccountRepository {
  /// Get all active accounts for a user (excludes family accounts).
  Future<List<AccountEntity>> getActive(String userId);

  /// Get all accounts belonging to a family.
  Future<List<AccountEntity>> getByFamily(String familyId);

  /// Get a single account by ID.
  Future<AccountEntity?> getById(String id);

  /// Insert or update an account.
  Future<void> upsert(AccountEntity entity);

  /// Update account balance by adding a delta (positive or negative, in 分).
  Future<void> adjustBalance(String accountId, int delta);

  /// Delete an account (soft-delete if supported).
  Future<void> delete(String id);
}
