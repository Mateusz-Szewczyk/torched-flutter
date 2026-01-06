import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Theme configuration - equivalent to Tailwind config and globals.css
// Colors converted from React frontend globals.css HSL values

class AppTheme {
  // ============================================================================
  // LIGHT THEME COLORS (from React globals.css :root)
  // ============================================================================
  // --background: 45 25% 96% → warm off-white
  static const Color lightBackground = Color(0xFFF7F5F0);
  // --foreground: 222.2 84% 4.9% → almost black
  static const Color lightForeground = Color(0xFF020817);

  // --muted: 45 15% 88%
  static const Color lightMuted = Color(0xFFE5E2DC);
  // --muted-foreground: 215.4 20% 42%
  static const Color lightMutedForeground = Color(0xFF566573);

  // --card: 45 25% 98%
  static const Color lightCard = Color(0xFFFAF9F6);
  // --card-foreground: 222.2 84% 4.9%
  static const Color lightCardForeground = Color(0xFF020817);

  // --popover: 45 30% 98%
  static const Color lightPopover = Color(0xFFFBFAF7);

  // --border: 45 25% 82%
  static const Color lightBorder = Color(0xFFD9D5CB);
  // --input: 45 25% 78%
  static const Color lightInput = Color(0xFFCFC9BD);

  // --primary: 222.2 47.4% 11.2% → dark blue
  static const Color lightPrimary = Color(0xFF0F172A);
  // --primary-foreground: 210 40% 98%
  static const Color lightPrimaryForeground = Color(0xFFF8FAFC);

  // --secondary: 45 30% 83%
  static const Color lightSecondary = Color(0xFFDDD7C9);
  // --accent: 45 30% 87%
  static const Color lightAccent = Color(0xFFE6E1D5);

  // --destructive: 0 84.2% 60.2%
  static const Color lightDestructive = Color(0xFFEF4444);
  // --ring: 215 25% 60%
  static const Color lightRing = Color(0xFF7A8FA3);

  // ============================================================================
  // DARK THEME COLORS (from React globals.css .dark)
  // ============================================================================
  // --background: 220 15% 7% → very dark blue-gray
  static const Color darkBackground = Color(0xFF0F1114);
  // --foreground: 210 40% 92% → light blue-gray
  static const Color darkForeground = Color(0xFFE1E8EF);

  // --muted: 220 15% 10%
  static const Color darkMuted = Color(0xFF161A1E);
  // --muted-foreground: 215 25% 65%
  static const Color darkMutedForeground = Color(0xFF8FA4B8);

  // --card: 220 15% 6% → very dark, almost black
  static const Color darkCard = Color(0xFF0D0F12);
  // --card-foreground: 210 40% 94%
  static const Color darkCardForeground = Color(0xFFE8EEF4);

  // --popover: 220 15% 4%
  static const Color darkPopover = Color(0xFF090A0C);

  // --border: 220 15% 18%
  static const Color darkBorder = Color(0xFF262C33);
  // --input: 220 15% 20%
  static const Color darkInput = Color(0xFF2B323A);

  // --primary: 210 15% 92% → light gray (inverted for dark mode)
  static const Color darkPrimary = Color(0xFFE5E9ED);
  // --primary-foreground: 222.2 47.4% 11.2%
  static const Color darkPrimaryForeground = Color(0xFF0F172A);

  // --secondary: 220 15% 10%
  static const Color darkSecondary = Color(0xFF161A1E);
  // --accent: 220 15% 10%
  static const Color darkAccent = Color(0xFF161A1E);

  // --destructive: 0 62.8% 30.6% → darker red for dark mode
  static const Color darkDestructive = Color(0xFF7F1D1D);
  // --destructive-foreground: 0 85.7% 97.3%
  static const Color darkDestructiveForeground = Color(0xFFFEE2E2);

  // --ring: 220 15% 18%
  static const Color darkRing = Color(0xFF262C33);

  // ============================================================================
  // ACCENT COLORS (shared)
  // ============================================================================
  static const Color accentBlue = Color(0xFF3B82F6);    // blue-500
  static const Color accentViolet = Color(0xFF8B5CF6);  // violet-500
  static const Color accentGreen = Color(0xFF10B981);   // green-500 (success)
  static const Color accentAmber = Color(0xFFF59E0B);   // amber-500 (warning)
  static const Color accentRed = Color(0xFFEF4444);     // red-500 (error)

