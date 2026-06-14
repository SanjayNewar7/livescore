import 'package:flutter/material.dart';

class AppTheme {
  // Colors
  static const Color primaryBlue = Color(0xFF007AFF);
  static const Color darkBlue = Color(0xFF0055B3);
  static const Color lightBlue = Color(0xFFE3F2FD);
  static const Color pureBlack = Color(0xFF000000);
  static const Color darkGray = Color(0xFF1C1C1E);
  static const Color mediumGray = Color(0xFF3A3A3C);
  static const Color lightGray = Color(0xFF8E8E93);
  static const Color extraLightGray = Color(0xFFF2F2F7);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color successGreen = Color(0xFF00C853);
  static const Color dangerRed = Color(0xFFD32F2F);
  static const Color liveRed = Color(0xFFFF3B30);
  static const Color warningOrange = Color(0xFFFF9500);

  // Light Theme
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: extraLightGray,
    primaryColor: primaryBlue,
    colorScheme: const ColorScheme.light(
      primary: primaryBlue,
      secondary: primaryBlue,
      surface: pureWhite,
      error: dangerRed,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: pureWhite,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: pureBlack,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        fontFamily: 'SportFont',
      ),
      iconTheme: IconThemeData(color: pureBlack),
    ),
    cardTheme: CardThemeData(
      color: pureWhite,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: pureBlack,
        fontSize: 48,
        fontWeight: FontWeight.w900,
        fontFamily: 'SportFont',
      ),
      displayMedium: TextStyle(
        color: pureBlack,
        fontSize: 32,
        fontWeight: FontWeight.w800,
        fontFamily: 'SportFont',
      ),
      displaySmall: TextStyle(
        color: pureBlack,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        fontFamily: 'SportFont',
      ),
      headlineMedium: TextStyle(
        color: pureBlack,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        fontFamily: 'SportFont',
      ),
      titleLarge: TextStyle(
        color: pureBlack,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        fontFamily: 'SportFont',
      ),
      titleMedium: TextStyle(
        color: pureBlack,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        fontFamily: 'SportFont',
      ),
      bodyLarge: TextStyle(
        color: pureBlack,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        fontFamily: 'SportFont',
      ),
      bodyMedium: TextStyle(
        color: lightGray,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        fontFamily: 'SportFont',
      ),
      bodySmall: TextStyle(
        color: lightGray,
        fontSize: 12,
        fontWeight: FontWeight.w300,
        fontFamily: 'SportFont',
      ),
      labelLarge: TextStyle(
        color: primaryBlue,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        fontFamily: 'SportFont',
      ),
      labelSmall: TextStyle(
        color: lightGray,
        fontSize: 10,
        fontWeight: FontWeight.w300,
        fontFamily: 'SportFont',
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: pureWhite,
      selectedItemColor: primaryBlue,
      unselectedItemColor: lightGray,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: extraLightGray,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      hintStyle: const TextStyle(color: lightGray),
    ),
  );

  // Dark Theme
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: pureBlack,
    primaryColor: primaryBlue,
    colorScheme: const ColorScheme.dark(
      primary: primaryBlue,
      secondary: primaryBlue,
      surface: darkGray,
      error: dangerRed,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: pureBlack,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: pureWhite,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        fontFamily: 'SportFont',
      ),
      iconTheme: IconThemeData(color: pureWhite),
    ),
    cardTheme: CardThemeData(
      color: darkGray,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: pureWhite,
        fontSize: 48,
        fontWeight: FontWeight.w900,
        fontFamily: 'SportFont',
      ),
      displayMedium: TextStyle(
        color: pureWhite,
        fontSize: 32,
        fontWeight: FontWeight.w800,
        fontFamily: 'SportFont',
      ),
      displaySmall: TextStyle(
        color: pureWhite,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        fontFamily: 'SportFont',
      ),
      headlineMedium: TextStyle(
        color: pureWhite,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        fontFamily: 'SportFont',
      ),
      titleLarge: TextStyle(
        color: pureWhite,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        fontFamily: 'SportFont',
      ),
      titleMedium: TextStyle(
        color: pureWhite,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        fontFamily: 'SportFont',
      ),
      bodyLarge: TextStyle(
        color: pureWhite,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        fontFamily: 'SportFont',
      ),
      bodyMedium: TextStyle(
        color: lightGray,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        fontFamily: 'SportFont',
      ),
      bodySmall: TextStyle(
        color: lightGray,
        fontSize: 12,
        fontWeight: FontWeight.w300,
        fontFamily: 'SportFont',
      ),
      labelLarge: TextStyle(
        color: primaryBlue,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        fontFamily: 'SportFont',
      ),
      labelSmall: TextStyle(
        color: lightGray,
        fontSize: 10,
        fontWeight: FontWeight.w300,
        fontFamily: 'SportFont',
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: darkGray,
      selectedItemColor: primaryBlue,
      unselectedItemColor: lightGray,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkGray,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      hintStyle: const TextStyle(color: lightGray),
    ),
  );
}