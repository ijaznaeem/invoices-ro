import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Icon-only create button used on each main tab.
class LedgerFab extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const LedgerFab({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: LedgerColors.primary.withValues(alpha: 0.32),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: LedgerColors.primary,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 56,
              height: 56,
              child: Icon(icon, color: Colors.white, size: 26),
            ),
          ),
        ),
      ),
    );
  }
}
