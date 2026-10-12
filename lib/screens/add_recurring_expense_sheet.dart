import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state_scope.dart';
import '../util/date_utils.dart';

Future<void> showAddRecurringExpenseSheet(BuildContext context) async {
  final state = AppStateScope.of(context);
  if (state.expenseHeads.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add expense heads in Settings first.')),
    );
    return;
  }
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _AddRecurringExpenseSheet(),
  );
}

class _AddRecurringExpenseSheet extends StatefulWidget {
  const _AddRecurringExpenseSheet();

  @override
  State<_AddRecurringExpenseSheet> createState() =>
      _AddRecurringExpenseSheetState();
}

class _AddRecurringExpenseSheetState extends State<_AddRecurringExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  int? _headId;
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  Frequency _frequency = Frequency.monthly;
  final _intervalDaysController = TextEditingController(text: '30');
  DateTime _startDate = DateTime.now();
  EndType _endType = EndType.never;
  final _endValueController = TextEditingController();
  DateTime? _endDate;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _headId ??= AppStateScope.of(context).expenseHeads.firstOrNull?.id;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _intervalDaysController.dispose();
    _endValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'New recurring expense',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: _headId,
                    decoration: const InputDecoration(
                      labelText: 'Expense head',
                    ),
                    items: state.expenseHeads
                        .where((h) => h.id != null)
                        .map(
                          (h) => DropdownMenuItem(
                            value: h.id,
                            child: Text(h.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _headId = v);
                    },
                    validator: (v) =>
                        v == null ? 'Choose an expense head' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Amount'),
                    validator: (v) {
                      final parsed = double.tryParse(v?.trim() ?? '');
                      if (parsed == null || parsed <= 0) {
                        return 'Enter a valid amount';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional, e.g. Office rent)',
                    ),
                  ),
                  _sectionLabel('Schedule'),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<Frequency>(
                          initialValue: _frequency,
                          decoration: const InputDecoration(
                            labelText: 'Frequency',
                          ),
                          items: Frequency.values
                              .map(
                                (f) => DropdownMenuItem(
                                  value: f,
                                  child: Text(frequencyLabel(f)),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(
                            () => _frequency = v ?? Frequency.monthly,
                          ),
                        ),
                      ),
                      if (_frequency == Frequency.custom) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _intervalDaysController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Every N days',
                            ),
                            validator: (v) =>
                                _requiredInt(v, min: 1, label: 'Days'),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _pickStartDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'First expense date',
                      ),
                      child: Text(
                        formatDate(
                          _startDate.toIso8601String().substring(0, 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<EndType>(
                    initialValue: _endType,
                    decoration: const InputDecoration(labelText: 'Ends'),
                    items: const [
                      DropdownMenuItem(
                        value: EndType.never,
                        child: Text('Never'),
                      ),
                      DropdownMenuItem(
                        value: EndType.count,
                        child: Text('After a number of times'),
                      ),
                      DropdownMenuItem(
                        value: EndType.date,
                        child: Text('On a specific date'),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _endType = v ?? EndType.never),
                  ),
                  if (_endType == EndType.count)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: TextFormField(
                        controller: _endValueController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Number of occurrences',
                        ),
                        validator: (v) => _endType == EndType.count
                            ? _requiredInt(v, min: 1, label: 'Occurrences')
                            : null,
                      ),
                    ),
                  if (_endType == EndType.date)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: InkWell(
                        onTap: _pickEndDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'End date',
                          ),
                          child: Text(
                            _endDate == null
                                ? 'Choose a date'
                                : formatDate(
                                    _endDate!.toIso8601String().substring(
                                          0,
                                          10,
                                        ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create recurring expense'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                letterSpacing: 0.6,
                fontWeight: FontWeight.w600,
              ),
        ),
      );

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_endType == EndType.date && _endDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Choose an end date.')));
      return;
    }

    setState(() => _saving = true);
    final startDateStr = _startDate.toIso8601String().substring(0, 10);
    final state = AppStateScope.of(context);
    final amount = double.parse(_amountController.text.trim());
    final headId = _headId;
    if (headId == null) return;

    await state.addRecurringExpense(
      RecurringExpense(
        headId: headId,
        amount: amount,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        frequency: _frequency,
        intervalDays: _frequency == Frequency.custom
            ? int.tryParse(_intervalDaysController.text)
            : null,
        startDate: startDateStr,
        nextDueDate: startDateStr,
        endType: _endType,
        endValue: _endType == EndType.count
            ? _endValueController.text.trim()
            : _endType == EndType.date
                ? _endDate?.toIso8601String().substring(0, 10)
                : null,
      ),
    );
    await state.runGenerationCheck();

    if (mounted) Navigator.pop(context);
  }

  String? _requiredInt(
    String? value, {
    required int min,
    required String label,
  }) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null) return 'Enter a valid number';
    if (parsed < min) return '$label must be at least $min';
    return null;
  }
}
