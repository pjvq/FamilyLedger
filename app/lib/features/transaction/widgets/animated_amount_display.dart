import 'package:flutter/material.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/amount_expression.dart';

/// 带滚动动画的金额显示 — 数字变化时平滑过渡
///
/// 使用 AnimatedSwitcher + SlideTransition 实现数字向上滚出、新数字从下滚入。
class AnimatedAmountDisplay extends StatelessWidget {
  final String expression;
  final String? note;
  final String currency;
  final VoidCallback? onNoteTap;

  const AnimatedAmountDisplay({
    super.key,
    required this.expression,
    this.note,
    this.currency = '¥',
    this.onNoteTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final displayAmount = expression.isEmpty || expression == '0' ? '0' : expression;
    final hasOp = AmountExpression.hasOperator(expression);
    final computedCents = hasOp ? AmountExpression.evaluateCents(expression) : null;

    return GestureDetector(
      onTap: onNoteTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main amount row with animated transition
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  currency,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w400,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.3),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          )),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      displayAmount,
                      // Only trigger switch animation on operator changes,
                      // not every digit press (prevents rapid-input stacking)
                      key: ValueKey(_operatorSignature(displayAmount)),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),

            // Computed result with animated fade
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: computedCents != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '= $currency${AmountExpression.formatCents(computedCents)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? NeutralColorsDark.neutral5
                              : NeutralColorsLight.neutral5,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 8),

            // Note area
            Builder(builder: (_) {
              final hasNote = note?.isNotEmpty ?? false;
              return Text(
                hasNote ? note! : '添加备注...',
                style: TextStyle(
                  fontSize: 14,
                  color: hasNote
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.35),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Generates a key that only changes when operators are added/removed.
  /// This prevents AnimatedSwitcher from firing on every digit keystroke.
  static String _operatorSignature(String expr) {
    final buf = StringBuffer();
    for (int i = 0; i < expr.length; i++) {
      final ch = expr[i];
      if (ch == '+' || ch == '-') {
        buf.write('$i$ch');
      }
    }
    return buf.toString();
  }
}
