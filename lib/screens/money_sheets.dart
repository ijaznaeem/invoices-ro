import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state_scope.dart';
import '../util/date_utils.dart';

Future<void> showIncomeSheet(BuildContext context,
    {CashReceipt? existing}) async {
  final state = AppStateScope.of(context);
  final fromController =
      TextEditingController(text: existing?.receivedFrom ?? '');
  final amountController = TextEditingController(
      text: existing == null ? '' : existing.amount.toStringAsFixed(2));
  final notesController = TextEditingController(text: existing?.notes ?? '');
  var date = DateTime.tryParse(existing?.receiptDate ?? '') ?? DateTime.now();
  final isEditing = existing != null;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (sheetContext) {
      return StatefulBuilder(builder: (sheetContext, setSheetState) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isEditing ? 'Edit income' : 'Record income',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: fromController,
                decoration: const InputDecoration(labelText: 'Received from'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: sheetContext,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setSheetState(() => date = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date'),
                  child:
                      Text(formatDate(date.toIso8601String().substring(0, 10))),
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
                  if (fromController.text.trim().isEmpty || amount <= 0) {
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      const SnackBar(
                          content: Text('Enter who paid and a valid amount.')),
                    );
                    return;
                  }
                  final record = CashReceipt(
                    id: existing?.id,
                    amount: amount,
                    receiptDate: date.toIso8601String().substring(0, 10),
                    receivedFrom: fromController.text.trim(),
                    notes: notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                    invoiceId: existing?.invoiceId,
                    invoiceNumber: existing?.invoiceNumber,
                  );
                  if (isEditing) {
                    await state.updateCashReceipt(record);
                  } else {
                    await state.addCashReceipt(record);
                  }
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
                child: Text(isEditing ? 'Save changes' : 'Save income'),
              ),
            ],
          ),
        );
      });
    },
  ).whenComplete(() {
    fromController.dispose();
    amountController.dispose();
    notesController.dispose();
  });
}

Future<void> showExpenseSheet(BuildContext context,
    {ExpenseRecord? existing}) async {
  final state = AppStateScope.of(context);
  if (state.expenseHeads.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add expense heads in Settings first.')),
    );
    return;
  }
  var headId = existing?.headId ?? state.expenseHeads.first.id!;
  final amountController = TextEditingController(
      text: existing == null ? '' : existing.amount.toStringAsFixed(2));
  final notesController = TextEditingController(text: existing?.notes ?? '');
  var date = DateTime.tryParse(existing?.expenseDate ?? '') ?? DateTime.now();
  final isEditing = existing != null;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (sheetContext) {
      return StatefulBuilder(builder: (sheetContext, setSheetState) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isEditing ? 'Edit expense' : 'New expense',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: headId,
                decoration: const InputDecoration(labelText: 'Expense head'),
                items: state.expenseHeads
                    .map((h) => DropdownMenuItem(
                          value: h.id,
                          child: Text(h.name),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setSheetState(() => headId = v);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: sheetContext,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setSheetState(() => date = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date'),
                  child:
                      Text(formatDate(date.toIso8601String().substring(0, 10))),
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
                          content: Text('Enter a valid expense amount.')),
                    );
                    return;
                  }
                  final record = ExpenseRecord(
                    id: existing?.id,
                    templateId: existing?.templateId,
                    headId: headId,
                    amount: amount,
                    expenseDate: date.toIso8601String().substring(0, 10),
                    notes: notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                  );
                  if (isEditing) {
                    await state.updateExpense(record);
                  } else {
                    await state.addExpense(record);
                  }
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
                child: Text(isEditing ? 'Save changes' : 'Save expense'),
              ),
            ],
          ),
        );
      });
    },
  ).whenComplete(() {
    amountController.dispose();
    notesController.dispose();
  });
}

Future<bool> confirmDelete(BuildContext context,
    {required String title, required String body}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete')),
      ],
    ),
  );
  return result == true;
}
