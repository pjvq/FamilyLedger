import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shadow Tokens
// ─────────────────────────────────────────────────────────────────────────────

/// Elevation/shadow tokens for Light mode.
///
/// Usage: `Container(decoration: BoxDecoration(boxShadow: ShadowTokensLight.sm))`
abstract final class ShadowTokensLight {
  /// Small shadow — subtle lift (cards, list items).
  static const List<BoxShadow> sm = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  /// Medium shadow — moderate lift (dropdowns, popovers).
  static const List<BoxShadow> md = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  /// Large shadow — strong lift (modals, floating action buttons).
  static const List<BoxShadow> lg = [
    BoxShadow(
      color: Color(0x1F000000),
      blurRadius: 16,
      offset: Offset(0, 8),
    ),
  ];
}

/// Elevation/shadow tokens for Dark mode.
///
/// In dark mode, shadows are more subtle and use lighter edges.
abstract final class ShadowTokensDark {
  /// Small shadow — subtle depth cue.
  static const List<BoxShadow> sm = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  /// Medium shadow — moderate depth.
  static const List<BoxShadow> md = [
    BoxShadow(
      color: Color(0x4D000000),
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  /// Large shadow — strong depth.
  static const List<BoxShadow> lg = [
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 16,
      offset: Offset(0, 8),
    ),
  ];
}
