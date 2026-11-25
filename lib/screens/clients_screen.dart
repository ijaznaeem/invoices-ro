import 'package:flutter/material.dart';

import '../models/models.dart';
import '../widgets/client_editor.dart';
import '../state/app_state_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/ledger_fab.dart';
import '../widgets/ledger_row.dart';
import '../widgets/status_pill.dart';

class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () => state.reloadClients(),
        child: state.clients.isEmpty
            ? EmptyState.fill(
                title: 'No clients yet',
                subtitle: 'Add a client to start billing them.',
                icon: Icons.people_outline,
              )
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 90, top: 4),
                itemCount: state.clients.length,
                itemBuilder: (context, index) {
                  final c = state.clients[index];
                  return Dismissible(
                    key: ValueKey(c.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 5),
                      decoration: BoxDecoration(
                        color: LedgerColors.overdue,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child:
                          const Icon(Icons.delete_outline, color: Colors.white),
                    ),
                    confirmDismiss: (_) => showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete client?'),
                        content: Text(
                            'This removes ${c.name}. Their past invoices are kept.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel')),
                          TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete')),
                        ],
                      ),
                    ),
                    onDismissed: (_) => state.deleteClient(c.id!),
                    child: LedgerRow(
                      title: c.name,
                      subtitle: [c.email, c.phone]
                          .where((s) => s != null && s.isNotEmpty)
                          .join(' · '),
                      onTap: () => _showClientSheet(context, client: c),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: LedgerFab(
        label: 'New client',
        icon: Icons.person_add_alt_1_rounded,
        onPressed: () => _showClientSheet(context),
      ),
    );
  }

  void _showClientSheet(BuildContext context, {Client? client}) {
    final state = AppStateScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ClientEditor(client: client, state: state),
    );
  }
}
