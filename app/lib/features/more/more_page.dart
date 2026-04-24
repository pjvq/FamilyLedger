import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/providers/auth_provider.dart';
import '../../domain/providers/family_provider.dart';

/// "More" tab — contains all secondary features
class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final familyState = ref.watch(familyProvider);

    return Semantics(
      label: '更多页面',
      child: Scaffold(
      appBar: AppBar(
        title: const Text('更多'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // User info card
          Card(
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
                          authState.userId ?? '',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Feature sections
          _SectionHeader(title: '资产管理', theme: theme),
          _MoreTile(
            icon: Icons.account_balance_rounded,
            title: '贷款管理',
            subtitle: '跟踪还款进度、模拟提前还款',
            onTap: () => Navigator.of(context).pushNamed(AppRouter.loans),
          ),
          _MoreTile(
            icon: Icons.trending_up_rounded,
            title: '投资管理',
            subtitle: '跟踪投资持仓、实时行情',
            onTap: () =>
                Navigator.of(context).pushNamed(AppRouter.investments),
          ),
          _MoreTile(
            icon: Icons.real_estate_agent_rounded,
            title: '资产管理',
            subtitle: '固定资产跟踪、自动折旧计算',
            onTap: () => Navigator.of(context).pushNamed(AppRouter.assets),
          ),

          _SectionHeader(title: '数据', theme: theme),
          _MoreTile(
            icon: Icons.assessment_rounded,
            title: '交易报表',
            subtitle: '按时间和分类查看交易明细',
            onTap: () => Navigator.of(context).pushNamed(AppRouter.report),
          ),
          _MoreTile(
            icon: Icons.file_download_rounded,
            title: '数据导出',
            subtitle: '导出交易数据为CSV/Excel/PDF',
            onTap: () =>
                Navigator.of(context).pushNamed(AppRouter.export),
          ),
          _MoreTile(
            icon: Icons.file_upload_rounded,
            title: 'CSV 导入',
            subtitle: '从 CSV 文件导入交易记录',
            onTap: () =>
                Navigator.of(context).pushNamed(AppRouter.csvImport),
          ),

          _SectionHeader(title: '设置', theme: theme),
          _MoreTile(
            icon: Icons.family_restroom_rounded,
            title: familyState.currentFamily != null
                ? familyState.currentFamily!.name
                : '家庭管理',
            subtitle: familyState.currentFamily != null
                ? '${familyState.members.length} 位成员'
                : '创建或加入家庭',
            onTap: () =>
                Navigator.of(context).pushNamed(AppRouter.settings),
          ),
          _MoreTile(
            icon: Icons.notifications_outlined,
            title: '通知设置',
            subtitle: '管理预算提醒和日常通知',
            onTap: () => Navigator.of(context)
                .pushNamed(AppRouter.notificationSettings),
          ),
          _MoreTile(
            icon: Icons.logout_rounded,
            title: '退出登录',
            isDestructive: true,
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('退出登录'),
                  content: const Text('确定要退出登录吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.expense,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('退出'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                      AppRouter.login, (_) => false);
                }
              }
            },
          ),
          const SizedBox(height: 80),
        ],
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        title,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool isDestructive;
  final VoidCallback onTap;

  const _MoreTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        isDestructive ? AppColors.expense : theme.colorScheme.onSurface;

    return Semantics(
      label: '$title${subtitle != null ? "，$subtitle" : ""}',
      child: Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: ListTile(
        leading: Icon(icon, color: color.withValues(alpha: 0.7)),
        title: Text(title,
            style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        subtitle: subtitle != null
            ? Text(subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ))
            : null,
        trailing: isDestructive
            ? null
            : Icon(Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: onTap,
      ),
    ),
    );
  }
}
