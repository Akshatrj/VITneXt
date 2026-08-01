import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color _seedColor = Color(0xFF006B5E);

  static ThemeData lightTheme({ColorScheme? dynamicLight}) {
    final colorScheme = dynamicLight ?? ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.background,
      textTheme: _textTheme(colorScheme.onBackground),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: colorScheme.onBackground,
        ),
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        color: colorScheme.surfaceVariant,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        filled: true,
        fillColor: colorScheme.surfaceVariant,
      ),
    );
  }

  static ThemeData darkTheme({ColorScheme? dynamicDark}) {
    final colorScheme = dynamicDark ?? ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    ).copyWith(
      background: Colors.black,
      surface: const Color(0xFF0A0A0A),
      surfaceVariant: const Color(0xFF121212),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.black,
      textTheme: _textTheme(Colors.white),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        color: const Color(0xFF121212),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: Colors.black,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        filled: true,
        fillColor: const Color(0xFF121212),
      ),
    );
  }

  static TextTheme _textTheme(Color color) {
    return TextTheme(
      displayLarge: GoogleFonts.outfit(color: color, fontWeight: FontWeight.bold),
      displayMedium: GoogleFonts.outfit(color: color, fontWeight: FontWeight.bold),
      displaySmall: GoogleFonts.outfit(color: color, fontWeight: FontWeight.bold),
      headlineLarge: GoogleFonts.outfit(color: color, fontWeight: FontWeight.w600),
      headlineMedium: GoogleFonts.outfit(color: color, fontWeight: FontWeight.w600),
      headlineSmall: GoogleFonts.outfit(color: color, fontWeight: FontWeight.w600),
      titleLarge: GoogleFonts.outfit(color: color, fontWeight: FontWeight.w600),
      titleMedium: GoogleFonts.inter(color: color, fontWeight: FontWeight.w600),
      titleSmall: GoogleFonts.inter(color: color, fontWeight: FontWeight.w600),
      bodyLarge: GoogleFonts.inter(color: color),
      bodyMedium: GoogleFonts.inter(color: color),
      bodySmall: GoogleFonts.inter(color: color),
      labelLarge: GoogleFonts.inter(color: color, fontWeight: FontWeight.w500),
      labelMedium: GoogleFonts.inter(color: color, fontWeight: FontWeight.w500),
      labelSmall: GoogleFonts.inter(color: color, fontWeight: FontWeight.w500),
    );
  }
}
