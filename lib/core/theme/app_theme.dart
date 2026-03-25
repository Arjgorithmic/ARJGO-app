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
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.light(
          primary: AppColors.accent,
          onPrimary: AppColors.white,
          surface: AppColors.background,
          onSurface: AppColors.text,
        ),
        textTheme: _textTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: const IconThemeData(color: AppColors.text),
          titleTextStyle: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.text,
            letterSpacing: 0.5,
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.divider,
          thickness: 1,
          space: 1,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.white,
          elevation: 0,
          selectedItemColor: AppColors.accent,
          unselectedItemColor: AppColors.grey,
          selectedLabelStyle: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.4,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w400,
            letterSpacing: 1.4,
          ),
          showSelectedLabels: true,
          showUnselectedLabels: true,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: false,
          border: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.divider, width: 1),
          ),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.divider, width: 1),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.accent, width: 1.5),
          ),
          labelStyle: GoogleFonts.dmSans(
            fontSize: 12,
            color: AppColors.grey,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w400,
          ),
          hintStyle: GoogleFonts.dmSans(
            fontSize: 14,
            color: AppColors.greyLight,
            fontWeight: FontWeight.w300,
          ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.white,
            elevation: 0,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            textStyle: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
        ),
      );

  static TextTheme get _textTheme => TextTheme(
        displayLarge: GoogleFonts.dmSans(
          fontSize: 56,
          fontWeight: FontWeight.w100,
          color: AppColors.text,
          letterSpacing: -1,
        ),
        displayMedium: GoogleFonts.dmSans(
          fontSize: 40,
          fontWeight: FontWeight.w200,
          color: AppColors.text,
          letterSpacing: -0.5,
        ),
        headlineLarge: GoogleFonts.dmSans(
          fontSize: 32,
          fontWeight: FontWeight.w200,
          color: AppColors.text,
        ),
        headlineMedium: GoogleFonts.dmSans(
          fontSize: 24,
          fontWeight: FontWeight.w300,
          color: AppColors.text,
        ),
        titleLarge: GoogleFonts.dmSans(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: AppColors.text,
          letterSpacing: 0.3,
        ),
        titleMedium: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.text,
          letterSpacing: 0.2,
        ),
        bodyLarge: GoogleFonts.dmSans(
          fontSize: 15,
          fontWeight: FontWeight.w300,
          color: AppColors.text,
        ),
        bodyMedium: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w300,
          color: AppColors.text,
        ),
        bodySmall: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: AppColors.grey,
          letterSpacing: 1.2,
        ),
        labelSmall: GoogleFonts.dmSans(
          fontSize: 9,
          fontWeight: FontWeight.w500,
          color: AppColors.grey,
          letterSpacing: 1.8,
        ),
      );
}
