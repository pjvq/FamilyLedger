import 'package:flutter/material.dart';

import '../../../core/theme/design_tokens.dart';

/// Greeting header — shows time-based greeting + current date.
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = _getGreeting(now.hour);
    final dateStr = '${now.month}月${now.day}日 ${_weekdayName(now.weekday)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpacingTokens.base,
        SpacingTokens.sm,
        SpacingTokens.base,
        SpacingTokens.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: TypographyTokens.headlineMd().copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            dateStr,
            style: TypographyTokens.bodySm(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting(int hour) {
    if (hour < 6) return '夜深了 🌙';
    if (hour < 9) return '早上好 ☀️';
    if (hour < 12) return '上午好 👋';
    if (hour < 14) return '中午好 🍱';
    if (hour < 18) return '下午好 ☕';
    if (hour < 22) return '晚上好 🌆';
    return '夜深了 🌙';
  }

  String _weekdayName(int weekday) {
    const names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return names[weekday - 1];
  }
}
