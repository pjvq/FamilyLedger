import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/smart_category/category_recommender.dart';
import '../services/smart_category/category_usage_profile.dart';
import 'category_merge_provider.dart';
import 'transaction_provider.dart';

/// 推荐输入 — 用于 family provider
final categoryRecommendInputProvider =
    StateProvider<CategoryRecommendInput>((ref) {
  return const CategoryRecommendInput(typeIndex: 0);
});

/// 转移矩阵 — 从最近 200 笔交易构建，惰性重建
final sequenceScorerProvider = FutureProvider<SequenceScorer>((ref) async {
  // Watch transaction count as stable invalidation signal
  final txnCount = ref.watch(
    transactionProvider.select((s) => s.transactions.length),
  );
  if (txnCount == 0) return const SequenceScorer({});

  // 取最近 200 笔的 categoryId 列表（按时间倒序）
  final txns = ref.read(transactionProvider).transactions;
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

  // 等待 sequence scorer 加载完成
  final sequenceScorer = await ref.watch(sequenceScorerProvider.future);

  // 获取所有分类画像
  final allProfiles = await profiler.getAllProfiles();

  // 过滤当前类型的活跃分类
  final categories = input.typeIndex == 0
      ? ref.watch(transactionProvider.select((s) => s.expenseCategories))
      : ref.watch(transactionProvider.select((s) => s.incomeCategories));
  final activeIds = {
    for (final c in categories)
      if (c.deletedAt == null) c.id,
  };

  // 统一单循环构建 profiles，避免双段逻辑耦合
  final profiles = <CategoryUsageProfile>[
    for (final id in activeIds)
      allProfiles[id] ?? CategoryUsageProfile(categoryId: id),
  ];

  if (profiles.isEmpty) return [];

  // 分类名称映射（用于冷启动时间段先验）
  final categoryNames = {
    for (final c in categories)
      if (c.deletedAt == null) c.id: c.name,
  };

  // 计算总交易量，决定用普通还是冷启动配置
  final totalTxns =
      profiles.fold<int>(0, (sum, p) => sum + p.totalCount);
  final config = CategoryRecommender.coldStartConfig(totalTxns);
  final recommender = CategoryRecommender();

  return recommender.recommend(
    profiles: profiles,
    sequenceScorer: sequenceScorer,
    input: input,
    config: config,
    booster: ColdStartBooster(categoryNames: categoryNames),
  );
});
