import 'category_usage_profile.dart';

/// 关键词重叠度计算器
/// 基于两个分类 topKeywords 的 Jaccard 系数
class KeywordOverlapScorer {
  const KeywordOverlapScorer._();

  /// 计算两个分类画像的关键词重叠度 [0, 1]
  static double score(CategoryUsageProfile a, CategoryUsageProfile b) {
    if (a.topKeywords.isEmpty || b.topKeywords.isEmpty) return 0.0;

    final setA = a.topKeywords.toSet();
    final setB = b.topKeywords.toSet();

    final intersection = setA.intersection(setB).length;
    final union = setA.union(setB).length;

    if (union == 0) return 0.0;
    return intersection / union;
  }
}
