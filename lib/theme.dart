import 'package:flutter/material.dart';

class AppTheme {
  static const teal = Color(0xFF1B4B4F);
  static const gold = Color(0xFFC9A227);
  static const cream = Color(0xFFF7F3E9);
  static const charcoal = Color(0xFF2B2B28);

  static ThemeData get theme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: teal,
        primary: teal,
        secondary: gold,
        surface: cream,
      ),
      scaffoldBackgroundColor: cream,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: teal,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: charcoal,
        displayColor: charcoal,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: gold,
        foregroundColor: charcoal,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: teal.withValues(alpha: 0.12)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        selectedColor: gold.withValues(alpha: 0.25),
      ),
    );
  }

  /// Color for a proficiency level, used in grid cells and chips.
  static Color levelColor(int levelIndex) {
    switch (levelIndex) {
      case 0:
        return Colors.grey.shade300;
      case 1:
        return teal.withValues(alpha: 0.25);
      case 2:
        return teal.withValues(alpha: 0.5);
      case 3:
        return teal.withValues(alpha: 0.8);
      case 4:
      default:
        return gold;
    }
  }
}
