import 'package:flutter/material.dart';
import 'design_tokens.dart';

class AppColors {
  static const green = Color(0xFF1B5E20);
  static const greenDark = Color(0xFF0F3D14);
  static const gold = Color(0xFFD4AF37);
  static const cream = Color(0xFFFAF7EF);
}

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.green, brightness: b)
      .copyWith(secondary: AppColors.gold);
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radius16));
  const text = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? const Color(0xFF0F130F) : AppColors.cream,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52), shape: shape, textStyle: text),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52), shape: shape, textStyle: text),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radius12)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: dark ? const Color(0xFF161B16) : Colors.white,
      indicatorColor: scheme.primaryContainer,
    ),
  );
}
