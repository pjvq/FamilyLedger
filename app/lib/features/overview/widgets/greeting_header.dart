import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/design_tokens.dart';

/// Greeting header — shows time-based greeting + current date.
///
/// Refreshes automatically every minute so the greeting stays current
/// even if the user stays on the page across time-of-day boundaries.
class GreetingHeader extends StatefulWidget {
  /// Optional [DateTime] override for testing.
  final DateTime? now;

  const GreetingHeader({super.key, this.now});

  @override
  State<GreetingHeader> createState() => _GreetingHeaderState();
}

class _GreetingHeaderState extends State<GreetingHeader> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.now == null) {
      // Refresh every 60 seconds to keep greeting/date current.
      _timer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.now ?? DateTime.now();
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
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  static String _getGreeting(int hour) {
    if (hour < 6) return '夜深了 🌙';
    if (hour < 9) return '早上好 ☀️';
    if (hour < 12) return '上午好 👋';
    if (hour < 14) return '中午好 🍱';
    if (hour < 18) return '下午好 ☕';
    if (hour < 22) return '晚上好 🌆';
    return '夜深了 🌙';
  }

  static String _weekdayName(int weekday) {
    const names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return names[(weekday - 1).clamp(0, 6)];
  }
}
