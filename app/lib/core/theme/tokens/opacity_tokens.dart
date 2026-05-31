/// Opacity design tokens — standardized alpha values across the app.
abstract final class OpacityTokens {
  /// Primary text / foreground (fully opaque)
  static const double full = 1.0;

  /// Secondary text, icons, labels
  static const double medium = 0.7;

  /// Tertiary text, hints, disabled
  static const double subtle = 0.5;

  /// Decorative / background accents
  static const double faint = 0.4;

  /// Nearly invisible / ghost states
  static const double ghost = 0.2;
}
