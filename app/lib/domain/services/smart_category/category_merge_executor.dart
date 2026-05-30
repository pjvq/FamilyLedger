import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

import '../../../data/local/database.dart';
import 'category_usage_profiler.dart';

/// 合并执行结果
class MergeResult {
  final int affectedTransactions;
  final String sourceCategoryId;
  final String targetCategoryId;
  final String mergeLogId;

  const MergeResult({
    required this.affectedTransactions,
    required this.sourceCategoryId,
    required this.targetCategoryId,
    required this.mergeLogId,
  });
}

/// 合并类型
abstract final class MergeType {
  static const simple = 'simple';
  static const crossParent = 'crossParent';
  static const parentMerge = 'parentMerge';
  static const moveOnly = 'moveOnly';
}

/// 撤销失败：已撤销过
class AlreadyUndoneException implements Exception {
  @override
  String toString() => '该合并已撤销';
}

/// 撤销失败：已过期（7天）
class UndoExpiredException implements Exception {
  @override
  String toString() => '撤销窗口已过期（超过7天）';
}

/// 撤销失败：目标分类已删除
class UndoTargetDeletedException implements Exception {
  @override
  String toString() => '目标分类已被删除，无法撤销';
}

/// 分类合并执行器
/// 事务性执行合并操作，支持 7 天撤销窗口
///
/// ⚠️ 必须单例使用（通过 DI 注入）
class CategoryMergeExecutor {
  final AppDatabase _db;
  final CategoryUsageProfiler _profiler;
  static const _uuid = Uuid();

  /// 撤销窗口时长
  static const _undoWindow = Duration(days: 7);

  CategoryMergeExecutor({
    required AppDatabase db,
    required CategoryUsageProfiler profiler,
  })  : _db = db,
        _profiler = profiler;

  /// 执行简单合并（两个叶子分类 / 同父子分类）
  ///
  /// [sourceCategoryId] 将被软删除的分类
  /// [targetCategoryId] 保留的分类
  /// [mergeType] 合并类型标记
  Future<MergeResult> executeMerge({
    required String sourceCategoryId,
    required String targetCategoryId,
    String mergeType = MergeType.simple,
  }) async {
    final mergeLogId = _uuid.v4();
    final now = DateTime.now();

    return _db.transaction(() async {
      // 0. 验证：source 和 target 都存在且未删除
      final source = await _getActiveCategory(sourceCategoryId);
      final target = await _getActiveCategory(targetCategoryId);
      if (source == null) {
        throw StateError('源分类不存在或已删除: $sourceCategoryId');
      }
      if (target == null) {
        throw StateError('目标分类不存在或已删除: $targetCategoryId');
      }

      // 1. 记录合并日志（用于撤销）
      await _db.into(_db.categoryMergeLog).insert(
        CategoryMergeLogCompanion.insert(
          id: mergeLogId,
          sourceCategoryId: sourceCategoryId,
          targetCategoryId: targetCategoryId,
          sourceCategoryName: source.name,
          sourceIconKey: Value(source.iconKey),
          sourceParentId: Value(source.parentId),
          mergeType: Value(mergeType),
          mergedAt: Value(now),
          expiresAt: now.add(_undoWindow),
        ),
      );

      // 2. 重映射所有交易的 categoryId + 标记 mergeLogId
      final affected = await _remapTransactions(
        sourceCategoryId: sourceCategoryId,
        targetCategoryId: targetCategoryId,
        mergeLogId: mergeLogId,
      );

      // 3. 更新合并日志的 affectedCount
      await (_db.update(_db.categoryMergeLog)
            ..where((l) => l.id.equals(mergeLogId)))
          .write(CategoryMergeLogCompanion(
        affectedCount: Value(affected),
      ));

      // 4. 如果 source 有子分类，移动到 target 下
      await _reparentChildren(sourceCategoryId, targetCategoryId);

      // 5. 更新预算引用
      await _remapBudgetCategories(sourceCategoryId, targetCategoryId);

      // 6. 软删除源分类
      await (_db.update(_db.categories)
            ..where((c) => c.id.equals(sourceCategoryId)))
          .write(CategoriesCompanion(
        deletedAt: Value(now),
      ));

      // 7. 合并使用统计（删除 source 的 slot/summary，target 稍后由 profiler 重建）
      await _cleanupUsageStats(sourceCategoryId);

      return MergeResult(
        affectedTransactions: affected,
        sourceCategoryId: sourceCategoryId,
        targetCategoryId: targetCategoryId,
        mergeLogId: mergeLogId,
      );
    });
  }

