import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

import '../../../data/local/database.dart';
import 'category_merge_detector.dart';
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

  /// 从 PairType 推导 MergeType（exhaustive switch expression — MAJOR #C）
  static String fromPairType(PairType pairType) => switch (pairType) {
        PairType.sameParent => simple,
        PairType.crossParent => crossParent,
        PairType.parent => parentMerge,
        PairType.parentVsLeaf => moveOnly,
      };
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
/// ⚠️ 必须单例使用（通过 DI 注入同一实例）
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

  /// 执行合并
  ///
  /// [sourceCategoryId] 将被软删除的分类
  /// [targetCategoryId] 保留的分类
  Future<MergeResult> executeMerge({
    required String sourceCategoryId,
    required String targetCategoryId,
    String mergeType = MergeType.simple,
  }) async {
    if (sourceCategoryId == targetCategoryId) {
      throw ArgumentError('源分类和目标分类不能相同: $sourceCategoryId');
    }

    final mergeLogId = _uuid.v4();
    final now = DateTime.now();

    return _db.transaction(() async {
      // 0. 验证
      final source = await _getActiveCategory(sourceCategoryId);
      final target = await _getActiveCategory(targetCategoryId);
      if (source == null) {
        throw StateError('源分类不存在或已删除: $sourceCategoryId');
      }
      if (target == null) {
        throw StateError('目标分类不存在或已删除: $targetCategoryId');
      }

      // 1. 记录被 reparent 的子分类 ID（持久化到 merge_log）
      final reparentedChildren = await (_db.select(_db.categories)
            ..where((c) => c.parentId.equals(sourceCategoryId))
            ..where((c) => c.deletedAt.isNull()))
          .get();
      final reparentedChildIds = reparentedChildren.map((c) => c.id).toList();

      // 2. 写入合并日志（含 reparentedChildIds）
      await _db.into(_db.categoryMergeLog).insert(
        CategoryMergeLogCompanion.insert(
          id: mergeLogId,
          sourceCategoryId: sourceCategoryId,
          targetCategoryId: targetCategoryId,
          sourceCategoryName: source.name,
          sourceIconKey: Value(source.iconKey),
          sourceParentId: Value(source.parentId),
          reparentedChildIds: Value(jsonEncode(reparentedChildIds)),
          mergeType: Value(mergeType),
          mergedAt: Value(now),
          expiresAt: now.add(_undoWindow),
        ),
      );

      // 3. 重映射交易
      final affected = await _remapTransactions(
        sourceCategoryId: sourceCategoryId,
        targetCategoryId: targetCategoryId,
        mergeLogId: mergeLogId,
      );

      // 4. 更新 affectedCount
      await (_db.update(_db.categoryMergeLog)
            ..where((l) => l.id.equals(mergeLogId)))
          .write(CategoryMergeLogCompanion(
        affectedCount: Value(affected),
      ));

      // 5. 移动子分类
      if (reparentedChildIds.isNotEmpty) {
        await _reparentChildren(sourceCategoryId, targetCategoryId);
      }

      // 6. 更新预算引用
      await _remapBudgetCategories(sourceCategoryId, targetCategoryId);

      // 7. 软删除源分类
      await (_db.update(_db.categories)
            ..where((c) => c.id.equals(sourceCategoryId)))
          .write(CategoriesCompanion(deletedAt: Value(now)));

      // 8. 清理使用统计
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
  Future<void> undoMerge(String mergeLogId) async {
    final log = await (_db.select(_db.categoryMergeLog)
          ..where((l) => l.id.equals(mergeLogId)))
        .getSingleOrNull();

    if (log == null) throw StateError('合并日志不存在: $mergeLogId');
    if (log.undoneAt != null) throw AlreadyUndoneException();
    if (DateTime.now().isAfter(log.expiresAt)) throw UndoExpiredException();

    final target = await _getActiveCategory(log.targetCategoryId);
    if (target == null) throw UndoTargetDeletedException();

    // 解析持久化的 reparentedChildIds
    List<String> reparentedChildIds;
    try {
      reparentedChildIds =
          (jsonDecode(log.reparentedChildIds) as List).cast<String>();
    } catch (_) {
      reparentedChildIds = [];
    }

    await _db.transaction(() async {
      // 1. 恢复源分类
      await (_db.update(_db.categories)
            ..where((c) => c.id.equals(log.sourceCategoryId)))
          .write(const CategoriesCompanion(deletedAt: Value(null)));

      // 2. 恢复交易 categoryId（只恢复本次合并标记的）
      await _db.customUpdate(
        'UPDATE transactions '
        'SET category_id = ?, merge_log_id = NULL '
        'WHERE merge_log_id = ?',
        variables: [
          Variable.withString(log.sourceCategoryId),
          Variable.withString(mergeLogId),
        ],
        updates: {_db.transactions},
        updateKind: UpdateKind.update,
      );

      // 3. 精确恢复子分类（只恢复 merge 时记录的那些）
      if (reparentedChildIds.isNotEmpty) {
        // 用 IN 子句恢复精确的子分类 parentId
        final placeholders =
            List.generate(reparentedChildIds.length, (_) => '?').join(', ');
        await _db.customUpdate(
          'UPDATE categories '
          'SET parent_id = ? '
          'WHERE id IN ($placeholders)',
          variables: [
            Variable.withString(log.sourceCategoryId),
            ...reparentedChildIds.map(Variable.withString),
          ],
          updates: {_db.categories},
          updateKind: UpdateKind.update,
        );
      }

      // 4. 标记已撤销
      await (_db.update(_db.categoryMergeLog)
            ..where((l) => l.id.equals(mergeLogId)))
          .write(CategoryMergeLogCompanion(
        undoneAt: Value(DateTime.now()),
      ));
    });

    // 5. 重建统计
    await _profiler.rebuildAll();
  }

  /// 忽略合并建议（30 天内不再提示）
  Future<void> dismissPair(String categoryIdA, String categoryIdB) async {
    final pairKey = CategoryMergeDetector.makePairKey(categoryIdA, categoryIdB);
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

  /// 获取可撤销的合并日志
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
  static String makePairKey(String idA, String idB) =>
      CategoryMergeDetector.makePairKey(idA, idB);
}
