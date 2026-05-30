import 'package:drift/drift.dart';

import '../../../data/local/database.dart';
import 'behavior_overlap_scorer.dart';
import 'category_usage_profile.dart';
import 'category_usage_profiler.dart';
import 'keyword_overlap_scorer.dart';
import 'text_similarity_scorer.dart';

/// 合并建议的配对类型
enum PairType { sameParent, crossParent, parent, parentVsLeaf }

/// 合并建议
class MergeSuggestion {
  final Category categoryA;
  final Category categoryB;
  final double confidence;
  final PairType pairType;
  final String reason;

  const MergeSuggestion({
    required this.categoryA,
    required this.categoryB,
    required this.confidence,
    required this.pairType,
    required this.reason,
  });

  /// 建议保留哪个分类 ID
  String get recommendedRetainId =>
      _recommendRetain(categoryA, categoryB);

  static String _recommendRetain(Category a, Category b) {
    // 1. 预设 > 用户自定义
    if (a.isPreset && !b.isPreset) return a.id;
    if (b.isPreset && !a.isPreset) return b.id;
    // 2. 名字短的更通用
    if (a.name.length < b.name.length) return a.id;
    if (b.name.length < a.name.length) return b.id;
    // 3. 字典序小的
    return a.id.compareTo(b.id) <= 0 ? a.id : b.id;
  }
}

/// 合并检测权重配置
class MergeWeights {
  final double text;
  final double semantic;
  final double behavior;
  final double keyword;

  const MergeWeights({
    this.text = 0.50,
    this.semantic = 0.00, // 默认无语义层（需 iOS NLEmbedding）
    this.behavior = 0.30,
    this.keyword = 0.20,
  });

  /// iOS 有语义层时的权重
  static const withSemantic = MergeWeights(
    text: 0.35,
    semantic: 0.30,
    behavior: 0.20,
    keyword: 0.15,
  );
}

/// 候选对内部表示
class _CandidatePair {
  final Category catA;
  final Category catB;
  final double textSim;
  final PairType pairType;

  _CandidatePair(this.catA, this.catB, this.textSim, this.pairType);
}

/// 分类合并检测器
/// 两阶段筛选：Pass 1 快速 TextSimilarity → Pass 2 完整评分
class CategoryMergeDetector {
  static const _maxDetailedPairs = 200;
  static const _textSimThreshold = 0.4;
  static const _confidenceThreshold = 0.6;

  final AppDatabase _db;
  final CategoryUsageProfiler _profiler;
  final MergeWeights _weights;

  /// 语义相似度回调（iOS 平台通道注入），返回 [0,1]
  final Future<double> Function(String, String)? semanticScorer;

  CategoryMergeDetector({
    required AppDatabase db,
    required CategoryUsageProfiler profiler,
    MergeWeights weights = const MergeWeights(),
    this.semanticScorer,
  })  : _db = db,
        _profiler = profiler,
        _weights = weights;

