import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../core/constants/category_icon_widget.dart';
import '../../../domain/providers/transaction_provider.dart';
import '../../../data/local/database.dart';

/// 快速分类选择器 — 2 行水平滚动网格
///
/// 排序规则：使用频率降序（最常用的排最前）
/// 选中态：icon 背景变主题色 + scale 动画
class QuickCategorySelector extends ConsumerWidget {
  final int typeIndex; // 0=支出, 1=收入
  final String? selectedCategoryId;
  final ValueChanged<String> onSelected;

  const QuickCategorySelector({
    super.key,
    required this.typeIndex,
    this.selectedCategoryId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get categories by type with precise select to minimize rebuilds
    final filtered = typeIndex == 0
        ? ref.watch(transactionProvider.select((s) => s.expenseCategories))
        : ref.watch(transactionProvider.select((s) => s.incomeCategories));

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          '暂无分类',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      );
    }

    // Split into 2 rows
    final midpoint = (filtered.length / 2).ceil();
    final row1 = filtered.take(midpoint).toList();
    final row2 = filtered.skip(midpoint).toList();

    return Column(
      children: [
        _buildRow(context, row1),
        const SizedBox(height: 8),
        _buildRow(context, row2),
      ],
    );
  }

  Widget _buildRow(BuildContext context, List<Category> items) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.md),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final cat = items[index];
          final isSelected = cat.id == selectedCategoryId;
          return _CategoryChip(
            category: cat,
            isSelected: isSelected,
            onTap: () {
              HapticFeedback.selectionClick();
              onSelected(cat.id);
            },
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final Category category;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? ColorTokens.primary.withValues(alpha: 0.12)
              : (isDark ? NeutralColorsDark.neutral2 : NeutralColorsLight.neutral1),
          borderRadius: BorderRadius.circular(RadiusTokens.sm),
          border: Border.all(
            color: isSelected
                ? ColorTokens.primary
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CategoryIconWidget(
              iconKey: category.iconKey,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              category.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? ColorTokens.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
