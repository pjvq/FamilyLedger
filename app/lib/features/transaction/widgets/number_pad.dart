import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 自定义数字键盘 — 大按键，清晰布局
class NumberPad extends StatelessWidget {
  final ValueChanged<String> onKey;
  final VoidCallback onDelete;
  final VoidCallback onConfirm;
  final bool confirmEnabled;

  const NumberPad({
    super.key,
    required this.onKey,
    required this.onDelete,
    required this.onConfirm,
    this.confirmEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    final keyColor = isDark ? const Color(0xFF3A3A3C) : Colors.white;

    return Container(
      color: bgColor,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _row(['7', '8', '9'], keyColor, theme),
          const SizedBox(height: 6),
          _row(['4', '5', '6'], keyColor, theme),
          const SizedBox(height: 6),
          _row(['1', '2', '3'], keyColor, theme),
          const SizedBox(height: 6),
          Row(
            children: [
              _keyButton('.', keyColor, theme),
              const SizedBox(width: 6),
              _keyButton('0', keyColor, theme),
              const SizedBox(width: 6),
              _deleteButton(keyColor, theme),
              const SizedBox(width: 6),
              _confirmButton(theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(List<String> keys, Color keyColor, ThemeData theme) {
    return Row(
      children: keys
          .expand((k) => [
                _keyButton(k, keyColor, theme),
                const SizedBox(width: 6),
              ])
          .toList()
        ..removeLast()
        ..add(const Spacer()), // 右边留空给确认按钮
    );
  }

  Widget _keyButton(String key, Color keyColor, ThemeData theme) {
    return Expanded(
      child: SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: () => onKey(key),
          style: ElevatedButton.styleFrom(
            backgroundColor: keyColor,
            foregroundColor: theme.colorScheme.onSurface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
            ),
          ),
          child: Text(key),
        ),
      ),
    );
  }

  Widget _deleteButton(Color keyColor, ThemeData theme) {
    return Expanded(
      child: SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: onDelete,
          onLongPress: () {
            // Long press to clear
            onDelete();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: keyColor,
            foregroundColor: theme.colorScheme.onSurface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Icon(Icons.backspace_outlined, size: 22),
        ),
      ),
    );
  }

  Widget _confirmButton(ThemeData theme) {
    return Expanded(
      child: SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: confirmEnabled ? onConfirm : null,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                confirmEnabled ? AppColors.primary : AppColors.primary.withValues(alpha: 0.3),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Icon(Icons.check_rounded, size: 26),
        ),
      ),
    );
  }
}
