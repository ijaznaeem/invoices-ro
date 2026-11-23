import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/ledger_fab.dart';
import '../widgets/status_pill.dart';

/// Standalone screen for managing the list of invoice payment options.
/// Accessible from the app drawer.
class PaymentOptionsScreen extends StatelessWidget {
  const PaymentOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final options = AppStateScope.of(context).paymentOptions;

    return Scaffold(
      appBar: AppTheme.screenBar('Payment options'),
      body: DecoratedBox(
        decoration: AppTheme.backgroundDecoration(context),
        child: options.isEmpty
            ? const _EmptyPaymentState()
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: options.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) =>
                    _PaymentOptionCard(option: options[i]),
              ),
      ),
      floatingActionButton: LedgerFab(
        label: 'Add payment option',
        icon: Icons.payment_rounded,
        onPressed: () => _showDialog(context),
      ),
    );
  }

  static Future<void> _showDialog(
    BuildContext context, {
    PaymentOption? existing,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => PaymentOptionDialog(
        existing: existing,
        onSave: (label, details) async {
          final state = AppStateScope.of(context);
          if (existing != null) {
            await state.updatePaymentOption(PaymentOption(
              id: existing.id,
              label: label,
              details: details,
              sortOrder: existing.sortOrder,
            ));
          } else {
            await state.addPaymentOption(PaymentOption(
              label: label,
              details: details,
              sortOrder: state.paymentOptions.length,
            ));
          }
        },
      ),
    );
  }
}

// ─── Card ────────────────────────────────────────────────────────────────────

class _PaymentOptionCard extends StatelessWidget {
  final PaymentOption option;
  const _PaymentOptionCard({required this.option});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.payment_outlined,
            size: 20,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          option.label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: option.details.trim().isNotEmpty
            ? Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  option.details.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => PaymentOptionsScreen._showDialog(
                context,
                existing: option,
              ),
            ),
            IconButton(
              tooltip: 'Delete',
              icon:
                  const Icon(Icons.delete_outline, size: 20, color: Colors.red),
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete payment option?'),
        content: Text('Remove "${option.label}" from the list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await AppStateScope.of(context).deletePaymentOption(option.id!);
    }
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────────

class _EmptyPaymentState extends StatelessWidget {
  const _EmptyPaymentState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmptyState(
              icon: Icons.account_balance_outlined,
              title: 'No payment options',
              subtitle:
                  'Add bank transfer, card, or any other payment method. Each one is printed on invoice PDFs.',
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Add / Edit dialog (public — also used from SettingsScreen) ───────────────

class PaymentOptionDialog extends StatefulWidget {
  final PaymentOption? existing;
  final Future<void> Function(String label, String details) onSave;

  const PaymentOptionDialog({super.key, required this.onSave, this.existing});

  @override
  State<PaymentOptionDialog> createState() => _PaymentOptionDialogState();
}

class _PaymentOptionDialogState extends State<PaymentOptionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelCtrl;
  late final TextEditingController _detailsCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.existing?.label ?? '');
    _detailsCtrl = TextEditingController(text: widget.existing?.details ?? '');
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(_labelCtrl.text.trim(), _detailsCtrl.text.trim());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Payment Option' : 'Add Payment Option'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 320),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _labelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Option Label',
                  hintText: 'e.g. Bank Transfer, PayPal, Cash',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                autofocus: true,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _detailsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Details',
                  hintText:
                      'Bank name\nAccount number\nSWIFT / BIC\nor any extra info',
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEdit ? 'Update' : 'Add'),
        ),
      ],
    );
  }
}
