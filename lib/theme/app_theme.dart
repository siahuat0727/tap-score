import 'package:flutter/material.dart';

import 'app_colors.dart';

/// App theme for Tap Score — clean, warm, and inviting.
class AppTheme {
  static const String _primaryFontFamily = 'Roboto';
  static const List<String> _fallbackFontFamilies = [
    'Noto Music',
    'Noto Sans Symbols',
    'Noto Sans SC',
  ];

  static ThemeData get lightTheme {
    final baseTheme = ThemeData(
      useMaterial3: true,
      fontFamily: _primaryFontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF3F51B5),
        brightness: Brightness.light,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.surfaceDim,
      iconTheme: const IconThemeData(color: AppColors.textSecondary),
    );

    final textTheme = _applyAppFont(baseTheme.textTheme);
    final primaryTextTheme = _applyAppFont(baseTheme.primaryTextTheme);

    return baseTheme.copyWith(
      textTheme: textTheme,
      primaryTextTheme: primaryTextTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceDim,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: _withAppFont(const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          letterSpacing: 0.5,
        )),
      ),
    );
  }

  static TextTheme _applyAppFont(TextTheme textTheme) {
    final themed = textTheme.apply(fontFamily: _primaryFontFamily);
    return themed.copyWith(
      displayLarge: _withAppFont(themed.displayLarge),
      displayMedium: _withAppFont(themed.displayMedium),
      displaySmall: _withAppFont(themed.displaySmall),
      headlineLarge: _withAppFont(themed.headlineLarge),
      headlineMedium: _withAppFont(themed.headlineMedium),
      headlineSmall: _withAppFont(themed.headlineSmall),
      titleLarge: _withAppFont(themed.titleLarge),
      titleMedium: _withAppFont(themed.titleMedium),
      titleSmall: _withAppFont(themed.titleSmall),
      bodyLarge: _withAppFont(themed.bodyLarge),
      bodyMedium: _withAppFont(themed.bodyMedium),
      bodySmall: _withAppFont(themed.bodySmall),
      labelLarge: _withAppFont(themed.labelLarge),
      labelMedium: _withAppFont(themed.labelMedium),
      labelSmall: _withAppFont(themed.labelSmall),
    );
  }

  static TextStyle? _withAppFont(TextStyle? style) {
    if (style == null) {
      return null;
    }

    return style.copyWith(
      fontFamily: _primaryFontFamily,
      fontFamilyFallback: _fallbackFontFamilies,
    );
  }
}
