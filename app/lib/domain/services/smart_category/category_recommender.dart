import 'dart:math';
import 'category_usage_profile.dart';

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

  /// [maxHourProb] 是所有候选分类中最大的 hourProb 值，用于归一化
  double score(CategoryUsageProfile profile, int hour, double maxHourProb) {
    if (maxHourProb <= 0) return 0;
    final hourProb = profile.hourProbability;
    // 取当前小时 ± 1 小时的平均概率（平滑）
    final smoothed = (hourProb[(hour - 1) % 24] +
            hourProb[hour] +
            hourProb[(hour + 1) % 24]) /
        3;
    return smoothed / maxHourProb;
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
    if (amountCents == null || amountCents <= 0) return 0;
    final bucket = CategoryUsageProfile.amountToBucket(amountCents);
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

  /// 从有序交易列表（最新在前）构建转移矩阵
  /// [categoryIds] 按时间倒序排列的分类 ID 列表
  static Map<String, Map<String, double>> buildMatrix(
      List<String> categoryIds) {
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
  const KeywordScorer();

  double score(CategoryUsageProfile profile, String? noteText) {
    if (noteText == null || noteText.isEmpty) return 0;
    if (profile.topKeywords.isEmpty) return 0;
    final words = tokenize(noteText);
    final keywords = profile.topKeywords.toSet();
    final matches = words.where((w) => keywords.contains(w)).length;
    return min(1.0, matches / 2); // 匹配 2 个关键词即满分
  }

  /// 分词器：中文用 2-char sliding window，拉丁文用空格分割
  static List<String> tokenize(String text) {
    final tokens = <String>[];
    final latin = RegExp(r'[a-zA-Z]+');

    // 拉丁文单词
    for (final m in latin.allMatches(text)) {
      if (m.group(0)!.length >= 2) tokens.add(m.group(0)!.toLowerCase());
    }

    // 中文 2-gram
    final cjk = text.replaceAll(RegExp(r'[^\u4e00-\u9fff]'), '');
    for (var i = 0; i < cjk.length - 1; i++) {
      tokens.add(cjk.substring(i, i + 2));
    }

    // 完整匹配（备注本身，去空格/标点）
    final clean =
        text.replaceAll(RegExp(r'[\s\p{P}]', unicode: true), '');
    if (clean.length >= 2 && clean.length <= 6) tokens.add(clean);

    return tokens;
  }
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

  const CategoryRecommendation({
    required this.categoryId,
    required this.score,
  });
}

/// 分类推荐器 — 纯算法层，无副作用
class CategoryRecommender {
  final RecommenderConfig config;
  final TimeSlotScorer _timeSlot;
  final RecencyScorer _recency;
  final FrequencyScorer _frequency;
  final AmountRangeScorer _amount;
  final KeywordScorer _keyword;

  CategoryRecommender({
    this.config = const RecommenderConfig(),
  })  : _timeSlot = const TimeSlotScorer(),
        _recency = const RecencyScorer(),
        _frequency = const FrequencyScorer(),
        _amount = const AmountRangeScorer(),
        _keyword = const KeywordScorer();

  /// 计算推荐排序
  ///
  /// [profiles] 所有候选分类的使用画像
  /// [sequenceScorer] 预构建的转移矩阵 scorer
  /// [input] 当前上下文（时间、金额、备注等）
  List<CategoryRecommendation> recommend({
    required List<CategoryUsageProfile> profiles,
    required SequenceScorer sequenceScorer,
    required CategoryRecommendInput input,
  }) {
    if (profiles.isEmpty) return [];

    final now = input.now ?? DateTime.now();
    final hour = now.hour;

    // Pre-compute global max values for normalization
    int maxLast7d = 0;
    int maxTotal = 0;
    double maxHourProb = 0;
    for (final p in profiles) {
      if (p.last7dCount > maxLast7d) maxLast7d = p.last7dCount;
      if (p.totalCount > maxTotal) maxTotal = p.totalCount;
      final hp = p.hourProbability;
      final smoothed =
          (hp[(hour - 1) % 24] + hp[hour] + hp[(hour + 1) % 24]) / 3;
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
      final timeScore = _timeSlot.score(p, hour, maxHourProb);
      final recencyScore = _recency.score(p, maxLast7d);
      final freqScore = _frequency.score(p, maxTotal);
      final amountScore = _amount.score(p, input.amountCents);
      final seqScore =
          sequenceScorer.score(input.lastCategoryId, p.categoryId);
      final kwScore = _keyword.score(p, input.noteText);

      final totalScore = wTime * timeScore +
          wRecency * recencyScore +
          wFreq * freqScore +
          wAmount * amountScore +
          wSeq * seqScore +
          wKeyword * kwScore;

      results.add(CategoryRecommendation(
        categoryId: p.categoryId,
        score: totalScore,
      ));
    }

    // Sort descending by score
    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  /// 冷启动：交易量不足时调整权重
  static RecommenderConfig coldStartConfig(int totalTransactions) {
    if (totalTransactions < 30) {
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
