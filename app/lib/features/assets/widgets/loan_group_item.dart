import 'package:flutter/material.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/micro_interactions.dart';
import '../../../domain/models/loan_models.dart';

/// 组合贷（loan group）紧凑行 — 视觉对齐 [LoanItem]。
///
/// 资产 Tab 负债区里展示一个组合贷的汇总：名称 + 组合贷标识 +
/// 整体还款进度 + 子贷款剩余本金之和（[LoanGroupDisplayItem.totalRemainingPrincipal]，单位：分）。
class LoanGroupItem extends StatelessWidget {
  final LoanGroupDisplayItem item;
  final VoidCallback? onTap;

  const LoanGroupItem({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = context.semanticColors;
    final progress = item.overallProgress.clamp(0.0, 1.0);

    return TapScale(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.base),
        child: Card(
          margin: const EdgeInsets.only(bottom: SpacingTokens.xs),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => withHaptic(() => onTap?.call()),
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
                          valueColor: AlwaysStoppedAnimation(colors.liability),
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
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.group.name,
                                style: TypographyTokens.bodyMd().copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: colors.liability.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '组合贷',
                                style: TypographyTokens.caption(
                                  color: colors.liability,
                                ).copyWith(fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.subLoans.length} 笔子贷款',
                          style: TypographyTokens.caption(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '¥${formatCentsWan(item.totalRemainingPrincipal)}',
                        style: TypographyTokens.amount(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.liability,
                        ),
                      ),
                      Text(
                        '剩余本金',
                        style: TypographyTokens.caption(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.4,
                          ),
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
