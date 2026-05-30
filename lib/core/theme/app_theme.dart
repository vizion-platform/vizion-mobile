import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF0F0F0F);
  static const Color surface = Color(0xFF161616);
  static const Color primaryGold = Color(0xFFD2C4A7);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.grey;
  static const Color gridLine = Color(0xFF1F1F1F);
}

class AppTheme {
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    primaryColor: AppColors.primaryGold,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryGold,
      background: AppColors.background,
      surface: AppColors.surface,
    ),
    fontFamily: 'sans-serif',
  );
}
