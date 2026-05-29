import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/micro_interactions.dart';
import '../../../data/local/database.dart';

/// Single loan row with circular progress indicator.
class LoanItem extends StatelessWidget {
  final Loan loan;
  final VoidCallback? onTap;

  const LoanItem({super.key, required this.loan, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = context.semanticColors;
    final progress = loan.principal > 0
        ? (loan.principal - loan.remainingPrincipal) / loan.principal
        : 0.0;

    return TapScale(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.base),
        child: Card(
          margin: const EdgeInsets.only(bottom: SpacingTokens.xs),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => hapticTap(() => onTap?.call()),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.base,
                vertical: SpacingTokens.md,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 3.5,
                          backgroundColor: isDark
                              ? NeutralColorsDark.neutral3
                              : NeutralColorsLight.neutral3,
                          valueColor:
                              AlwaysStoppedAnimation(colors.liability),
                        ),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: SpacingTokens.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loan.name,
                          style: TypographyTokens.bodyMd().copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${loan.paidMonths}/${loan.totalMonths}期 · ${loan.annualRate.toStringAsFixed(2)}%',
                          style: TypographyTokens.caption(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '¥${formatCentsWan(loan.remainingPrincipal)}',
                        style: TypographyTokens.amount(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.liability,
                        ),
                      ),
                      Text(
                        '剩余本金',
                        style: TypographyTokens.caption(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4),
                        ),
                      ),
                    ],
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
