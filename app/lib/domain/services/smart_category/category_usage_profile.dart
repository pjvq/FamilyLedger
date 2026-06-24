/// 分类使用画像 — 从 category_usage_slots + category_usage_summary 聚合而来
class CategoryUsageProfile {
  /// 小时槽位数
  static const hourSlotCount = 24;

  /// 星期槽位数
  static const weekdaySlotCount = 7;

  /// 金额区间数
  static const amountBucketCount = 6;

  final String categoryId;
  final int totalCount;
  final int last30dCount;
  final int last7dCount;
  final List<int> hourDistribution;
  final List<int> weekdayDistribution;
  final List<int> amountBuckets;
  final List<String> topKeywords; // max 20
  final DateTime? lastUsedAt;

  CategoryUsageProfile({
    required this.categoryId,
    this.totalCount = 0,
    this.last30dCount = 0,
    this.last7dCount = 0,
    List<int>? hourDistribution,
    List<int>? weekdayDistribution,
    List<int>? amountBuckets,
    this.topKeywords = const [],
    this.lastUsedAt,
  }) : hourDistribution =
           hourDistribution ?? List<int>.filled(hourSlotCount, 0),
       weekdayDistribution =
           weekdayDistribution ?? List<int>.filled(weekdaySlotCount, 0),
       amountBuckets = amountBuckets ?? List<int>.filled(amountBucketCount, 0);

  /// 归一化的小时分布 (概率向量, sum=1)
  List<double> get hourProbability => _normalize(hourDistribution);

  /// 归一化的星期分布
  List<double> get weekdayProbability => _normalize(weekdayDistribution);

  /// 归一化的金额区间分布
  List<double> get amountProbability => _normalize(amountBuckets);

  static List<double> _normalize(List<int> distribution) {
    final total = distribution.fold<int>(0, (a, b) => a + b);
    if (total == 0)
      return List.filled(distribution.length, 1.0 / distribution.length);
    return distribution.map((c) => c / total).toList();
  }

  /// 金额分桶: <20, 20-50, 50-100, 100-500, 500-2000, >=2000 (单位: 分)
  static int amountToBucket(int cents) {
    final yuan = cents / 100;
    if (yuan < 20) return 0;
    if (yuan < 50) return 1;
    if (yuan < 100) return 2;
    if (yuan < 500) return 3;
    if (yuan < 2000) return 4;
    return 5;
  }
}
