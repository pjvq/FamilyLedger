import 'package:flutter/material.dart';

import '../../../core/theme/design_tokens.dart';
import '../../settings/category_cleanup_page.dart';

/// 分类整理提示基类 — 供概览页卡片和分类管理页 banner 复用
///
/// [variant] 控制渲染样式：card（较大带圆角 padding）或 banner（紧凑行）
enum CleanupPromptVariant { card, banner }

class CategoryCleanupPrompt extends StatelessWidget {
  final int suggestionCount;
  final CleanupPromptVariant variant;
  final VoidCallback? onTap;

  const CategoryCleanupPrompt({
    super.key,
    required this.suggestionCount,
    this.variant = CleanupPromptVariant.card,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestionCount == 0) return const SizedBox.shrink();
    // card variant requires >= 3 suggestions
    if (variant == CleanupPromptVariant.card && suggestionCount < 3) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Unified brand color — indigo accent for both variants
    final bgColor = isDark
        ? const Color(0xFF1A1A2E)
        : const Color(0xFFF0F4FF);
    final iconBgColor = isDark
        ? const Color(0xFF2D2D4E)
        : const Color(0xFFE0E8FF);
    const accentColor = Color(0xFF6366F1);

    final effectiveOnTap = onTap ??
        () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CategoryCleanupPage()),
            );

    if (variant == CleanupPromptVariant.banner) {
      return Material(
        color: bgColor,
        child: InkWell(
          onTap: effectiveOnTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.auto_fix_high, size: 18, color: accentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '发现 $suggestionCount 个可合并的分类，点击整理',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: OpacityTokens.medium),
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: theme.colorScheme.onSurface
                      .withValues(alpha: OpacityTokens.faint),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Card variant (overview page)
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpacingTokens.base, 0, SpacingTokens.base, SpacingTokens.sm,
      ),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(RadiusTokens.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(RadiusTokens.lg),
          onTap: effectiveOnTap,
          child: Padding(
            padding: const EdgeInsets.all(SpacingTokens.base),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(RadiusTokens.md),
                  ),
                  child: const Icon(
                    Icons.auto_fix_high,
                    size: 18,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: SpacingTokens.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '分类整理建议',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '发现 $suggestionCount 个可能重复的分类',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: OpacityTokens.subtle),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: theme.colorScheme.onSurface
                      .withValues(alpha: OpacityTokens.faint),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
