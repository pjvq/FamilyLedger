import 'package:flutter/material.dart';

import '../../../core/theme/design_tokens.dart';

/// Standard card container for overview page cards.
///
/// Provides consistent decoration (background, border, radius) across
/// all overview summary cards, eliminating duplication.
class OverviewCardContainer extends StatelessWidget {
  /// Thin border width used by all overview cards.
  static const double borderWidth = 0.5;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const OverviewCardContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(SpacingTokens.base),
    this.margin = const EdgeInsets.fromLTRB(
      SpacingTokens.base,
      SpacingTokens.sm,
      SpacingTokens.base,
      SpacingTokens.sm,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: margin,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: isDark
              ? NeutralColorsDark.neutral2
              : NeutralColorsLight.neutral1,
          borderRadius: BorderRadius.circular(RadiusTokens.lg),
          border: Border.all(
            color: isDark
                ? NeutralColorsDark.neutral3
                : NeutralColorsLight.neutral3,
            width: OverviewCardContainer.borderWidth,
          ),
        ),
        child: child,
      ),
    );
  }
}
