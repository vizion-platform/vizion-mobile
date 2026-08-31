import 'package:flutter/material.dart';

class AppColors {
  static const Color salmon = Color(0xFFFA8072);
  static const Color darkSalmon = Color(0xFFE9967A);
  static const Color lightSalmon = Color(0xFFFFA07A);
  static const Color coral = Color(0xFFFF7F50);
  static const Color tomato = Color(0xFFFF6347);
  static const Color background = Color(0xFF0F0F0F);
  static const Color surface = Color(0xFF161616);
  static const Color primaryGold = coral;
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
      surface: AppColors.surface,
    ),
    fontFamily: 'sans-serif',
  );
}
