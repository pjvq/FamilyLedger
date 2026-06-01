import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../domain/providers/budget_provider.dart';
import 'overview_card_container.dart';

/// Progress bar height for budget category rows.
const double _progressBarHeight = 5;

/// Budget progress card — swipeable between monthly and yearly view.
///
/// Hidden when no budget is configured (shows setup hint instead).
class BudgetProgressCard extends ConsumerStatefulWidget {
  const BudgetProgressCard({super.key});

  @override
  ConsumerState<BudgetProgressCard> createState() => _BudgetProgressCardState();
}

class _BudgetProgressCardState extends ConsumerState<BudgetProgressCard> {
  int _currentPage = 0; // 0=monthly, 1=yearly

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final execution = ref.watch(budgetProvider.select((s) => s.execution));

    if (execution == null || execution.totalBudget == 0) {
      return GestureDetector(
        onTap: () => context.push(AppRouter.budget),
        child: OverviewCardContainer(
          child: Row(
            children: [
              Icon(Icons.track_changes_rounded,
                  size: IconSizeTokens.xs, color: colors.warning),
              const SizedBox(width: SpacingTokens.xs),
              Text(
                '设置月度预算',
                style: TypographyTokens.bodySm().copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded,
                  size: IconSizeTokens.sm,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4)),
            ],
          ),
        ),
      );
    }

    // Annual budget from provider
    final budgetState = ref.watch(budgetProvider);
    final annualBudget = budgetState.annualBudget;
    final annualExec = budgetState.annualExecution;

    // If no annual budget set, use monthly × 12 as estimate
    final yearlyBudget = annualBudget != null
        ? annualBudget.totalAmount
        : (execution.totalBudget * 12);
    final yearlySpent = annualExec?.totalSpent ?? 0;

    return GestureDetector(
      onTap: () => context.push(AppRouter.budget),
      child: OverviewCardContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Swipeable content
            SizedBox(
              height: _calcCardHeight(execution),
              child: PageView(
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _MonthlyView(execution: execution, colors: colors),
                  _YearlyView(
                    yearlyBudget: yearlyBudget,
                    yearlySpent: yearlySpent,
                    colors: colors,
                  ),
                ],
              ),
            ),
            // Page indicator
            const SizedBox(height: SpacingTokens.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PageDot(active: _currentPage == 0),
                const SizedBox(width: 6),
                _PageDot(active: _currentPage == 1),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _calcCardHeight(BudgetExecutionData execution) {
    final catCount = execution.categoryExecutions.length.clamp(0, 3);
    // Layout: header row + spacing + category rows (generous to handle font scaling)
    const headerHeight = 24.0 + SpacingTokens.md;
    const rowHeight = 28.0 + SpacingTokens.sm;
    return headerHeight + catCount * rowHeight + SpacingTokens.sm;
  }
}

/// Monthly budget view
class _MonthlyView extends StatelessWidget {
  final BudgetExecutionData execution;
  final AppSemanticColors colors;

  const _MonthlyView({required this.execution, required this.colors});

  @override
  Widget build(BuildContext context) {
    final categoriesByRate = [...execution.categoryExecutions]
      ..sort((a, b) => b.executionRate.compareTo(a.executionRate));
    final top3 = categoriesByRate.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.track_changes_rounded,
                size: IconSizeTokens.xs, color: colors.warning),
            const SizedBox(width: SpacingTokens.xs),
            Text(
              '月预算',
              style: TypographyTokens.bodySm().copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '${(execution.executionRate * 100).toInt()}%',
              style: TypographyTokens.bodySm().copyWith(
                fontWeight: FontWeight.w700,
                color: _rateColor(execution.executionRate, colors),
              ),
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.md),
        ...top3.map((cat) => _BudgetCategoryRow(
              name: cat.categoryName,
              rate: cat.executionRate,
              colors: colors,
            )),
      ],
    );
  }
}

/// Yearly budget view
class _YearlyView extends StatelessWidget {
  final int yearlyBudget;
  final int yearlySpent;
  final AppSemanticColors colors;

  const _YearlyView({
    required this.yearlyBudget,
    required this.yearlySpent,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final rate = yearlyBudget > 0 ? yearlySpent / yearlyBudget : 0.0;
    final now = DateTime.now();
    // Expected progress based on time elapsed in the year
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays + 1;
    final expectedRate = dayOfYear / 365;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                size: IconSizeTokens.xs, color: ColorTokens.primary),
            const SizedBox(width: SpacingTokens.xs),
            Text(
              '${now.year}年预算',
              style: TypographyTokens.bodySm().copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '${(rate * 100).toInt()}%',
              style: TypographyTokens.bodySm().copyWith(
                fontWeight: FontWeight.w700,
                color: _rateColor(rate, colors),
              ),
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.sm),
        // Total progress bar
        LayoutBuilder(
          builder: (context, constraints) {
            final barWidth = constraints.maxWidth;
            return ClipRRect(
              borderRadius: BorderRadius.circular(RadiusTokens.sm / 2),
              child: Stack(
                children: [
                  LinearProgressIndicator(
                    value: rate.clamp(0.0, 1.0),
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.06),
                    color: _rateColor(rate, colors),
                    minHeight: 8,
                  ),
                  // Expected progress marker
                  Positioned(
                    left: barWidth * expectedRate.clamp(0.0, 1.0),
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 2,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: SpacingTokens.sm),
        // Summary text
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '已用 ¥${_fmtYuan(yearlySpent)}',
              style: TypographyTokens.caption(),
            ),
            Text(
              '总 ¥${_fmtYuan(yearlyBudget)}',
              style: TypographyTokens.caption(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          rate > expectedRate ? '⚠️ 超出预期进度' : '✅ 支出进度正常',
          style: TypographyTokens.caption(
            color: rate > expectedRate ? colors.warning : colors.income,
          ),
        ),
      ],
    );
  }

  String _fmtYuan(int cents) => (cents / 100).toStringAsFixed(0);
}

/// Page indicator dot
class _PageDot extends StatelessWidget {
  final bool active;
  const _PageDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: active ? 12 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: active
            ? ColorTokens.primary
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

Color _rateColor(double rate, AppSemanticColors colors) {
  if (rate >= 1.0) return colors.error;
  if (rate >= 0.8) return colors.warning;
  return colors.income;
}

class _BudgetCategoryRow extends StatelessWidget {
  final String name;
  final double rate;
  final AppSemanticColors colors;

  const _BudgetCategoryRow({
    required this.name,
    required this.rate,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = _rateColor(rate, colors);

    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TypographyTokens.caption(),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${(rate * 100).toInt()}%',
                style: TypographyTokens.caption(color: barColor).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(RadiusTokens.sm / 2),
            child: LinearProgressIndicator(
              value: rate.clamp(0.0, 1.0),
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.06),
              color: barColor,
              minHeight: _progressBarHeight,
            ),
          ),
        ],
      ),
    );
  }
}
