import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/providers/category_merge_provider.dart';
import 'category_cleanup_prompt.dart';

/// 分类整理提醒卡片 — 有 ≥3 条高置信度合并建议时显示
class CategoryCleanupReminderCard extends ConsumerWidget {
  const CategoryCleanupReminderCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(categoryMergeSuggestionsProvider);
    final count = suggestionsAsync.when(
      data: (s) => s.length,
      loading: () => 0,
      error: (_, __) => 0,
    );

    return CategoryCleanupPrompt(
      suggestionCount: count,
      variant: CleanupPromptVariant.card,
    );
  }
}
