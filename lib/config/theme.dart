import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Theme configuration - equivalent to Tailwind config and globals.css

class AppTheme {
  // Colors - based on Tailwind default palette
  static const Color primaryColor = Color(0xFF3B82F6); // blue-500
  static const Color primaryDark = Color(0xFF1E40AF); // blue-800
  static const Color primaryLight = Color(0xFF93C5FD); // blue-300

  static const Color secondaryColor = Color(0xFF8B5CF6); // violet-500
  static const Color accentColor = Color(0xFF10B981); // green-500

  static const Color errorColor = Color(0xFFEF4444); // red-500
  static const Color warningColor = Color(0xFFF59E0B); // amber-500
  static const Color successColor = Color(0xFF10B981); // green-500

  // Light theme colors
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF9FAFB); // gray-50
  static const Color lightCardBackground = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE5E7EB); // gray-200

  // Dark theme colors
  static const Color darkBackground = Color(0xFF0F172A); // slate-900
  static const Color darkSurface = Color(0xFF1E293B); // slate-800
  static const Color darkCardBackground = Color(0xFF334155); // slate-700
  static const Color darkBorder = Color(0xFF475569); // slate-600

  // Text colors
  static const Color lightTextPrimary = Color(0xFF111827); // gray-900
  static const Color lightTextSecondary = Color(0xFF6B7280); // gray-500
  static const Color darkTextPrimary = Color(0xFFF9FAFB); // gray-50
  static const Color darkTextSecondary = Color(0xFF9CA3AF); // gray-400

  // Light Theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: lightBackground,

    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      error: errorColor,
      surface: lightSurface,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: lightTextPrimary,
      onError: Colors.white,
    ),

    textTheme: GoogleFonts.interTextTheme(
      const TextTheme(
        displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w400, color: lightTextPrimary),
        displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w400, color: lightTextPrimary),
        displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w400, color: lightTextPrimary),
        headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: lightTextPrimary),
        headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: lightTextPrimary),
        headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: lightTextPrimary),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: lightTextPrimary),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: lightTextPrimary),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: lightTextPrimary),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: lightTextPrimary),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: lightTextPrimary),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: lightTextSecondary),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: lightTextPrimary),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: lightTextPrimary),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: lightTextSecondary),
      ),
    ),

    cardTheme: CardThemeData(
      color: lightCardBackground,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: lightBorder, width: 1),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: lightBorder, width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: lightBorder, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: lightBorder, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: errorColor, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: lightCardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: lightBackground,
      foregroundColor: lightTextPrimary,
      elevation: 0,
      centerTitle: false,
    ),
  );

  // Dark Theme
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: darkBackground,

    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      error: errorColor,
      surface: darkSurface,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: darkTextPrimary,
      onError: Colors.white,
    ),

    textTheme: GoogleFonts.interTextTheme(
      const TextTheme(
        displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w400, color: darkTextPrimary),
        displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w400, color: darkTextPrimary),
        displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w400, color: darkTextPrimary),
        headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: darkTextPrimary),
        headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: darkTextPrimary),
        headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: darkTextPrimary),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: darkTextPrimary),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: darkTextPrimary),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: darkTextPrimary),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: darkTextPrimary),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: darkTextPrimary),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: darkTextSecondary),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: darkTextPrimary),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: darkTextPrimary),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: darkTextSecondary),
      ),
    ),

    cardTheme: CardThemeData(
      color: darkCardBackground,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: darkBorder, width: 1),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryLight,
        side: const BorderSide(color: darkBorder, width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: darkBorder, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: darkBorder, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: errorColor, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: darkCardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: darkBackground,
      foregroundColor: darkTextPrimary,
      elevation: 0,
      centerTitle: false,
    ),
  );
}

