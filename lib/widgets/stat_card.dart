import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(context),
      child: Stack(
        children: [
          Positioned(
            right: -12,
            top: -15,
            child: Container(
              width: 65,
              height: 65,
              decoration: BoxDecoration(
                color:
                    (valueColor ?? LedgerColors.primary).withValues(alpha: .09),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const Spacer(),
                Text(
                  value,
                  style: AppTheme.mono(
                    size: 21,
                    color: valueColor ?? LedgerColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
