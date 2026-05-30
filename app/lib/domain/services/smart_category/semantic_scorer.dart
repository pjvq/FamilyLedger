import 'nl_embedding_bridge.dart';

/// 语义相似度评分器
///
/// 利用 iOS NLEmbedding 词向量计算分类名的语义距离。
/// Android 上不可用，由 CategoryMergeDetector 降级（权重分配给 TextSimilarity）。
class SemanticScorer {
  /// 平台是否可用（缓存结果）
  bool? _available;

  /// 缓存的批量距离结果
  Map<String, double>? _cachedDistances;

  /// 检查是否可用
  Future<bool> get isAvailable async {
    _available ??= await NLEmbeddingBridge.isAvailable;
    return _available!;
  }

  /// 预计算一批词的距离矩阵（减少 channel round-trip）
  ///
  /// 应在 Pass 2 开始前调用，传入所有候选分类名
  Future<void> precompute(List<String> categoryNames) async {
    if (!await isAvailable) return;

    // 去重
    final unique = categoryNames.toSet().toList();
    if (unique.length < 2) return;

    _cachedDistances = await NLEmbeddingBridge.batchDistances(unique);
  }

  /// 获取两个分类名的语义相似度分数
  ///
  /// 返回 0.0~1.0 (1.0 = 语义完全相同)
  /// 如果平台不可用或词不在词表中返回 null
  Future<double?> score(String nameA, String nameB) async {
    if (!await isAvailable) return null;

    // 优先使用预计算的缓存
    if (_cachedDistances != null) {
      final key = NLEmbeddingBridge.pairKey(nameA, nameB);
      final dist = _cachedDistances![key];
      if (dist != null) {
        return _distanceToScore(dist);
      }
    }

    // fallback: 单次调用
    final dist = await NLEmbeddingBridge.distance(nameA, nameB);
    if (dist == null) return null;
    return _distanceToScore(dist);
  }

  /// 清空缓存
  void clearCache() {
    _cachedDistances = null;
  }

  /// NLEmbedding distance (0~2) → similarity score (0~1)
  /// 0 = 相同 → 1.0
  /// 2 = 无关 → 0.0
  double _distanceToScore(double distance) {
    return (1.0 - distance / 2.0).clamp(0.0, 1.0);
  }
}
