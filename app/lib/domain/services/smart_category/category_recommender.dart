import 'dart:math';
import 'category_usage_profile.dart';
import 'category_usage_profiler.dart';

/// 推荐系统配置权重
class RecommenderConfig {
  final double timeSlotWeight;
  final double recencyWeight;
  final double frequencyWeight;
  final double amountWeight;
  final double sequenceWeight;
  final double keywordWeight;

  const RecommenderConfig({
    this.timeSlotWeight = 0.25,
    this.recencyWeight = 0.20,
    this.frequencyWeight = 0.15,
    this.amountWeight = 0.20,
    this.sequenceWeight = 0.10,
    this.keywordWeight = 0.10,
  });
}

// ─── TimeSlotScorer ──────────────────────────────────────────────────────────

/// 根据当前时间在该分类的历史小时分布中的概率打分
class TimeSlotScorer {
  const TimeSlotScorer();

  /// 平滑后的小时概率（当前小时 ± 1 小时的平均）
  static double smoothedProb(CategoryUsageProfile profile, int hour) {
    final hp = profile.hourProbability;
    return (hp[(hour - 1) % 24] + hp[hour] + hp[(hour + 1) % 24]) / 3;
  }

  /// [maxHourProb] 是所有候选分类中最大的 smoothedProb 值，用于归一化
  double score(CategoryUsageProfile profile, int hour, double maxHourProb) {
    if (maxHourProb <= 0) return 0;
    return smoothedProb(profile, hour) / maxHourProb;
  }
}

// ─── RecencyScorer ───────────────────────────────────────────────────────────

/// 近 7 天使用次数 / max(所有分类近7天次数)
class RecencyScorer {
  const RecencyScorer();

  double score(CategoryUsageProfile profile, int maxLast7d) {
    if (maxLast7d <= 0) return 0;
    return profile.last7dCount / maxLast7d;
  }
}

// ─── FrequencyScorer ─────────────────────────────────────────────────────────

/// 总使用次数 / max(所有分类总次数)
class FrequencyScorer {
  const FrequencyScorer();

  double score(CategoryUsageProfile profile, int maxTotal) {
    if (maxTotal <= 0) return 0;
    return profile.totalCount / maxTotal;
  }
}

// ─── AmountRangeScorer ───────────────────────────────────────────────────────

/// 当前金额落在该分类金额区间的概率
class AmountRangeScorer {
  const AmountRangeScorer();

  double score(CategoryUsageProfile profile, int? amountCents) {
    if (amountCents == null || amountCents == 0) return 0;
    final bucket = CategoryUsageProfile.amountToBucket(amountCents.abs());
    return profile.amountProbability[bucket];
  }
}

// ─── SequenceScorer ──────────────────────────────────────────────────────────

/// 基于最近 N 笔交易建立转移矩阵，计算转移概率
class SequenceScorer {
  /// 转移矩阵: fromCategoryId → { toCategoryId → probability }
  final Map<String, Map<String, double>> transitionMatrix;

  const SequenceScorer(this.transitionMatrix);

  double score(String? lastCategoryId, String candidateId) {
    if (lastCategoryId == null) return 0;
    final transitions = transitionMatrix[lastCategoryId];
    if (transitions == null) return 0;
    return transitions[candidateId] ?? 0;
  }

  /// 从有序交易列表構建转移矩阵
  /// [categoryIds] 按时间倒序排列的分类 ID 列表（最新在前）
  /// 转移方向：from=较早交易分类 → to=紧随其后的交易分类
  static Map<String, Map<String, double>> buildMatrix(
    List<String> categoryIds,
  ) {
    if (categoryIds.length < 2) return {};

    // 统计相邻对 (从旧到新方向: i+1 → i，因为 list 是倒序)
    final counts = <String, Map<String, int>>{};
    for (var i = categoryIds.length - 1; i > 0; i--) {
      final from = categoryIds[i];
      final to = categoryIds[i - 1];
      final inner = counts.putIfAbsent(from, () => {});
      inner[to] = (inner[to] ?? 0) + 1;
    }

    // 转为概率
    final matrix = <String, Map<String, double>>{};
    for (final entry in counts.entries) {
      final total = entry.value.values.fold<int>(0, (a, b) => a + b);
      if (total == 0) continue;
      matrix[entry.key] = {
        for (final e in entry.value.entries) e.key: e.value / total,
      };
    }
    return matrix;
  }
}

// ─── KeywordScorer ───────────────────────────────────────────────────────────

/// 备注文本与该分类 topKeywords 的匹配度
class KeywordScorer {
  /// 匹配多少个关键词即满分
  static const _matchesForFullScore = 2;

  const KeywordScorer();

