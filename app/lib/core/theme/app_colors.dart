import 'package:flutter/material.dart';

/// FamilyLedger 颜色系统
/// 收入=绿色系, 支出=红/橙色系, 资产=蓝色系, 负债=暖红色系
class AppColors {
  AppColors._();

  // Brand
  static const primary = Color(0xFF5B6EF5);
  static const primaryDark = Color(0xFF8B9AFF);

  // Semantic — Income / Expense
  static const income = Color(0xFF34C759);
  static const incomeDark = Color(0xFF30D158);
  static const expense = Color(0xFFFF6B6B);
  static const expenseDark = Color(0xFFFF7B7B);

  // Semantic — Asset / Liability
  static const asset = Color(0xFF007AFF);
  static const assetDark = Color(0xFF64D2FF);
  static const liability = Color(0xFFFF6259);
  static const liabilityDark = Color(0xFFFF8A80);

  // Neutral
  static const surfaceLight = Color(0xFFF8F9FA);
  static const surfaceDark = Color(0xFF1C1C1E);
  static const cardLight = Colors.white;
  static const cardDark = Color(0xFF2C2C2E);
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF8E8E93);
  static const textPrimaryDark = Color(0xFFF5F5F7);
  static const textSecondaryDark = Color(0xFF98989D);
  static const divider = Color(0xFFE5E5EA);
  static const dividerDark = Color(0xFF38383A);

  // Chart palette (色盲友好)
  static const chartPalette = [
    Color(0xFF5B6EF5),
    Color(0xFF34C759),
    Color(0xFFFF9500),
    Color(0xFFFF6B6B),
    Color(0xFFAF52DE),
    Color(0xFF5AC8FA),
    Color(0xFFFFCC00),
    Color(0xFFFF2D55),
  ];
}
