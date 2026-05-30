import 'dart:math';

import 'category_usage_profile.dart';

/// 行为重叠度计算器
/// 基于两个分类的时间段/金额/星期分布的 Jensen-Shannon 散度
class BehaviorOverlapScorer {
  const BehaviorOverlapScorer._();

  /// 计算两个分类画像的行为重叠度 [0, 1]
  /// 1 = 完全相同的使用模式, 0 = 完全不同
  static double score(CategoryUsageProfile a, CategoryUsageProfile b) {
    // 至少一方无数据时返回 0（无法判断）
    if (a.totalCount == 0 || b.totalCount == 0) return 0.0;

    // JS Divergence of hour distributions (1 - JSD = similarity)
    final hourSim = 1.0 - jensenShannonDivergence(
      a.hourProbability,
      b.hourProbability,
    );

    // JS Divergence of amount bucket distributions
    final amountSim = 1.0 - jensenShannonDivergence(
      a.amountProbability,
      b.amountProbability,
    );

    // Weekday cosine similarity
    final weekdaySim = cosineSimilarity(
      a.weekdayDistribution.map((e) => e.toDouble()).toList(),
      b.weekdayDistribution.map((e) => e.toDouble()).toList(),
    );

    return (hourSim + amountSim + weekdaySim) / 3;
  }

  /// Jensen-Shannon Divergence (对称的 KL 散度变体)
  /// 取值 [0, 1]（使用 log2 时）
  static double jensenShannonDivergence(List<double> p, List<double> q) {
    assert(p.length == q.length);
    final n = p.length;
    final m = List<double>.generate(n, (i) => (p[i] + q[i]) / 2);

    double klPM = 0;
    double klQM = 0;
    for (var i = 0; i < n; i++) {
      if (p[i] > 0 && m[i] > 0) {
        klPM += p[i] * log(p[i] / m[i]) / ln2;
      }
      if (q[i] > 0 && m[i] > 0) {
        klQM += q[i] * log(q[i] / m[i]) / ln2;
      }
    }

    return ((klPM + klQM) / 2).clamp(0.0, 1.0);
  }

  /// 余弦相似度 [0, 1]（向量非负时）
  static double cosineSimilarity(List<double> a, List<double> b) {
    assert(a.length == b.length);
    double dot = 0, normA = 0, normB = 0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0;
    return (dot / (sqrt(normA) * sqrt(normB))).clamp(0.0, 1.0);
  }
}
