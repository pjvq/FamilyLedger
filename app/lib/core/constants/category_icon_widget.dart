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

  /// Legacy emoji icon (fallback when iconKey is empty).
  final String? icon;

  /// Icon size (applies to both Material Icon and emoji text).
  final double size;

  /// Whether to show the colored circle background (Material Icons only).
  final bool showBackground;

  const CategoryIconWidget({
    super.key,
    this.iconKey,
    this.icon,
    this.size = 24,
    this.showBackground = true,
  });

  /// Resolve the effective icon key from iconKey + legacy icon fields.
  static String resolveIconKey(String? iconKey, String? icon) {
    if (iconKey != null && iconKey.isNotEmpty) return iconKey;
    if (icon != null && icon.isNotEmpty) return 'emoji:$icon';
    return 'other';
  }

  /// Check if a key represents an emoji icon.
  static bool isEmoji(String key) => key.startsWith('emoji:');

  /// Extract the emoji character from an emoji key.
  static String emojiChar(String key) =>
      key.startsWith('emoji:') ? key.substring(6) : key;

  @override
  Widget build(BuildContext context) {
    final key = resolveIconKey(iconKey, icon);

    if (isEmoji(key)) {
      // Emoji rendering
      final emoji = emojiChar(key);
      if (showBackground) {
        return Container(
          width: size + 16,
          height: size + 16,
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular((size + 16) / 2),
          ),
          alignment: Alignment.center,
          child: Text(emoji, style: TextStyle(fontSize: size)),
        );
      }
      return Text(emoji, style: TextStyle(fontSize: size));
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
