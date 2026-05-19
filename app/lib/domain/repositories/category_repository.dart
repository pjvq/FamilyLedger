import 'package:drift/drift.dart';

import '../../data/local/database.dart';
import '../entities/entities.dart';
import '../interfaces/interfaces.dart';

/// Concrete implementation of [ICategoryRepository] backed by Drift (SQLite).
///
/// Responsibilities:
/// - Local CRUD for categories
/// - Batch upsert for sync pull
/// - Default category seeding
///
/// No network calls, no sync logic.
class CategoryRepository implements ICategoryRepository {
  final AppDatabase _db;

  CategoryRepository(this._db);

  @override
  Future<List<CategoryEntity>> getByType(String type, {String? userId}) async {
    final rows = await _db.getCategoriesByType(type, userId: userId);
    return rows.map(_toEntity).toList();
  }

  @override
  Future<List<CategoryEntity>> getAll() async {
    final rows = await _db.getAllCategories();
    return rows.map(_toEntity).toList();
  }

  @override
  Future<CategoryEntity?> getById(String id) async {
    final rows = await (_db.select(_db.categories)
          ..where((c) => c.id.equals(id)))
        .get();
    return rows.isEmpty ? null : _toEntity(rows.first);
  }

  @override
  Future<void> upsert(CategoryEntity entity) async {
    await _db.into(_db.categories).insertOnConflictUpdate(
          CategoriesCompanion.insert(
            id: entity.id,
            name: entity.name,
            type: entity.type,
            isPreset: Value(entity.isPreset),
            sortOrder: Value(entity.sortOrder),
            parentId: Value(entity.parentId),
            iconKey: Value(entity.iconKey),
          ),
        );
  }

  @override
  Future<void> batchUpsert(List<CategoryEntity> entities) async {
    await _db.batch((batch) {
      for (final entity in entities) {
        batch.insert(
          _db.categories,
          CategoriesCompanion.insert(
            id: entity.id,
            name: entity.name,
            type: entity.type,
            isPreset: Value(entity.isPreset),
            sortOrder: Value(entity.sortOrder),
            parentId: Value(entity.parentId),
            iconKey: Value(entity.iconKey),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  @override
  Future<void> seedForOwner(String ownerID) async {
    // Delegate to existing seed logic in TransactionRepository if needed,
    // or provide default categories inline. For now this is a no-op —
    // seeding is handled by the server on user creation.
  }

  /// Convert Drift model to domain entity.
  static CategoryEntity _toEntity(Category row) => CategoryEntity(
        id: row.id,
        name: row.name,
        type: row.type,
        parentId: row.parentId,
        iconKey: row.iconKey,
        sortOrder: row.sortOrder,
        isPreset: row.isPreset,
      );
}
