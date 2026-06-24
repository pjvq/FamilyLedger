import 'package:flutter/material.dart';

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
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// Display large — 34px / bold. Hero numbers, onboarding headlines.
  static TextStyle displayLg({Color? color}) =>
      color == null ? _displayLg : _displayLg.copyWith(color: color);

  static const _displayMd = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  /// Display medium — 28px / bold. Section heroes.
  static TextStyle displayMd({Color? color}) =>
      color == null ? _displayMd : _displayMd.copyWith(color: color);

  // ─── Headline ───

  static const _headlineLg = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// Headline large — 24px / semibold. Page titles.
  static TextStyle headlineLg({Color? color}) =>
      color == null ? _headlineLg : _headlineLg.copyWith(color: color);

  static const _headlineMd = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// Headline medium — 20px / semibold. Card titles.
  static TextStyle headlineMd({Color? color}) =>
      color == null ? _headlineMd : _headlineMd.copyWith(color: color);

  // ─── Title ───

  static const _titleLg = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  /// Title large — 18px / medium. Prominent labels.
  static TextStyle titleLg({Color? color}) =>
      color == null ? _titleLg : _titleLg.copyWith(color: color);

  static const _titleMd = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  /// Title medium — 16px / medium. Standard labels.
  static TextStyle titleMd({Color? color}) =>
      color == null ? _titleMd : _titleMd.copyWith(color: color);

  // ─── Body ───

  static const _bodyLg = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// Body large — 16px / regular. Primary reading text.
  static TextStyle bodyLg({Color? color}) =>
      color == null ? _bodyLg : _bodyLg.copyWith(color: color);

  static const _bodyMd = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// Body medium — 14px / regular. Secondary text, descriptions.
  static TextStyle bodyMd({Color? color}) =>
      color == null ? _bodyMd : _bodyMd.copyWith(color: color);

  static const _bodySm = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// Body small — 13px / regular. Tertiary text, timestamps.
  static TextStyle bodySm({Color? color}) =>
      color == null ? _bodySm : _bodySm.copyWith(color: color);

  // ─── Caption & Overline ───

  static const _caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// Caption — 12px / regular. Labels, auxiliary info.
  static TextStyle caption({Color? color}) =>
      color == null ? _caption : _caption.copyWith(color: color);

  static const _overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.5,
  );

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
  }) => TextStyle(
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontFeatures: const [FontFeature.tabularFigures()],
    color: color,
  );
}
