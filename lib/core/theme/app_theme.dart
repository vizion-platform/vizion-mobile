import 'package:flutter/material.dart';

class AppColors {
  static const Color goldenrod = Color(0xFFDAA520);
  static const Color darkGoldenrod = Color(0xFFB8860B);
  static const Color background = Color(0xFF0F0F0F);
  static const Color surface = Color(0xFF161616);
  static const Color primaryGold = goldenrod;
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
      onPrimary: Colors.black,
      surface: AppColors.surface,
    ),
    fontFamily: 'sans-serif',
  );
}
