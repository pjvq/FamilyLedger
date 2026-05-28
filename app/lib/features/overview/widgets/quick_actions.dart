import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/design_tokens.dart';

/// Quick action row — 4 shortcut buttons for common operations.
class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

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
          _QuickActionButton(
            icon: Icons.swap_horiz_rounded,
            label: '转账',
            onTap: () => context.push(AppRouter.transfer),
            isDark: isDark,
          ),
          const SizedBox(width: SpacingTokens.sm),
          _QuickActionButton(
            icon: Icons.account_balance_rounded,
            label: '贷款',
            onTap: () => context.push(AppRouter.loans),
            isDark: isDark,
          ),
          const SizedBox(width: SpacingTokens.sm),
          _QuickActionButton(
            icon: Icons.trending_up_rounded,
            label: '投资',
            onTap: () => context.push(AppRouter.investments),
            isDark: isDark,
          ),
          const SizedBox(width: SpacingTokens.sm),
          _QuickActionButton(
            icon: Icons.bar_chart_rounded,
            label: '报表',
            onTap: () => context.push(AppRouter.report),
            isDark: isDark,
          ),
        ],
      ),
    );
  }
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
    return Expanded(
      child: Material(
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
            onTap: onTap,
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
      ),
    );
  }
}
