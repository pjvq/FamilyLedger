import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Card elevation level.
enum FlCardElevation {
  /// No shadow.
  none,

  /// Subtle shadow.
  sm,

  /// Moderate shadow.
  md,

  /// Strong shadow.
  lg,
}

/// 标准卡片容器组件。
///
/// 支持 elevation (none/sm/md/lg)、自定义 padding、onTap 交互、
/// 圆角自定义。Light/Dark 模式自动适配阴影。
///
/// ```dart
/// FlCard(
///   elevation: FlCardElevation.sm,
///   child: Text('内容'),
/// )
/// ```
class FlCard extends StatelessWidget {
  /// Creates an [FlCard].
  const FlCard({
    super.key,
    required this.child,
    this.elevation = FlCardElevation.sm,
    this.padding,
    this.borderRadius,
    this.onTap,
    this.color,
  });

  /// Card content.
  final Widget child;

  /// Shadow elevation level.
  final FlCardElevation elevation;

  /// Content padding. Defaults to [SpacingTokens.base] on all sides.
  final EdgeInsetsGeometry? padding;

  /// Border radius. Defaults to [RadiusTokens.lg].
  final BorderRadius? borderRadius;

  /// Optional tap callback. Adds ink splash when provided.
  final VoidCallback? onTap;

  /// Override background color. Defaults to neutral0.
  final Color? color;

  List<BoxShadow> _resolveShadow(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    switch (elevation) {
      case FlCardElevation.none:
        return const [];
      case FlCardElevation.sm:
        return isLight ? ShadowTokensLight.sm : ShadowTokensDark.sm;
      case FlCardElevation.md:
        return isLight ? ShadowTokensLight.md : ShadowTokensDark.md;
      case FlCardElevation.lg:
        return isLight ? ShadowTokensLight.lg : ShadowTokensDark.lg;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isLight = brightness == Brightness.light;

    final bgColor =
        color ??
        (isLight ? NeutralColorsLight.neutral0 : NeutralColorsDark.neutral0);
    final radius = borderRadius ?? BorderRadius.circular(RadiusTokens.lg);

    final container = Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: radius,
        boxShadow: _resolveShadow(brightness),
      ),
      padding: padding ?? const EdgeInsets.all(SpacingTokens.base),
      child: child,
    );

    if (onTap == null) return container;

    // Shadow must be on the outer wrapper (outside Material) to avoid clipping.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: _resolveShadow(brightness),
      ),
      child: Material(
        color: bgColor,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(SpacingTokens.base),
            child: child,
          ),
        ),
      ),
    );
  }
}
