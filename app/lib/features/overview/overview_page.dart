import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/widgets/custom_refresh.dart';
import '../../core/widgets/sync_status_indicator.dart';
import '../../domain/providers/app_providers.dart';
import '../../domain/providers/family_provider.dart';
import '../../domain/providers/notification_provider.dart';
import '../../sync/sync_engine.dart';
import 'widgets/budget_progress_card.dart';
import 'widgets/greeting_header.dart';
import 'widgets/monthly_summary_card.dart';
import 'widgets/net_worth_hero_card.dart';
import 'widgets/quick_actions.dart';
import 'widgets/category_cleanup_reminder_card.dart';
import 'widgets/reminders_card.dart';

/// 概览页 — 财务健康一眼看。
///
/// Layout:
/// 1. GreetingHeader — 时间问候 + 日期
/// 2. NetWorthHeroCard — 净资产大数字 + 趋势
/// 3. QuickActions — 快捷操作 4 键
/// 4. MonthlySummaryCard — 本月收支环形图
/// 5. BudgetProgressCard — 预算 Top 3 进度条
/// 6. RemindersCard — 智能提醒（贷款/预算）
/// 7. RecentTransactionsCard — 最近 5 笔交易
class OverviewPage extends ConsumerStatefulWidget {
  const OverviewPage({super.key});

  @override
  ConsumerState<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends ConsumerState<OverviewPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(syncEngineProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final familyState = ref.watch(familyProvider);
    final familyId = ref.watch(currentFamilyIdProvider);
    final notifState = ref.watch(notificationProvider);
    final hasFamily = familyState.currentFamily != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('家庭账本'),
        centerTitle: false,
        actions: [
          const SyncStatusIndicator(),
          _NotificationBell(
            unreadCount: notifState.unreadCount,
            onTap: () => context.push('/mine/notifications'),
          ),
        ],
      ),
      body: CustomRefreshIndicator(
        onRefresh: () async {
          await ref.read(syncEngineProvider).forcePull();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverList.list(
              children: [
                // Personal ↔ Family switcher
                if (hasFamily)
                  _ModeSwitcher(
                    isFamilyMode: familyId != null,
                    familyName: familyState.currentFamily?.name ?? '',
                    onToggle: _handleModeSwitch,
                  ),
                // 1. Greeting
                const GreetingHeader(),
                // 2. Net Worth Hero
                const NetWorthHeroCard(),
                // 3. Quick Actions
                const QuickActions(),
                // 4. Monthly Summary (donut)
                const MonthlySummaryCard(),
                // 5. Budget Progress (Top 3)
                const BudgetProgressCard(),
                // 6. Smart Reminders
                const RemindersCard(),
                // 7. Category Cleanup Reminder
                const CategoryCleanupReminderCard(),
                // Bottom safe area padding
                const SizedBox(height: SpacingTokens.xl4 + SpacingTokens.xl),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleModeSwitch(bool isFamily) {
    ref.read(familyProvider.notifier).switchMode(toFamily: isFamily);
  }
}

// ────────── Mode Switcher ──────────

class _ModeSwitcher extends StatelessWidget {
  final bool isFamilyMode;
  final String familyName;
  final ValueChanged<bool> onToggle;

  const _ModeSwitcher({
    required this.isFamilyMode,
    required this.familyName,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      label: isFamilyMode ? '当前为家庭模式，点击切换到个人模式' : '当前为个人模式，点击切换到家庭模式',
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          SpacingTokens.base,
          SpacingTokens.sm,
          SpacingTokens.base,
          0,
        ),
        padding: const EdgeInsets.all(SpacingTokens.xs),
        decoration: BoxDecoration(
          color: isDark
              ? NeutralColorsDark.neutral2
              : NeutralColorsLight.neutral2,
          borderRadius: BorderRadius.circular(RadiusTokens.md),
        ),
        child: Row(
          children: [
            Expanded(
              child: _SwitcherButton(
                label: '个人',
                icon: Icons.person_rounded,
                isActive: !isFamilyMode,
                isDark: isDark,
                onTap: () => onToggle(false),
              ),
            ),
            Expanded(
              child: _SwitcherButton(
                label: familyName,
                icon: Icons.family_restroom_rounded,
                isActive: isFamilyMode,
                isDark: isDark,
                onTap: () => onToggle(true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitcherButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _SwitcherButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.symmetric(
          vertical: SpacingTokens.md,
          horizontal: SpacingTokens.base,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? NeutralColorsDark.neutral1 : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(RadiusTokens.sm),
          boxShadow: isActive
              ? (isDark ? ShadowTokensDark.sm : ShadowTokensLight.sm)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: IconSizeTokens.sm,
              color: isActive
                  ? (isDark ? ColorTokens.primaryLight : ColorTokens.primary)
                  : (isDark
                        ? NeutralColorsDark.neutral4
                        : NeutralColorsLight.neutral4),
            ),
            const SizedBox(width: SpacingTokens.sm),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style:
                    TypographyTokens.bodySm(
                      color: isActive
                          ? (isDark
                                ? NeutralColorsDark.neutral7
                                : NeutralColorsLight.neutral7)
                          : (isDark
                                ? NeutralColorsDark.neutral4
                                : NeutralColorsLight.neutral4),
                    ).copyWith(
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────── Notification Bell ──────────

const double _badgeFontSize = 10.0;
const double _iconInactiveOpacity = 0.7;

class _NotificationBell extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onTap;

  const _NotificationBell({required this.unreadCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: unreadCount > 0 ? '通知，$unreadCount条未读' : '通知',
      button: true,
      child: IconButton(
        onPressed: onTap,
        tooltip: unreadCount > 0 ? '通知，$unreadCount条未读' : '通知',
        icon: Badge(
          isLabelVisible: unreadCount > 0,
          label: Text(
            unreadCount > 99 ? '99+' : '$unreadCount',
            style: const TextStyle(
              fontSize: _badgeFontSize,
              color: Colors.white,
            ),
          ),
          child: Icon(
            Icons.notifications_outlined,
            color: theme.colorScheme.onSurface.withValues(
              alpha: _iconInactiveOpacity,
            ),
          ),
        ),
      ),
    );
  }
}
