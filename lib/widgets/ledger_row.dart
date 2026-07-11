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
      return LedgerColors.primary;
  }
}

/// A single ruled row — the ledger-book detail carried over from the web
/// app. A colored tick on the left signals status at a glance, a title +
/// subtitle sit in the middle, and a right-aligned monospace figure (an
/// amount or a date) closes the row like a real ledger column.
class LedgerRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? overline;
  final String? trailingFigure;
  final String? trailingSubtitle;
  final double? trailingWidth;
  final LedgerTick tick;
  final Widget? trailingWidget;
  final VoidCallback? onTap;

  const LedgerRow({
    super.key,
    required this.title,
    required this.subtitle,
    this.overline,
    this.trailingFigure,
    this.trailingSubtitle,
    this.trailingWidth,
    this.tick = LedgerTick.neutral,
    this.trailingWidget,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 42,
              decoration: BoxDecoration(
                color: _tickColor(tick),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (overline != null) ...[
                    Text(
                      overline!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                    ),
                    const SizedBox(height: 3),
                  ],
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (trailingFigure != null || trailingWidget != null)
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: SizedBox(
                  width: trailingWidth ?? 108,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (trailingWidget != null) ...[
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: trailingWidget!,
                        ),
                        if (trailingFigure != null) const SizedBox(height: 5),
                      ],
                      if (trailingFigure != null)
                        Text(
                          trailingFigure!,
                          style: AppTheme.mono(
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                        ),
                      if (trailingSubtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          trailingSubtitle!,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontSize: 11,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
