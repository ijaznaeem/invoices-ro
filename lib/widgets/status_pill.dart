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
            foreground: Color(0xFF2563EB),
            background: Color(0xFFEFF6FF));
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

  const EmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: LedgerColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 28, color: LedgerColors.primary),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(subtitle,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
