import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// 标准分割线组件。
///
/// 支持水平/垂直方向、左缩进 (indent)、自定义厚度。
/// 默认: 0.5px thick, neutral3 色。
///
/// ```dart
/// FlDivider()
/// FlDivider(indent: 56) // 左缩进，用于列表分割
/// FlDivider.vertical(height: 24) // 垂直分割线
/// ```
class FlDivider extends StatelessWidget {
  /// Creates a horizontal [FlDivider].
  const FlDivider({
    super.key,
    this.indent = 0,
    this.endIndent = 0,
    this.thickness = 0.5,
    this.color,
  }) : _isVertical = false,
       _height = null;

  /// Creates a vertical [FlDivider].
  const FlDivider.vertical({
    super.key,
    double? height,
    this.thickness = 0.5,
    this.color,
  }) : _isVertical = true,
       _height = height,
       indent = 0,
       endIndent = 0;

  /// Left indent for horizontal divider.
  final double indent;

  /// Right indent for horizontal divider.
  final double endIndent;

  /// Line thickness. Defaults to 0.5.
  final double thickness;

  /// Override color. Defaults to neutral3.
  final Color? color;

  final bool _isVertical;
  final double? _height;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isLight = brightness == Brightness.light;
    final dividerColor = color ??
        (isLight ? NeutralColorsLight.neutral3 : NeutralColorsDark.neutral3);

    if (_isVertical) {
      return Container(
        width: thickness,
        height: _height,
        color: dividerColor,
      );
    }

    return Padding(
      padding: EdgeInsets.only(left: indent, right: endIndent),
      child: Container(
        height: thickness,
        color: dividerColor,
      ),
    );
  }
}
