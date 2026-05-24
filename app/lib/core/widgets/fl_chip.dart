import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// 可选择的 Chip 标签组件。
///
/// 用于分类筛选、标签选择等场景。
/// 支持 selected/unselected 状态、可选 icon、onTap 回调。
///
/// ```dart
/// FlChip(
///   label: '餐饮',
///   selected: true,
///   icon: Icons.restaurant,
///   onTap: () => toggleCategory('food'),
/// )
/// ```
class FlChip extends StatelessWidget {
  /// Creates an [FlChip].
  const FlChip({
    super.key,
    required this.label,
    this.selected = false,
    this.icon,
    this.onTap,
  });

  /// Chip text label.
  final String label;

  /// Whether the chip is in selected state.
  final bool selected;

  /// Optional leading icon.
  final IconData? icon;

  /// Callback when tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isLight = brightness == Brightness.light;

    final bgColor = selected
        ? ColorTokens.primaryLight
        : (isLight ? NeutralColorsLight.neutral2 : NeutralColorsDark.neutral2);
    final fgColor = selected
        ? ColorTokens.primary
        : (isLight ? NeutralColorsLight.neutral6 : NeutralColorsDark.neutral6);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(RadiusTokens.full),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(RadiusTokens.full),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(RadiusTokens.full),
          child: SizedBox(
            height: 32,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: SpacingTokens.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: IconSizeTokens.xs, color: fgColor),
                    const SizedBox(width: SpacingTokens.xs),
                  ],
                  Text(
                    label,
                    style: TypographyTokens.bodyMd(color: fgColor).copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
