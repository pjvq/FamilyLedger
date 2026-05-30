/// 分类使用画像 — 从 category_usage_slots + category_usage_summary 聚合而来
class CategoryUsageProfile {
  final String categoryId;
  final int totalCount;
  final int last30dCount;
  final int last7dCount;
  final List<int> hourDistribution; // length 24
  final List<int> weekdayDistribution; // length 7
  final List<int> amountBuckets; // length 6
  final List<String> topKeywords; // max 20
  final DateTime? lastUsedAt;

  const CategoryUsageProfile({
    required this.categoryId,
    this.totalCount = 0,
    this.last30dCount = 0,
    this.last7dCount = 0,
    List<int>? hourDistribution,
    List<int>? weekdayDistribution,
    List<int>? amountBuckets,
    this.topKeywords = const [],
    this.lastUsedAt,
  })  : hourDistribution = hourDistribution ?? const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        weekdayDistribution = weekdayDistribution ?? const [0, 0, 0, 0, 0, 0, 0],
        amountBuckets = amountBuckets ?? const [0, 0, 0, 0, 0, 0];

  /// 归一化的小时分布 (概率向量, sum=1)
  List<double> get hourProbability {
    final total = hourDistribution.fold<int>(0, (a, b) => a + b);
    if (total == 0) return List.filled(24, 1.0 / 24);
    return hourDistribution.map((c) => c / total).toList();
  }

  /// 归一化的星期分布
  List<double> get weekdayProbability {
    final total = weekdayDistribution.fold<int>(0, (a, b) => a + b);
    if (total == 0) return List.filled(7, 1.0 / 7);
    return weekdayDistribution.map((c) => c / total).toList();
  }

  /// 归一化的金额区间分布
  List<double> get amountProbability {
    final total = amountBuckets.fold<int>(0, (a, b) => a + b);
    if (total == 0) return List.filled(6, 1.0 / 6);
    return amountBuckets.map((c) => c / total).toList();
  }

  /// 金额分桶: <20, 20-50, 50-100, 100-500, 500-2000, >=2000
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
