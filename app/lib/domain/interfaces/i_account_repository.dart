import '../../data/local/database.dart';

/// Contract for account data access.
abstract interface class IAccountRepository {
  /// Get all active accounts for a user (excludes family accounts).
  Future<List<Account>> getActive(String userId);

  /// Get all accounts belonging to a family.
  Future<List<Account>> getByFamily(String familyId);

  /// Get a single account by ID.
  Future<Account?> getById(String id);

  /// Insert or update an account.
  Future<void> upsert(AccountsCompanion entry);

  /// Update account balance by adding a delta (positive or negative).
  Future<void> adjustBalance(String accountId, int delta);

  /// Delete an account (soft-delete if supported).
  Future<void> delete(String id);
}
