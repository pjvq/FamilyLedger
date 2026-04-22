import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Expandable/collapsible card wrapper used by all dashboard sections
class DashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Widget child;
  final Widget? trailing;
  final Key? cardKey;

  const DashboardCard({
    super.key,
    required this.title,
    required this.icon,
    required this.isExpanded,
    required this.onToggle,
    required this.child,
    this.trailing,
    this.cardKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      label: '$title卡片，${isExpanded ? "已展开" : "已折叠"}',
      child: Card(
        key: cardKey,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        elevation: isDark ? 0 : 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        child: Column(
          children: [
            // Header (always visible, tappable)
            InkWell(
              onTap: onToggle,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
                bottom: Radius.circular(16),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(icon, size: 20,
                        color: isDark ? AppColors.primaryDark : AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (trailing != null) ...[
                      trailing!,
                      const SizedBox(width: 8),
                    ],
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Body (animated expand/collapse)
            AnimatedCrossFade(
              firstChild: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: child,
              ),
              secondChild: const SizedBox.shrink(),
              crossFadeState: isExpanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 250),
              sizeCurve: Curves.easeInOutCubic,
            ),
          ],
        ),
      ),
    );
  }
}
