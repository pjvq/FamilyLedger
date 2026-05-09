import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers/sync_status_provider.dart';
import '../../domain/providers/app_providers.dart';

/// Compact sync status indicator for AppBar.
/// Always visible — shows connection dot + optional status text.
class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStatusProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final familyId = ref.watch(currentFamilyIdProvider);
    final isFamilyMode = familyId != null && familyId.isNotEmpty;

    final (icon, label, color, showDot) = _resolveDisplay(syncState, isDark, theme);

    return Tooltip(
      message: _tooltipMessage(syncState, isFamilyMode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDot) ...[
              _ConnectionDot(color: _dotColor(syncState)),
              const SizedBox(width: 6),
            ],
            if (syncState.status == SyncStatus.syncing)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: color,
                ),
              )
            else
              Icon(icon, size: 14, color: color),
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

  (IconData, String, Color, bool) _resolveDisplay(
    SyncState state,
    bool isDark,
    ThemeData theme,
  ) {
    return switch (state.status) {
      SyncStatus.syncing => (
          Icons.sync_rounded,
          '同步中',
          theme.colorScheme.primary,
          true,
        ),
      SyncStatus.pending => (
          Icons.cloud_upload_outlined,
          '${state.pendingCount} 待上传',
          Colors.orange,
          true,
        ),
      SyncStatus.failed => (
          Icons.error_outline_rounded,
          '${state.failedCount} 条失败',
          Colors.red,
          true,
        ),
      SyncStatus.offline => (
          Icons.cloud_off_rounded,
          '离线',
          isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          true,
        ),
      SyncStatus.synced => (
          Icons.check_circle_outline_rounded,
          _syncedLabel(state),
          Colors.green,
          true,
        ),
    };
  }

  String _syncedLabel(SyncState state) {
    if (state.lastSyncTime == null) return '已同步';
    final diff = DateTime.now().difference(state.lastSyncTime!);
    if (diff.inSeconds < 10) return '刚刚同步';
    if (diff.inMinutes < 1) return '${diff.inSeconds}秒前';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    return '${diff.inHours}小时前';
  }

  String _tooltipMessage(SyncState state, bool isFamilyMode) {
    final parts = <String>[];

    if (isFamilyMode) {
      parts.add('家庭模式');
    }

    parts.add(switch (state.status) {
      SyncStatus.synced => '数据已同步',
      SyncStatus.syncing => '正在同步...',
      SyncStatus.pending => '${state.pendingCount} 条数据等待上传',
      SyncStatus.failed => '${state.failedCount} 条数据上传失败',
      SyncStatus.offline => '当前无网络连接',
    });

    if (state.wsConnected) {
      parts.add('实时连接正常');
    } else if (state.status != SyncStatus.offline) {
      parts.add('实时连接断开');
    }

    if (state.lastSyncTime != null) {
      final diff = DateTime.now().difference(state.lastSyncTime!);
      if (diff.inMinutes < 1) {
        parts.add('最后同步: 刚刚');
      } else {
        parts.add('最后同步: ${diff.inMinutes}分钟前');
      }
    }

    return parts.join(' · ');
  }

  Color _dotColor(SyncState state) {
    if (state.status == SyncStatus.offline) return Colors.grey;
    if (state.status == SyncStatus.failed) return Colors.red;
    if (state.wsConnected) return Colors.green;
    return Colors.orange; // online but WS disconnected
  }
}

/// Small colored dot indicating real-time connection status.
class _ConnectionDot extends StatelessWidget {
  final Color color;
  const _ConnectionDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
