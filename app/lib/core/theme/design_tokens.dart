import 'package:flutter/material.dart';

// ============================================================================
// FamilyLedger Design Tokens
//
// Single source of truth for all visual design decisions.
// Aligned with UX documentation (Part 2, Section 4).
//
// Usage:
//   ColorTokens.primary          → brand primary color
//   SpacingTokens.md             → 12px spacing
//   RadiusTokens.lg              → 16px border radius
//   TypographyTokens.bodyMd()    → body medium text style
// ============================================================================

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
  static const Color warning = Color(0xFFF39C12);

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
  static const Color warning = Color(0xFFE67E22);

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
    Color(0xFF5B6EF5), // primary blue-purple
    Color(0xFF2ECC71), // green
    Color(0xFFF39C12), // amber
    Color(0xFF9B59B6), // purple
    Color(0xFF1ABC9C), // teal
    Color(0xFFE74C3C), // red
    Color(0xFF34495E), // dark slate
    Color(0xFFF06292), // pink
  ];
}

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

// ─────────────────────────────────────────────────────────────────────────────
// Radius Tokens
// ─────────────────────────────────────────────────────────────────────────────

/// Border radius tokens.
///
/// Usage: `BorderRadius.circular(RadiusTokens.md)`
abstract final class RadiusTokens {
  /// Small — 8px. Inputs, chips.
  static const double sm = 8.0;

  /// Medium — 12px. Cards, dialogs.
  static const double md = 12.0;

  /// Large — 16px. Bottom sheets, large cards.
  static const double lg = 16.0;

  /// Extra large — 24px. Modals, overlays.
  static const double xl = 24.0;

  /// Full — 999px. Pills, circular elements.
  static const double full = 999.0;
}

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

// ─────────────────────────────────────────────────────────────────────────────
// Typography Tokens
// ─────────────────────────────────────────────────────────────────────────────

/// Typography scale using system fonts.
///
/// SF Pro on iOS, Roboto on Android — no custom font families specified,
/// which lets Flutter use the platform default.
///
/// Usage: `Text('Hello', style: TypographyTokens.headlineMd())`
abstract final class TypographyTokens {
  // ─── Display ───

  static const _displayLg = TextStyle(
    fontSize: 34, fontWeight: FontWeight.w700, height: 1.2);
  /// Display large — 34px / bold. Hero numbers, onboarding headlines.
  static TextStyle displayLg({Color? color}) =>
      color == null ? _displayLg : _displayLg.copyWith(color: color);

  static const _displayMd = TextStyle(
    fontSize: 28, fontWeight: FontWeight.w700, height: 1.25);
  /// Display medium — 28px / bold. Section heroes.
  static TextStyle displayMd({Color? color}) =>
      color == null ? _displayMd : _displayMd.copyWith(color: color);

  // ─── Headline ───

  static const _headlineLg = TextStyle(
    fontSize: 24, fontWeight: FontWeight.w600, height: 1.3);
  /// Headline large — 24px / semibold. Page titles.
  static TextStyle headlineLg({Color? color}) =>
      color == null ? _headlineLg : _headlineLg.copyWith(color: color);

  static const _headlineMd = TextStyle(
    fontSize: 20, fontWeight: FontWeight.w600, height: 1.3);
  /// Headline medium — 20px / semibold. Card titles.
  static TextStyle headlineMd({Color? color}) =>
      color == null ? _headlineMd : _headlineMd.copyWith(color: color);

  // ─── Title ───

  static const _titleLg = TextStyle(
    fontSize: 18, fontWeight: FontWeight.w500, height: 1.4);
  /// Title large — 18px / medium. Prominent labels.
  static TextStyle titleLg({Color? color}) =>
      color == null ? _titleLg : _titleLg.copyWith(color: color);

  static const _titleMd = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w500, height: 1.4);
  /// Title medium — 16px / medium. Standard labels.
  static TextStyle titleMd({Color? color}) =>
      color == null ? _titleMd : _titleMd.copyWith(color: color);

  // ─── Body ───

  static const _bodyLg = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w400, height: 1.5);
  /// Body large — 16px / regular. Primary reading text.
  static TextStyle bodyLg({Color? color}) =>
      color == null ? _bodyLg : _bodyLg.copyWith(color: color);

  static const _bodyMd = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w400, height: 1.5);
  /// Body medium — 14px / regular. Secondary text, descriptions.
  static TextStyle bodyMd({Color? color}) =>
      color == null ? _bodyMd : _bodyMd.copyWith(color: color);

  static const _bodySm = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w400, height: 1.5);
  /// Body small — 13px / regular. Tertiary text, timestamps.
  static TextStyle bodySm({Color? color}) =>
      color == null ? _bodySm : _bodySm.copyWith(color: color);

  // ─── Caption & Overline ───

  static const _caption = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w400, height: 1.4);
  /// Caption — 12px / regular. Labels, auxiliary info.
  static TextStyle caption({Color? color}) =>
      color == null ? _caption : _caption.copyWith(color: color);

  static const _overline = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w500, height: 1.4, letterSpacing: 0.5);
  /// Overline — 11px / medium. All-caps category labels.
  static TextStyle overline({Color? color}) =>
      color == null ? _overline : _overline.copyWith(color: color);

  // ─── Amount (Tabular Figures) ───

  /// Amount text style with tabular figures for aligned numbers.
  ///
  /// [fontSize] defaults to 16. [fontWeight] defaults to bold.
  static TextStyle amount({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
  }) =>
      TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: color,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Icon Size Tokens
// ─────────────────────────────────────────────────────────────────────────────

/// Standard icon sizes.
///
/// Usage: `Icon(Icons.home, size: IconSizeTokens.md)`
abstract final class IconSizeTokens {
  /// Extra small — 16px. Inline indicators.
  static const double xs = 16.0;

  /// Small — 20px. Compact list icons.
  static const double sm = 20.0;

  /// Medium — 24px. Standard icons (Material default).
  static const double md = 24.0;

  /// Large — 28px. Emphasis icons.
  static const double lg = 28.0;

  /// Extra large — 32px. Featured icons.
  static const double xl = 32.0;

  /// 2× extra large — 48px. Hero/illustration icons.
  static const double xl2 = 48.0;
}
