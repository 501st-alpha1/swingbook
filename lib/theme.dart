import 'package:flutter/material.dart';

class AppTheme {
  // Light palette
  static const teal = Color(0xFF1B4B4F);
  static const gold = Color(0xFFC9A227);
  static const cream = Color(0xFFF7F3E9);
  static const charcoal = Color(0xFF2B2B28);

  // Dark palette — lighter teal/gold so they hold contrast on a dark surface,
  // a near-black background instead of pure black (easier on the eyes / OLED-friendly).
  static const tealDark = Color(0xFF3E8E91);
  static const goldDark = Color(0xFFE0BB4A);
  static const surfaceDark = Color(0xFF15191A);
  static const onSurfaceDark = Color(0xFFE9E6DD);

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: teal,
        brightness: Brightness.light,
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

  static ThemeData get darkTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: tealDark,
        brightness: Brightness.dark,
        primary: tealDark,
        secondary: goldDark,
        surface: surfaceDark,
      ),
      scaffoldBackgroundColor: surfaceDark,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceDark,
        foregroundColor: onSurfaceDark,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: onSurfaceDark,
        displayColor: onSurfaceDark,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: goldDark,
        foregroundColor: surfaceDark,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF1E2426),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: tealDark.withValues(alpha: 0.25)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        selectedColor: goldDark.withValues(alpha: 0.3),
      ),
    );
  }

  /// Color for a proficiency level, used in grid cells and chips.
  /// Pass the current [Brightness] (e.g. `Theme.of(context).brightness`)
  /// so cell colors stay legible in both light and dark mode.
  static Color levelColor(int levelIndex, [Brightness brightness = Brightness.light]) {
    final isDark = brightness == Brightness.dark;
    final baseTeal = isDark ? tealDark : teal;
    final baseGold = isDark ? goldDark : gold;

    switch (levelIndex) {
      case 0:
        return isDark ? const Color(0xFF333938) : Colors.grey.shade300;
      case 1:
        return baseTeal.withValues(alpha: isDark ? 0.3 : 0.25);
      case 2:
        return baseTeal.withValues(alpha: isDark ? 0.55 : 0.5);
      case 3:
        return baseTeal.withValues(alpha: isDark ? 0.85 : 0.8);
      case 4:
      default:
        return baseGold;
    }
  }
}
