import 'package:flutter/material.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/amount_expression.dart';

/// 金额显示区域 — 显示输入表达式和计算结果
class QuickAmountDisplay extends StatelessWidget {
  final String expression;
  final String? note;
  final String currency;
  final VoidCallback? onNoteTap;

  const QuickAmountDisplay({
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
            // Main amount row
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
                  child: Text(
                    displayAmount,
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
              ],
            ),

            // Computed result (when expression has operators)
            if (computedCents != null) ...[
              const SizedBox(height: 4),
              Text(
                '= $currency${AmountExpression.formatCents(computedCents)}',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? NeutralColorsDark.neutral5
                      : NeutralColorsLight.neutral5,
                ),
              ),
            ],

            const SizedBox(height: 8),

            // Note area
            Text(
              note?.isNotEmpty == true ? note! : '添加备注...',
              style: TextStyle(
                fontSize: 14,
                color: note?.isNotEmpty == true
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
