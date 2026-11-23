import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../state/app_state_scope.dart';
import '../theme/app_theme.dart';
import '../util/currency_utils.dart';
import '../util/date_utils.dart';
import '../widgets/ledger_fab.dart';
import '../widgets/ledger_row.dart';
import '../widgets/status_pill.dart';
import 'invoice_edit_screen.dart';
import 'invoice_pdf_preview_screen.dart';

const _filters = ['All', 'Pending', 'Partial', 'Overdue', 'Paid', 'Cancelled'];

class InvoicesScreen extends StatelessWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: LedgerFab(
        label: 'New invoice',
        icon: Icons.receipt_long_rounded,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InvoiceEditScreen()),
        ),
      ),
      body: Column(children: [
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final f = _filters[i];
                final selected = state.invoiceFilter == f;
                return ChoiceChip(
                  label: Text(f),
                  selected: selected,
                  onSelected: (_) => state.setInvoiceFilter(f),
                );
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => state.reloadInvoices(),
              child: state.invoices.isEmpty
                  ? EmptyState.fill(
                      title: 'No invoices here',
                      subtitle:
                          'Create a one-off invoice or add a recurring schedule.',
                      icon: Icons.receipt_long_outlined,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 88, top: 4),
                      itemCount: state.invoices.length,
                      itemBuilder: (context, index) {
                        final inv = state.invoices[index];
                        final display = inv.displayStatus(todayStr());
                        final tick = display == 'Paid'
                            ? LedgerTick.paid
                            : display == 'Overdue'
                                ? LedgerTick.overdue
                                : display == 'Cancelled'
                                    ? LedgerTick.neutral
                                    : display == 'Partial'
                                        ? LedgerTick.pending
                                        : LedgerTick.pending;
                        final balanceLine = inv.amountPaid > 0
                            ? 'Paid ${money(inv.amountPaid)} · Due ${money(inv.balanceDue)}'
                            : 'Due ${formatDate(inv.dueDate)}';
                        return LedgerRow(
                          tick: tick,
                          overline: inv.invoiceNumber,
                          title: inv.clientName?.trim().isNotEmpty == true
                              ? inv.clientName!
                              : 'Client',
                          subtitle: 'Issued ${formatDate(inv.issueDate)}',
                          trailingFigure: money(inv.total),
                          trailingSubtitle: balanceLine,
                          trailingWidget: StatusPill.forInvoiceStatus(display),
                          onTap: () => _showActions(context, state, inv),
                        );
                      },
                    ),
            ),
          ),
        ]),
    );
  }

  void _showActions(BuildContext context, AppState state, InvoiceRecord inv) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(inv.invoiceNumber,
                  style: Theme.of(context).textTheme.titleLarge),
              subtitle: Text(
                '${inv.clientName ?? ''} · ${money(inv.total)}'
                '${inv.amountPaid > 0 ? '\nPaid ${money(inv.amountPaid)} · Balance ${money(inv.balanceDue)}' : ''}',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit invoice'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InvoiceEditScreen(invoice: inv),
                  ),
                );
              },
            ),
            if (inv.isOpen)
              ListTile(
                leading: const Icon(Icons.payments_outlined,
                    color: Colors.teal),
                title: const Text('Record payment'),
                subtitle: Text('Balance due ${money(inv.balanceDue)}'),
                onTap: () {
                  Navigator.pop(context);
                  _showRecordPayment(context, state, inv);
                },
              ),
            if (inv.isOpen)
              ListTile(
                leading:
                    const Icon(Icons.check_circle_outline, color: Colors.green),
                title: const Text('Mark paid in full'),
                onTap: () {
                  Navigator.pop(context);
                  state.markInvoicePaid(inv.id!);
                },
              ),
            ListTile(
              leading:
                  const Icon(Icons.picture_as_pdf_outlined, color: Colors.blue),
              title: const Text('Preview PDF'),
              onTap: () async {
                Navigator.pop(context);
                final paymentMethod =
                    await _pickPaymentMethod(context, state.paymentOptions);
                if (paymentMethod == null || !context.mounted) return;
                final client = await state.getClient(inv.clientId);
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InvoicePdfPreviewScreen(
                      invoice: inv,
                      client: client,
                      paymentMethod: paymentMethod,
                      settings: state.businessSettings,
                      paymentOptions: state.paymentOptions,
                    ),
                  ),
                );
              },
            ),
            if (inv.status != InvoiceStatus.cancelled)
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: Colors.red),
                title: const Text('Cancel invoice'),
                onTap: () {
                  Navigator.pop(context);
                  state.cancelInvoice(inv.id!);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRecordPayment(
      BuildContext context, AppState state, InvoiceRecord inv) async {
    final amountController =
        TextEditingController(text: inv.balanceDue.toStringAsFixed(2));
    final notesController = TextEditingController();
    var paymentDate = DateTime.now();
    var method = 'Cash';
    final methods = [
      'Cash',
      'Bank Transfer',
      'Card',
      'Cheque',
      'Other',
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: LedgerColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                    decoration: const BoxDecoration(
                      color: LedgerColors.teal,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Record payment',
                            style: Theme.of(sheetContext)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(
                          '${inv.invoiceNumber} · Balance ${money(inv.balanceDue)}',
                          style: Theme.of(sheetContext)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.white70),
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
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Amount received'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: method,
                    decoration: const InputDecoration(labelText: 'Method'),
                    items: methods
                        .map((m) =>
                            DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setSheetState(() => method = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: sheetContext,
                        initialDate: paymentDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setSheetState(() => paymentDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration:
                          const InputDecoration(labelText: 'Payment date'),
                      child: Text(formatDate(
                          paymentDate.toIso8601String().substring(0, 10))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesController,
                    decoration:
                        const InputDecoration(labelText: 'Notes (optional)'),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () async {
                      final amount =
                          double.tryParse(amountController.text.trim()) ?? 0;
                      if (amount <= 0) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(
                              content: Text('Enter a valid payment amount.')),
                        );
                        return;
                      }
                      await state.recordInvoicePayment(
                        invoice: inv,
                        amount: amount,
                        paymentDate:
                            paymentDate.toIso8601String().substring(0, 10),
                        method: method,
                        notes: notesController.text.trim().isEmpty
                            ? null
                            : notesController.text.trim(),
                      );
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Recorded payment of ${money(amount)}')),
                        );
                      }
                    },
                    child: const Text('Save payment'),
                  ),
                      ],
                    ),
                  ),
                ],
              ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      amountController.dispose();
      notesController.dispose();
    });
  }

  Future<String?> _pickPaymentMethod(
      BuildContext context, List<PaymentOption> options) {
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) {
        final tiles = options.isNotEmpty
            ? options
                .map<Widget>((o) => ListTile(
                      leading: const Icon(Icons.payment_outlined),
                      title: Text(o.label),
                      onTap: () => Navigator.pop(sheetContext, o.label),
                    ))
                .toList()
            : <Widget>[
                ListTile(
                  leading: const Icon(Icons.account_balance_outlined),
                  title: const Text('Bank Transfer'),
                  onTap: () => Navigator.pop(sheetContext, 'Bank Transfer'),
                ),
                ListTile(
                  leading: const Icon(Icons.credit_card_outlined),
                  title: const Text('Credit/Debit Card'),
                  onTap: () => Navigator.pop(sheetContext, 'Credit/Debit Card'),
                ),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: const Text('Cash / Wallet Payment'),
                  onTap: () =>
                      Navigator.pop(sheetContext, 'Cash / Wallet Payment'),
                ),
              ];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  'Choose preferred payment',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                subtitle:
                    const Text('Highlighted at top of PDF payment section'),
              ),
              ...tiles,
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
