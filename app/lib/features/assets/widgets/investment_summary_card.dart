import 'package:flutter/material.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/format.dart';
import '../../../domain/providers/investment_provider.dart';

/// Compact investment portfolio summary card for the assets tab.
class InvestmentSummaryCard extends StatelessWidget {
  final PortfolioSummary portfolio;
  final VoidCallback onTap;

  const InvestmentSummaryCard({
    super.key,
    required this.portfolio,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final isUp = portfolio.totalProfit >= 0;
    final profitColor = isUp ? colors.income : colors.expense;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.base),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(SpacingTokens.base),
            child: Row(
              children: [
                // Left: total value
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '总市值',
                        style: TypographyTokens.caption(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '¥${formatCentsWan(portfolio.totalValue)}',
                        style: TypographyTokens.headlineMd().copyWith(
                          fontWeight: FontWeight.bold,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${portfolio.holdings.length} 只持仓',
                        style: TypographyTokens.caption(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                // Right: profit
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '累计收益',
                      style: TypographyTokens.caption(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${isUp ? "+" : ""}¥${formatCentsWan(portfolio.totalProfit)}',
                      style: TypographyTokens.titleLg().copyWith(
                        fontWeight: FontWeight.w700,
                        color: profitColor,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: profitColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${isUp ? "+" : ""}${(portfolio.totalReturn * 100).toStringAsFixed(2)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: profitColor,
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
    );
  }
}
