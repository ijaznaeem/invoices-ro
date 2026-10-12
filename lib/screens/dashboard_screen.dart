import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
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
    final upcomingItems = <({String date, String title, String subtitle})>[
      ...state.upcoming.map((t) => (
            date: t.nextDueDate,
            title: t.displayName,
            subtitle: 'Invoice · ${frequencyLabel(t.frequency)}',
          )),
      ...state.upcomingExpenses.map((t) => (
            date: t.nextDueDate,
            title: t.displayName,
            subtitle:
                'Expense · ${t.headName ?? 'Expense'} · ${frequencyLabel(t.frequency)}',
          )),
    ]..sort((a, b) => a.date.compareTo(b.date));

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          state.reloadDashboard(),
          state.reloadLedger(),
          state.reloadCashReceipts(),
          state.reloadExpenses(),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            monthTitle(DateTime.now()),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          Text(
            'This month',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: [
              StatCard(
                  label: 'Collected',
                  value: money(state.monthCollected),
                  valueColor: LedgerColors.paid),
              StatCard(
                  label: 'Spent',
                  value: money(state.monthSpent),
                  valueColor: LedgerColors.overdue),
              StatCard(
                  label: 'Left over',
                  value: money(state.monthNet),
                  valueColor: state.monthNet >= 0
                      ? LedgerColors.secondary
                      : LedgerColors.overdue),
              StatCard(label: 'Still owed', value: money(state.outstanding)),
            ],
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.1,
            children: [
              StatCard(
                  label: 'Overdue',
                  value: '${state.overdueCount}',
                  valueColor: LedgerColors.overdue),
              StatCard(
                  label: 'Due this week',
                  value: '${state.dueThisWeek}',
                  valueColor: LedgerColors.brass),
            ],
          ),
          const SizedBox(height: 18),
          _SectionCard(
            title: 'Revenue vs expenses',
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
              child: SizedBox(
                height: 220,
                child: _RevenueExpenseChart(
                  invoiced: state.monthlyInvoiced,
                  expenses: state.monthlyExpenses,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Invoice status',
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
              child: SizedBox(
                height: 200,
                child: _StatusPieChart(counts: state.invoiceStatusCounts),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Cash collected (6 months)',
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
              child: SizedBox(
                height: 180,
                child: _CashBarChart(series: state.monthlyCash),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Coming up',
            child: upcomingItems.isEmpty
                ? const EmptyState(
                    title: 'Nothing scheduled',
                    subtitle: 'Recurring invoices and expenses show up here.',
                    icon: Icons.event_available_outlined,
                  )
                : Column(
                    children: upcomingItems
                        .take(8)
                        .map((t) => LedgerRow(
                              title: t.title,
                              subtitle: t.subtitle,
                              trailingFigure: formatDate(t.date),
                            ))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Recent activity',
            child: state.notifications.isEmpty
                ? const EmptyState(
                    title: 'No activity yet',
                    subtitle: 'Generated invoices and payments show up here.',
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

class _RevenueExpenseChart extends StatelessWidget {
  final List<MonthlyAmount> invoiced;
  final List<MonthlyAmount> expenses;

  const _RevenueExpenseChart({
    required this.invoiced,
    required this.expenses,
  });

  @override
  Widget build(BuildContext context) {
    if (invoiced.isEmpty) {
      return const Center(child: Text('No data yet'));
    }
    final maxY = [
      ...invoiced.map((e) => e.amount),
      ...expenses.map((e) => e.amount),
      1.0,
    ].reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY * 1.15,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: LedgerColors.border.withValues(alpha: 0.7),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    getTitlesWidget: (value, meta) => Text(
                      value >= 1000
                          ? '${(value / 1000).toStringAsFixed(0)}k'
                          : value.toStringAsFixed(0),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= invoiced.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(invoiced[i].label,
                            style: const TextStyle(fontSize: 11)),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < invoiced.length; i++)
                      FlSpot(i.toDouble(), invoiced[i].amount),
                  ],
                  isCurved: true,
                  color: LedgerColors.primary,
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: LedgerColors.primary.withValues(alpha: 0.12),
                  ),
                ),
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < expenses.length; i++)
                      FlSpot(i.toDouble(), expenses[i].amount),
                  ],
                  isCurved: true,
                  color: LedgerColors.overdue,
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            _LegendDot(color: LedgerColors.primary, label: 'Invoiced'),
            SizedBox(width: 16),
            _LegendDot(color: LedgerColors.overdue, label: 'Expenses'),
          ],
        ),
      ],
    );
  }
}

class _StatusPieChart extends StatelessWidget {
  final Map<String, int> counts;
  const _StatusPieChart({required this.counts});

  @override
  Widget build(BuildContext context) {
    final pending = counts['Pending'] ?? 0;
    final partial = counts['Partial'] ?? 0;
    final paid = counts['Paid'] ?? 0;
    final cancelled = counts['Cancelled'] ?? 0;
    final overdue = counts['Overdue'] ?? 0;
    final total = pending + partial + paid + cancelled + overdue;
    if (total == 0) {
      return const Center(child: Text('No invoices yet'));
    }

    final sections = <PieChartSectionData>[
      if (pending > 0)
        PieChartSectionData(
          value: pending.toDouble(),
          color: LedgerColors.brass,
          title: '$pending',
          radius: 52,
          titleStyle: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      if (partial > 0)
        PieChartSectionData(
          value: partial.toDouble(),
          color: const Color(0xFF3B82F6),
          title: '$partial',
          radius: 52,
          titleStyle: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      if (overdue > 0)
        PieChartSectionData(
          value: overdue.toDouble(),
          color: LedgerColors.overdue,
          title: '$overdue',
          radius: 52,
          titleStyle: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      if (paid > 0)
        PieChartSectionData(
          value: paid.toDouble(),
          color: LedgerColors.paid,
          title: '$paid',
          radius: 52,
          titleStyle: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      if (cancelled > 0)
        PieChartSectionData(
          value: cancelled.toDouble(),
          color: LedgerColors.inactive,
          title: '$cancelled',
          radius: 52,
          titleStyle: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
        ),
    ];

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 34,
              sections: sections,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _LegendDot(color: LedgerColors.brass, label: 'Pending'),
            SizedBox(height: 6),
            _LegendDot(color: Color(0xFF3B82F6), label: 'Partial'),
            SizedBox(height: 6),
            _LegendDot(color: LedgerColors.overdue, label: 'Overdue'),
            SizedBox(height: 6),
            _LegendDot(color: LedgerColors.paid, label: 'Paid'),
            SizedBox(height: 6),
            _LegendDot(color: LedgerColors.inactive, label: 'Cancelled'),
          ],
        ),
      ],
    );
  }
}

class _CashBarChart extends StatelessWidget {
  final List<MonthlyAmount> series;
  const _CashBarChart({required this.series});

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) return const Center(child: Text('No cash data yet'));
    final maxY = [
      ...series.map((e) => e.amount),
      1.0,
    ].reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: maxY * 1.2,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= series.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(series[i].label,
                      style: const TextStyle(fontSize: 11)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < series.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: series[i].amount,
                  width: 14,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(6)),
                  color: LedgerColors.secondary,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
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
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
            decoration: BoxDecoration(
              color: LedgerColors.primary.withValues(alpha: 0.06),
              border: const Border(
                bottom: BorderSide(color: LedgerColors.border),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: LedgerColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 9),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}
