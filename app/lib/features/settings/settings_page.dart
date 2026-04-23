import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/providers/auth_provider.dart';
import '../../domain/providers/family_provider.dart';
import '../../domain/providers/theme_provider.dart';
import '../../domain/providers/sync_status_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final familyState = ref.watch(familyProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // User info card
          _UserInfoCard(
            email: authState.userId ?? '',
            theme: theme,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // Family section
          if (familyState.currentFamily != null) ...[
            _FamilyInfoCard(
              familyName: familyState.currentFamily!.name,
              memberCount: familyState.members.length,
              theme: theme,
              isDark: isDark,
              onViewMembers: () {
                Navigator.of(context).pushNamed(AppRouter.familyMembers);
              },
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.link_rounded,
              title: '生成邀请码',
              subtitle: '邀请家人加入',
              onTap: () => _generateInviteCode(context, ref),
            ),
            _SettingsTile(
              icon: Icons.exit_to_app_rounded,
              title: '退出家庭',
              subtitle: '离开当前家庭',
              isDestructive: true,
              onTap: () => _showLeaveConfirm(context, ref),
            ),
          ] else ...[
            _SectionHeader(title: '家庭', theme: theme),
            _SettingsTile(
              icon: Icons.group_add_rounded,
              title: '创建家庭',
              subtitle: '创建一个新的家庭账本',
              onTap: () => _showCreateFamilyDialog(context, ref),
            ),
            _SettingsTile(
              icon: Icons.qr_code_rounded,
              title: '加入家庭',
              subtitle: '通过邀请码加入',
              onTap: () => _showJoinFamilyDialog(context, ref),
            ),
          ],

          const SizedBox(height: 24),
          _SectionHeader(title: '外观', theme: theme),
          _ThemeModeTile(ref: ref, theme: theme),

          const SizedBox(height: 24),
          _SectionHeader(title: '同步', theme: theme),
          const _SyncStatusTile(),

          const SizedBox(height: 24),
          _SectionHeader(title: '其他', theme: theme),
          _SettingsTile(
            icon: Icons.account_balance_rounded,
            title: '贷款管理',
            subtitle: '跟踪还款进度、模拟提前还款',
            onTap: () => Navigator.of(context).pushNamed(AppRouter.loans),
          ),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: '通知设置',
            subtitle: '管理预算提醒和日常通知',
            onTap: () => Navigator.of(context).pushNamed(AppRouter.notificationSettings),
          ),

          const SizedBox(height: 24),
          _SectionHeader(title: '账号', theme: theme),
          _SettingsTile(
            icon: Icons.logout_rounded,
            title: '退出登录',
            isDestructive: true,
            onTap: () => _showLogoutConfirm(context, ref),
          ),
        ],
      ),
    );
  }

  void _showCreateFamilyDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('创建家庭'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入家庭名称',
            prefixIcon: Icon(Icons.family_restroom_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(familyProvider.notifier).createFamily(name);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _showJoinFamilyDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('加入家庭'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: '输入邀请码',
            prefixIcon: Icon(Icons.vpn_key_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final code = controller.text.trim();
              if (code.isNotEmpty) {
                ref.read(familyProvider.notifier).joinFamily(code);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('加入'),
          ),
        ],
      ),
    );
  }

  void _generateInviteCode(BuildContext context, WidgetRef ref) async {
    final code = await ref.read(familyProvider.notifier).generateInviteCode();
    if (code != null && context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('邀请码'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SelectableText(
                  code,
                  style: Theme.of(ctx).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '有效期 7 天',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('已复制到剪贴板')),
                );
              },
              child: const Text('复制'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    }
  }

  void _showLeaveConfirm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出家庭'),
        content: const Text('确定要退出当前家庭吗？退出后将无法查看家庭账本。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.expense,
            ),
            onPressed: () {
              ref.read(familyProvider.notifier).leaveFamily();
              Navigator.of(ctx).pop();
            },
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.expense,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil(AppRouter.login, (_) => false);
              }
            },
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }
}

// ────────── Sub-widgets ──────────

class _UserInfoCard extends StatelessWidget {
  final String email;
  final ThemeData theme;
  final bool isDark;

  const _UserInfoCard({
    required this.email,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: isDark
                  ? AppColors.primaryDark.withValues(alpha: 0.2)
                  : AppColors.primary.withValues(alpha: 0.1),
              child: Icon(
                Icons.person_rounded,
                size: 28,
                color: isDark ? AppColors.primaryDark : AppColors.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '我的账号',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FamilyInfoCard extends StatelessWidget {
  final String familyName;
  final int memberCount;
  final ThemeData theme;
  final bool isDark;
  final VoidCallback onViewMembers;

  const _FamilyInfoCard({
    required this.familyName,
    required this.memberCount,
    required this.theme,
    required this.isDark,
    required this.onViewMembers,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onViewMembers,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF2C2C4A), const Color(0xFF1C1C3E)]
                        : [AppColors.primary, const Color(0xFF4A5AF0)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      familyName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$memberCount 位成员',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool isDestructive;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isDestructive ? AppColors.expense : theme.colorScheme.onSurface;

    return Semantics(
      label: title,
      hint: subtitle,
      button: true,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        child: ListTile(
          leading: Icon(icon, color: color.withValues(alpha: 0.7)),
          title: Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                )
              : null,
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onTap: onTap,
        ),
      ),
    );
  }
}

// ────────── Theme mode tile ──────────

class _ThemeModeTile extends StatelessWidget {
  final WidgetRef ref;
  final ThemeData theme;

  const _ThemeModeTile({required this.ref, required this.theme});

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final (icon, label) = switch (themeMode) {
      ThemeMode.system => (Icons.brightness_auto_rounded, '跟随系统'),
      ThemeMode.light => (Icons.light_mode_rounded, '浅色模式'),
      ThemeMode.dark => (Icons.dark_mode_rounded, '深色模式'),
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
        title: const Text('外观模式', style: TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
        trailing: SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_rounded, size: 18)),
            ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded, size: 18)),
            ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded, size: 18)),
          ],
          selected: {themeMode},
          onSelectionChanged: (s) {
            ref.read(themeModeProvider.notifier).setThemeMode(s.first);
            HapticFeedback.selectionClick();
          },
          showSelectedIcon: false,
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

// ────────── Sync status tile ──────────

class _SyncStatusTile extends ConsumerWidget {
  const _SyncStatusTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStatusProvider);
    final theme = Theme.of(context);

    final (icon, label, subtitle, color) = switch (syncState.status) {
      SyncStatus.synced => (
          Icons.cloud_done_rounded,
          '已同步',
          '所有数据均已同步到服务器',
          Colors.green,
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
          Colors.orange,
        ),
      SyncStatus.offline => (
          Icons.cloud_off_rounded,
          '离线模式',
          '断网时可正常记账，联网后自动同步',
          Colors.grey,
        ),
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: ListTile(
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
            : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
