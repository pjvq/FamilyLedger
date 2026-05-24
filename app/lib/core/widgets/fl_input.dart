import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// 标准文本输入框组件。
///
/// 支持 label、hint、error 提示、prefix/suffix icon、obscureText。
/// 对齐 Material 3 风格但使用自定义 design tokens。
///
/// ```dart
/// FlInput(
///   label: '金额',
///   hint: '请输入金额',
///   prefixIcon: Icons.attach_money,
/// )
/// ```
class FlInput extends StatelessWidget {
  /// Creates an [FlInput].
  const FlInput({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.error,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.enabled = true,
    this.maxLines = 1,
    this.focusNode,
  });

  /// Text editing controller.
  final TextEditingController? controller;

  /// Label text displayed above the input.
  final String? label;

  /// Hint text displayed inside the input when empty.
  final String? hint;

  /// Error message. When non-null, the input shows error styling.
  final String? error;

  /// Icon displayed at the start of the input.
  final IconData? prefixIcon;

  /// Icon displayed at the end of the input.
  final IconData? suffixIcon;

  /// Callback when suffix icon is tapped.
  final VoidCallback? onSuffixTap;

  /// Whether to obscure text (for passwords).
  final bool obscureText;

  /// Keyboard type.
  final TextInputType? keyboardType;

  /// Called when the text changes.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits (e.g. presses done).
  final ValueChanged<String>? onSubmitted;

  /// Whether to autofocus this input.
  final bool autofocus;

  /// Whether the input is enabled.
  final bool enabled;

  /// Maximum number of lines.
  final int maxLines;

  /// Focus node.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isLight = brightness == Brightness.light;

    final fillColor =
        isLight ? NeutralColorsLight.neutral2 : NeutralColorsDark.neutral2;
    final textColor =
        isLight ? NeutralColorsLight.neutral7 : NeutralColorsDark.neutral7;
    final hintColor =
        isLight ? NeutralColorsLight.neutral4 : NeutralColorsDark.neutral4;
    final errorColor =
        isLight ? SemanticColorsLight.error : SemanticColorsDark.error;

    final hasError = error != null && error!.isNotEmpty;

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(RadiusTokens.md),
      borderSide: BorderSide.none,
    );

    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(RadiusTokens.md),
      borderSide: BorderSide(color: errorColor, width: 1.5),
    );

    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(RadiusTokens.md),
      borderSide: const BorderSide(color: ColorTokens.primary, width: 1.5),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: TypographyTokens.bodyMd(color: textColor),
          ),
          const SizedBox(height: SpacingTokens.sm),
        ],
        TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          autofocus: autofocus,
          enabled: enabled,
          maxLines: maxLines,
          style: TypographyTokens.bodyLg(color: textColor),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TypographyTokens.bodyLg(color: hintColor),
            filled: true,
            fillColor: fillColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.base,
              vertical: SpacingTokens.md,
            ),
            border: border,
            enabledBorder: hasError ? errorBorder : border,
            focusedBorder: hasError ? errorBorder : focusedBorder,
            disabledBorder: border,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: IconSizeTokens.md, color: hintColor)
                : null,
            suffixIcon: suffixIcon != null
                ? GestureDetector(
                    onTap: onSuffixTap,
                    child: Icon(suffixIcon,
                        size: IconSizeTokens.md, color: hintColor),
                  )
                : null,
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: SpacingTokens.xs),
          Text(
            error!,
            style: TypographyTokens.caption(color: errorColor),
          ),
        ],
      ],
    );
  }
}
