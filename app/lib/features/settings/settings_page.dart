import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/sync_status_tile.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/design_tokens.dart';
import '../../domain/providers/auth_provider.dart';
import '../../domain/providers/account_provider.dart';
import '../../domain/providers/app_providers.dart';
import '../../domain/providers/family_provider.dart';
import '../../domain/providers/theme_provider.dart';
import '../../domain/providers/sync_status_provider.dart';
import '../../sync/sync_engine.dart';

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
            email: authState.email ?? authState.userId ?? '',
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
                context.push(AppRouter.familyMembers);
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
          const SyncStatusTile(),

          const SizedBox(height: 24),
          _SectionHeader(title: '其他', theme: theme),
          _SettingsTile(
            icon: Icons.category_rounded,
            title: '分类管理',
            subtitle: '管理收支分类和子分类',
            onTap: () => context.push(AppRouter.categoryManage),
          ),
          _SettingsTile(
            icon: Icons.account_balance_rounded,
            title: '贷款管理',
            subtitle: '跟踪还款进度、模拟提前还款',
            onTap: () => context.push(AppRouter.loans),
          ),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: '通知设置',
            subtitle: '管理预算提醒和日常通知',
            onTap: () => context.push(AppRouter.notificationSettings),
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
            onPressed: () => ctx.pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ctx.pop();
                final familyId = await ref
                    .read(familyProvider.notifier)
                    .createFamily(name);
                if (familyId != null) {
                  // Auto-switch to family mode
                  ref.read(currentFamilyIdProvider.notifier).state = familyId;
                  ref.read(sharedPreferencesProvider)
                      .setString(AppConstants.familyIdKey, familyId);
                  // Auto-create default family account
                  await ref.read(accountProvider.notifier).createAccount(
                    name: '家庭共享账户',
                    accountType: 'cash',
                    familyId: familyId,
                  );
                }
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
            onPressed: () => ctx.pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final code = controller.text.trim();
              if (code.isNotEmpty) {
                ctx.pop();
                final familyId = await ref
                    .read(familyProvider.notifier)
                    .joinFamily(code);
                if (familyId != null) {
                  ref.read(currentFamilyIdProvider.notifier).state = familyId;
                  ref.read(sharedPreferencesProvider)
                      .setString(AppConstants.familyIdKey, familyId);
                  // Ensure family has at least one account locally
                  final db = ref.read(databaseProvider);
                  final existingAccounts = await db.getAccountsByFamily(familyId);
                  if (existingAccounts.isEmpty) {
                    await ref.read(accountProvider.notifier).createAccount(
                      name: '家庭共享账户',
                      accountType: 'cash',
                      familyId: familyId,
                    );
                  }
                }
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
              onPressed: () => ctx.pop(),
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
            onPressed: () => ctx.pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.semanticColors.expense,
            ),
            onPressed: () {
              ref.read(familyProvider.notifier).leaveFamily();
              ctx.pop();
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
            onPressed: () => ctx.pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.semanticColors.expense,
            ),
            onPressed: () async {
              ctx.pop();
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go(AppRouter.login);
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
                  ? ColorTokens.primaryLight.withValues(alpha: 0.2)
                  : ColorTokens.primary.withValues(alpha: 0.1),
              child: Icon(
                Icons.person_rounded,
                size: 28,
                color: isDark ? ColorTokens.primaryLight : ColorTokens.primary,
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
                        : [ColorTokens.primary, GradientTokens.primaryGradientAlt],
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
    final color = isDestructive ? context.semanticColors.expense : theme.colorScheme.onSurface;

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

