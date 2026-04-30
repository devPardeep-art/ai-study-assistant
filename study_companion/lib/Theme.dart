import 'package:flutter/material.dart';

/* ─── DESIGN TOKENS ─── */
const kBg = Color(0xFFF8FAFC);
const kSurface = Color(0xFFFFFFFF);
const kSurface2 = Color(0xFFF1F5F9);
const kAccent = Color(0xFF4338CA);
const kAccent2 = Color(0xFF10B981);
const kAccentLight = Color(0xFFEEF2FF);
const kIndigoDark = Color(0xFF1E1B4B);
const kAmber = Color(0xFFF59E0B);
const kRed = Color(0xFFEF4444);
const kText = Color(0xFF1E293B);
const kText2 = Color(0xFF64748B);
const kBorder = Color(0xFFE2E8F0);

/* ─── TYPOGRAPHY ─── */
const kTitle = TextStyle(
  fontSize: 26,
  fontWeight: FontWeight.w900,
  color: kIndigoDark,
  letterSpacing: -0.5,
);

const kSubtitle = TextStyle(
  fontSize: 14,
  color: kText2,
  fontWeight: FontWeight.w500,
);

const kBody = TextStyle(
  fontSize: 15,
  color: kText,
  height: 1.6,
);

const kLabel = TextStyle(
  fontSize: 12,
  color: kAccent,
  fontWeight: FontWeight.w800,
  letterSpacing: 1.2,
);

const kBaseUrl = 'http://192.168.1.85:8000';

/* ─── CORE THEME ─── */
ThemeData appTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: kBg,
    colorScheme: const ColorScheme.light(
      primary: kAccent,
      secondary: kIndigoDark,
      surface: kSurface,
      onSurface: kIndigoDark,
      error: kRed,
    ),
    fontFamily: 'Inter',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: kIndigoDark,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
      iconTheme: IconThemeData(color: kIndigoDark),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kIndigoDark,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurface,
      hintStyle: const TextStyle(color: kText2, fontSize: 14),
      contentPadding: const EdgeInsets.all(20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: kAccent, width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      color: kSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: kBorder, width: 1),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: kSurface,
      selectedItemColor: kAccent,
      unselectedItemColor: kText2,
      type: BottomNavigationBarType.fixed,
      elevation: 20,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: kIndigoDark,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}