import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class StatusPill extends StatelessWidget {
  final String label;
  final Color foreground;
  final Color background;

  const StatusPill({
    super.key,
    required this.label,
    required this.foreground,
    required this.background,
  });

  factory StatusPill.forInvoiceStatus(String status) {
    switch (status) {
      case 'Paid':
        return StatusPill(
            label: status,
            foreground: LedgerColors.paid,
            background: LedgerColors.paidBg);
      case 'Partial':
        return const StatusPill(
            label: 'Partial',
            foreground: LedgerColors.sky,
            background: Color(0xFFEEF2FF));
      case 'Overdue':
        return StatusPill(
            label: status,
            foreground: LedgerColors.overdue,
            background: LedgerColors.overdueBg);
      case 'Cancelled':
        return StatusPill(
            label: status,
            foreground: LedgerColors.muted,
            background: const Color(0xFFF1F5F9));
      default:
        return StatusPill(
            label: status,
            foreground: LedgerColors.brass,
            background: LedgerColors.brassBg);
    }
  }

  factory StatusPill.forTemplateStatus(String status) {
    switch (status) {
      case 'active':
        return StatusPill(
            label: 'ACTIVE',
            foreground: LedgerColors.paid,
            background: LedgerColors.paidBg);
      case 'paused':
        return StatusPill(
            label: 'PAUSED',
            foreground: LedgerColors.brass,
            background: LedgerColors.brassBg);
      default:
        return StatusPill(
            label: 'ENDED',
            foreground: LedgerColors.muted,
            background: const Color(0xFFF1F5F9));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTheme.mono(
            size: 10.5, weight: FontWeight.w700, color: foreground),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool embedded;

  const EmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.embedded = false,
  });

  /// Scrollable empty state that stays centered above a floating button.
  static Widget fill({
    required String title,
    required String subtitle,
    IconData icon = Icons.inbox_outlined,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: EmptyState(
                title: title,
                subtitle: subtitle,
                icon: icon,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: LedgerColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, size: 26, color: LedgerColors.primary),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
    if (embedded) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: content,
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 96),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: AppTheme.cardDecoration(context),
        child: content,
      ),
    );
  }
}
