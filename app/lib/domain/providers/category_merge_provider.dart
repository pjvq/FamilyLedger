import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../services/smart_category/category_merge_detector.dart';
import '../services/smart_category/category_merge_executor.dart';
import '../services/smart_category/category_usage_profiler.dart';
import '../services/smart_category/semantic_scorer.dart';
import 'app_providers.dart';

/// CategoryUsageProfiler — 单例，keepAlive 确保生命周期（MAJOR #7）
final categoryUsageProfilerProvider = Provider<CategoryUsageProfiler>((ref) {
  ref.keepAlive();
  final db = ref.watch(databaseProvider);
  return CategoryUsageProfiler(db);
});

/// SemanticScorer — 单例，keepAlive
final semanticScorerProvider = Provider<SemanticScorer>((ref) {
  ref.keepAlive();
  return SemanticScorer();
});

/// CategoryMergeDetector — 单例，keepAlive。
/// 异步初始化以探测 NLEmbedding 可用性，注入语义回调 + 动态权重。
final categoryMergeDetectorProvider = FutureProvider<CategoryMergeDetector>((ref) async {
  ref.keepAlive();
  final db = ref.watch(databaseProvider);
  final profiler = ref.watch(categoryUsageProfilerProvider);
  final semantic = ref.watch(semanticScorerProvider);

  final hasSemantics = await semantic.isAvailable;

  return CategoryMergeDetector(
    db: db,
    profiler: profiler,
    weights: hasSemantics ? MergeWeights.withSemantic : const MergeWeights(),
    semanticScorer: hasSemantics
        ? (a, b) async => (await semantic.score(a, b)) ?? 0.0
        : null,
  );
});

/// CategoryMergeExecutor — 单例，keepAlive
final categoryMergeExecutorProvider = Provider<CategoryMergeExecutor>((ref) {
  ref.keepAlive();
  final db = ref.watch(databaseProvider);
  final profiler = ref.watch(categoryUsageProfilerProvider);
  return CategoryMergeExecutor(db: db, profiler: profiler);
});

/// 合并建议列表（带缓存，手动 invalidate 刷新）
final categoryMergeSuggestionsProvider =
    FutureProvider<List<MergeSuggestion>>((ref) async {
  ref.keepAlive();
  final detectorAsync = ref.watch(categoryMergeDetectorProvider);
  final detector = detectorAsync.valueOrNull;
  if (detector == null) return [];
  return detector.scan();
});

/// 可撤销的合并日志
final undoableMergeLogsProvider =
    FutureProvider<List<CategoryMergeLogData>>((ref) async {
  ref.keepAlive();
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
