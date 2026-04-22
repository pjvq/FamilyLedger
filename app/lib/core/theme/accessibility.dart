import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 无障碍增强工具集
///
/// 提供语义化包装器、tooltip 辅助和对比度检查工具。

/// 为 IconButton 添加 tooltip 的便捷构造器
IconButton a11yIconButton({
  required IconData icon,
  required String tooltip,
  required VoidCallback? onPressed,
  double? iconSize,
  Color? color,
  EdgeInsetsGeometry? padding,
}) {
  return IconButton(
    icon: Icon(icon, size: iconSize),
    tooltip: tooltip,
    onPressed: onPressed,
    color: color,
    padding: padding,
  );
}

/// 语义化金额文字
///
/// 自动生成无障碍标签，将 "¥1234.56" 读成 "1234元56分"
class SemanticAmount extends StatelessWidget {
  final String amount;
  final TextStyle? style;
  final TextAlign? textAlign;

  const SemanticAmount({
    super.key,
    required this.amount,
    this.style,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _amountToSpeech(amount),
      excludeSemantics: true,
      child: Text(
        amount,
        style: style,
        textAlign: textAlign,
      ),
    );
  }

  static String _amountToSpeech(String amount) {
    final cleaned = amount.replaceAll(RegExp(r'[¥\s,]'), '');
    final parts = cleaned.split('.');
    final yuan = parts[0];
    final fen = parts.length > 1 ? parts[1] : '';

    if (fen.isEmpty || fen == '00') {
      return '$yuan元';
    }
    return '$yuan元$fen分';
  }
}

/// 语义化百分比
class SemanticPercent extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const SemanticPercent({
    super.key,
    required this.text,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final cleaned = text.replaceAll('%', '');
    final isPositive = !cleaned.startsWith('-');
    final number = cleaned.replaceAll(RegExp(r'[+-]'), '');
    final prefix = isPositive ? '上涨' : '下跌';

    return Semantics(
      label: '$prefix百分之$number',
      excludeSemantics: true,
      child: Text(text, style: style),
    );
  }
}

/// WCAG AA 对比度检查工具
class ContrastChecker {
  ContrastChecker._();

  /// 计算两个颜色的对比度
  static double contrastRatio(Color foreground, Color background) {
    final l1 = _relativeLuminance(foreground);
    final l2 = _relativeLuminance(background);
    final lighter = math.max(l1, l2);
    final darker = math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// 检查是否满足 WCAG AA 标准
  static bool meetsAA(Color foreground, Color background,
      {bool isLargeText = false}) {
    final ratio = contrastRatio(foreground, background);
    return isLargeText ? ratio >= 3.0 : ratio >= 4.5;
  }

  static double _relativeLuminance(Color color) {
    final r = _linearize(color.r);
    final g = _linearize(color.g);
    final b = _linearize(color.b);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// sRGB → linear. Input 0.0–1.0.
  static double _linearize(double c) {
    return c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }
}
