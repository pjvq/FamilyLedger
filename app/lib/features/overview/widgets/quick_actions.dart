import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/micro_interactions.dart';

/// Quick action row — data-driven shortcut buttons for common operations.
class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  static const _actions = [
    _ActionDef(
      icon: Icons.pie_chart_rounded,
      label: '预算',
      route: AppRouter.budget,
    ),
    _ActionDef(
      icon: Icons.account_balance_rounded,
      label: '贷款',
      route: AppRouter.loans,
    ),
    _ActionDef(
      icon: Icons.trending_up_rounded,
      label: '投资',
      route: AppRouter.investments,
    ),
    _ActionDef(
      icon: Icons.bar_chart_rounded,
      label: '报表',
      route: AppRouter.report,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpacingTokens.base, SpacingTokens.xs,
        SpacingTokens.base, SpacingTokens.sm,
      ),
      child: Row(
        children: [
          for (int i = 0; i < _actions.length; i++) ...[
            if (i > 0) const SizedBox(width: SpacingTokens.sm),
            Expanded(
              child: _QuickActionButton(
                icon: _actions[i].icon,
                label: _actions[i].label,
                onTap: () => context.push(_actions[i].route),
                isDark: isDark,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionDef {
  final IconData icon;
  final String label;
  final String route;

  const _ActionDef({
    required this.icon,
    required this.label,
    required this.route,
  });
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(RadiusTokens.md),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          color: isDark
              ? NeutralColorsDark.neutral2
              : NeutralColorsLight.neutral2,
          borderRadius: BorderRadius.circular(RadiusTokens.md),
        ),
        child: InkWell(
          onTap: () => withHaptic(onTap, haptic: HapticType.lightImpact),
          borderRadius: BorderRadius.circular(RadiusTokens.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                vertical: SpacingTokens.md),
            child: Column(
              children: [
                Icon(icon,
                    size: IconSizeTokens.md,
                    color: ColorTokens.primary),
                const SizedBox(height: SpacingTokens.xs),
                Text(
                  label,
                  style: TypographyTokens.caption(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
