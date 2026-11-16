import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../state/app_state_scope.dart';
import '../util/currency_utils.dart';
import '../util/date_utils.dart';
import '../widgets/ledger_row.dart';
import '../widgets/status_pill.dart';
import 'add_template_sheet.dart';

class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () => state.reloadTemplates(),
        child: state.templates.isEmpty
            ? ListView(
                padding: const EdgeInsets.symmetric(vertical: 60),
                children: const [
                  EmptyState(
                    title: 'No recurring invoices yet',
                    subtitle: 'Tap the + button to set one up.',
                    icon: Icons.autorenew,
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 90, top: 4),
                itemCount: state.templates.length,
                itemBuilder: (context, index) {
                  final t = state.templates[index];
                  final tick = t.status == TemplateStatus.active
                      ? LedgerTick.paid
                      : t.status == TemplateStatus.paused
                          ? LedgerTick.pending
                          : LedgerTick.neutral;
                  return LedgerRow(
                    tick: tick,
                    title: t.clientName ?? 'Client',
                    subtitle:
                        '${frequencyLabel(t.frequency)} · next due ${formatDate(t.nextDueDate)} · ${t.occurrencesGenerated} generated',
                    trailingFigure: money(t.total),
                    onTap: () => _showActions(context, state, t),
                    trailingWidget: StatusPill.forTemplateStatus(t.status.name),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'templates_fab',
        onPressed: () => showAddTemplateSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('New recurring invoice'),
      ),
    );
  }

  void _showActions(BuildContext context, AppState state, RecurringTemplate t) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(t.clientName ?? 'Client',
                  style: Theme.of(context).textTheme.titleLarge),
              subtitle: Text(
                  '${frequencyLabel(t.frequency)} · next due ${formatDate(t.nextDueDate)}'),
            ),
            if (t.status != TemplateStatus.ended)
              ListTile(
                leading: Icon(t.status == TemplateStatus.active
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline),
                title: Text(
                    t.status == TemplateStatus.active ? 'Pause' : 'Resume'),
                onTap: () {
                  Navigator.pop(context);
                  state.toggleTemplateStatus(t);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              subtitle: const Text('Past generated invoices are kept'),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete recurring invoice?'),
                    content: const Text(
                        'This stops future invoices from being generated. Past invoices stay in your records.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete')),
                    ],
                  ),
                );
                if (confirmed == true) state.deleteTemplate(t.id!);
              },
            ),
          ],
        ),
      ),
    );
  }
}
