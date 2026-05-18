import '../entities/entities.dart';

/// Contract for category data access.
abstract interface class ICategoryRepository {
  /// Get categories filtered by type, optionally scoped to a user.
  Future<List<CategoryEntity>> getByType(String type, {String? userId});

  /// Get all categories (no type filter).
  Future<List<CategoryEntity>> getAll();

  /// Get a single category by ID.
  Future<CategoryEntity?> getById(String id);

  /// Insert or update a category.
  Future<void> upsert(CategoryEntity entity);

  /// Batch upsert categories (for sync pull).
  Future<void> batchUpsert(List<CategoryEntity> entities);

  /// Seed default categories for a new user/family.
  Future<void> seedForOwner(String ownerID);
}
