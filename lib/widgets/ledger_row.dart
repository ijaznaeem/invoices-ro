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

/// Compact transaction-style row inspired by the bKash card list.
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
      borderRadius: BorderRadius.circular(9),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: .7),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.09),
              blurRadius: 14,
              offset: const Offset(2, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(8, 9, 12, 9),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _tickColor(tick).withValues(alpha: .11),
                shape: BoxShape.circle,
              ),
              child: Icon(
                switch (tick) {
                  LedgerTick.paid => Icons.check_rounded,
                  LedgerTick.pending => Icons.schedule_rounded,
                  LedgerTick.overdue => Icons.priority_high_rounded,
                  LedgerTick.neutral => Icons.receipt_long_rounded,
                },
                color: _tickColor(tick),
                size: 25,
              ),
            ),
            const SizedBox(width: 10),
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
                    const SizedBox(height: 2),
                  ],
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
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
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
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
