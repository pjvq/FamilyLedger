import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Button variant styles.
enum FlButtonVariant {
  /// Primary filled button with brand color background.
  primary,

  /// Secondary filled button with lighter background.
  secondary,

  /// Outline button with border and transparent background.
  outline,

  /// Text-only button with no background or border.
  text,
}

/// Button size presets.
enum FlButtonSize {
  /// Small button — 36px height.
  small,

  /// Medium button — 44px height (default).
  medium,

  /// Large button — 52px height.
  large,
}

/// FamilyLedger 标准按钮组件。
///
/// 支持 4 种变体: [FlButtonVariant.primary], [FlButtonVariant.secondary],
/// [FlButtonVariant.outline], [FlButtonVariant.text].
///
/// 支持 3 种尺寸: [FlButtonSize.small] (36h), [FlButtonSize.medium] (44h),
/// [FlButtonSize.large] (52h).
///
/// 支持 loading 状态、disabled 状态、icon + label 组合。
///
/// ```dart
/// FlButton(
///   label: '保存',
///   variant: FlButtonVariant.primary,
///   onPressed: () {},
/// )
/// ```
class FlButton extends StatelessWidget {
  /// Creates an [FlButton].
  const FlButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = FlButtonVariant.primary,
    this.size = FlButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.expanded = false,
  });

  /// Button text label.
  final String label;

  /// Callback when pressed. Null means disabled.
  final VoidCallback? onPressed;

  /// Visual variant of the button.
  final FlButtonVariant variant;

  /// Size preset.
  final FlButtonSize size;

  /// Optional leading icon.
  final IconData? icon;

  /// Whether to show a loading indicator instead of label.
  final bool isLoading;

  /// Whether the button should expand to fill available width.
  final bool expanded;

  double get _height {
    switch (size) {
      case FlButtonSize.small:
        return 36;
      case FlButtonSize.medium:
        return 44;
      case FlButtonSize.large:
        return 52;
    }
  }

  EdgeInsetsGeometry get _padding {
    switch (size) {
      case FlButtonSize.small:
        return const EdgeInsets.symmetric(
          horizontal: SpacingTokens.md,
          vertical: SpacingTokens.xs,
        );
      case FlButtonSize.medium:
        return const EdgeInsets.symmetric(
          horizontal: SpacingTokens.base,
          vertical: SpacingTokens.sm,
        );
      case FlButtonSize.large:
        return const EdgeInsets.symmetric(
          horizontal: SpacingTokens.lg,
          vertical: SpacingTokens.md,
        );
    }
  }

  double get _fontSize {
    switch (size) {
      case FlButtonSize.small:
        return 13;
      case FlButtonSize.medium:
        return 14;
      case FlButtonSize.large:
        return 16;
    }
  }

  double get _iconSize {
    switch (size) {
      case FlButtonSize.small:
        return IconSizeTokens.xs;
      case FlButtonSize.medium:
        return IconSizeTokens.sm;
      case FlButtonSize.large:
        return IconSizeTokens.md;
    }
  }

  bool get _disabled => onPressed == null || isLoading;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final colors = _resolveColors(brightness);

    final buttonChild = _buildChild(colors);

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(RadiusTokens.md),
      side: variant == FlButtonVariant.outline
          ? BorderSide(
              color: _disabled
                  ? (brightness == Brightness.light
                        ? NeutralColorsLight.neutral3
                        : NeutralColorsDark.neutral3)
                  : ColorTokens.primary,
            )
          : BorderSide.none,
    );

    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(
        Size(expanded ? double.infinity : 0, _height),
      ),
      padding: WidgetStatePropertyAll(_padding),
      shape: WidgetStatePropertyAll(shape),
      backgroundColor: WidgetStatePropertyAll(colors.background),
      foregroundColor: WidgetStatePropertyAll(colors.foreground),
      overlayColor: WidgetStatePropertyAll(
        colors.foreground.withValues(alpha: 0.08),
      ),
      elevation: const WidgetStatePropertyAll(0),
    );

    if (variant == FlButtonVariant.text) {
      return TextButton(
        onPressed: _disabled ? null : onPressed,
        style: style,
        child: buttonChild,
      );
    }

    return ElevatedButton(
      onPressed: _disabled ? null : onPressed,
      style: style,
      child: buttonChild,
    );
  }

  Widget _buildChild(_ButtonColors colors) {
    if (isLoading) {
      return SizedBox(
        width: _iconSize,
        height: _iconSize,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: colors.foreground,
        ),
      );
    }

    final textWidget = Text(
      label,
      style: TextStyle(fontSize: _fontSize, fontWeight: FontWeight.w500),
    );

    if (icon == null) return textWidget;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: _iconSize),
        const SizedBox(width: SpacingTokens.sm),
        textWidget,
      ],
    );
  }

  _ButtonColors _resolveColors(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final disabledBg = isLight
        ? NeutralColorsLight.neutral2
        : NeutralColorsDark.neutral2;
    final disabledFg = isLight
        ? NeutralColorsLight.neutral4
        : NeutralColorsDark.neutral4;

    if (_disabled) {
      return _ButtonColors(
        background:
            variant == FlButtonVariant.text ||
                variant == FlButtonVariant.outline
            ? Colors.transparent
            : disabledBg,
        foreground: disabledFg,
      );
    }

    switch (variant) {
      case FlButtonVariant.primary:
        return const _ButtonColors(
          background: ColorTokens.primary,
          foreground: Colors.white,
        );
      case FlButtonVariant.secondary:
        return _ButtonColors(
          background: ColorTokens.primaryLight,
          foreground: brightness == Brightness.light
              ? ColorTokens.primaryDark
              : Colors.white,
        );
      case FlButtonVariant.outline:
        return const _ButtonColors(
          background: Colors.transparent,
          foreground: ColorTokens.primary,
        );
      case FlButtonVariant.text:
        return const _ButtonColors(
          background: Colors.transparent,
          foreground: ColorTokens.primary,
        );
    }
  }
}

class _ButtonColors {
  const _ButtonColors({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}
