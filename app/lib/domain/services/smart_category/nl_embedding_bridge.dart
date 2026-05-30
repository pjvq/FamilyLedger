import 'package:flutter/services.dart';

/// 平台通道桥接层 — 封装 iOS NLEmbedding
///
/// 实例化后可注入 SemanticScorer。
/// iOS 上使用 NaturalLanguage.framework 的中文词向量。
/// Android/其他平台返回不可用，由上层降级处理。
class NLEmbeddingBridge {
  final MethodChannel _channel;

  NLEmbeddingBridge({
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel('familyledger/nl_embedding');

  /// 检查平台是否支持语义嵌入
  Future<bool> checkAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 计算两个词的语义距离
  /// 返回 0~2 (0=相同, 2=无关)，平台不支持时返回 null
  Future<double?> distance(String word1, String word2) async {
    try {
      return await _channel.invokeMethod<double>('distance', {
        'word1': word1,
        'word2': word2,
      });
    } catch (_) {
      return null;
    }
  }

  /// 批量计算：给定一组词，返回所有 pair 的距离
  /// key 格式: "word1|word2"(字典序排列，确保唯一性)
  Future<Map<String, double>?> batchDistances(List<String> words) async {
    if (words.length < 2) return {};
    try {
      final result = await _channel.invokeMethod<Map>('batchDistances', {
        'words': words,
      });
      return result?.cast<String, double>();
    } catch (_) {
      return null;
    }
  }
}
