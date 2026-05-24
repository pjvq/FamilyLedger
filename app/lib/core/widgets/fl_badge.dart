import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// 数字徽章组件。
///
/// 显示红色小圆点或带数字的通知徽章。
/// 通常叠加在图标右上角使用。
///
/// ```dart
/// FlBadge(count: 5, child: Icon(Icons.notifications))
/// ```
class FlBadge extends StatelessWidget {
  /// Creates an [FlBadge].
  ///
  /// If [count] is null or 0, shows a dot indicator.
  /// If [count] > 0, shows the number (capped at 99+).
  const FlBadge({
    super.key,
    required this.child,
    this.count,
    this.show = true,
  });

  /// The widget to show the badge on (typically an Icon).
  final Widget child;

  /// Badge count. Null or 0 shows a dot; > 0 shows the number.
  final int? count;

  /// Whether to show the badge. Useful for conditional display.
  final bool show;

  @override
  Widget build(BuildContext context) {
    if (!show) return child;

    final isDot = count == null || count == 0;
    final displayText =
        count != null && count! > 99 ? '99+' : count?.toString();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -4,
          right: -4,
          child: isDot
              ? Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: SemanticColorsLight.error,
                    shape: BoxShape.circle,
                  ),
                )
              : Container(
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingTokens.xs,
                  ),
                  decoration: BoxDecoration(
                    color: SemanticColorsLight.error,
                    borderRadius: BorderRadius.circular(RadiusTokens.full),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    displayText!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// 文字标签组件。
///
/// 带背景色的文字标签，用于状态指示、分类标记等。
///
/// ```dart
/// FlTag(label: '已完成', color: SemanticColorsLight.success)
/// ```
class FlTag extends StatelessWidget {
  /// Creates an [FlTag].
  const FlTag({
    super.key,
    required this.label,
    this.color,
    this.textColor,
  });

  /// Tag text.
  final String label;

  /// Background color. Defaults to [ColorTokens.primaryLight].
  final Color? color;

  /// Text color. Defaults to [ColorTokens.primary].
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? ColorTokens.primaryLight;
    final fg = textColor ?? ColorTokens.primary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.sm,
        vertical: SpacingTokens.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(RadiusTokens.sm),
      ),
      child: Text(
        label,
        style: TypographyTokens.caption(color: fg).copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
