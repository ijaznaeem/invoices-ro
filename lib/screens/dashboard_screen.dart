import 'package:flutter/material.dart';

import '../state/app_state_scope.dart';
import '../theme/app_theme.dart';
import '../util/currency_utils.dart';
import '../util/date_utils.dart';
import '../widgets/ledger_row.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_pill.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return RefreshIndicator(
      onRefresh: () => state.reloadDashboard(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text('Today is ${formatDate(todayStr())}',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.7,
            children: [
              StatCard(label: 'Outstanding', value: money(state.outstanding)),
              StatCard(
                  label: 'Due this week',
                  value: '${state.dueThisWeek}',
                  valueColor: LedgerColors.brass),
              StatCard(
                  label: 'Overdue',
                  value: '${state.overdueCount}',
                  valueColor: LedgerColors.overdue),
              StatCard(
                  label: 'Active recurring',
                  value: '${state.activeTemplateCount}'),
            ],
          ),
          const SizedBox(height: 24),
          _SectionCard(
            title: 'Upcoming due dates',
            child: state.upcoming.isEmpty
                ? const EmptyState(
                    title: 'Nothing scheduled',
                    subtitle: 'Create a recurring invoice to see it here.',
                    icon: Icons.event_available_outlined,
                  )
                : Column(
                    children: state.upcoming
                        .map((t) => LedgerRow(
                              title: t.clientName ?? 'Client',
                              subtitle: frequencyLabel(t.frequency),
                              trailingFigure: formatDate(t.nextDueDate),
                            ))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Recent activity',
            child: state.notifications.isEmpty
                ? const EmptyState(
                    title: 'No activity yet',
                    subtitle: 'Generated invoices and reminders show up here.',
                    icon: Icons.notifications_none,
                  )
                : Column(
                    children: state.notifications
                        .take(8)
                        .map((n) => LedgerRow(
                              title: n.message,
                              subtitle: n.createdAt,
                              tick: n.isRead
                                  ? LedgerTick.neutral
                                  : LedgerTick.pending,
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: LedgerColors.primary.withValues(alpha: 0.04),
              border: const Border(
                bottom: BorderSide(color: LedgerColors.border),
              ),
            ),
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          child,
        ],
      ),
    );
  }
}
