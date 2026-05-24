import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/sync_status_indicator.dart';
import '../../domain/providers/app_providers.dart';
import '../../domain/providers/family_provider.dart';
import '../../domain/providers/notification_provider.dart';
import '../../sync/sync_engine.dart';
import '../dashboard/dashboard_page.dart';
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
              onToggle: (isFamily) {
                final fState = ref.read(familyProvider);
                final newId = isFamily ? fState.currentFamily?.id : null;
                ref.read(currentFamilyIdProvider.notifier).state = newId;
                final prefs = ref.read(sharedPreferencesProvider);
                if (newId != null) {
                  prefs.setString(AppConstants.familyIdKey, newId);
                  ref.read(familyProvider.notifier).refreshMembers();
                } else {
                  prefs.remove(AppConstants.familyIdKey);
                }
              },
            ),
          const Expanded(child: DashboardPage()),
        ],
      ),
    );
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
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF2C2C2E)
              : const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(14),
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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? AppColors.cardDark : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color:
                        Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive
                  ? (isDark ? AppColors.primaryDark : AppColors.primary)
                  : (isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive
                      ? (isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimary)
                      : (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary),
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
            style: const TextStyle(fontSize: 10, color: Colors.white),
          ),
          child: Icon(
            Icons.notifications_outlined,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}
