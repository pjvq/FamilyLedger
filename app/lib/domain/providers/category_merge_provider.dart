import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../services/smart_category/category_merge_detector.dart';
import '../services/smart_category/category_merge_executor.dart';
import '../services/smart_category/category_usage_profiler.dart';
import 'app_providers.dart';

/// CategoryUsageProfiler — 单例
final categoryUsageProfilerProvider = Provider<CategoryUsageProfiler>((ref) {
  final db = ref.watch(databaseProvider);
  return CategoryUsageProfiler(db);
});

/// CategoryMergeDetector — 单例
final categoryMergeDetectorProvider = Provider<CategoryMergeDetector>((ref) {
  final db = ref.watch(databaseProvider);
  final profiler = ref.watch(categoryUsageProfilerProvider);
  return CategoryMergeDetector(
    db: db,
    profiler: profiler,
  );
});

/// CategoryMergeExecutor — 单例
final categoryMergeExecutorProvider = Provider<CategoryMergeExecutor>((ref) {
  final db = ref.watch(databaseProvider);
  final profiler = ref.watch(categoryUsageProfilerProvider);
  return CategoryMergeExecutor(db: db, profiler: profiler);
});

/// 合并建议列表（异步按需加载）
final categoryMergeSuggestionsProvider =
    FutureProvider.autoDispose<List<MergeSuggestion>>((ref) async {
  final detector = ref.watch(categoryMergeDetectorProvider);
  return detector.scan();
});

/// 可撤销的合并日志
final undoableMergeLogsProvider =
    FutureProvider.autoDispose<List<CategoryMergeLogData>>((ref) async {
  final executor = ref.watch(categoryMergeExecutorProvider);
  return executor.getUndoableMergeLogs();
});

/// 合并操作 Notifier（执行合并 / 撤销 / 忽略，自动 invalidate 建议列表）
class CategoryMergeActionsNotifier extends Notifier<void> {
  @override
  void build() {}

  /// 执行合并
  Future<MergeResult> merge({
    required String sourceCategoryId,
    required String targetCategoryId,
    String mergeType = MergeType.simple,
  }) async {
    final executor = ref.read(categoryMergeExecutorProvider);
    final result = await executor.executeMerge(
      sourceCategoryId: sourceCategoryId,
      targetCategoryId: targetCategoryId,
      mergeType: mergeType,
    );
    _invalidateAll();
    return result;
  }

  /// 撤销合并
  Future<void> undo(String mergeLogId) async {
    final executor = ref.read(categoryMergeExecutorProvider);
    await executor.undoMerge(mergeLogId);
    _invalidateAll();
  }

  /// 忽略配对（30 天内不再提示）
  Future<void> dismiss(String categoryIdA, String categoryIdB) async {
    final executor = ref.read(categoryMergeExecutorProvider);
    await executor.dismissPair(categoryIdA, categoryIdB);
    _invalidateAll();
  }

  void _invalidateAll() {
    ref.invalidate(categoryMergeSuggestionsProvider);
    ref.invalidate(undoableMergeLogsProvider);
  }
}

final categoryMergeActionsProvider =
    NotifierProvider<CategoryMergeActionsNotifier, void>(
  CategoryMergeActionsNotifier.new,
);
