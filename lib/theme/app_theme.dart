import 'package:flutter/material.dart';

/// App theme for Tap Score — clean, warm, and inviting.
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF3F51B5),
        brightness: Brightness.light,
        surface: const Color(0xFFF8F6F0),
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F3ED),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF5F3ED),
        foregroundColor: Color(0xFF333333),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: Color(0xFF333333),
          letterSpacing: 0.5,
        ),
      ),
      iconTheme: const IconThemeData(
        color: Color(0xFF555555),
      ),
    );
  }
}
