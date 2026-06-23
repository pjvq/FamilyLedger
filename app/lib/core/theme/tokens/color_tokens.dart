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
  static const Color income = Color(0xFF34C759);

  /// Expense — red indicating outgoing cash flow.
  static const Color expense = Color(0xFFFF6B6B);

  /// Asset — blue indicating owned value.
  static const Color asset = Color(0xFF007AFF);

  /// Liability — orange indicating owed value.
  static const Color liability = Color(0xFFFF6259);

  /// Success state — intentionally shares value with [income].
  static const Color success = income;

  /// Warning state.
  static const Color warning = Color(0xFFFF9500);

  /// Error state — intentionally shares value with [expense].
  static const Color error = expense;

  /// Informational state.
  static const Color info = Color(0xFF007AFF);
}

/// Semantic colors for financial categories (Dark mode).
abstract final class SemanticColorsDark {
  /// Income — green (darker variant for dark backgrounds).
  static const Color income = Color(0xFF30D158);

  /// Expense — red (darker variant for dark backgrounds).
  static const Color expense = Color(0xFFFF7B7B);

  /// Asset — blue (darker variant for dark backgrounds).
  static const Color asset = Color(0xFF64D2FF);

  /// Liability — orange (darker variant for dark backgrounds).
  static const Color liability = Color(0xFFFF8A80);

  /// Success state — intentionally shares value with [income].
  static const Color success = income;

  /// Warning state.
  static const Color warning = Color(0xFFFF9F0A);

  /// Error state — intentionally shares value with [expense].
  static const Color error = expense;

  /// Informational state.
  static const Color info = Color(0xFF64D2FF);
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
  /// Positional slot names to avoid coupling to hue.
  /// Slot 1-8 are the primary chart palette (color-blind safe).
  /// Slot 9-10 are extended colors for charts with more series.
  static const Color slot1 = Color(0xFF5B6EF5); // Indigo
  static const Color slot2 = Color(0xFF2ECC71); // Emerald
  static const Color slot3 = Color(0xFFF39C12); // Amber
  static const Color slot4 = Color(0xFF9B59B6); // Purple
  static const Color slot5 = Color(0xFF1ABC9C); // Teal
  static const Color slot6 = Color(0xFFE74C3C); // Coral
  static const Color slot7 = Color(0xFF34495E); // Slate
  static const Color slot8 = Color(0xFFF06292); // Pink
  static const Color slot9 = Color(0xFF64D2FF); // Light Blue
  static const Color slot10 = Color(0xFF30D158); // Light Green

  /// Full chart palette for pie/bar/line charts (color-blind safe, per UX design doc).
  static const List<Color> palette = [
    slot1,
    slot2,
    slot3,
    slot4,
    slot5,
    slot6,
    slot7,
    slot8,
    slot9,
    slot10,
  ];
}

/// Skeleton/shimmer loading placeholder colors.
abstract final class SkeletonTokens {
  // Light mode
  static const Color baseLight = Color(0xFFE8E8E8);
  static const Color highlightLight = Color(0xFFF5F5F5);
  static const Color containerLight = Color(0xFFFFFFFF);
  // Dark mode
  static const Color baseDark = Color(0xFF3A3A3C);
  static const Color highlightDark = Color(0xFF4A4A4C);
  static const Color containerDark = Color(0xFF2C2C2E);
}

/// Dark mode card/hero gradient tokens for module headers.
///
/// Derivation rule: Each module maps to a hue from its semantic color.
/// - Saturation: 25–35% (subdued for dark backgrounds)
/// - Lightness: start ≈ 15–18%, end ≈ 10–13%
/// - Hue: matches module accent (loan=red, invest=indigo, asset=cyan, etc.)
///
/// To add a new module gradient: pick its accent hue, apply S≈30%, L=16%/12%.
abstract final class DarkCardGradients {
  // Primary/generic (overview, settings)
  static const Color primaryStart = Color(0xFF2C2C4A);
  static const Color primaryEnd = Color(0xFF1C1C3E);
  // Loan
  static const Color loanStart = Color(0xFF2A1A1A);
  static const Color loanEnd = Color(0xFF1A0F0F);
  // Loan group
  static const Color loanGroupStart = Color(0xFF1A1A2E);
  static const Color loanGroupEnd = Color(0xFF16213E);
  // Investment
  static const Color investmentStart = Color(0xFF1A1A3A);
  static const Color investmentEnd = Color(0xFF0F0F2A);
  // Asset / fixed asset
  static const Color assetStart = Color(0xFF1A2A3A);
  static const Color assetEnd = Color(0xFF0F1F2F);
  // Net worth (assets tab)
  static const Color netWorthStart = Color(0xFF1A3A2A);
  static const Color netWorthEnd = Color(0xFF0F2A1F);
  // Dashboard
  static const Color dashboardStart = Color(0xFF1A2A4A);
  static const Color dashboardEnd = Color(0xFF0F1A2F);
}

/// Third-party brand colors (for import format badges, etc.).
abstract final class BrandColors {
  static const Color wechat = Color(0xFF07C160);
  static const Color alipay = Color(0xFF1677FF);
  static const Color baishiAA = Color(0xFFFF9800);
}

/// Metal/commodity colors for investment type indicators.
abstract final class CommodityColors {
  static const Color gold = Color(0xFFD4AF37);
  static const Color silver = Color(0xFFA8A9AD);
  static const Color platinum = Color(0xFFE5E4E2);

  /// Fallback for unknown commodity types.
  static const Color fallback = Color(0xFF9E9E9E);
}

/// Gradient color tokens for decorative/emphasis gradients.
abstract final class GradientTokens {
  static const Color primaryGradientStart = Color(0xFF5B6EF5);
  static const Color primaryGradientEnd = Color(0xFF8B9AFF);
  static const Color incomeGradientStart = Color(0xFF34C759);
  static const Color incomeGradientEnd = Color(0xFF28B34A);
  static const Color expenseGradientStart = Color(0xFFFF6B6B);
  static const Color expenseGradientEnd = Color(0xFFFF4757);
  static const Color assetGradientStart = Color(0xFF007AFF);
  static const Color assetGradientEnd = Color(0xFF0056CC);
  static const Color primaryGradientAlt = Color(0xFF4A5AF0);
  static const Color primaryGradientDeep = Color(0xFF3D50E0);
  static const Color primaryGradientSoft = Color(0xFF4A5DE5);
}
