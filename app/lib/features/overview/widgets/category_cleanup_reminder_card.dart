import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../domain/providers/category_merge_provider.dart';
import '../../../domain/services/smart_category/category_merge_detector.dart';
import '../../settings/category_cleanup_page.dart';

/// 分类整理提醒卡片 — 有 ≥3 条高置信度合并建议时显示
class CategoryCleanupReminderCard extends ConsumerWidget {
  const CategoryCleanupReminderCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(categoryMergeSuggestionsProvider);
    final suggestions = suggestionsAsync.when(
      data: (s) => s,
      loading: () => <MergeSuggestion>[],
      error: (_, __) => <MergeSuggestion>[],
    );

    if (suggestions.length < 3) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpacingTokens.base, 0, SpacingTokens.base, SpacingTokens.sm,
      ),
      child: Material(
        color: isDark
            ? const Color(0xFF1A1A2E)
            : const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(RadiusTokens.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(RadiusTokens.lg),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CategoryCleanupPage()),
          ),
          child: Padding(
            padding: const EdgeInsets.all(SpacingTokens.base),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2D2D4E)
                        : const Color(0xFFE0E8FF),
                    borderRadius: BorderRadius.circular(RadiusTokens.md),
                  ),
                  child: const Icon(
                    Icons.auto_fix_high,
                    size: 18,
                    color: Color(0xFF6366F1),
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
                        '发现 ${suggestions.length} 个可能重复的分类',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
