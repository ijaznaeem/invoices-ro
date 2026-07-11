import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ledger palette — shared across light and dark mode.
class LedgerColors {
  static const ink = Color(0xFF1F2A24);
  static const inkStrong = Color(0xFF1B3A2F);
  static const paper = Color(0xFFF5F6F1);
  static const paperRaised = Color(0xFFFFFFFF);
  static const rule = Color(0xFFCBD2C5);

  static const brass = Color(0xFFB8873D);
  static const brassBg = Color(0xFFFBF1DE);
  static const overdue = Color(0xFFAE423F);
  static const overdueBg = Color(0xFFFBE9E7);
  static const paid = Color(0xFF3F7D58);
  static const paidBg = Color(0xFFE7F1EA);
  static const muted = Color(0xFF6B7568);

  // Dark mode variants
  static const darkPaper = Color(0xFF141C17);
  static const darkPaperRaised = Color(0xFF1C2620);
  static const darkRule = Color(0xFF33403A);
  static const darkInk = Color(0xFFEAEFE9);
  static const darkMuted = Color(0xFF9BA79E);
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme =
        _textTheme(base.textTheme, LedgerColors.ink, LedgerColors.muted);
    return base.copyWith(
      scaffoldBackgroundColor: LedgerColors.paper,
      colorScheme: base.colorScheme.copyWith(
        primary: LedgerColors.inkStrong,
        secondary: LedgerColors.brass,
        error: LedgerColors.overdue,
        surface: LedgerColors.paperRaised,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: LedgerColors.inkStrong,
        foregroundColor: LedgerColors.paper,
        elevation: 0,
        titleTextStyle: GoogleFonts.fraunces(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: LedgerColors.paper,
        ),
      ),
      cardTheme: CardThemeData(
        color: LedgerColors.paperRaised,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: LedgerColors.rule),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: LedgerColors.inkStrong,
        foregroundColor: LedgerColors.paper,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: LedgerColors.paperRaised,
        indicatorColor: LedgerColors.paidBg,
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: LedgerColors.ink),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: LedgerColors.paper,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: LedgerColors.rule),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: LedgerColors.rule),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: LedgerColors.inkStrong, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(color: LedgerColors.rule, space: 1),
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = _textTheme(
        base.textTheme, LedgerColors.darkInk, LedgerColors.darkMuted);
    return base.copyWith(
      scaffoldBackgroundColor: LedgerColors.darkPaper,
      colorScheme: base.colorScheme.copyWith(
        primary: LedgerColors.paid,
        secondary: LedgerColors.brass,
        error: LedgerColors.overdue,
        surface: LedgerColors.darkPaperRaised,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: LedgerColors.darkPaperRaised,
        foregroundColor: LedgerColors.darkInk,
        elevation: 0,
        titleTextStyle: GoogleFonts.fraunces(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: LedgerColors.darkInk,
        ),
      ),
      cardTheme: CardThemeData(
        color: LedgerColors.darkPaperRaised,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: LedgerColors.darkRule),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: LedgerColors.paid,
        foregroundColor: Colors.white,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: LedgerColors.darkPaperRaised,
        indicatorColor: LedgerColors.paid.withValues(alpha: 0.25),
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: LedgerColors.darkInk),
        ),
      ),
      dividerTheme:
          const DividerThemeData(color: LedgerColors.darkRule, space: 1),
    );
  }

  static TextTheme _textTheme(TextTheme base, Color ink, Color muted) {
    return base
        .copyWith(
          headlineSmall: GoogleFonts.fraunces(
              fontSize: 24, fontWeight: FontWeight.w600, color: ink),
          titleLarge: GoogleFonts.fraunces(
              fontSize: 18, fontWeight: FontWeight.w600, color: ink),
          titleMedium: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w600, color: ink),
          bodyMedium: GoogleFonts.inter(fontSize: 14, color: ink),
          bodySmall: GoogleFonts.inter(fontSize: 12.5, color: muted),
          labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w600),
        )
        .apply(fontFamily: GoogleFonts.inter().fontFamily);
  }

  /// Monospace style for figures (amounts, dates, invoice numbers) — the
  /// ledger-book detail carried over from the web version.
  static TextStyle mono(
          {double size = 14,
          FontWeight weight = FontWeight.w600,
          Color? color}) =>
      GoogleFonts.ibmPlexMono(fontSize: size, fontWeight: weight, color: color);
}
