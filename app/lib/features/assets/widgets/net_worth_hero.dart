import 'package:flutter/material.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/models/dashboard_models.dart';

/// Net worth hero card — shows total, assets vs liabilities bar, MoM change.
class NetWorthHero extends StatelessWidget {
  final NetWorthData netWorth;

  const NetWorthHero({super.key, required this.netWorth});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isUp = netWorth.changeFromLastMonth >= 0;
    final totalAssets =
        netWorth.cashAndBank + netWorth.investmentValue + netWorth.fixedAssetValue;
    final totalLiabilities = netWorth.loanBalance.abs();
    // Guard against NaN/Infinity (review #2)
    final safeChangePercent = netWorth.changePercent.isFinite
        ? netWorth.changePercent
        : 0.0;

    return Semantics(
      label: '净资产${formatCentsWan(netWorth.total)}，'
          '总资产${formatCentsWan(totalAssets)}，负债${formatCentsWan(totalLiabilities)}，'
          '较上月${isUp ? "增加" : "减少"}${formatCentsWan(netWorth.changeFromLastMonth.abs())}',
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          SpacingTokens.base,
          SpacingTokens.sm,
          SpacingTokens.base,
          SpacingTokens.base,
        ),
        padding: const EdgeInsets.all(SpacingTokens.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [DarkCardGradients.netWorthStart, DarkCardGradients.netWorthEnd]
                : [ColorTokens.primary, GradientTokens.primaryGradientSoft],
          ),
          borderRadius: BorderRadius.circular(RadiusTokens.xl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '净资产',
              style: TypographyTokens.bodySm(
                  color: Colors.white.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: SpacingTokens.xs),
            AnimatedCounter(
              value: netWorth.total,
              prefix: '¥',
              useWanUnit: true,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: SpacingTokens.sm),
            // Month-over-month change
            Row(
              children: [
                Icon(
                  isUp
                      ? Icons.arrow_drop_up_rounded
                      : Icons.arrow_drop_down_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 20,
                ),
                Text(
                  '较上月 ${isUp ? "+" : ""}${formatCentsWan(netWorth.changeFromLastMonth)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (safeChangePercent != 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${isUp ? "+" : ""}${(safeChangePercent * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: SpacingTokens.base),
            // Assets vs Liabilities bar (hidden when empty — review #3)
            if (totalAssets > 0 || totalLiabilities > 0) ...[
              _AssetLiabilityBar(
                totalAssets: totalAssets,
                totalLiabilities: totalLiabilities,
              ),
              const SizedBox(height: SpacingTokens.sm),
              Row(
                children: [
                  _LegendDot(color: Colors.white.withValues(alpha: 0.9)),
                  const SizedBox(width: 4),
                  Text(
                    '资产 ¥${formatCentsWan(totalAssets)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 16),
                  _LegendDot(color: Colors.white.withValues(alpha: 0.4)),
                  const SizedBox(width: 4),
                  Text(
                    '负债 ¥${formatCentsWan(totalLiabilities)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AssetLiabilityBar extends StatelessWidget {
  final int totalAssets;
  final int totalLiabilities;

  const _AssetLiabilityBar({
    required this.totalAssets,
    required this.totalLiabilities,
  });

  @override
  Widget build(BuildContext context) {
    final total = totalAssets + totalLiabilities;
    final assetRatio = total > 0 ? totalAssets / total : 0.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 6,
        child: Row(
          children: [
            Expanded(
              flex: (assetRatio * 100).round().clamp(1, 99),
              child: Container(
                  color: Colors.white.withValues(alpha: 0.9)),
            ),
            Expanded(
              flex: ((1 - assetRatio) * 100).round().clamp(1, 99),
              child: Container(
                  color: Colors.white.withValues(alpha: 0.3)),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  const _LegendDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
