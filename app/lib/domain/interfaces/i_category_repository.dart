import '../../data/local/database.dart';

/// Contract for category data access.
abstract interface class ICategoryRepository {
  /// Get categories filtered by type, optionally scoped to a user.
  Future<List<Category>> getByType(String type, {String? userId});

  /// Get all categories (no type filter).
  Future<List<Category>> getAll();

  /// Get a single category by ID.
  Future<Category?> getById(String id);

  /// Insert or update a category.
  Future<void> upsert(CategoriesCompanion entry);

  /// Batch upsert categories (for sync pull).
  Future<void> batchUpsert(List<CategoriesCompanion> entries);

  /// Seed default categories for a new user/family.
  Future<void> seedForOwner(String ownerID);
}
