import 'dart:math';

/// 文本相似度计算器
/// 用于分类合并检测的 L2 层（快速，纯 Dart，<1ms/pair）
class TextSimilarityScorer {
  const TextSimilarityScorer._();

  /// 包含关系最低要求：被包含字符串长度 >= 2
  static const _minContainsLength = 2;

  /// 计算两个分类名的文本相似度 [0, 1]
  static double score(String nameA, String nameB) {
    if (nameA == nameB) return 1.0;
    if (nameA.isEmpty || nameB.isEmpty) return 0.0;

    double best = 0;

    // 1. 包含关系 ("点外卖" contains "外卖")
    // 门槛：被包含串长度 >= 2，避免单字匹配误报 (MAJOR #7)
    final shorter = nameA.length <= nameB.length ? nameA : nameB;
    final longer = nameA.length > nameB.length ? nameA : nameB;
    if (shorter.length >= _minContainsLength && longer.contains(shorter)) {
      best = max(best, 0.7 + 0.15 * (shorter.length / longer.length));
    }

    // 2. 归一化编辑距离
    final editDist = _levenshtein(nameA, nameB);
    final maxLen = max(nameA.length, nameB.length);
    final editScore = 1.0 - (editDist / maxLen);
    best = max(best, editScore);

    // 3. 字符 bigram Jaccard
    final bigramsA = _bigrams(nameA);
    final bigramsB = _bigrams(nameB);
    if (bigramsA.isNotEmpty && bigramsB.isNotEmpty) {
      final intersection = bigramsA.intersection(bigramsB).length;
      final union = bigramsA.union(bigramsB).length;
      final jaccard = union > 0 ? intersection / union : 0.0;
      best = max(best, jaccard);
    }

    return best;
  }

  static Set<String> _bigrams(String s) {
    if (s.length < 2) return {};
    final result = <String>{};
    for (var i = 0; i < s.length - 1; i++) {
      result.add(s.substring(i, i + 2));
    }
    return result;
  }

  static int _levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final m = a.length;
    final n = b.length;
    var prev = List<int>.generate(n + 1, (i) => i);
    var curr = List<int>.filled(n + 1, 0);

    for (var i = 1; i <= m; i++) {
      curr[0] = i;
      for (var j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = min(min(prev[j] + 1, curr[j - 1] + 1), prev[j - 1] + cost);
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[n];
  }
}
