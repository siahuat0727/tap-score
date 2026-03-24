import 'package:flutter/material.dart';

import 'app_colors.dart';

/// App theme for Tap Score — clean, warm, and inviting.
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF3F51B5),
        brightness: Brightness.light,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.surfaceDim,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceDim,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          letterSpacing: 0.5,
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary),
    );
  }
}
