import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum LedgerTick { neutral, paid, pending, overdue }

Color _tickColor(LedgerTick tick) {
  switch (tick) {
    case LedgerTick.paid:
      return LedgerColors.paid;
    case LedgerTick.pending:
      return LedgerColors.brass;
    case LedgerTick.overdue:
      return LedgerColors.overdue;
    case LedgerTick.neutral:
      return LedgerColors.inkStrong;
  }
}

/// A single ruled row — the ledger-book detail carried over from the web
/// app. A colored tick on the left signals status at a glance, a title +
/// subtitle sit in the middle, and a right-aligned monospace figure (an
/// amount or a date) closes the row like a real ledger column.
class LedgerRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? trailingFigure;
  final LedgerTick tick;
  final Widget? trailingWidget;
  final VoidCallback? onTap;

  const LedgerRow({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailingFigure,
    this.tick = LedgerTick.neutral,
    this.trailingWidget,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: isDark ? LedgerColors.darkRule : LedgerColors.rule),
            left: BorderSide(color: _tickColor(tick), width: 4),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (trailingFigure != null)
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Text(trailingFigure!, style: AppTheme.mono(color: Theme.of(context).textTheme.bodyMedium?.color)),
              ),
            if (trailingWidget != null) Padding(padding: const EdgeInsets.only(left: 8), child: trailingWidget),
          ],
        ),
      ),
    );
  }
}