  // ============================================================================
  // ORANGE BRAND COLORS (Primary accent for TorchED)
  // ============================================================================
  static const Color brandOrange = Color(0xFFF97316);        // orange-500 - Main brand color
  static const Color brandOrangeLight = Color(0xFFFB923C);   // orange-400 - Lighter variant
  static const Color brandOrangeDark = Color(0xFFEA580C);    // orange-600 - Darker variant
  static const Color brandOrangeSubtle = Color(0xFFFED7AA);  // orange-200 - Very light for backgrounds
  static const Color brandOrangeMuted = Color(0xFFFFEDD5);   // orange-100 - Subtle background
  static const Color brandOrangeDeep = Color(0xFFC2410C);    // orange-700 - Deep orange for dark mode
  static const Color brandOrangeOnDark = Color(0xFFFDBA74);  // orange-300 - For dark mode text/icons

  // Theme-specific orange variants
  static const Color brandOrangeLightTheme = Color(0xFFEA580C);  // Darker orange for light mode (orange-600)
  static const Color brandOrangeDarkTheme = Color(0xFFe66f32);  // Lighter orange for dark mode

  // ============================================================================
  // LIGHT THEME
  // ============================================================================
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: lightPrimary,
    scaffoldBackgroundColor: lightBackground,

    colorScheme: const ColorScheme.light(
      primary: lightPrimary,
      onPrimary: lightPrimaryForeground,
      primaryContainer: lightAccent,
      onPrimaryContainer: lightForeground,
      secondary: lightSecondary,
      onSecondary: lightForeground,
      secondaryContainer: lightMuted,
      onSecondaryContainer: lightMutedForeground,
      tertiary: brandOrangeLightTheme,
      onTertiary: Colors.white,
      tertiaryContainer: brandOrangeMuted,
      onTertiaryContainer: brandOrangeDeep,
      error: lightDestructive,
      onError: Colors.white,
      surface: lightCard,
      onSurface: lightForeground,
      surfaceContainerLowest: lightBackground,
      surfaceContainerLow: lightPopover,
      surfaceContainer: lightCard,
      surfaceContainerHigh: lightMuted,
      surfaceContainerHighest: lightSecondary,
      outline: lightBorder,
      outlineVariant: lightInput,
    ),

