import 'dart:math' show exp;

import 'package:meta/meta.dart';

/// 语义距离计算接口(依赖倒置 - domain 不依赖 platform channel)
///
/// 实现者提供:
/// - [isAvailable]: 是否可用
/// - [distance]: 两个词的距离 (0=相同, 2=无关)
/// - [batchDistances]: 批量计算
typedef SemanticDistanceFn =
    Future<double?> Function(String word1, String word2);
typedef SemanticBatchFn =
    Future<Map<String, double>?> Function(List<String> words);
typedef SemanticAvailableFn = Future<bool> Function();

/// 语义相似度评分器(纯 domain 层,不依赖 Flutter)
///
/// 通过构造函数注入平台实现。iOS 注入 NLEmbeddingBridge,
/// Android 注入返回 null 的 stub,测试直接注入 mock。
class SemanticScorer {
  final SemanticAvailableFn _checkAvailable;
  final SemanticDistanceFn _getDistance;
  final SemanticBatchFn _getBatchDistances;

  /// 缓存的批量距离结果
  Map<String, double>? _cachedDistances;

  /// 可用性缓存 + 过期(CRITICAL #2 - 5 分钟后重新检测)
  bool? _available;
  DateTime? _availableCheckedAt;
  static const _availableCacheDuration = Duration(minutes: 5);

  SemanticScorer({
    required SemanticAvailableFn checkAvailable,
    required SemanticDistanceFn getDistance,
    required SemanticBatchFn getBatchDistances,
  }) : _checkAvailable = checkAvailable,
       _getDistance = getDistance,
       _getBatchDistances = getBatchDistances;

  /// 检查是否可用(带 5 分钟过期缓存)
  Future<bool> get isAvailable async {
    final now = DateTime.now();
    if (_available != null &&
        _availableCheckedAt != null &&
        now.difference(_availableCheckedAt!) < _availableCacheDuration) {
      return _available!;
    }
    _available = await _checkAvailable();
    _availableCheckedAt = now;
    return _available!;
  }

  /// 预计算一批词的距离矩阵(减少 channel round-trip)
  Future<void> precompute(List<String> categoryNames) async {
    if (!await isAvailable) return;

    final unique = categoryNames.toSet().toList();
    if (unique.length < 2) return;

    _cachedDistances = await _getBatchDistances(unique);
  }

  /// 获取两个分类名的语义相似度分数
  ///
  /// 返回 0.0~1.0 (1.0 = 语义完全相同)
  /// 如果平台不可用或词不在词表中返回 null
  Future<double?> score(String nameA, String nameB) async {
    if (!await isAvailable) return null;

    // MAJOR #6: 短路相同名称,避免无意义 platform call
    if (nameA == nameB) return 1.0;

    // 优先使用预计算的缓存
    if (_cachedDistances != null) {
      final key = makePairKey(nameA, nameB);
      final dist = _cachedDistances![key];
      if (dist != null) {
        return _distanceToScore(dist);
      }
    }

    // fallback: 单次调用
    final dist = await _getDistance(nameA, nameB);
    if (dist == null) return null;
    return _distanceToScore(dist);
  }

  /// 清空缓存
  @visibleForTesting
  void clearCache() {
    _cachedDistances = null;
  }

  /// 重置可用性缓存(测试用)
  @visibleForTesting
  void resetAvailability() {
    _available = null;
    _availableCheckedAt = null;
  }

  /// NLEmbedding distance (0~2) → similarity score (0~1)
  ///
  /// sigmoid 映射提升有效区间 (0~0.8) 的区分度
  /// distance 0 → ~0.96, distance 0.8 → 0.5, distance 2 → ~0.008
  double _distanceToScore(double distance) {
    if (distance.isNaN) return 0.0; // NaN 视为无关
    final x = 4.0 * (distance - 0.8);
    return 1.0 / (1.0 + exp(x));
  }

  /// pair key（字典序排列）—— 委托统一实现
  static String makePairKey(String word1, String word2) {
    final sorted = [word1, word2]..sort();
    return '${sorted[0]}|${sorted[1]}';
  }
}
