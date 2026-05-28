/// 金额格式化工具。
///
/// 使用整数运算避免浮点精度丢失。
/// 所有金额以"分"（cents）为单位存储。
library;

/// 将分转为元字符串，整数运算，无精度丢失。
///
/// [showSign] 为 true 时正数显示 `+` 前缀。
/// ```dart
/// formatCents(12345) → "123.45"
/// formatCents(-500, showSign: true) → "-5.00"
/// formatCents(500, showSign: true) → "+5.00"
/// ```
String formatCents(int cents, {bool showSign = false}) {
  final sign = cents < 0
      ? '-'
      : (showSign ? '+' : '');
  final abs = cents.abs();
  final yuan = abs ~/ 100;
  final fen = (abs % 100).toString().padLeft(2, '0');
  return '$sign$yuan.$fen';
}

/// 将分转为元字符串，隐藏 .00 小数部分（用于整数金额）。
///
/// ```dart
/// formatCentsCompact(10000) → "100"
/// formatCentsCompact(10050) → "100.50"
/// ```
String formatCentsCompact(int cents) {
  final abs = cents.abs();
  final sign = cents < 0 ? '-' : '';
  final yuan = abs ~/ 100;
  final remainder = abs % 100;
  if (remainder == 0) return '$sign$yuan';
  return '$sign$yuan.${remainder.toString().padLeft(2, '0')}';
}

/// Format cents to compact CNY string with 万 unit for large amounts.
/// ```
/// formatCentsWan(500000000) → "500.00万"
/// formatCentsWan(123456) → "1234.56"
/// formatCentsWan(-500000000) → "-500.00万"
/// ```
String formatCentsWan(int cents) {
  final yuan = cents.abs() / 100;
  final sign = cents < 0 ? '-' : '';
  if (yuan >= 10000) {
    return '$sign${(yuan / 10000).toStringAsFixed(2)}万';
  }
  return '$sign${yuan.toStringAsFixed(2)}';
}
