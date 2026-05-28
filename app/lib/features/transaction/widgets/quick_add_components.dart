import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/design_tokens.dart';

/// 账户选择器 Pill — 胶囊形状，点击弹出账户列表
class AccountPill extends StatelessWidget {
  final String accountName;
  final IconData? icon;
  final VoidCallback onTap;

  const AccountPill({
    super.key,
    required this.accountName,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.base, vertical: SpacingTokens.sm),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? NeutralColorsDark.neutral4
                : NeutralColorsLight.neutral3,
          ),
          color: isDark
              ? NeutralColorsDark.neutral2
              : NeutralColorsLight.neutral1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
              const SizedBox(width: 6),
            ],
            Text(
              accountName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// 收入/支出/转账类型切换器
class TransactionTypeSelector extends StatelessWidget {
  final int selectedIndex; // 0=支出, 1=收入, 2=转账
  final ValueChanged<int> onChanged;

  const TransactionTypeSelector({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });

  static const _labels = ['支出', '收入'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_labels.length, (i) {
        final isSelected = i == selectedIndex;
        return GestureDetector(
          onTap: () {
            if (!isSelected) {
              HapticFeedback.selectionClick();
              onChanged(i);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _labels[i],
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  height: 3,
                  width: isSelected ? 24 : 0,
                  decoration: BoxDecoration(
                    color: ColorTokens.primary,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
