import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state_scope.dart';
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
            ? ListView(
                padding: const EdgeInsets.symmetric(vertical: 60),
                children: const [
                  EmptyState(
                    title: 'No clients yet',
                    subtitle: 'Add a client to start billing them.',
                    icon: Icons.people_outline,
                  ),
                ],
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
                      color: Colors.red.shade400,
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
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'clients_fab',
        onPressed: () => _showClientSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('New client'),
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
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(isEditing ? 'Edit client' : 'New client',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 16),
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
      ),
    ).whenComplete(() {
      nameCtrl.dispose();
      emailCtrl.dispose();
      phoneCtrl.dispose();
      addressCtrl.dispose();
    });
  }
}
