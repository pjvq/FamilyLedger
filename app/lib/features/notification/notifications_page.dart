import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/router/app_router.dart';
import '../../data/local/database.dart' as db;
import '../../domain/providers/notification_provider.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifState = ref.watch(notificationProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('通知'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context)
                .pushNamed(AppRouter.notificationSettings),
            icon: const Icon(Icons.settings_rounded),
            tooltip: '通知设置',
          ),
        ],
      ),
      body: notifState.isLoading && notifState.notifications.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : notifState.notifications.isEmpty
              ? _EmptyState(theme: theme)
              : RefreshIndicator(
                  onRefresh: () => ref
                      .read(notificationProvider.notifier)
                      .loadNotifications(0),
                  child: _NotificationList(
                    notifications: notifState.notifications,
                    isDark: isDark,
                    theme: theme,
                    onMarkRead: (id) => ref
                        .read(notificationProvider.notifier)
                        .markAsRead([id]),
                  ),
                ),
    );
  }
}

// ────────── Empty State ──────────

class _EmptyState extends StatelessWidget {
  final ThemeData theme;
  const _EmptyState({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 80,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无通知',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '新的通知会出现在这里',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────── Notification List ──────────

class _NotificationList extends StatelessWidget {
  final List<db.Notification> notifications;
  final bool isDark;
  final ThemeData theme;
  final ValueChanged<String> onMarkRead;

  const _NotificationList({
    required this.notifications,
    required this.isDark,
    required this.theme,
    required this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    // Group: today vs earlier
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final today =
        notifications.where((n) => n.createdAt.isAfter(todayStart)).toList();
    final earlier =
        notifications.where((n) => !n.createdAt.isAfter(todayStart)).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        if (today.isNotEmpty) ...[
          _SectionHeader(title: '今天', theme: theme),
          ...today.map((n) => _NotificationTile(
                notification: n,
                isDark: isDark,
                theme: theme,
                onMarkRead: () => onMarkRead(n.id),
              )),
        ],
        if (earlier.isNotEmpty) ...[
          _SectionHeader(title: '更早', theme: theme),
          ...earlier.map((n) => _NotificationTile(
                notification: n,
                isDark: isDark,
                theme: theme,
                onMarkRead: () => onMarkRead(n.id),
              )),
        ],
      ],
    );
  }
}

// ────────── Section Header ──────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final ThemeData theme;

  const _SectionHeader({required this.title, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
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

// ────────── Notification Tile ──────────

class _NotificationTile extends StatelessWidget {
  final db.Notification notification;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onMarkRead;

  const _NotificationTile({
    required this.notification,
    required this.isDark,
    required this.theme,
    required this.onMarkRead,
  });

  IconData _typeIcon(String type) {
    switch (type) {
      case 'budget_alert':
        return Icons.warning_amber_rounded;
      case 'budget_warning':
        return Icons.trending_up_rounded;
      case 'daily_summary':
        return Icons.summarize_rounded;
      case 'loan_reminder':
        return Icons.event_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'budget_alert':
        return AppColors.expense;
      case 'budget_warning':
        return const Color(0xFFFF9500);
      case 'daily_summary':
        return AppColors.primary;
      case 'loan_reminder':
        return AppColors.asset;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${notification.isRead ? "已读" : "未读"}通知：${notification.title}，${notification.body}',
      child: Dismissible(
        key: ValueKey(notification.id),
        direction: notification.isRead
            ? DismissDirection.none
            : DismissDirection.startToEnd,
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 24),
          color: AppColors.primary.withValues(alpha: 0.1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.done_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                '标为已读',
                style: TextStyle(color: AppColors.primary),
              ),
            ],
          ),
        ),
        confirmDismiss: (direction) async {
          onMarkRead();
          return false; // Don't remove, just mark read
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color:
                    Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Stack(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _typeColor(notification.type)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _typeIcon(notification.type),
                    color: _typeColor(notification.type),
                    size: 22,
                  ),
                ),
                // Unread dot
                if (!notification.isRead)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? AppColors.cardDark
                              : AppColors.cardLight,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              notification.title,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight:
                    notification.isRead ? FontWeight.w400 : FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                notification.body,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            trailing: Text(
              _formatTime(notification.createdAt),
              style: theme.textTheme.labelSmall?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
            ),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            onTap: () {
              if (!notification.isRead) onMarkRead();
            },
          ),
        ),
      ),
    );
  }
}
