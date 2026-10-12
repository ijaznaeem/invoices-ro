import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../state/app_state_scope.dart';
import '../theme/app_theme.dart';
import '../util/currency_utils.dart';
import '../util/date_utils.dart';
import '../widgets/ledger_row.dart';
import '../widgets/status_pill.dart';
import 'add_recurring_expense_sheet.dart';

class RecurringExpensesScreen extends StatelessWidget {
  const RecurringExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Recurring expenses')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'recurring_expenses_fab',
        onPressed: () => showAddRecurringExpenseSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('New schedule'),
      ),
      body: DecoratedBox(
        decoration: AppTheme.backgroundDecoration(context),
        child: RefreshIndicator(
          onRefresh: () => state.reloadRecurringExpenses(),
          child: state.recurringExpenses.isEmpty
              ? ListView(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  children: const [
                    EmptyState(
                      title: 'No recurring expenses yet',
                      subtitle:
                          'Set up rent, utilities, or subscriptions to post automatically.',
                      icon: Icons.autorenew,
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 90, top: 8),
                  itemCount: state.recurringExpenses.length,
                  itemBuilder: (context, index) {
                    final t = state.recurringExpenses[index];
                    final tick = t.status == TemplateStatus.active
                        ? LedgerTick.paid
                        : t.status == TemplateStatus.paused
                            ? LedgerTick.pending
                            : LedgerTick.neutral;
                    return LedgerRow(
                      tick: tick,
                      overline: t.headName ?? 'Expense',
                      title: t.displayName,
                      subtitle:
                          '${frequencyLabel(t.frequency)} · next ${formatDate(t.nextDueDate)} · ${t.occurrencesGenerated} posted',
                      trailingFigure: money(t.amount),
                      onTap: () => _showActions(context, state, t),
                      trailingWidget: StatusPill.forTemplateStatus(
                        t.status.name,
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context, AppState state, RecurringExpense t) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                t.displayName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              subtitle: Text(
                '${frequencyLabel(t.frequency)} · next ${formatDate(t.nextDueDate)}',
              ),
            ),
            if (t.status != TemplateStatus.ended)
              ListTile(
                leading: Icon(
                  t.status == TemplateStatus.active
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                ),
                title: Text(
                  t.status == TemplateStatus.active ? 'Pause' : 'Resume',
                ),
                onTap: () {
                  Navigator.pop(context);
                  state.toggleRecurringExpenseStatus(t);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              subtitle: const Text('Past generated expenses are kept'),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete recurring expense?'),
                    content: const Text(
                      'This stops future expenses from being generated. Past expenses stay in your records.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) state.deleteRecurringExpense(t.id!);
              },
            ),
          ],
        ),
      ),
    );
  }
}
