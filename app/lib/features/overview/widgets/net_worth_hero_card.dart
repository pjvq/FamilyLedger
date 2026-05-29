import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/animated_counter.dart';
import '../../../domain/providers/dashboard_provider.dart';

/// Net worth hero card — gradient background, big number, month-over-month change.
class NetWorthHeroCard extends ConsumerWidget {
  const NetWorthHeroCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dashboardProvider.select((s) => s.netWorth));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.semanticColors;

    final isUp = data.changeFromLastMonth >= 0;
    final changeColor = isUp ? colors.income : colors.expense;

    return Hero(
      tag: 'net_worth_hero',
      child: Padding(
      padding: const EdgeInsets.fromLTRB(
          SpacingTokens.base, SpacingTokens.xs, SpacingTokens.base, SpacingTokens.sm),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [DarkCardGradients.dashboardStart, DarkCardGradients.dashboardEnd]
                : [GradientTokens.primaryGradientStart, GradientTokens.primaryGradientDeep],
          ),
          borderRadius: BorderRadius.circular(RadiusTokens.lg),
          boxShadow: isDark ? ShadowTokensDark.md : ShadowTokensLight.md,
        ),
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '净资产',
                style: TypographyTokens.bodySm(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: SpacingTokens.sm),
              AnimatedCounter(
                value: data.total,
                prefix: '¥ ',
                useWanUnit: true,
                style: TypographyTokens.displayLg().copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: SpacingTokens.sm),
              if (data.changeFromLastMonth != 0 || data.changePercent != 0)
                Row(
                  children: [
                    Icon(
                      isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      size: IconSizeTokens.xs,
                      color: changeColor,
                    ),
                    const SizedBox(width: SpacingTokens.xs),
                    Text(
                      '${data.changePercent >= 0 ? "+" : ""}${data.changePercent.toStringAsFixed(1)}%',
                      style: TypographyTokens.bodySm(color: changeColor).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: SpacingTokens.sm),
                    Text(
                      '较上月',
                      style: TypographyTokens.caption(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: SpacingTokens.md),
              // Asset breakdown row
              Row(
                children: [
                  _MiniStat(
                    label: '资产',
                    value: data.totalAssets,
                    color: colors.income,
                  ),
                  const SizedBox(width: SpacingTokens.base),
                  _MiniStat(
                    label: '负债',
                    value: data.loanBalance,
                    color: colors.expense,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TypographyTokens.caption(
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: SpacingTokens.xs),
        Text(
          '¥${formatCentsMini(value)}',
          style: TypographyTokens.bodyMd().copyWith(
            color: color.withValues(alpha: 0.9),
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