  double score(CategoryUsageProfile profile, String? noteText) {
    if (noteText == null || noteText.isEmpty) return 0;
    if (profile.topKeywords.isEmpty) return 0;
    final words = tokenize(noteText);
    final keywords = profile.topKeywords.toSet();
    final matches = words.where((w) => keywords.contains(w)).length;
    return min(1.0, matches / _matchesForFullScore);
  }

  /// 分词器 — 委托给 CategoryUsageProfiler.tokenize（保证和关键词提取用同一分词策略）
  static List<String> tokenize(String text) =>
      CategoryUsageProfiler.tokenize(text);
}

// ─── CategoryRecommender ─────────────────────────────────────────────────────

/// 推荐输入参数
class CategoryRecommendInput {
  final int typeIndex; // 0=支出, 1=收入
  final int? amountCents;
  final String? noteText;
  final String? lastCategoryId;
  final DateTime? now; // for testing; defaults to DateTime.now()

  const CategoryRecommendInput({
    required this.typeIndex,
    this.amountCents,
    this.noteText,
    this.lastCategoryId,
    this.now,
  });
}

/// 推荐结果
class CategoryRecommendation {
  final String categoryId;
  final double score;

  const CategoryRecommendation({required this.categoryId, required this.score});
}

// ─── ScoreBooster ─────────────────────────────────────────────────────────────

/// 冷启动分数增强器接口 — 可选注入 recommend()，避免方法签名膨胀
abstract class ScoreBooster {
  /// 为候选分类提供额外的 frequency/time 基础分
  /// 返回 null 表示不干预
  double? boostFrequency(CategoryUsageProfile profile);
  double? boostRecency(CategoryUsageProfile profile);
  double? boostTimeSlot(CategoryUsageProfile profile, int hour);
}

/// 冷启动增强器 — 分类名 → 时间段先验 + 新分类基础分
class ColdStartBooster implements ScoreBooster {
  final Map<String, String> categoryNames;

  const ColdStartBooster({required this.categoryNames});

  @override
  double? boostFrequency(CategoryUsageProfile profile) {
    if (profile.totalCount == 0) return _newCategoryBaselineScore;
    return null;
  }

  @override
  double? boostRecency(CategoryUsageProfile profile) {
    if (profile.totalCount == 0) return _newCategoryBaselineScore;
    return null;
  }

  @override
  double? boostTimeSlot(CategoryUsageProfile profile, int hour) {
    if (profile.totalCount == 0) {
      return TimePrior.score(categoryNames[profile.categoryId] ?? '', hour);
    }
    return null;
  }

  static const _newCategoryBaselineScore = 0.3;
}

// ─── TimePrior ────────────────────────────────────────────────────────────────

/// 时间段先验得分表 — static final RegExp，避免重复编译
class TimePrior {
  TimePrior._();

  /// 时间段匹配规则：RegExp → 各时间段得分函数
  static final List<_TimePriorRule> _rules = [
    _TimePriorRule(
      pattern: _mealPattern,
      scorer: (hour) {
        if (hour >= 6 && hour <= 9) return 0.7;
        if (hour >= 11 && hour <= 13) return 0.9;
        if (hour >= 17 && hour <= 20) return 0.8;
        return 0.1;
      },
    ),
    _TimePriorRule(
      pattern: _transportPattern,
      scorer: (hour) {
        if ((hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19)) return 0.8;
        return 0.2;
      },
    ),
    _TimePriorRule(
      pattern: _salaryPattern,
      scorer: (_) => 0.5, // 工资不依赖时间，基础分高于默认
    ),
  ];

  // 预编译正则 — 只编译一次
  static final _mealPattern = RegExp(r'早餐|午餐|晚餐|外卖|餐饮|美食|吃饭|火锅|烧烤|快餐');
  static final _transportPattern = RegExp(r'交通|通勤|地铁|公交|打车|加油');
  static final _salaryPattern = RegExp(r'工资|薪酬|奖金|收入');

  /// 默认基础分（未命中任何规则时）
  static const _defaultScore = 0.3;

  /// 根据分类名和小时返回先验得分 [0, 1]
  static double score(String categoryName, int hour) {
    for (final rule in _rules) {
      if (rule.pattern.hasMatch(categoryName)) {
        return rule.scorer(hour);
      }
    }
    return _defaultScore;
  }
}

class _TimePriorRule {
  final RegExp pattern;
  final double Function(int hour) scorer;
  const _TimePriorRule({required this.pattern, required this.scorer});
}

// ─── CategoryRecommender ─────────────────────────────────────────────────────

/// 分类推荐器 — 纯算法层，无副作用
class CategoryRecommender {
  static const _instance = CategoryRecommender._();
  factory CategoryRecommender() => _instance;
  const CategoryRecommender._();

  final TimeSlotScorer _timeSlot = const TimeSlotScorer();
  final RecencyScorer _recency = const RecencyScorer();
  final FrequencyScorer _frequency = const FrequencyScorer();
  final AmountRangeScorer _amount = const AmountRangeScorer();
  final KeywordScorer _keyword = const KeywordScorer();

