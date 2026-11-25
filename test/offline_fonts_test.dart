import 'dart:ui' show FontWeight;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:invoices_ro/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('app themes load bundled fonts with runtime downloads disabled',
      () async {
    GoogleFonts.config.allowRuntimeFetching = false;
    AppTheme.light();
    AppTheme.dark();
    AppTheme.mono();
    AppTheme.mono(weight: FontWeight.w500);
    await GoogleFonts.pendingFonts();
  });
}
