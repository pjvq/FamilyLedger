import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../services/smart_category/category_recommender.dart';
import '../services/smart_category/category_usage_profile.dart';
import 'app_providers.dart';
import 'category_merge_provider.dart';
import 'transaction_provider.dart';

/// 推荐输入 — 用于 family provider
final categoryRecommendInputProvider =
    StateProvider<CategoryRecommendInput>((ref) {
  return const CategoryRecommendInput(typeIndex: 0);
});

/// 转移矩阵 — 从最近 200 笔交易构建，惰性重建
final _sequenceScorerProvider = FutureProvider<SequenceScorer>((ref) async {
  // 依赖 transactions 列表变化来 invalidate
  final txns = ref.watch(transactionProvider.select((s) => s.transactions));

  // 取最近 200 笔的 categoryId 列表（按时间倒序）
  final recentIds = <String>[];
  for (var i = 0; i < txns.length && recentIds.length < 200; i++) {
    recentIds.add(txns[i].categoryId);
  }

  final matrix = SequenceScorer.buildMatrix(recentIds);
  return SequenceScorer(matrix);
});

/// 分类推荐结果 — 响应式更新
final categoryRecommendProvider =
    FutureProvider<List<CategoryRecommendation>>((ref) async {
  final input = ref.watch(categoryRecommendInputProvider);
  final profiler = ref.watch(categoryUsageProfilerProvider);
  final sequenceScorerAsync = ref.watch(_sequenceScorerProvider);

  // 等待 sequence scorer
  final sequenceScorer = sequenceScorerAsync.when(
    data: (s) => s,
    loading: () => const SequenceScorer({}),
    error: (_, __) => const SequenceScorer({}),
  );

  // 获取所有分类画像
  final allProfiles = await profiler.getAllProfiles();

  // 过滤当前类型的活跃分类
  final categories = input.typeIndex == 0
      ? ref.read(transactionProvider.select((s) => s.expenseCategories))
      : ref.read(transactionProvider.select((s) => s.incomeCategories));
  final activeIds = {
    for (final c in categories)
      if (c.deletedAt == null) c.id,
  };

  final profiles = allProfiles.entries
      .where((e) => activeIds.contains(e.key))
      .map((e) => e.value)
      .toList();

  if (profiles.isEmpty) return [];

  // 计算总交易量，决定用普通还是冷启动配置
  final totalTxns =
      profiles.fold<int>(0, (sum, p) => sum + p.totalCount);
  final config = CategoryRecommender.coldStartConfig(totalTxns);
  final recommender = CategoryRecommender(config: config);

  return recommender.recommend(
    profiles: profiles,
    sequenceScorer: sequenceScorer,
    input: input,
  );
});
