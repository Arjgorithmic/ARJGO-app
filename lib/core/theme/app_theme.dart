import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract class AppColors {
  static const background = Color(0xFFF8F8F8);
  static const text = Color(0xFF1A1A1A);
  static const accent = Color(0xFF2D4040);
  static const divider = Color(0xFFE8EAEA);
  static const grey = Color(0xFFAAAAAA);
  static const greyLight = Color(0xFFCCCCCC);
  static const white = Color(0xFFFFFFFF);
}

abstract class AppTheme {
  static ThemeData get light => _buildTheme(Brightness.light);
  static ThemeData get dark => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0A0A) : AppColors.background;
    final card = isDark ? const Color(0xFF141414) : AppColors.white;
    final text = isDark ? AppColors.white : AppColors.text;
    final divider = isDark ? const Color(0xFF1E1E1E) : AppColors.divider;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      cardColor: card,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.accent,
        onPrimary: AppColors.white,
        secondary: AppColors.accent,
        onSecondary: AppColors.white,
        error: Colors.red,
        onError: AppColors.white,
        background: bg,
        onBackground: text,
        surface: card,
        onSurface: text,
      ),
      textTheme: _textTheme(text),
      dividerTheme: DividerThemeData(color: divider, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: text),
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: text,
          letterSpacing: 0.5,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: card,
        elevation: 0,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
    );
  }

  static TextTheme _textTheme(Color color) => TextTheme(
        headlineLarge: GoogleFonts.dmSans(fontSize: 32, fontWeight: FontWeight.w200, color: color),
        headlineMedium: GoogleFonts.dmSans(fontSize: 24, fontWeight: FontWeight.w300, color: color),
        titleLarge: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w500, color: color),
        bodyLarge: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w300, color: color),
        bodyMedium: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w300, color: color),
        labelSmall: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.w500, color: AppColors.grey, letterSpacing: 2),
      );
}
