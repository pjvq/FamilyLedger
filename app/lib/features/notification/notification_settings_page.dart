import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/providers/notification_provider.dart';

class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifState = ref.watch(notificationProvider);
    final settings = notifState.settings;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    void updateSetting(NotificationSettingsModel newSettings) {
      ref.read(notificationProvider.notifier).updateSettings(newSettings);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('通知设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Section: Budget alerts
          _SectionHeader(title: '预算提醒', theme: theme),
          _SettingSwitchTile(
            icon: Icons.warning_amber_rounded,
            iconColor: AppColors.expense,
            title: '预算超支提醒',
            subtitle: '支出超过预算金额时通知',
            value: settings.budgetAlert,
            isDark: isDark,
            onChanged: (v) =>
                updateSetting(settings.copyWith(budgetAlert: v)),
          ),
          _SettingSwitchTile(
            icon: Icons.trending_up_rounded,
            iconColor: const Color(0xFFFF9500),
            title: '预算80%预警',
            subtitle: '支出达到预算80%时提醒',
            value: settings.budgetWarning,
            isDark: isDark,
            onChanged: (v) =>
                updateSetting(settings.copyWith(budgetWarning: v)),
          ),

          const SizedBox(height: 16),
          _SectionHeader(title: '定期提醒', theme: theme),
          _SettingSwitchTile(
            icon: Icons.summarize_rounded,
            iconColor: AppColors.primary,
            title: '每日支出汇总',
            subtitle: '每天晚上推送今日支出概览',
            value: settings.dailySummary,
            isDark: isDark,
            onChanged: (v) =>
                updateSetting(settings.copyWith(dailySummary: v)),
          ),
          _SettingSwitchTile(
            icon: Icons.event_rounded,
            iconColor: AppColors.asset,
            title: '还款日提醒',
            subtitle: '信用卡/借贷还款日前提醒',
            value: settings.loanReminder,
            isDark: isDark,
            onChanged: (v) =>
                updateSetting(settings.copyWith(loanReminder: v)),
          ),

          // Reminder days slider
          if (settings.loanReminder) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '提前提醒天数',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Semantics(
                            label: '提前${settings.reminderDaysBefore}天提醒',
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: (isDark
                                        ? AppColors.primaryDark
                                        : AppColors.primary)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${settings.reminderDaysBefore}天',
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.primaryDark
                                      : AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: settings.reminderDaysBefore.toDouble(),
                        min: 1,
                        max: 7,
                        divisions: 6,
                        label: '${settings.reminderDaysBefore}天',
                        onChanged: (v) => updateSetting(
                          settings.copyWith(
                              reminderDaysBefore: v.round()),
                        ),
                      ),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '1天',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '7天',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ────────── Sub-widgets ──────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final ThemeData theme;

  const _SectionHeader({required this.title, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SettingSwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final bool isDark;
  final ValueChanged<bool> onChanged;

  const _SettingSwitchTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: title,
      hint: subtitle,
      toggled: value,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        child: SwitchListTile(
          secondary: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(subtitle),
          value: value,
          onChanged: onChanged,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
