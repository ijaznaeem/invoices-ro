import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const StatCard({super.key, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(letterSpacing: 0.6),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTheme.mono(size: 22, color: valueColor ?? Theme.of(context).textTheme.titleLarge?.color),
            ),
          ],
        ),
      ),
    );
  }
}