  /// 计算推荐排序
  ///
  /// [profiles] 所有候选分类的使用画像
  /// [sequenceScorer] 预构建的转移矩阵 scorer
  /// [input] 当前上下文（时间、金额、备注等）
  /// [config] 权重配置（默认可以不传）
  /// [booster] 可选的冷启动分数增强器（替代旧的 categoryNames 参数）
  List<CategoryRecommendation> recommend({
    required List<CategoryUsageProfile> profiles,
    required SequenceScorer sequenceScorer,
    required CategoryRecommendInput input,
    RecommenderConfig config = const RecommenderConfig(),
    ScoreBooster? booster,
  }) {
    if (profiles.isEmpty) return [];
    assert(
      (config.timeSlotWeight +
                  config.recencyWeight +
                  config.frequencyWeight +
                  config.amountWeight +
                  config.sequenceWeight +
                  config.keywordWeight -
                  1.0)
              .abs() <
          0.01,
      'RecommenderConfig weights must sum to 1.0',
    );

    final now = input.now ?? DateTime.now();
    final hour = now.hour;

    // Pre-compute global max values for normalization
    int maxLast7d = 0;
    int maxTotal = 0;
    double maxHourProb = 0;
    for (final p in profiles) {
      if (p.last7dCount > maxLast7d) maxLast7d = p.last7dCount;
      if (p.totalCount > maxTotal) maxTotal = p.totalCount;
      final smoothed = TimeSlotScorer.smoothedProb(p, hour);
      if (smoothed > maxHourProb) maxHourProb = smoothed;
    }

    // Dynamic weight redistribution
    final hasAmount = input.amountCents != null && input.amountCents! > 0;
    final hasNote = input.noteText != null && input.noteText!.isNotEmpty;

    double wTime = config.timeSlotWeight;
    double wRecency = config.recencyWeight;
    double wFreq = config.frequencyWeight;
    double wAmount = hasAmount ? config.amountWeight : 0;
    double wSeq = config.sequenceWeight;
    double wKeyword = hasNote ? config.keywordWeight : 0;

    // Redistribute disabled weights proportionally
    final activeTotal = wTime + wRecency + wFreq + wAmount + wSeq + wKeyword;
    if (activeTotal > 0 && activeTotal < 1.0) {
      final scale = 1.0 / activeTotal;
      wTime *= scale;
      wRecency *= scale;
      wFreq *= scale;
      wAmount *= scale;
      wSeq *= scale;
      wKeyword *= scale;
    }

    // Score each profile
    final results = <CategoryRecommendation>[];
    for (final p in profiles) {
      double timeScore = _timeSlot.score(p, hour, maxHourProb);
      double recencyScore = _recency.score(p, maxLast7d);
      double freqScore = _frequency.score(p, maxTotal);
      final amountScore = _amount.score(p, input.amountCents);
      final seqScore = sequenceScorer.score(input.lastCategoryId, p.categoryId);
      final kwScore = _keyword.score(p, input.noteText);

      // 冷启动增强：通过 booster 注入基础分
      if (booster != null) {
        final boostedFreq = booster.boostFrequency(p);
        if (boostedFreq != null) freqScore = boostedFreq;

        final boostedRecency = booster.boostRecency(p);
        if (boostedRecency != null) recencyScore = boostedRecency;

        // 新分类始终应用时间先验 — 无论老分类是否有时段数据。
        // 时间先验的价值在于让新分类在合适时段获得曝光，
        // 不应受 maxHourProb 归一化（老分类横向比较）的约束。
        final boostedTime = booster.boostTimeSlot(p, hour);
        if (boostedTime != null) timeScore = boostedTime;
      }

      final totalScore =
          wTime * timeScore +
          wRecency * recencyScore +
          wFreq * freqScore +
          wAmount * amountScore +
          wSeq * seqScore +
          wKeyword * kwScore;

      results.add(
        CategoryRecommendation(categoryId: p.categoryId, score: totalScore),
      );
    }

    // Sort descending by score, filter out zero-score entries
    results.sort((a, b) => b.score.compareTo(a.score));
    return results.where((r) => r.score > 0).toList();
  }

  /// 冷启动阈值：交易量低于此值时使用冷启动权重
  static const _coldStartThreshold = 30;

  /// 冷启动：交易量不足时调整权重
  static RecommenderConfig coldStartConfig(int totalTransactions) {
    if (totalTransactions < _coldStartThreshold) {
      // 数据不够，增大 frequency，减小 timeSlot
      return const RecommenderConfig(
        timeSlotWeight: 0.10,
        recencyWeight: 0.25,
        frequencyWeight: 0.30,
        amountWeight: 0.15,
        sequenceWeight: 0.10,
        keywordWeight: 0.10,
      );
    }
    return const RecommenderConfig();
  }
}
