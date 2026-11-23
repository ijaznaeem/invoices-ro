import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final IconData icon;
  final bool filled;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.icon = Icons.insights_rounded,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final tone = valueColor ?? LedgerColors.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!filled || isDark) {
      return Container(
        decoration: AppTheme.cardDecoration(context),
        padding: const EdgeInsets.all(16),
        child: _body(
          context,
          tone: tone,
          labelColor: Theme.of(context).textTheme.bodySmall?.color,
          valueColor: tone,
          iconBackground: tone.withValues(alpha: 0.14),
          iconColor: tone,
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: tone.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: _body(
        context,
        tone: tone,
        labelColor: Colors.white.withValues(alpha: 0.82),
        valueColor: Colors.white,
        iconBackground: Colors.white.withValues(alpha: 0.18),
        iconColor: Colors.white,
      ),
    );
  }

  Widget _body(
    BuildContext context, {
    required Color tone,
    required Color? labelColor,
    required Color valueColor,
    required Color iconBackground,
    required Color iconColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const Spacer(),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.mono(size: 18, color: valueColor),
        ),
      ],
    );
  }
}
