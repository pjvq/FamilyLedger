import 'dart:math';

import 'package:meta/meta.dart';

import 'category_usage_profile.dart';

/// 行为重叠度计算器
/// 基于两个分类的时间段/金额/星期分布的统计距离
class BehaviorOverlapScorer {
  const BehaviorOverlapScorer._();

  /// 各维度权重
  static const _hourWeight = 0.4;
  static const _amountWeight = 0.35;
  static const _weekdayWeight = 0.25;

  /// 计算两个分类画像的行为重叠度 [0, 1]
  /// 1 = 完全相同的使用模式, 0 = 完全不同
  static double score(CategoryUsageProfile a, CategoryUsageProfile b) {
    // 至少一方无数据时返回 0（无法判断）
    if (a.totalCount == 0 || b.totalCount == 0) return 0.0;

    // 1-JSD for hour distributions
    final hourSim = 1.0 - jensenShannonDivergence(
      a.hourProbability,
      b.hourProbability,
    );

    // 1-JSD for amount bucket distributions
    final amountSim = 1.0 - jensenShannonDivergence(
      a.amountProbability,
      b.amountProbability,
    );

    // 1-JSD for weekday (统一使用 JSD 避免度量空间不一致 — MINOR #15)
    final weekdaySim = 1.0 - jensenShannonDivergence(
      a.weekdayProbability,
      b.weekdayProbability,
    );

    return _hourWeight * hourSim + _amountWeight * amountSim + _weekdayWeight * weekdaySim;
  }

  /// Jensen-Shannon Divergence (对称的 KL 散度变体)
  /// 取值 [0, 1]（使用 log2 时）
  @visibleForTesting
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
  @visibleForTesting
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
