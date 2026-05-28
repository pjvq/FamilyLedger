import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/format.dart';
import '../../../data/local/database.dart';
import '../../../domain/models/dashboard_models.dart';
import '../../../domain/providers/dashboard_provider.dart';
import '../../../domain/providers/loan_provider.dart';

/// Upcoming reminders card — shows loan payment due dates + budget warnings.
///
/// Displayed at the top of the overview/dashboard page.
/// Only renders if there are actionable reminders.
class RemindersCard extends ConsumerWidget {
  const RemindersCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loans = ref.watch(loanProvider.select((s) => s.loans));
    final budget = ref.watch(
        dashboardProvider.select((s) => s.budgetSummary));

    final reminders = _buildReminders(loans, budget);
    if (reminders.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpacingTokens.base, 0, SpacingTokens.base, SpacingTokens.sm,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? NeutralColorsDark.neutral2 : NeutralColorsLight.neutral1,
          borderRadius: BorderRadius.circular(RadiusTokens.lg),
          border: Border.all(
            color: isDark ? NeutralColorsDark.neutral3 : NeutralColorsLight.neutral3,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  SpacingTokens.base, SpacingTokens.md,
                  SpacingTokens.base, SpacingTokens.xs),
              child: Row(
                children: [
                  Icon(Icons.notifications_active_rounded,
                      size: 16, color: context.semanticColors.warning),
                  const SizedBox(width: SpacingTokens.xs),
                  Text(
                    '待办提醒',
                    style: TypographyTokens.bodySm().copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // Reminder items
            ...reminders.map((r) => _ReminderItem(reminder: r)),
            const SizedBox(height: SpacingTokens.sm),
          ],
        ),
      ),
    );
  }

  List<_Reminder> _buildReminders(List<Loan> loans, BudgetSummaryData budget) {
    final reminders = <_Reminder>[];
    final now = DateTime.now();
    final today = now.day;

    // Loan payment reminders: show if payment day is within 7 days
    for (final loan in loans) {
      if (loan.paidMonths >= loan.totalMonths) continue; // fully paid

      final payDay = loan.paymentDay;
      final daysUntil = _daysUntilPayment(today, payDay, now);

      if (daysUntil <= 7) {
        reminders.add(_Reminder(
          type: _ReminderType.loanPayment,
          title: loan.name,
          subtitle: daysUntil == 0
              ? '今天还款日'
              : daysUntil == 1
                  ? '明天还款'
                  : '$daysUntil天后还款',
          icon: Icons.account_balance_rounded,
          color: daysUntil <= 1
              ? const Color(0xFFE74C3C)
              : const Color(0xFFF39C12),
          routeId: loan.id,
        ));
      }
    }

    // Budget overrun warning
    if (budget.totalBudget > 0 && budget.executionRate >= 0.8) {
      final pct = (budget.executionRate * 100).toInt();
      reminders.add(_Reminder(
        type: _ReminderType.budgetWarning,
        title: '预算预警',
        subtitle: pct >= 100
            ? '本月已超支 ¥${formatCentsWan((budget.totalSpent - budget.totalBudget).abs())}'
            : '已使用 $pct%，剩余 ¥${formatCentsWan(budget.totalBudget - budget.totalSpent)}',
        icon: Icons.warning_amber_rounded,
        color: pct >= 100
            ? const Color(0xFFE74C3C)
            : const Color(0xFFF39C12),
      ));
    }

    return reminders;
  }

  /// Calculate days until next payment day from today.
  int _daysUntilPayment(int today, int payDay, DateTime now) {
    if (payDay >= today) {
      return payDay - today;
    }
    // Payment day already passed this month — next month
    final nextMonth = DateTime(now.year, now.month + 1, payDay);
    return nextMonth.difference(now).inDays;
  }
}

// ─── Models ───

enum _ReminderType { loanPayment, budgetWarning }

class _Reminder {
  final _ReminderType type;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? routeId;

  const _Reminder({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.routeId,
  });
}

// ─── Reminder Item Widget ───

class _ReminderItem extends StatelessWidget {
  final _Reminder reminder;

  const _ReminderItem({required this.reminder});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => _handleTap(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.base,
            vertical: SpacingTokens.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: reminder.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(reminder.icon, size: 16, color: reminder.color),
              ),
              const SizedBox(width: SpacingTokens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.title,
                      style: TypographyTokens.bodyMd().copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      reminder.subtitle,
                      style: TypographyTokens.caption(color: reminder.color),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context) {
    switch (reminder.type) {
      case _ReminderType.loanPayment:
        if (reminder.routeId != null) {
          context.push(AppRouter.loanDetail(reminder.routeId!));
        }
      case _ReminderType.budgetWarning:
        context.push(AppRouter.budget);
    }
  }
}
