import 'package:flutter/material.dart';
import 'color_tokens.dart';

/// Theme extension providing context-aware semantic colors.
/// Usage: `Theme.of(context).extension<AppSemanticColors>()!.income`
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color income;
  final Color expense;
  final Color asset;
  final Color liability;
  final Color warning;
  final Color success;
  final Color error;
  final Color info;

  const AppSemanticColors({
    required this.income,
    required this.expense,
    required this.asset,
    required this.liability,
    required this.warning,
    required this.success,
    required this.error,
    required this.info,
  });

  static const light = AppSemanticColors(
    income: SemanticColorsLight.income,
    expense: SemanticColorsLight.expense,
    asset: SemanticColorsLight.asset,
    liability: SemanticColorsLight.liability,
    warning: SemanticColorsLight.warning,
    success: SemanticColorsLight.success,
    error: SemanticColorsLight.error,
    info: SemanticColorsLight.info,
  );

  static const dark = AppSemanticColors(
    income: SemanticColorsDark.income,
    expense: SemanticColorsDark.expense,
    asset: SemanticColorsDark.asset,
    liability: SemanticColorsDark.liability,
    warning: SemanticColorsDark.warning,
    success: SemanticColorsDark.success,
    error: SemanticColorsDark.error,
    info: SemanticColorsDark.info,
  );

  @override
  AppSemanticColors copyWith({
    Color? income,
    Color? expense,
    Color? asset,
    Color? liability,
    Color? warning,
    Color? success,
    Color? error,
    Color? info,
  }) {
    return AppSemanticColors(
      income: income ?? this.income,
      expense: expense ?? this.expense,
      asset: asset ?? this.asset,
      liability: liability ?? this.liability,
      warning: warning ?? this.warning,
      success: success ?? this.success,
      error: error ?? this.error,
      info: info ?? this.info,
    );
  }

  @override
  AppSemanticColors lerp(AppSemanticColors? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      asset: Color.lerp(asset, other.asset, t)!,
      liability: Color.lerp(liability, other.liability, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      success: Color.lerp(success, other.success, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

/// Convenience extension for accessing semantic colors from BuildContext.
extension SemanticColorsX on BuildContext {
  AppSemanticColors get semanticColors =>
      Theme.of(this).extension<AppSemanticColors>()!;
}
