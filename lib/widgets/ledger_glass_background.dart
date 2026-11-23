import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Quiet wallpaper: a fine dot grid and soft corner light, kept behind content.
class LedgerGlassBackground extends StatelessWidget {
  const LedgerGlassBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: AppTheme.backgroundDecoration(context),
      child: CustomPaint(
        painter: _LedgerBackdropPainter(isDark: isDark),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _LedgerBackdropPainter extends CustomPainter {
  final bool isDark;
  const _LedgerBackdropPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    _dots(canvas, size);
    _wash(
      canvas,
      Offset(size.width + 30, -20),
      150,
      LedgerColors.primary.withValues(alpha: isDark ? 0.16 : 0.09),
    );
    _wash(
      canvas,
      Offset(-30, size.height * 0.72),
      130,
      LedgerColors.teal.withValues(alpha: isDark ? 0.12 : 0.07),
    );
    _wash(
      canvas,
      Offset(size.width * 0.15, size.height + 10),
      110,
      LedgerColors.accent.withValues(alpha: isDark ? 0.10 : 0.05),
    );
  }

  void _dots(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? Colors.white : LedgerColors.primary)
          .withValues(alpha: isDark ? 0.035 : 0.045);
    const gap = 28.0;
    for (var y = gap; y < size.height; y += gap) {
      for (var x = gap; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), 0.8, paint);
      }
    }
  }

  void _wash(Canvas canvas, Offset center, double radius, Color color) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 48),
    );
  }

  @override
  bool shouldRepaint(covariant _LedgerBackdropPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
