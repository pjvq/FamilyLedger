// ─────────────────────────────────────────────────────────────────────────────
// Spacing Tokens
// ─────────────────────────────────────────────────────────────────────────────

/// Spacing scale based on a 4px base unit.
///
/// Usage: `SizedBox(height: SpacingTokens.md)` or `EdgeInsets.all(SpacingTokens.base)`
abstract final class SpacingTokens {
  /// Base unit — all spacing derives from this (4px).
  static const double unit = 4.0;

  /// Extra small — 4px. Tight internal spacing.
  static const double xs = 4.0;

  /// Small — 8px. Internal element spacing.
  static const double sm = 8.0;

  /// Medium — 12px. Compact section spacing.
  static const double md = 12.0;

  /// Base — 16px. Standard content spacing.
  static const double base = 16.0;

  /// Large — 20px. Generous content spacing.
  static const double lg = 20.0;

  /// Extra large — 24px. Section separation.
  static const double xl = 24.0;

  /// 2× extra large — 32px. Major section breaks.
  static const double xl2 = 32.0;

  /// 3× extra large — 48px. Page-level spacing.
  static const double xl3 = 48.0;

  /// 4× extra large — 64px. Hero/display spacing.
  static const double xl4 = 64.0;
}
