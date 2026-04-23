import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers/sync_status_provider.dart';

/// Small sync status chip for AppBar or home page
class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStatusProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (syncState.status == SyncStatus.synced) {
      return const SizedBox.shrink(); // Nothing to show
    }

    final (icon, label, color) = switch (syncState.status) {
      SyncStatus.syncing => (
          Icons.sync_rounded,
          '同步中...',
          theme.colorScheme.primary,
        ),
      SyncStatus.pending => (
          Icons.cloud_upload_outlined,
          '${syncState.pendingCount} 条待同步',
          Colors.orange,
        ),
      SyncStatus.offline => (
          Icons.cloud_off_rounded,
          '离线模式',
          isDark ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
      _ => (Icons.check_circle_outline, '已同步', Colors.green),
    };

    return Tooltip(
      message: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            syncState.status == SyncStatus.syncing
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                : Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
