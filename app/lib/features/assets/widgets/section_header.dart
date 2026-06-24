import 'package:flutter/material.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/format.dart';

/// Section header — shows icon, title, total amount, and chevron.
/// Wrapped in Material for InkWell ripple (review #8).
class SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final int total;
  final Color color;
  final VoidCallback? onTap;

  const SectionHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.total,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isNegative = total < 0;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          SpacingTokens.base,
          SpacingTokens.lg,
          SpacingTokens.base,
          SpacingTokens.sm,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(RadiusTokens.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: SpacingTokens.xs),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const SizedBox(width: SpacingTokens.sm),
                  Text(
                    title,
                    style: TypographyTokens.titleMd().copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${isNegative ? "-" : ""}¥${formatCentsWan(total.abs())}',
                    style: TypographyTokens.bodyMd().copyWith(
                      fontWeight: FontWeight.w600,
                      color: color,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.3),
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
