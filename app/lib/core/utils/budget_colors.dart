import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Returns appropriate color for budget execution rate.
Color budgetRateColor(BuildContext context, double rate) {
  final colors = context.semanticColors;
  if (rate >= 1.0) return colors.expense;
  if (rate >= 0.8) return colors.warning;
  return colors.income;
}
