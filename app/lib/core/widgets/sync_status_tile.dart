import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/providers/app_providers.dart';
import '../../domain/providers/sync_status_provider.dart';
import '../../sync/sync_engine.dart';
import '../theme/tokens/semantic_theme_extension.dart';

/// Shared sync status indicator tile used in More and Settings pages.
class SyncStatusTile extends ConsumerWidget {
  const SyncStatusTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStatusProvider);
    final theme = Theme.of(context);
    final colors = context.semanticColors;

    final (icon, label, subtitle, color) = switch (syncState.status) {
      SyncStatus.synced => (
          Icons.cloud_done_rounded,
          '已同步',
          '所有数据均已同步到服务器',
          colors.success,
        ),
      SyncStatus.syncing => (
          Icons.sync_rounded,
          '同步中...',
          '正在上传本地变更',
          theme.colorScheme.primary,
        ),
      SyncStatus.pending => (
          Icons.cloud_upload_outlined,
          '待同步',
          '${syncState.pendingCount} 条操作等待上传',
          colors.warning,
        ),
      SyncStatus.offline => (
          Icons.cloud_off_rounded,
          '离线模式',
          '数据仅保存在本地',
          colors.warning,
        ),
      SyncStatus.failed => (
          Icons.error_outline_rounded,
          '同步失败',
          '${syncState.failedCount} 条操作上传失败，请检查网络',
          colors.error,
        ),
    };

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      ),
      trailing: syncState.status == SyncStatus.syncing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : syncState.status == SyncStatus.failed
              ? TextButton.icon(
                  onPressed: () async {
                    await ref.read(databaseProvider).resetDeadSyncOps();
                    ref.read(syncEngineProvider).syncNow();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('重试'),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.error,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                )
              : null,
    );
  }
}
