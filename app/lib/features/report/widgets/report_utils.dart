import 'package:flutter/material.dart';

import '../../../core/theme/design_tokens.dart';

// ── Quick date range presets ──

enum DatePreset {
  thisMonth('本月'),
  lastMonth('上月'),
  last30('近30天'),
  last90('近90天'),
  thisQuarter('本季度'),
  thisYear('本年'),
  all('所有'),
  custom('自定义');

  final String label;
  const DatePreset(this.label);
}

DateTimeRange presetRange(DatePreset p) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 23, 59, 59);
  switch (p) {
    case DatePreset.thisMonth:
      return DateTimeRange(start: DateTime(now.year, now.month, 1), end: today);
    case DatePreset.lastMonth:
      final start = DateTime(now.year, now.month - 1, 1);
      final end = DateTime(now.year, now.month, 0, 23, 59, 59);
      return DateTimeRange(start: start, end: end);
    case DatePreset.last30:
      return DateTimeRange(
          start: today.subtract(const Duration(days: 29)), end: today);
    case DatePreset.last90:
      return DateTimeRange(
          start: today.subtract(const Duration(days: 89)), end: today);
    case DatePreset.thisQuarter:
      final qStart = DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1, 1);
      return DateTimeRange(start: qStart, end: today);
    case DatePreset.thisYear:
      return DateTimeRange(start: DateTime(now.year, 1, 1), end: today);
    case DatePreset.all:
      return DateTimeRange(start: DateTime(2000, 1, 1), end: today);
    case DatePreset.custom:
      return DateTimeRange(start: DateTime(now.year, now.month, 1), end: today);
  }
}

// ── Pie chart colors ──

const chartColors = ChartColors.palette;

// ── Helpers ──

String fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String fmtYuan(int cents) {
  final yuan = cents / 100;
  return yuan.toStringAsFixed(2);
}

/// Mini segment control
class MiniSegment extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onTap;

  const MiniSegment({
    super.key,
    required this.labels,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(labels.length, (i) {
          final isSelected = i == selected;
          return GestureDetector(
            onTap: () => onTap(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? NeutralColorsDark.neutral2 : Colors.white)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 2,
                        )
                      ]
                    : null,
              ),
              child: Text(
                labels[i],
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