  /// 扫描所有分类，生成合并建议列表（按置信度降序）
  Future<List<MergeSuggestion>> scan() async {
    // 获取所有未删除分类
    final categories = await (_db.select(_db.categories)
          ..where((c) => c.deletedAt.isNull()))
        .get();

    // 获取已忽略的配对
    final dismissedPairs = await _getDismissedPairs();

    // 获取所有画像
    final profiles = await _profiler.getAllProfiles();

    // === Pass 1: TextSimilarity 快速筛选 ===
    final candidates = <_CandidatePair>[];

    // 按层级分组
    final parents = categories.where((c) => c.parentId == null).toList();
    final childrenByParent = <String, List<Category>>{};
    for (final c in categories.where((c) => c.parentId != null)) {
      childrenByParent.putIfAbsent(c.parentId!, () => []).add(c);
    }

    // 1. 父分类间
    for (var i = 0; i < parents.length; i++) {
      for (var j = i + 1; j < parents.length; j++) {
        if (parents[i].type != parents[j].type) continue;
        if (_isPresetPair(parents[i], parents[j])) continue;
        final textSim = TextSimilarityScorer.score(parents[i].name, parents[j].name);
        if (textSim >= _textSimThreshold) {
          candidates.add(_CandidatePair(parents[i], parents[j], textSim, PairType.parent));
        }
      }
    }

    // 2. 同一父级下子分类间
    for (final group in childrenByParent.values) {
      for (var i = 0; i < group.length; i++) {
        for (var j = i + 1; j < group.length; j++) {
          if (group[i].type != group[j].type) continue;
          final textSim = TextSimilarityScorer.score(group[i].name, group[j].name);
          if (textSim >= _textSimThreshold) {
            candidates.add(_CandidatePair(group[i], group[j], textSim, PairType.sameParent));
          }
        }
      }
    }

    // 3. 不同父级下子分类间
    final parentIds = childrenByParent.keys.toList();
    for (var i = 0; i < parentIds.length; i++) {
      for (var j = i + 1; j < parentIds.length; j++) {
        final groupA = childrenByParent[parentIds[i]]!;
        final groupB = childrenByParent[parentIds[j]]!;
        for (final a in groupA) {
          for (final b in groupB) {
            if (a.type != b.type) continue;
            final textSim = TextSimilarityScorer.score(a.name, b.name);
            if (textSim >= _textSimThreshold) {
              candidates.add(_CandidatePair(a, b, textSim, PairType.crossParent));
            }
          }
        }
      }
    }

    // 4. 父 vs 叶子（无子分类的父级 vs 有子分类的父级情况已在 1 处理）
    // 这里检测有子分类的父级 vs 无子分类的同类型一级分类
    for (final parent in parents) {
      if (!childrenByParent.containsKey(parent.id)) continue; // 跳过无子分类的
      for (final leaf in parents) {
        if (leaf.id == parent.id) continue;
        if (leaf.type != parent.type) continue;
        if (childrenByParent.containsKey(leaf.id)) continue; // 跳过有子分类的
        final textSim = TextSimilarityScorer.score(parent.name, leaf.name);
        if (textSim >= _textSimThreshold) {
          candidates.add(_CandidatePair(parent, leaf, textSim, PairType.parentVsLeaf));
        }
      }
    }

    // 按 textSim 降序，截取前 _maxDetailedPairs
    candidates.sort((a, b) => b.textSim.compareTo(a.textSim));
    final topCandidates = candidates.take(_maxDetailedPairs).toList();

    // === Pass 2: 完整评分 ===
    final suggestions = <MergeSuggestion>[];

    for (final pair in topCandidates) {
      final pairKey = _makePairKey(pair.catA.id, pair.catB.id);
      if (dismissedPairs.contains(pairKey)) continue;
      if (_isParentChild(pair.catA, pair.catB)) continue;

      final profileA = profiles[pair.catA.id] ?? CategoryUsageProfile(categoryId: pair.catA.id);
      final profileB = profiles[pair.catB.id] ?? CategoryUsageProfile(categoryId: pair.catB.id);

      // 各维度评分
      final textScore = pair.textSim;
      double semanticScore = 0;
      if (semanticScorer != null && _weights.semantic > 0) {
        semanticScore = await semanticScorer!(pair.catA.name, pair.catB.name);
      }
      final behaviorScore = BehaviorOverlapScorer.score(profileA, profileB);
      final keywordScore = KeywordOverlapScorer.score(profileA, profileB);

      // 加权求和
      final confidence = _weights.text * textScore +
          _weights.semantic * semanticScore +
          _weights.behavior * behaviorScore +
          _weights.keyword * keywordScore;

      if (confidence >= _confidenceThreshold) {
        final reasons = <String>[];
        if (textScore >= 0.7) reasons.add('名称相似(${(textScore * 100).round()}%)');
        if (behaviorScore >= 0.6) reasons.add('使用模式相近');
        if (keywordScore >= 0.3) reasons.add('关键词重叠');
        if (semanticScore >= 0.6) reasons.add('语义相近');

        suggestions.add(MergeSuggestion(
          categoryA: pair.catA,
          categoryB: pair.catB,
          confidence: confidence,
          pairType: pair.pairType,
          reason: reasons.join(' + '),
        ));
      }
    }

    suggestions.sort((a, b) => b.confidence.compareTo(a.confidence));
    return suggestions;
  }

  /// 创建分类时即时检测（只用 TextSimilarity，<1ms）
  List<MergeSuggestion> instantCheck(
    String newName,
    String newType,
    List<Category> existingCategories,
  ) {
    final suggestions = <MergeSuggestion>[];
    for (final existing in existingCategories) {
      if (existing.type != newType) continue;
      final sim = TextSimilarityScorer.score(newName, existing.name);
      if (sim >= 0.7) {
        suggestions.add(MergeSuggestion(
          categoryA: existing,
          categoryB: existing, // placeholder, 新分类还没创建
          confidence: sim,
          pairType: PairType.sameParent,
          reason: '名称相似(${(sim * 100).round()}%)',
        ));
      }
    }
    suggestions.sort((a, b) => b.confidence.compareTo(a.confidence));
    return suggestions;
  }

  // ──────────── 内部方法 ────────────

  Future<Set<String>> _getDismissedPairs() async {
    final now = DateTime.now();
    final dismissals = await (_db.select(_db.categoryMergeDismissals)
          ..where((d) => d.expiresAt.isBiggerOrEqualValue(now)))
        .get();
    return dismissals.map((d) => d.pairKey).toSet();
  }

  bool _isPresetPair(Category a, Category b) => a.isPreset && b.isPreset;

  bool _isParentChild(Category a, Category b) =>
      a.parentId == b.id || b.parentId == a.id;

  static String _makePairKey(String idA, String idB) {
    final sorted = [idA, idB]..sort();
    return '${sorted[0]}|${sorted[1]}';
  }
}
