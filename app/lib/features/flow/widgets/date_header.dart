import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/format.dart';

/// 日期分组头（显示日期标签和当日合计）。
class DateHeader extends StatelessWidget {
  final DateTime date;
  final int dayTotal;

  const DateHeader({
    super.key,
    required this.date,
    required this.dayTotal,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;

    String label;
    if (isToday) {
      label = '今天';
    } else if (isYesterday) {
      label = '昨天';
    } else if (date.year == now.year) {
      label = DateFormat('M月d日 E', 'zh_CN').format(date);
    } else {
      label = DateFormat('yyyy年M月d日').format(date);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpacingTokens.base,
        SpacingTokens.md,
        SpacingTokens.base,
        SpacingTokens.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TypographyTokens.bodySm(
              color: isDark
                  ? NeutralColorsDark.neutral5
                  : NeutralColorsLight.neutral5,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            formatCents(dayTotal, showSign: true),
            style: TypographyTokens.bodySm(
              color: dayTotal >= 0
                  ? context.semanticColors.income
                  : context.semanticColors.expense,
            ),
          ),
        ],
      ),
    );
  }
}
