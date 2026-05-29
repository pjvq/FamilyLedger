import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../models/dashboard_models.dart';
import 'dashboard_provider.dart';
import 'loan_provider.dart';

// ─── Models ───

enum ReminderType { loanPayment, budgetWarning }

@immutable
class Reminder {
  final ReminderType type;
  final String title;
  final String subtitle;
  final IconData icon;
  /// Semantic severity: true = error/critical, false = warning.
  final bool isCritical;
  final String? routeId;

  const Reminder({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isCritical,
    this.routeId,
  });
}

// ─── Provider ───

/// Provides computed reminders list based on loans and budget state.
///
/// Business rules:
/// - Loan reminders: payment day within 7 days → show reminder.
/// - Budget warning: execution rate ≥ 80% → show warning.
///
/// NOTE: If loan count grows significantly, consider splitting into
/// separate loan/budget reminder providers to reduce recomputation.
final reminderProvider = Provider<List<Reminder>>((ref) {
  final loans = ref.watch(loanProvider.select((s) => s.loans));
  final budget = ref.watch(
      dashboardProvider.select((s) => s.budgetSummary));
  return buildReminders(loans, budget);
});

/// Pure function to build reminders — testable without providers.
///
/// [now] can be injected for testing; defaults to [DateTime.now].
List<Reminder> buildReminders(
  List<Loan> loans,
  BudgetSummaryData budget, {
  DateTime? now,
}) {
  final effectiveNow = now ?? DateTime.now();
  final reminders = <Reminder>[];

  // Loan payment reminders: show if payment day is within 7 days
  for (final loan in loans) {
    if (loan.paidMonths >= loan.totalMonths) continue; // fully paid

    final daysUntil = daysUntilPayment(loan.paymentDay, effectiveNow);

    if (daysUntil <= 7) {
      reminders.add(Reminder(
        type: ReminderType.loanPayment,
        title: loan.name,
        subtitle: daysUntil == 0
            ? '今天还款日'
            : daysUntil == 1
                ? '明天还款'
                : '$daysUntil天后还款',
        icon: Icons.account_balance_rounded,
        isCritical: daysUntil <= 1,
        routeId: loan.id,
      ));
    }
  }

  // Budget overrun warning
  if (budget.totalBudget > 0 && budget.executionRate >= 0.8) {
    final pct = (budget.executionRate * 100).toInt();
    reminders.add(Reminder(
      type: ReminderType.budgetWarning,
      title: '预算预警',
      subtitle: pct >= 100
          ? '本月已超支'
          : '已使用 $pct%',
      icon: Icons.warning_amber_rounded,
      isCritical: pct >= 100,
    ));
  }

  return reminders;
}

/// Calculate days until next payment day.
///
/// Bank convention: if [payDay] exceeds the number of days in the
/// current (or next) month, treat the last day of that month as the
/// effective payment day.
int daysUntilPayment(int payDay, DateTime now) {
  final today = now.day;
  final daysInThisMonth = DateUtils.getDaysInMonth(now.year, now.month);

  // Effective payment day this month (clamp to month length).
  final effectivePayDay = payDay.clamp(1, daysInThisMonth);

  if (effectivePayDay >= today) {
    return effectivePayDay - today;
  }

  // Payment day already passed this month — compute for next month.
  final nextMonthYear = now.month == 12 ? now.year + 1 : now.year;
  final nextMonth = now.month == 12 ? 1 : now.month + 1;
  final daysInNextMonth = DateUtils.getDaysInMonth(nextMonthYear, nextMonth);
  final effectiveNextPayDay = payDay.clamp(1, daysInNextMonth);

  final nextPayDate = DateTime(nextMonthYear, nextMonth, effectiveNextPayDay);
  return nextPayDate.difference(DateTime(now.year, now.month, now.day)).inDays;
}
