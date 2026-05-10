import 'package:flutter/material.dart';
import 'category_icons.dart';

/// Unified category icon renderer.
///
/// Supports two icon formats via a single `iconKey` field:
/// - Material Icons key: e.g. `food_breakfast`, `transport_metro`
/// - Emoji prefix: e.g. `emoji:🍜`, `emoji:🚇`
///
/// When both `iconKey` and legacy `icon` (emoji) are provided,
/// `iconKey` takes precedence. The `icon` field is for backward
/// compatibility only.
class CategoryIconWidget extends StatelessWidget {
  /// Primary icon identifier. Material Icons key or `emoji:X` format.
  final String? iconKey;

  /// Icon size (applies to both Material Icon and emoji text).
  final double size;

  /// Whether to show the colored circle background (Material Icons only).
  final bool showBackground;

  const CategoryIconWidget({
    super.key,
    this.iconKey,
    this.size = 24,
    this.showBackground = true,
  });

  /// Resolve the effective icon key.
  static String resolveIconKey(String? iconKey) {
    if (iconKey != null && iconKey.isNotEmpty) return iconKey;
    return 'other';
  }

  /// Check if a key represents an emoji icon.
  static bool isEmoji(String key) => key.startsWith('emoji:');

  /// Extract the emoji character from an emoji key.
  static String emojiChar(String key) =>
      key.startsWith('emoji:') ? key.substring(6) : key;

  @override
  Widget build(BuildContext context) {
    final key = resolveIconKey(iconKey);

    if (isEmoji(key)) {
      // Emoji rendering
      final emoji = emojiChar(key);
      final emojiText = FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(emoji,
            style: TextStyle(fontSize: size, height: 1.15),
            strutStyle: StrutStyle(fontSize: size, height: 1.15, forceStrutHeight: true),
            textAlign: TextAlign.center),
      );

      if (showBackground) {
        return Container(
          width: size + 16,
          height: size + 16,
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular((size + 16) / 2),
          ),
          alignment: Alignment.center,
          child: SizedBox(width: size, height: size, child: Center(child: emojiText)),
        );
      }
      return SizedBox(width: size, height: size, child: Center(child: emojiText));
    }

    // Material Icons rendering
    final iconData = CategoryIcons.getIcon(key);
    final color = CategoryIcons.getColor(key);

    if (showBackground) {
      return Container(
        width: size + 16,
        height: size + 16,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular((size + 16) / 2),
        ),
        alignment: Alignment.center,
        child: Icon(iconData, size: size, color: color),
      );
    }
    return Icon(iconData, size: size, color: color);
  }
}
