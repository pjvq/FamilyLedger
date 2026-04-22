import 'package:flutter/material.dart';

/// 金额文字样式扩展
///
/// 所有金额显示应使用 tabularFigures 确保数字等宽对齐。
/// 使用方式:
/// ```dart
/// Text('¥1,234.56', style: AmountStyle.large(context))
/// Text('¥1,234.56', style: theme.textTheme.bodyLarge?.withTabularFigures)
/// ```
class AmountStyle {
  AmountStyle._();

  /// 大号金额（如卡片标题）
  static TextStyle large(BuildContext context) {
    final theme = Theme.of(context);
    return (theme.textTheme.headlineSmall ?? const TextStyle()).copyWith(
      fontWeight: FontWeight.bold,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// 中号金额（如列表项）
  static TextStyle medium(BuildContext context) {
    final theme = Theme.of(context);
    return (theme.textTheme.bodyLarge ?? const TextStyle()).copyWith(
      fontWeight: FontWeight.bold,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// 小号金额（如辅助信息）
  static TextStyle small(BuildContext context) {
    final theme = Theme.of(context);
    return (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// 超大金额（如仪表盘）
  static TextStyle display(BuildContext context) {
    final theme = Theme.of(context);
    return (theme.textTheme.headlineMedium ?? const TextStyle()).copyWith(
      fontWeight: FontWeight.bold,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}

/// TextStyle 扩展: 快速添加 tabularFigures
extension TabularFiguresExtension on TextStyle {
  /// 返回启用了 tabularFigures 的新 TextStyle
  TextStyle get withTabularFigures => copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
