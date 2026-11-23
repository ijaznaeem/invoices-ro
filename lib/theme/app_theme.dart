import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LedgerColors {
  static const primary = Color(0xFF6C63FF);
  static const secondary = Color(0xFF2EC4B6);
  static const accent = Color(0xFFFF6B81);
  static const sky = Color(0xFF5A4CFD);
  static const amber = Color(0xFFFFB547);
  static const orange = Color(0xFFFF9F43);
  static const teal = Color(0xFF2EC4B6);
  static const background = Color(0xFFF5F6FF);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF2C2940);
  static const textSecondary = Color(0xFF8B879E);
  static const border = Color(0xFFE7E3F2);
  static const error = Color(0xFFFF5C7C);
  static const inactive = Color(0xFFB7B3C7);
  static const gradientStart = Color(0xFFF7F5FC);

  static const ink = textPrimary;
  static const inkStrong = primary;
  static const paper = background;
  static const paperRaised = surface;
  static const rule = border;
  static const brass = amber;
  static const brassBg = Color(0xFFFFF6E8);
  static const overdue = error;
  static const overdueBg = Color(0xFFFFEEF2);
  static const paid = Color(0xFF1FA971);
  static const paidBg = Color(0xFFE8F8F1);
  static const muted = textSecondary;

  static const darkPaper = Color(0xFF14121C);
  static const darkPaperRaised = Color(0xFF221F2E);
  static const darkRule = Color(0xFF322E42);
  static const darkInk = Color(0xFFF4F2FA);
  static const darkMuted = Color(0xFFB7B3C9);
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
          Color(0xFF1C1830),
          LedgerColors.darkPaper,
          Color(0xFF121018),
        ],
      ),
    );
  }

  static AppBar screenBar(String title, {List<Widget>? actions}) {
    return AppBar(
      backgroundColor: LedgerColors.primary,
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      title: Text(title),
      actions: actions,
    );
  }

  static BoxDecoration cardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? LedgerColors.darkPaperRaised : LedgerColors.surface,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF5C4DFF).withValues(alpha: isDark ? 0.12 : 0.06),
          blurRadius: 24,
          offset: const Offset(0, 10),
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
        scrolledUnderElevation: 0,
        backgroundColor: LedgerColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: LedgerColors.textPrimary,
        centerTitle: true,
        toolbarHeight: 64,
        iconTheme: const IconThemeData(color: LedgerColors.primary),
        titleTextStyle: GoogleFonts.roboto(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: LedgerColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: LedgerColors.surface,
        elevation: 2,
        shadowColor: const Color(0x1A5C4DFF),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: LedgerColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: GoogleFonts.roboto(
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
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: GoogleFonts.roboto(
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
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: GoogleFonts.roboto(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: LedgerColors.primary,
          textStyle: GoogleFonts.roboto(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: LedgerColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        extendedTextStyle: TextStyle(fontWeight: FontWeight.w700),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 68,
        backgroundColor: LedgerColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? LedgerColors.primary : LedgerColors.inactive,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.roboto(
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
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: LedgerColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: LedgerColors.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: LedgerColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: LedgerColors.error, width: 1.4),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: LedgerColors.surface,
        selectedColor: LedgerColors.primary.withValues(alpha: 0.12),
        checkmarkColor: LedgerColors.primary,
        labelStyle: GoogleFonts.roboto(
          color: LedgerColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: GoogleFonts.roboto(
          color: LedgerColors.primary,
          fontWeight: FontWeight.w700,
        ),
        side: const BorderSide(color: LedgerColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: LedgerColors.primary,
        textColor: LedgerColors.textPrimary,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(9)),
        ),
      ),
      dividerTheme:
          const DividerThemeData(color: LedgerColors.border, space: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: LedgerColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: LedgerColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: LedgerColors.textPrimary,
        contentTextStyle: GoogleFonts.roboto(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: LedgerColors.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF8B7CFF),
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
        scrolledUnderElevation: 0,
        backgroundColor: LedgerColors.darkPaper,
        surfaceTintColor: Colors.transparent,
        foregroundColor: LedgerColors.darkInk,
        centerTitle: true,
        toolbarHeight: 64,
        iconTheme: const IconThemeData(color: Color(0xFF8B7CFF)),
        titleTextStyle: GoogleFonts.roboto(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: LedgerColors.darkInk,
        ),
      ),
      cardTheme: CardThemeData(
        color: LedgerColors.darkPaperRaised,
        elevation: 1,
        shadowColor: Colors.black,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: LedgerColors.darkPaperRaised,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Color(0xFF8B7CFF),
        textColor: LedgerColors.darkInk,
        selectedColor: Color(0xFFB7ADFF),
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(9)),
        ),
      ),
      inputDecorationTheme: light().inputDecorationTheme.copyWith(
            fillColor: LedgerColors.darkPaperRaised,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
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
          headlineSmall: GoogleFonts.roboto(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: ink,
          ),
          titleLarge: GoogleFonts.roboto(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
          titleMedium: GoogleFonts.roboto(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
          bodyMedium: GoogleFonts.roboto(fontSize: 14, color: ink),
          bodySmall: GoogleFonts.roboto(fontSize: 12.5, color: muted),
          labelLarge: GoogleFonts.roboto(fontWeight: FontWeight.w700),
        )
        .apply(fontFamily: GoogleFonts.roboto().fontFamily);
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