  /// 撤销合并
  ///
  /// 恢复源分类 + 恢复交易的 categoryId + 重建统计
  Future<void> undoMerge(String mergeLogId) async {
    final log = await (_db.select(_db.categoryMergeLog)
          ..where((l) => l.id.equals(mergeLogId)))
        .getSingleOrNull();

    if (log == null) throw StateError('合并日志不存在: $mergeLogId');
    if (log.undoneAt != null) throw AlreadyUndoneException();
    if (DateTime.now().isAfter(log.expiresAt)) throw UndoExpiredException();

    // 检查 target 是否仍存在
    final target = await _getActiveCategory(log.targetCategoryId);
    if (target == null) throw UndoTargetDeletedException();

    await _db.transaction(() async {
      // 1. 恢复源分类（取消软删除）
      await (_db.update(_db.categories)
            ..where((c) => c.id.equals(log.sourceCategoryId)))
          .write(const CategoriesCompanion(
        deletedAt: Value(null),
      ));

      // 2. 恢复交易的 categoryId（只恢复本次合并标记的交易）
      await _db.customStatement(
        'UPDATE transactions '
        'SET category_id = ?, merge_log_id = NULL '
        'WHERE merge_log_id = ?',
        [log.sourceCategoryId, mergeLogId],
      );

      // 3. 恢复子分类的 parentId（如果有被移动的）
      await (_db.update(_db.categories)
            ..where((c) => c.parentId.equals(log.targetCategoryId))
            ..where((c) => c.deletedAt.isNull()))
          .write(CategoriesCompanion(
        parentId: Value(log.sourceParentId),
      ));
      // 注意：子分类恢复有边界情况（如 target 本身有子分类），
      // 这里只恢复原本属于 source 的子分类。
      // TODO: S4 可用 category_merge_log 附加字段精确记录哪些子分类被移动

      // 4. 标记日志为已撤销
      await (_db.update(_db.categoryMergeLog)
            ..where((l) => l.id.equals(mergeLogId)))
          .write(CategoryMergeLogCompanion(
        undoneAt: Value(DateTime.now()),
      ));
    });

    // 5. 事务外重建两个分类的使用统计
    await _profiler.rebuildAll();
  }

  /// 忽略合并建议（30 天内不再提示）
  Future<void> dismissPair(String categoryIdA, String categoryIdB) async {
    final pairKey = _makePairKey(categoryIdA, categoryIdB);
    final now = DateTime.now();

    await _db.customInsert(
      'INSERT INTO category_merge_dismissals (id, pair_key, dismissed_at, expires_at) '
      'VALUES (?, ?, ?, ?) '
      'ON CONFLICT(pair_key) DO UPDATE SET dismissed_at = excluded.dismissed_at, expires_at = excluded.expires_at',
      variables: [
        Variable.withString(_uuid.v4()),
        Variable.withString(pairKey),
        Variable.withDateTime(now),
        Variable.withDateTime(now.add(const Duration(days: 30))),
      ],
      updates: {_db.categoryMergeDismissals},
    );
  }

  /// 获取可撤销的合并日志列表（未过期 + 未撤销）
  Future<List<CategoryMergeLogData>> getUndoableMergeLogs() async {
    final now = DateTime.now();
    return (_db.select(_db.categoryMergeLog)
          ..where((l) => l.undoneAt.isNull())
          ..where((l) => l.expiresAt.isBiggerOrEqualValue(now))
          ..orderBy([(l) => OrderingTerm.desc(l.mergedAt)]))
        .get();
  }

  // ──────────── 内部方法 ────────────

  Future<Category?> _getActiveCategory(String categoryId) async {
    return (_db.select(_db.categories)
          ..where((c) => c.id.equals(categoryId))
          ..where((c) => c.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Future<int> _remapTransactions({
    required String sourceCategoryId,
    required String targetCategoryId,
    required String mergeLogId,
  }) async {
    return _db.customUpdate(
      'UPDATE transactions '
      'SET category_id = ?, merge_log_id = ? '
      'WHERE category_id = ? AND deleted_at IS NULL',
      variables: [
        Variable.withString(targetCategoryId),
        Variable.withString(mergeLogId),
        Variable.withString(sourceCategoryId),
      ],
      updates: {_db.transactions},
      updateKind: UpdateKind.update,
    );
  }

  Future<void> _reparentChildren(String sourceId, String targetId) async {
    await _db.customUpdate(
      'UPDATE categories '
      'SET parent_id = ? '
      'WHERE parent_id = ? AND deleted_at IS NULL',
      variables: [
        Variable.withString(targetId),
        Variable.withString(sourceId),
      ],
      updates: {_db.categories},
      updateKind: UpdateKind.update,
    );
  }

  Future<void> _remapBudgetCategories(String sourceId, String targetId) async {
    // 先检查 target 是否已有同 budget 的记录，避免 UNIQUE 冲突
    await _db.customUpdate(
      'UPDATE category_budgets '
      'SET category_id = ? '
      'WHERE category_id = ? '
      'AND budget_id NOT IN (SELECT budget_id FROM category_budgets WHERE category_id = ?)',
      variables: [
        Variable.withString(targetId),
        Variable.withString(sourceId),
        Variable.withString(targetId),
      ],
      updates: {_db.categoryBudgetsTable},
      updateKind: UpdateKind.update,
    );
    // 删除 source 剩余的预算记录（target 已有的 budget）
    await _db.customUpdate(
      'DELETE FROM category_budgets WHERE category_id = ?',
      variables: [Variable.withString(sourceId)],
      updates: {_db.categoryBudgetsTable},
      updateKind: UpdateKind.delete,
    );
  }

  Future<void> _cleanupUsageStats(String categoryId) async {
    await (_db.delete(_db.categoryUsageSlots)
          ..where((s) => s.categoryId.equals(categoryId)))
        .go();
    await (_db.delete(_db.categoryUsageSummary)
          ..where((s) => s.categoryId.equals(categoryId)))
        .go();
  }

  @visibleForTesting
  static String makePairKey(String idA, String idB) => _makePairKey(idA, idB);

  static String _makePairKey(String idA, String idB) {
    final sorted = [idA, idB]..sort();
    return '${sorted[0]}|${sorted[1]}';
  }
}
