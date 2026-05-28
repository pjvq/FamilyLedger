import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/widgets/sync_status_indicator.dart';
import '../../domain/providers/app_providers.dart';
import '../../domain/providers/family_provider.dart';
import '../../domain/providers/notification_provider.dart';
import '../../sync/sync_engine.dart';
import '../dashboard/dashboard_page.dart';
import 'widgets/greeting_header.dart';
import 'widgets/quick_actions.dart';
import 'widgets/reminders_card.dart';
import 'package:go_router/go_router.dart';

/// 概览页 — 包含 family switcher + dashboard。
///
/// 从旧的 [HomePage] 中的 _DashboardShell 抽取而来。
class OverviewPage extends ConsumerStatefulWidget {
  const OverviewPage({super.key});

  @override
  ConsumerState<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends ConsumerState<OverviewPage> {
  @override
  void initState() {
    super.initState();
    // SyncEngine is auto-started by the provider when user is logged in.
    // Just read the provider to ensure it's alive (Riverpod is lazy).
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
        title: const Text('FamilyLedger'),
        centerTitle: false,
        actions: [
          const SyncStatusIndicator(),
          _NotificationBell(
            unreadCount: notifState.unreadCount,
            onTap: () => context.push('/mine/notifications'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Personal ↔ Family switcher
          if (hasFamily)
            _ModeSwitcher(
              isFamilyMode: familyId != null,
              familyName: familyState.currentFamily?.name ?? '',
              onToggle: _handleModeSwitch,
            ),
          // Greeting + Quick actions + Reminders above dashboard
          const GreetingHeader(),
          const QuickActions(),
          const RemindersCard(),
          const Expanded(child: DashboardPage()),
        ],
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
      label: isFamilyMode
          ? '当前为家庭模式，点击切换到个人模式'
          : '当前为个人模式，点击切换到家庭模式',
      child: Container(
        margin: const EdgeInsets.fromLTRB(SpacingTokens.base, SpacingTokens.sm, SpacingTokens.base, 0),
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
        padding: const EdgeInsets.symmetric(vertical: SpacingTokens.md, horizontal: SpacingTokens.base),
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
                style: TypographyTokens.bodySm(
                  color: isActive
                      ? (isDark
                          ? NeutralColorsDark.neutral7
                          : NeutralColorsLight.neutral7)
                      : (isDark
                          ? NeutralColorsDark.neutral4
                          : NeutralColorsLight.neutral4),
                ).copyWith(fontWeight: isActive ? FontWeight.w600 : FontWeight.w400),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────── Notification Bell ──────────

/// Badge text font size (smaller than caption for compact badge).
const double _kBadgeFontSize = 10.0;

/// Inactive icon opacity.
const double _kIconInactiveOpacity = 0.7;

class _NotificationBell extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onTap;

  const _NotificationBell({
    required this.unreadCount,
    required this.onTap,
  });

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
            style: const TextStyle(fontSize: _kBadgeFontSize, color: Colors.white),
          ),
          child: Icon(
            Icons.notifications_outlined,
            color: theme.colorScheme.onSurface.withValues(alpha: _kIconInactiveOpacity),
          ),
        ),
      ),
    );
  }
}
