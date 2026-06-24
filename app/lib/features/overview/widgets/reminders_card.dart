import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../domain/providers/reminder_provider.dart';

/// Upcoming reminders card — shows loan payment due dates + budget warnings.
///
/// Displayed at the top of the overview/dashboard page.
/// Only renders if there are actionable reminders.
class RemindersCard extends ConsumerWidget {
  const RemindersCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(reminderProvider);
    if (reminders.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = context.semanticColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpacingTokens.base,
        0,
        SpacingTokens.base,
        SpacingTokens.sm,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? NeutralColorsDark.neutral2
              : NeutralColorsLight.neutral1,
          borderRadius: BorderRadius.circular(RadiusTokens.lg),
          border: Border.all(
            color: isDark
                ? NeutralColorsDark.neutral3
                : NeutralColorsLight.neutral3,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SpacingTokens.base,
                SpacingTokens.md,
                SpacingTokens.base,
                SpacingTokens.xs,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications_active_rounded,
                    size: 16,
                    color: colors.warning,
                  ),
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
}

// ─── Reminder Item Widget ───

class _ReminderItem extends StatelessWidget {
  final Reminder reminder;

  const _ReminderItem({required this.reminder});

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final color = reminder.isCritical ? colors.error : colors.warning;

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
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(reminder.icon, size: 16, color: color),
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
                      style: TypographyTokens.caption(color: color),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context) {
    switch (reminder.type) {
      case ReminderType.loanPayment:
        if (reminder.routeId != null) {
          context.push(AppRouter.loanDetail(reminder.routeId!));
        }
      case ReminderType.budgetWarning:
        context.push(AppRouter.budget);
    }
  }
}
