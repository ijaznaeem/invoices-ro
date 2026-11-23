import 'package:flutter/material.dart';

import '../models/models.dart';
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
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: client?.name ?? '');
    final emailCtrl = TextEditingController(text: client?.email ?? '');
    final phoneCtrl = TextEditingController(text: client?.phone ?? '');
    final addressCtrl = TextEditingController(text: client?.address ?? '');
    final isEditing = client != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: LedgerColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                decoration: const BoxDecoration(
                  color: LedgerColors.primary,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_add_alt_1_rounded,
                          color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isEditing ? 'Edit client' : 'New client',
                        style: Theme.of(sheetContext)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 12),
              TextFormField(
                controller: addressCtrl,
                decoration: const InputDecoration(labelText: 'Address'),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  if (!(formKey.currentState?.validate() ?? false)) return;
                  final savedClient = Client(
                    id: client?.id,
                    name: nameCtrl.text.trim(),
                    email: emailCtrl.text.trim().isEmpty
                        ? null
                        : emailCtrl.text.trim(),
                    phone: phoneCtrl.text.trim().isEmpty
                        ? null
                        : phoneCtrl.text.trim(),
                    address: addressCtrl.text.trim().isEmpty
                        ? null
                        : addressCtrl.text.trim(),
                  );
                  if (isEditing) {
                    await state.updateClient(savedClient);
                  } else {
                    await state.addClient(savedClient);
                  }
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
                child: Text(isEditing ? 'Save changes' : 'Add client'),
              ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    ).whenComplete(() {
      nameCtrl.dispose();
      emailCtrl.dispose();
      phoneCtrl.dispose();
      addressCtrl.dispose();
    });
  }
}
