import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../services/smart_category/category_merge_detector.dart';
import '../services/smart_category/category_merge_executor.dart';
import '../services/smart_category/category_usage_profiler.dart';
import '../services/smart_category/nl_embedding_bridge.dart';
import '../services/smart_category/semantic_scorer.dart';
import 'app_providers.dart';
import 'transaction_provider.dart';

/// CategoryUsageProfiler — 单例，keepAlive 确保生命周期
final categoryUsageProfilerProvider = Provider<CategoryUsageProfiler>((ref) {
  ref.keepAlive();
  final db = ref.watch(databaseProvider);
  final profiler = CategoryUsageProfiler(db);

  // 周期性后台刷新 topKeywords + recency counts
  // 每 6 小时刷新 recency，每周全量重建
  Timer? recencyTimer;
  Timer? fullRebuildTimer;
  // NOTE: 内存变量，进程重启后丢失。冷启动后首次 hourly check 会触发 rebuildAll，
  // 这是可接受的——rebuildAll 本身是幂等操作且耗时不长（< 1s），
  // 作为 trade-off 避免引入 SharedPreferences 依赖。
  DateTime? lastFullRebuildAt;

  recencyTimer = Timer.periodic(const Duration(hours: 6), (_) async {
    try {
      await profiler.refreshRecencyCounts();
    } catch (e, st) {
      // 降级：刷新失败不影响应用运行，下次 Timer 触发重试
      // TODO: 接入 metrics、Crashlytics 等可观测性基础设施
      assert(() {
        // ignore: avoid_print
        print('[CategoryUsageProfiler] refreshRecencyCounts failed: $e\n$st');
        return true;
      }());
    }
  });

  fullRebuildTimer = Timer.periodic(const Duration(hours: 1), (_) async {
    // 持久化时间戳检查，而非依赖 7天 Timer（杀进程后重置）
    final now = DateTime.now();
    if (lastFullRebuildAt != null &&
        now.difference(lastFullRebuildAt!).inDays < 7) {
      return;
    }
    try {
      await profiler.rebuildAll();
      lastFullRebuildAt = now;
    } catch (e, st) {
      assert(() {
        // ignore: avoid_print
        print('[CategoryUsageProfiler] rebuildAll failed: $e\n$st');
        return true;
      }());
    }
  });

  ref.onDispose(() {
    recencyTimer?.cancel();
    fullRebuildTimer?.cancel();
  });

  return profiler;
});

/// NLEmbeddingBridge — 实例化平台通道（可注入替换）
final nlEmbeddingBridgeProvider = Provider<NLEmbeddingBridge>((ref) {
  ref.keepAlive();
  return NLEmbeddingBridge();
});

/// SemanticScorer — 单例，通过 bridge 注入实现（DIP）
final semanticScorerProvider = Provider<SemanticScorer>((ref) {
  ref.keepAlive();
  final bridge = ref.watch(nlEmbeddingBridgeProvider);
  return SemanticScorer(
    checkAvailable: bridge.checkAvailable,
    getDistance: bridge.distance,
    getBatchDistances: bridge.batchDistances,
  );
});

/// CategoryMergeDetector — 异步初始化（探测 NLEmbedding 可用性）
final categoryMergeDetectorProvider =
    FutureProvider<CategoryMergeDetector>((ref) async {
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

/// 合并建议列表（CRITICAL #3 — 正确传播 loading/error 状态）
final categoryMergeSuggestionsProvider =
    FutureProvider<List<MergeSuggestion>>((ref) async {
  ref.keepAlive();
  // 等待 detector 初始化完成（传播 loading/error）
  final detector = await ref.watch(categoryMergeDetectorProvider.future);
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

    // 入队同步（失败不影响本地合并结果）
    try {
      final syncQueue = ref.read(offlineSyncQueueProvider);
      await syncQueue.enqueueUpdate(
        entityType: 'category_merge',
        entityId: result.mergeLogId,
        payload: {
          'source_category_id': sourceCategoryId,
          'target_category_id': targetCategoryId,
        },
      );
    } catch (_) {
      // enqueue 失败不阻塞本地合并，下次同步时会重试
    }

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
