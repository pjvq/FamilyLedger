import 'package:familyledger/domain/entities/entities.dart';
import 'package:familyledger/domain/interfaces/interfaces.dart';

/// In-memory implementation of [ICategoryRepository] for unit testing.
///
/// Simulates category storage including hierarchy (parent/child relationships).
class InMemoryCategoryRepository implements ICategoryRepository {
  final List<CategoryEntity> _store = [];

  /// Expose store for test assertions.
  List<CategoryEntity> get store => List.unmodifiable(_store);

  /// Inject seed data.
  void seed(List<CategoryEntity> categories) {
    _store
      ..clear()
      ..addAll(categories);
  }

  @override
  Future<List<CategoryEntity>> getByType(String type, {String? userId}) async {
    return _store.where((c) => c.type == type).toList();
  }

  @override
  Future<List<CategoryEntity>> getAll() async {
    return List.unmodifiable(_store);
  }

  @override
  Future<CategoryEntity?> getById(String id) async {
    try {
      return _store.firstWhere((c) => c.id == id);
    } on StateError {
      return null;
    }
  }

  @override
  Future<void> upsert(CategoryEntity entity) async {
    _store.removeWhere((c) => c.id == entity.id);
    _store.add(entity);
  }

  @override
  Future<void> batchUpsert(List<CategoryEntity> entities) async {
    for (final entity in entities) {
      _store.removeWhere((c) => c.id == entity.id);
      _store.add(entity);
    }
  }

  @override
  Future<void> seedForOwner(String ownerID) async {
    // Seed minimal default categories for testing.
    final defaults = [
      CategoryEntity(
        id: 'cat_food',
        name: '餐饮',
        type: 'expense',
        isPreset: true,
        sortOrder: 1,
      ),
      CategoryEntity(
        id: 'cat_transport',
        name: '交通',
        type: 'expense',
        isPreset: true,
        sortOrder: 2,
      ),
      CategoryEntity(
        id: 'cat_salary',
        name: '工资',
        type: 'income',
        isPreset: true,
        sortOrder: 1,
      ),
      CategoryEntity(
        id: 'cat_bonus',
        name: '奖金',
        type: 'income',
        isPreset: true,
        sortOrder: 2,
      ),
    ];
    for (final cat in defaults) {
      if (!_store.any((c) => c.id == cat.id)) {
        _store.add(cat);
      }
    }
  }
}
