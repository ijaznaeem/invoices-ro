import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LedgerColors {
  static const primary = Color(0xFF2563EB);
  static const secondary = Color(0xFF10B981);
  static const accent = Color(0xFFF59E0B);
  static const background = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const error = Color(0xFFEF4444);
  static const inactive = Color(0xFF94A3B8);
  static const gradientStart = Color(0xFFEEF5FF);

  static const ink = textPrimary;
  static const inkStrong = primary;
  static const paper = background;
  static const paperRaised = surface;
  static const rule = border;
  static const brass = accent;
  static const brassBg = Color(0xFFFFF7E6);
  static const overdue = error;
  static const overdueBg = Color(0xFFFFEEEE);
  static const paid = secondary;
  static const paidBg = Color(0xFFEAFBF4);
  static const muted = textSecondary;

  static const darkPaper = Color(0xFF0F172A);
  static const darkPaperRaised = Color(0xFF111827);
  static const darkRule = Color(0xFF263244);
  static const darkInk = Color(0xFFF8FAFC);
  static const darkMuted = Color(0xFFCBD5E1);
}

class AppTheme {
  static const gradientDecoration = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        LedgerColors.gradientStart,
        LedgerColors.background,
        Colors.white,
      ],
    ),
  );

  static BoxDecoration backgroundDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) return gradientDecoration;
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF111827),
          LedgerColors.darkPaper,
          Color(0xFF0B1120),
        ],
      ),
    );
  }

  static BoxDecoration cardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? LedgerColors.darkPaperRaised : LedgerColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isDark ? LedgerColors.darkRule : LedgerColors.border,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: LedgerColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: LedgerColors.primary,
      secondary: LedgerColors.secondary,
      tertiary: LedgerColors.accent,
      error: LedgerColors.error,
      surface: LedgerColors.surface,
      onSurface: LedgerColors.textPrimary,
      outline: LedgerColors.border,
    );
    final textTheme = _textTheme(
      base.textTheme,
      LedgerColors.textPrimary,
      LedgerColors.textSecondary,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: LedgerColors.background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: LedgerColors.textPrimary,
        centerTitle: false,
        iconTheme: const IconThemeData(color: LedgerColors.textPrimary),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: LedgerColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: LedgerColors.surface,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: LedgerColors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: LedgerColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: LedgerColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: LedgerColors.textPrimary,
          minimumSize: const Size(double.infinity, 54),
          side: const BorderSide(color: Color(0xFFCBD5E1)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: LedgerColors.primary,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: LedgerColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        extendedTextStyle: TextStyle(fontWeight: FontWeight.w700),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 20,
        height: 72,
        backgroundColor: LedgerColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: LedgerColors.primary.withValues(alpha: 0.10),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? LedgerColors.primary : LedgerColors.inactive,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? LedgerColors.primary : LedgerColors.inactive,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: LedgerColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        hintStyle: const TextStyle(color: LedgerColors.inactive),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: LedgerColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: LedgerColors.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: LedgerColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: LedgerColors.error, width: 1.4),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: LedgerColors.surface,
        selectedColor: LedgerColors.primary.withValues(alpha: 0.12),
        checkmarkColor: LedgerColors.primary,
        labelStyle: GoogleFonts.inter(
          color: LedgerColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: GoogleFonts.inter(
          color: LedgerColors.primary,
          fontWeight: FontWeight.w700,
        ),
        side: const BorderSide(color: LedgerColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: LedgerColors.primary,
        textColor: LedgerColors.textPrimary,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      dividerTheme:
          const DividerThemeData(color: LedgerColors.border, space: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: LedgerColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: LedgerColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: LedgerColors.textPrimary,
        contentTextStyle: GoogleFonts.inter(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: LedgerColors.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF60A5FA),
      secondary: LedgerColors.secondary,
      tertiary: LedgerColors.accent,
      error: LedgerColors.error,
      surface: LedgerColors.darkPaperRaised,
      onSurface: LedgerColors.darkInk,
      outline: LedgerColors.darkRule,
    );
    final textTheme = _textTheme(
        base.textTheme, LedgerColors.darkInk, LedgerColors.darkMuted);

    return light().copyWith(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: LedgerColors.darkPaper,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: LedgerColors.darkInk,
        centerTitle: false,
        iconTheme: const IconThemeData(color: LedgerColors.darkInk),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: LedgerColors.darkInk,
        ),
      ),
      cardTheme: CardThemeData(
        color: LedgerColors.darkPaperRaised,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: LedgerColors.darkRule),
        ),
      ),
      inputDecorationTheme: light().inputDecorationTheme.copyWith(
            fillColor: LedgerColors.darkPaperRaised,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: LedgerColors.darkRule),
            ),
          ),
      dividerTheme:
          const DividerThemeData(color: LedgerColors.darkRule, space: 1),
    );
  }

  static TextTheme _textTheme(TextTheme base, Color ink, Color muted) {
    return base
        .copyWith(
          headlineSmall: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: ink,
          ),
          titleLarge: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
          titleMedium: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
          bodyMedium: GoogleFonts.inter(fontSize: 14, color: ink),
          bodySmall: GoogleFonts.inter(fontSize: 12.5, color: muted),
          labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w700),
        )
        .apply(fontFamily: GoogleFonts.inter().fontFamily);
  }

  static TextStyle mono({
    double size = 14,
    FontWeight weight = FontWeight.w700,
    Color? color,
  }) =>
      GoogleFonts.ibmPlexMono(
        fontSize: size,
        fontWeight: weight,
        color: color,
      );
}
