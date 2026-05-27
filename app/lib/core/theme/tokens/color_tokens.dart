import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Color Tokens
// ─────────────────────────────────────────────────────────────────────────────

/// Primary brand colors.
abstract final class ColorTokens {
  /// Brand primary — used for CTAs, active states, navigation highlights.
  static const Color primary = Color(0xFF5B6EF5);

  /// Lighter variant of primary — hover states, backgrounds.
  static const Color primaryLight = Color(0xFF8B9AFF);

  /// Darker variant of primary — pressed states, emphasis.
  static const Color primaryDark = Color(0xFF3D4FD9);
}

/// Semantic colors for financial categories (Light mode).
abstract final class SemanticColorsLight {
  /// Income — green indicating positive cash flow.
  static const Color income = Color(0xFF2ECC71);

  /// Expense — red indicating outgoing cash flow.
  static const Color expense = Color(0xFFE74C3C);

  /// Asset — blue indicating owned value.
  static const Color asset = Color(0xFF3498DB);

  /// Liability — orange indicating owed value.
  static const Color liability = Color(0xFFE67E22);

  /// Success state — intentionally shares value with [income].
  static const Color success = income;

  /// Warning state.
  static const Color warning = Color(0xFFE67E22);

  /// Error state — intentionally shares value with [expense].
  static const Color error = expense;

  /// Informational state.
  static const Color info = Color(0xFF3498DB);
}

/// Semantic colors for financial categories (Dark mode).
abstract final class SemanticColorsDark {
  /// Income — green (darker variant for dark backgrounds).
  static const Color income = Color(0xFF27AE60);

  /// Expense — red (darker variant for dark backgrounds).
  static const Color expense = Color(0xFFC0392B);

  /// Asset — blue (darker variant for dark backgrounds).
  static const Color asset = Color(0xFF2980B9);

  /// Liability — orange (darker variant for dark backgrounds).
  static const Color liability = Color(0xFFD35400);

  /// Success state — intentionally shares value with [income].
  static const Color success = income;

  /// Warning state.
  static const Color warning = Color(0xFFD35400);

  /// Error state — intentionally shares value with [expense].
  static const Color error = expense;

  /// Informational state.
  static const Color info = Color(0xFF2980B9);
}

/// Neutral color scale — Light mode (8 steps from white to near-black).
abstract final class NeutralColorsLight {
  /// Pure white — card backgrounds.
  static const Color neutral0 = Color(0xFFFFFFFF);

  /// Very light grey — page background.
  static const Color neutral1 = Color(0xFFF8F9FA);

  /// Light grey — secondary backgrounds.
  static const Color neutral2 = Color(0xFFF1F3F5);

  /// Medium light grey — borders, dividers.
  static const Color neutral3 = Color(0xFFDEE2E6);

  /// Mid grey — disabled text, placeholders.
  static const Color neutral4 = Color(0xFFADB5BD);

  /// Dark grey — secondary text.
  static const Color neutral5 = Color(0xFF6C757D);

  /// Darker grey — primary text (secondary weight).
  static const Color neutral6 = Color(0xFF495057);

  /// Near black — primary text.
  static const Color neutral7 = Color(0xFF212529);
}

/// Neutral color scale — Dark mode (8 steps from near-black to near-white).
abstract final class NeutralColorsDark {
  /// Deepest dark — page background.
  static const Color neutral0 = Color(0xFF121212);

  /// Dark surface — elevated surfaces.
  static const Color neutral1 = Color(0xFF1E1E1E);

  /// Card/container background.
  static const Color neutral2 = Color(0xFF2C2C2C);

  /// Borders, dividers.
  static const Color neutral3 = Color(0xFF3D3D3D);

  /// Disabled text, icons.
  static const Color neutral4 = Color(0xFF5C5C5C);

  /// Secondary text.
  static const Color neutral5 = Color(0xFF8C8C8C);

  /// Primary text (secondary weight).
  static const Color neutral6 = Color(0xFFBFBFBF);

  /// Near white — primary text.
  static const Color neutral7 = Color(0xFFF5F5F5);
}

/// Chart palette — 8 colors, designed to be color-blind friendly.
abstract final class ChartColors {
  /// Full chart palette for pie/bar/line charts.
  static const List<Color> palette = [
    Color(0xFF5B6EF5), // Indigo
    Color(0xFF2ECC71), // Emerald
    Color(0xFFF39C12), // Amber
    Color(0xFF9B59B6), // Purple
    Color(0xFF1ABC9C), // Teal
    Color(0xFFE74C3C), // Coral
    Color(0xFF34495E), // Slate
    Color(0xFFF06292), // Pink
  ];
}

/// Gradient color tokens for decorative/emphasis gradients.
abstract final class GradientTokens {
  static const Color primaryGradientStart = Color(0xFF5B6EF5);
  static const Color primaryGradientEnd = Color(0xFF8B9AFF);
  static const Color incomeGradientStart = Color(0xFF2ECC71);
  static const Color incomeGradientEnd = Color(0xFF27AE60);
  static const Color expenseGradientStart = Color(0xFFE74C3C);
  static const Color expenseGradientEnd = Color(0xFFC0392B);
  static const Color assetGradientStart = Color(0xFF3498DB);
  static const Color assetGradientEnd = Color(0xFF2980B9);
  static const Color primaryGradientAlt = Color(0xFF4A5AF0);
  static const Color primaryGradientDeep = Color(0xFF3D50E0);
  static const Color primaryGradientSoft = Color(0xFF4A5DE5);
}