    textTheme: GoogleFonts.interTextTheme(
      const TextTheme(
        displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w400, color: lightForeground),
        displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w400, color: lightForeground),
        displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w400, color: lightForeground),
        headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: lightForeground),
        headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: lightForeground),
        headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: lightForeground),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: lightForeground),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: lightForeground),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: lightForeground),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: lightForeground),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: lightForeground),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: lightMutedForeground),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: lightForeground),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: lightForeground),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: lightMutedForeground),
      ),
    ),

    cardTheme: CardThemeData(
      color: lightCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: lightBorder, width: 1),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: brandOrangeLightTheme,
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

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: brandOrangeLightTheme,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: brandOrangeLightTheme,
        side: BorderSide(color: brandOrangeLightTheme, width: 1.5),
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
        borderSide: BorderSide(color: brandOrangeLightTheme, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: lightDestructive, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      hintStyle: TextStyle(color: lightMutedForeground),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: lightCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: lightBackground,
      foregroundColor: lightForeground,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    ),

    dividerTheme: const DividerThemeData(
      color: lightBorder,
      thickness: 1,
    ),

    chipTheme: ChipThemeData(
      backgroundColor: lightMuted,
      selectedColor: brandOrangeLightTheme,
      labelStyle: const TextStyle(color: lightForeground),
      secondarySelectedColor: brandOrangeSubtle,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),

    tabBarTheme: const TabBarThemeData(
      labelColor: brandOrangeLightTheme,
      unselectedLabelColor: lightMutedForeground,
      indicatorColor: brandOrangeLightTheme,
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: lightForeground,
      contentTextStyle: const TextStyle(color: lightBackground),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      behavior: SnackBarBehavior.floating,
    ),

    // Light theme floating action button
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: brandOrangeLightTheme,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: CircleBorder(),
    ),

    // Light theme progress indicator
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: brandOrangeLightTheme,
      linearTrackColor: brandOrangeMuted,
      circularTrackColor: brandOrangeMuted,
    ),

    // Light theme slider
    sliderTheme: SliderThemeData(
      activeTrackColor: brandOrangeLightTheme,
      inactiveTrackColor: brandOrangeSubtle,
      thumbColor: brandOrangeLightTheme,
      overlayColor: brandOrangeLightTheme.withValues(alpha: 0.2),
    ),

    // Light theme switch
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return brandOrangeLightTheme;
        return lightMutedForeground;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return brandOrangeSubtle;
        return lightMuted;
      }),
    ),

    // Light theme checkbox
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return brandOrangeLightTheme;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(Colors.white),
      side: const BorderSide(color: lightBorder, width: 1.5),
    ),

    // Light theme radio
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return brandOrangeLightTheme;
        return lightMutedForeground;
      }),
    ),

    // Light theme badge
    badgeTheme: const BadgeThemeData(
      backgroundColor: brandOrangeLightTheme,
      textColor: Colors.white,
    ),
  );

  // ============================================================================
  // DARK THEME
  // ============================================================================
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: darkPrimary,
    scaffoldBackgroundColor: darkBackground,

    colorScheme: const ColorScheme.dark(
      primary: darkPrimary,
      onPrimary: darkPrimaryForeground,
      primaryContainer: darkAccent,
      onPrimaryContainer: darkForeground,
      secondary: darkSecondary,
      onSecondary: darkForeground,
      secondaryContainer: darkMuted,
      onSecondaryContainer: darkMutedForeground,
      tertiary: brandOrangeDarkTheme,
      onTertiary: Colors.white,
      tertiaryContainer: brandOrangeDeep,
      onTertiaryContainer: brandOrangeOnDark,
      error: darkDestructive,
      onError: darkDestructiveForeground,
      surface: darkCard,
      onSurface: darkForeground,
      surfaceContainerLowest: darkBackground,
      surfaceContainerLow: darkPopover,
      surfaceContainer: darkCard,
      surfaceContainerHigh: darkMuted,
      surfaceContainerHighest: darkSecondary,
      outline: darkBorder,
      outlineVariant: darkInput,
    ),

    textTheme: GoogleFonts.interTextTheme(
      const TextTheme(
        displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w400, color: darkForeground),
        displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w400, color: darkForeground),
        displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w400, color: darkForeground),
        headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: darkForeground),
        headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: darkForeground),
        headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: darkForeground),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: darkForeground),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: darkForeground),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: darkForeground),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: darkForeground),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: darkForeground),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: darkMutedForeground),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: darkForeground),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: darkForeground),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: darkMutedForeground),
      ),
    ),

    cardTheme: CardThemeData(
      color: darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: darkBorder, width: 1),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: brandOrangeDarkTheme,
        foregroundColor: Colors.black,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: brandOrangeDarkTheme,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: brandOrangeDarkTheme,
        side: const BorderSide(color: brandOrangeDarkTheme, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkMuted,
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
        borderSide: const BorderSide(color: brandOrangeDarkTheme, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: darkDestructive, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      hintStyle: TextStyle(color: darkMutedForeground),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: darkCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: darkBackground,
      foregroundColor: darkForeground,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    ),

    dividerTheme: const DividerThemeData(
      color: darkBorder,
      thickness: 1,
    ),

    chipTheme: ChipThemeData(
      backgroundColor: darkMuted,
      selectedColor: brandOrangeDarkTheme,
      labelStyle: TextStyle(color: darkForeground),
      secondarySelectedColor: brandOrangeDeep,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),

    tabBarTheme: const TabBarThemeData(
      labelColor: brandOrangeDarkTheme,
      unselectedLabelColor: darkMutedForeground,
      indicatorColor: brandOrangeDarkTheme,
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: darkForeground,
      contentTextStyle: TextStyle(color: darkBackground),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      behavior: SnackBarBehavior.floating,
    ),

    // Scrollbar styling
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.all(darkBorder),
      trackColor: WidgetStateProperty.all(darkMuted),
      radius: const Radius.circular(3),
      thickness: WidgetStateProperty.all(6),
    ),

    // Bottom sheet
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: darkCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),

    // Popup menu
    popupMenuTheme: PopupMenuThemeData(
      color: darkPopover,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: darkBorder),
      ),
    ),

    // Tooltip
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: darkForeground,
        borderRadius: BorderRadius.circular(4),
      ),
      textStyle: TextStyle(color: darkBackground, fontSize: 12),
    ),

    // Dark theme floating action button
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: brandOrangeDarkTheme,
      foregroundColor: Colors.black,
      elevation: 4,
      shape: CircleBorder(),
    ),

    // Dark theme progress indicator
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: brandOrangeDarkTheme,
      linearTrackColor: brandOrangeDeep,
      circularTrackColor: brandOrangeDeep,
    ),

    // Dark theme slider
    sliderTheme: SliderThemeData(
      activeTrackColor: brandOrangeDarkTheme,
      inactiveTrackColor: brandOrangeDeep,
      thumbColor: brandOrangeDarkTheme,
      overlayColor: brandOrangeDarkTheme.withValues(alpha: 0.2),
    ),

    // Dark theme switch
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return brandOrangeDarkTheme;
        return darkMutedForeground;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return brandOrangeDeep;
        return darkMuted;
      }),
    ),

    // Dark theme checkbox
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return brandOrangeDarkTheme;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(Colors.black),
      side: const BorderSide(color: darkBorder, width: 1.5),
    ),

    // Dark theme radio
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return brandOrangeDarkTheme;
        return darkMutedForeground;
      }),
    ),

    // Dark theme badge
    badgeTheme: const BadgeThemeData(
      backgroundColor: brandOrangeDarkTheme,
      textColor: Colors.black,
    ),
  );
}

