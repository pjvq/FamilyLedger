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
            _buildDigitKey('7', keyBg),
            _buildDigitKey('8', keyBg),
            _buildDigitKey('9', keyBg),
            _buildFuncKey(bg: funcBg, icon: Icons.calendar_today_rounded, onTap: onDateTap, semanticLabel: '日期'),
          ]),
          const SizedBox(height: 6),
          _buildRow([
            _buildDigitKey('4', keyBg),
            _buildDigitKey('5', keyBg),
            _buildDigitKey('6', keyBg),
            _buildFuncKey(bg: funcBg, text: '+', onTap: () => onOperator('+')),
          ]),
          const SizedBox(height: 6),
          _buildRow([
            _buildDigitKey('1', keyBg),
            _buildDigitKey('2', keyBg),
            _buildDigitKey('3', keyBg),
            _buildFuncKey(bg: funcBg, text: '-', onTap: () => onOperator('-')),
          ]),
          const SizedBox(height: 6),
          _buildRow([
            _buildDigitKey('.', keyBg),
            _buildDigitKey('0', keyBg),
            _buildDeleteKey(funcBg),
            _buildConfirmKey(),
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

  Widget _buildDigitKey(String digit, Color bg) {
    return _KeyButton(
      bg: bg,
      onTap: () {
        HapticFeedback.lightImpact();
        onDigit(digit);
      },
      child: Text(
        digit,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildFuncKey({
    required Color bg,
    IconData? icon,
    String? text,
    required VoidCallback onTap,
    String? semanticLabel,
  }) {
    return _KeyButton(
      bg: bg,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      semanticLabel: semanticLabel ?? text,
      child: icon != null
          ? Icon(icon, size: 20)
          : Text(
              text!,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
    );
  }

  Widget _buildDeleteKey(Color bg) {
    return _KeyButton(
      bg: bg,
      onTap: () {
        HapticFeedback.lightImpact();
        onDelete();
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        onClear();
      },
      semanticLabel: '删除',
      child: const Icon(Icons.backspace_outlined, size: 22),
    );
  }

  Widget _buildConfirmKey() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: confirmEnabled
            ? () {
                HapticFeedback.mediumImpact();
                onConfirm();
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: confirmEnabled
              ? ColorTokens.primary
              : ColorTokens.primary.withValues(alpha: 0.3),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RadiusTokens.md),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: Text(confirmLabel),
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final Widget child;
  final Color bg;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;

  const _KeyButton({
    required this.child,
    required this.bg,
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
