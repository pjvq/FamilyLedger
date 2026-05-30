import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

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
  String get recommendedRetainId => _recommendRetain(categoryA, categoryB);

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
    this.semantic = 0.00,
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

  /// 根据实际参与的维度归一化权重（MAJOR #8）
  MergeWeights normalize({required bool hasSemanticScorer}) {
    final effectiveText = text;
    final effectiveSemantic = hasSemanticScorer ? semantic : 0.0;
    final effectiveBehavior = behavior;
    final effectiveKeyword = keyword;

    final sum = effectiveText + effectiveSemantic + effectiveBehavior + effectiveKeyword;
    if (sum == 0) return this;

    return MergeWeights(
      text: effectiveText / sum,
      semantic: effectiveSemantic / sum,
      behavior: effectiveBehavior / sum,
      keyword: effectiveKeyword / sum,
    );
  }
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
  /// 进入详细评分的最大候选对数
  static const _maxDetailedPairs = 200;

  /// Pass 1 文本相似度阈值
  static const _textSimThreshold = 0.4;

  /// 最终合并建议置信度阈值
  static const _confidenceThreshold = 0.6;

  /// 生成 reason 时各维度的"显著"阈值
  static const _textReasonThreshold = 0.7;
  static const _behaviorReasonThreshold = 0.6;
  static const _keywordReasonThreshold = 0.3;
  static const _semanticReasonThreshold = 0.6;

  final AppDatabase _db;
  final CategoryUsageProfiler _profiler;
  final MergeWeights _rawWeights;

  /// 语义相似度回调（iOS 平台通道注入），返回 [0,1]
  final Future<double> Function(String, String)? semanticScorer;

  CategoryMergeDetector({
    required AppDatabase db,
    required CategoryUsageProfiler profiler,
    MergeWeights weights = const MergeWeights(),
    this.semanticScorer,
  })  : _db = db,
        _profiler = profiler,
        _rawWeights = weights;

  /// 扫描所有分类，生成合并建议列表（按置信度降序）
  Future<List<MergeSuggestion>> scan() async {
    // 归一化权重（MAJOR #8）
    final weights = _rawWeights.normalize(hasSemanticScorer: semanticScorer != null);

    // 获取所有未删除分类
    final categories = await (_db.select(_db.categories)
          ..where((c) => c.deletedAt.isNull()))
        .get();

    // 获取已忽略的配对
    final dismissedPairs = await _getDismissedPairs();

    // 获取所有画像
    final profiles = await _profiler.getAllProfiles();

    // === Pass 1: TextSimilarity 快速筛选 ===
    final candidates = _generateCandidates(categories);

    // 按 textSim 降序，截取前 _maxDetailedPairs
    candidates.sort((a, b) => b.textSim.compareTo(a.textSim));
    final topCandidates = candidates.take(_maxDetailedPairs).toList();

    // === Pass 2: 完整评分 ===
    final suggestions = <MergeSuggestion>[];

    for (final pair in topCandidates) {
      final pairKey = makePairKey(pair.catA.id, pair.catB.id);
      if (dismissedPairs.contains(pairKey)) continue;
      if (_isParentChild(pair.catA, pair.catB)) continue;

      final profileA = profiles[pair.catA.id] ?? CategoryUsageProfile(categoryId: pair.catA.id);
      final profileB = profiles[pair.catB.id] ?? CategoryUsageProfile(categoryId: pair.catB.id);

      // 各维度评分
      final textScore = pair.textSim;
      double semanticScore = 0;
      if (semanticScorer != null && weights.semantic > 0) {
        semanticScore = await semanticScorer!(pair.catA.name, pair.catB.name);
      }
      final behaviorScore = BehaviorOverlapScorer.score(profileA, profileB);
      final keywordScore = KeywordOverlapScorer.score(profileA, profileB);

      // 加权求和
      final confidence = weights.text * textScore +
          weights.semantic * semanticScore +
          weights.behavior * behaviorScore +
          weights.keyword * keywordScore;

      if (confidence >= _confidenceThreshold) {
        final reasons = <String>[];
        if (textScore >= _textReasonThreshold) reasons.add('名称相似(${(textScore * 100).round()}%)');
        if (behaviorScore >= _behaviorReasonThreshold) reasons.add('使用模式相近');
        if (keywordScore >= _keywordReasonThreshold) reasons.add('关键词重叠');
        if (semanticScore >= _semanticReasonThreshold) reasons.add('语义相近');

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
  /// 返回与新名称相似的已有分类列表
  List<MergeSuggestion> instantCheck(
    String newName,
    String newType,
    List<Category> existingCategories,
  ) {
    final suggestions = <MergeSuggestion>[];
    for (final existing in existingCategories) {
      if (existing.type != newType) continue;
      final sim = TextSimilarityScorer.score(newName, existing.name);
      if (sim >= _textReasonThreshold) {
        suggestions.add(MergeSuggestion(
          categoryA: existing,
          categoryB: existing, // 标记: 新分类尚未创建，这里填 existing 仅作参考
          confidence: sim,
          pairType: PairType.sameParent,
          reason: '与「${existing.name}」名称相似(${(sim * 100).round()}%)',
        ));
      }
    }
    suggestions.sort((a, b) => b.confidence.compareTo(a.confidence));
    return suggestions;
  }

  // ──────────── Pass 1: 候选生成 (MAJOR #6 优化) ────────────

  /// 生成候选对 — 使用 bigram 倒排索引剪枝，避免全量 O(n²)
  List<_CandidatePair> _generateCandidates(List<Category> categories) {
    final candidates = <_CandidatePair>[];

    // 按层级分组
    final parents = categories.where((c) => c.parentId == null).toList();
    final childrenByParent = <String, List<Category>>{};
    for (final c in categories.where((c) => c.parentId != null)) {
      childrenByParent.putIfAbsent(c.parentId!, () => []).add(c);
    }

    // 构建 bigram 倒排索引用于快速剪枝
    final bigramIndex = <String, List<int>>{}; // bigram → indices in categories
    for (var i = 0; i < categories.length; i++) {
      final name = categories[i].name;
      for (var j = 0; j < name.length - 1; j++) {
        final bg = name.substring(j, j + 2);
        bigramIndex.putIfAbsent(bg, () => []).add(i);
      }
    }

    // 用倒排索引找到共享至少一个 bigram 的候选对
    final seenPairs = <String>{};

    for (var i = 0; i < categories.length; i++) {
      final catA = categories[i];
      final nameA = catA.name;
      final candidateIndices = <int>{};

      for (var j = 0; j < nameA.length - 1; j++) {
        final bg = nameA.substring(j, j + 2);
        final indices = bigramIndex[bg];
        if (indices != null) {
          for (final idx in indices) {
            if (idx > i) candidateIndices.add(idx);
          }
        }
      }

      for (final j in candidateIndices) {
        final catB = categories[j];

        // 基本过滤
        if (catA.type != catB.type) continue;
        if (_isPresetPair(catA, catB)) continue;

        final pairId = '${catA.id}|${catB.id}';
        if (seenPairs.contains(pairId)) continue;
        seenPairs.add(pairId);

        final textSim = TextSimilarityScorer.score(catA.name, catB.name);
        if (textSim < _textSimThreshold) continue;

        // 确定配对类型
        final pairType = _classifyPair(catA, catB, childrenByParent);
        candidates.add(_CandidatePair(catA, catB, textSim, pairType));
      }
    }

    return candidates;
  }

  PairType _classifyPair(
    Category a,
    Category b,
    Map<String, List<Category>> childrenByParent,
  ) {
    final aIsParent = a.parentId == null;
    final bIsParent = b.parentId == null;

    if (aIsParent && bIsParent) {
      final aHasChildren = childrenByParent.containsKey(a.id);
      final bHasChildren = childrenByParent.containsKey(b.id);
      if (aHasChildren != bHasChildren) return PairType.parentVsLeaf;
      return PairType.parent;
    }

    if (!aIsParent && !bIsParent) {
      return a.parentId == b.parentId ? PairType.sameParent : PairType.crossParent;
    }

    return PairType.parentVsLeaf;
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

  /// 生成配对 key（字典序排列，确保唯一）
  @visibleForTesting
  static String makePairKey(String idA, String idB) {
    final sorted = [idA, idB]..sort();
    return '${sorted[0]}|${sorted[1]}';
  }
}
