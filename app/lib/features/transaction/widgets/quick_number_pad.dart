import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/design_tokens.dart';

/// 快速记账数字键盘 — 4×4 网格，含日期/+/-/完成
///
/// Layout:
/// ```
/// [7] [8] [9] [日期]
/// [4] [5] [6] [ + ]
/// [1] [2] [3] [ - ]
/// [.] [0] [⌫] [完成]
/// ```
class QuickNumberPad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback onClear;
  final VoidCallback onConfirm;
  final VoidCallback onDateTap;
  final ValueChanged<String> onOperator;
  final bool confirmEnabled;
  final String confirmLabel;

  const QuickNumberPad({
    super.key,
    required this.onDigit,
    required this.onDelete,
    required this.onClear,
    required this.onConfirm,
    required this.onDateTap,
    required this.onOperator,
    this.confirmEnabled = true,
    this.confirmLabel = '完成',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final keyBg = isDark ? NeutralColorsDark.neutral2 : NeutralColorsLight.neutral1;
    final funcBg = isDark ? NeutralColorsDark.neutral3 : NeutralColorsLight.neutral2;

    return Container(
      padding: EdgeInsets.fromLTRB(
        SpacingTokens.sm,
        SpacingTokens.sm,
        SpacingTokens.sm,
        MediaQuery.of(context).padding.bottom + SpacingTokens.sm,
      ),
      decoration: BoxDecoration(
        color: isDark ? NeutralColorsDark.neutral1 : NeutralColorsLight.neutral0,
        border: Border(
          top: BorderSide(
            color: isDark ? NeutralColorsDark.neutral3 : NeutralColorsLight.neutral3,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRow([
            _DigitKey('7', keyBg, theme),
            _DigitKey('8', keyBg, theme),
            _DigitKey('9', keyBg, theme),
            _FuncKey(icon: Icons.calendar_today_rounded, label: '日期', bg: funcBg, theme: theme, onTap: onDateTap),
          ]),
          const SizedBox(height: 6),
          _buildRow([
            _DigitKey('4', keyBg, theme),
            _DigitKey('5', keyBg, theme),
            _DigitKey('6', keyBg, theme),
            _FuncKey(text: '+', bg: funcBg, theme: theme, onTap: () => onOperator('+')),
          ]),
          const SizedBox(height: 6),
          _buildRow([
            _DigitKey('1', keyBg, theme),
            _DigitKey('2', keyBg, theme),
            _DigitKey('3', keyBg, theme),
            _FuncKey(text: '-', bg: funcBg, theme: theme, onTap: () => onOperator('-')),
          ]),
          const SizedBox(height: 6),
          _buildRow([
            _DigitKey('.', keyBg, theme),
            _DigitKey('0', keyBg, theme),
            _DeleteKey(bg: funcBg, theme: theme, onDelete: onDelete, onClear: onClear),
            _ConfirmKey(enabled: confirmEnabled, label: confirmLabel, theme: theme, onTap: onConfirm),
          ]),
        ],
      ),
    );
  }

  Widget _buildRow(List<Widget> keys) {
    return Row(
      children: keys
          .expand((k) => [Expanded(child: k), const SizedBox(width: 6)])
          .toList()
        ..removeLast(),
    );
  }

  // ignore: unused_element
  Widget _DigitKey(String digit, Color bg, ThemeData theme) {
    return _KeyButton(
      child: Text(
        digit,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
      ),
      bg: bg,
      theme: theme,
      onTap: () {
        HapticFeedback.lightImpact();
        onDigit(digit);
      },
    );
  }

  // ignore: unused_element
  Widget _FuncKey({
    IconData? icon,
    String? text,
    String? label,
    required Color bg,
    required ThemeData theme,
    required VoidCallback onTap,
  }) {
    return _KeyButton(
      child: icon != null
          ? Icon(icon, size: 20)
          : Text(
              text!,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
      bg: bg,
      theme: theme,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      semanticLabel: label ?? text,
    );
  }

  // ignore: unused_element
  Widget _DeleteKey({
    required Color bg,
    required ThemeData theme,
    required VoidCallback onDelete,
    required VoidCallback onClear,
  }) {
    return _KeyButton(
      child: const Icon(Icons.backspace_outlined, size: 22),
      bg: bg,
      theme: theme,
      onTap: () {
        HapticFeedback.lightImpact();
        onDelete();
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        onClear();
      },
      semanticLabel: '删除',
    );
  }

  // ignore: unused_element
  Widget _ConfirmKey({
    required bool enabled,
    required String label,
    required ThemeData theme,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: enabled
            ? () {
                HapticFeedback.mediumImpact();
                onTap();
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled
              ? ColorTokens.primary
              : ColorTokens.primary.withValues(alpha: 0.3),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RadiusTokens.md),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final Widget child;
  final Color bg;
  final ThemeData theme;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;

  const _KeyButton({
    required this.child,
    required this.bg,
    required this.theme,
    required this.onTap,
    this.onLongPress,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Semantics(
        label: semanticLabel,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(RadiusTokens.md),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(RadiusTokens.md),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
