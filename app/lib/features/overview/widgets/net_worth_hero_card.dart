import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/design_tokens.dart';
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

    return Padding(
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
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : ColorTokens.primary)
                  .withValues(alpha: isDark ? 0.3 : 0.2),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '净资产',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '¥ ${_fmtDisplay(data.total)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 8),
              if (data.changeFromLastMonth != 0 || data.changePercent != 0)
                Row(
                  children: [
                    Icon(
                      isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      size: 14,
                      color: changeColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${data.changePercent >= 0 ? "+" : ""}${data.changePercent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: changeColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '较上月',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              // Asset breakdown row
              Row(
                children: [
                  _MiniStat(label: '资产', value: data.cashAndBank + data.investmentValue + data.fixedAssetValue, color: colors.income),
                  const SizedBox(width: 16),
                  _MiniStat(label: '负债', value: data.loanBalance, color: colors.expense),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmtDisplay(int cents) {
    final yuan = cents / 100;
    if (yuan.abs() >= 10000) return '${(yuan / 10000).toStringAsFixed(2)}万';
    return yuan.toStringAsFixed(2);
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final yuan = value / 100;
    final display = yuan.abs() >= 10000
        ? '${(yuan / 10000).toStringAsFixed(1)}万'
        : yuan.toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '¥$display',
          style: TextStyle(
            color: color.withValues(alpha: 0.9),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
