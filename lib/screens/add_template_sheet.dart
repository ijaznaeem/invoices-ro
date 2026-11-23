import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state_scope.dart';
import '../theme/app_theme.dart';
import '../util/currency_utils.dart';
import '../util/date_utils.dart';
import '../widgets/searchable_dropdown.dart';

class _ItemDraft {
  final descriptionController = TextEditingController();
  final quantityController = TextEditingController(text: '1');
  final priceController = TextEditingController(text: '0');

  void dispose() {
    descriptionController.dispose();
    quantityController.dispose();
    priceController.dispose();
  }
}

Future<void> showAddTemplateSheet(BuildContext context) async {
  final state = AppStateScope.of(context);
  if (state.clients.isEmpty) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Add a client first.')));
    return;
  }
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => const _AddTemplateSheet(),
  );
}

class _AddTemplateSheet extends StatefulWidget {
  const _AddTemplateSheet();

  @override
  State<_AddTemplateSheet> createState() => _AddTemplateSheetState();
}

class _AddTemplateSheetState extends State<_AddTemplateSheet> {
  final _formKey = GlobalKey<FormState>();
  int? _clientId;
  final List<_ItemDraft> _items = [_ItemDraft()];
  Frequency _frequency = Frequency.monthly;
  final _intervalDaysController = TextEditingController(text: '30');
  DateTime _startDate = DateTime.now();
  final _paymentTermsController = TextEditingController(text: '14');
  EndType _endType = EndType.never;
  final _endValueController = TextEditingController();
  DateTime? _endDate;
  int? _selectedTaxId;
  final _notesController = TextEditingController();
  bool _saving = false;

  double get _subtotal => _items.fold(0.0, (s, i) {
        final q = double.tryParse(i.quantityController.text) ?? 0;
        final p = double.tryParse(i.priceController.text) ?? 0;
        return s + q * p;
      });

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initTaxSelection());
  }

  Future<void> _initTaxSelection() async {
    final state = AppStateScope.of(context);
    if (state.taxRates.isEmpty) {
      await state.reloadTaxRates();
    }
    if (!mounted) return;
    setState(() {
      _selectedTaxId = state.defaultTaxRate.id ?? state.taxRates.firstOrNull?.id;
    });
  }

  TaxRate? _resolveTax(List<TaxRate> rates) {
    if (rates.isEmpty) return null;
    if (_selectedTaxId != null) {
      final found = rates.where((r) => r.id == _selectedTaxId).firstOrNull;
      if (found != null) return found;
    }
    return rates.where((r) => r.ratePercent == 0).firstOrNull ?? rates.first;
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    _intervalDaysController.dispose();
    _paymentTermsController.dispose();
    _endValueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Form(
        key: _formKey,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
              decoration: const BoxDecoration(
                color: LedgerColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.autorenew_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'New schedule',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: Colors.white),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                children: [
                  SearchableDropdown<int>(
                    label: 'Client',
                    hint: 'Select a client',
                    searchHint: 'Search clients…',
                    prefixIcon: Icons.person_search_rounded,
                    value: _clientId,
                    emptyMessage: 'No clients match your search',
                    items: state.clients
                        .where((c) => c.id != null)
                        .map((c) {
                          final details = [
                            if (c.email?.trim().isNotEmpty == true) c.email!,
                            if (c.phone?.trim().isNotEmpty == true) c.phone!,
                          ].join(' · ');
                          return SearchableOption<int>(
                            value: c.id!,
                            label: c.name,
                            subtitle: details.isEmpty ? null : details,
                            searchText:
                                '${c.name} ${c.email ?? ''} ${c.phone ?? ''}',
                          );
                        })
                        .toList(),
                    onChanged: (id) => setState(() => _clientId = id),
                    validator: (v) => v == null ? 'Choose a client' : null,
                  ),
                  _sectionLabel('Line items'),
                  ..._items
                      .asMap()
                      .entries
                      .map((entry) => _itemRow(entry.key, entry.value)),
                  TextButton.icon(
                    onPressed: () => setState(() => _items.add(_ItemDraft())),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add line item'),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('Subtotal ${money(_subtotal)}',
                        style: AppTheme.mono(size: 15)),
                  ),
                  _sectionLabel('Schedule'),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<Frequency>(
                          initialValue: _frequency,
                          decoration:
                              const InputDecoration(labelText: 'Frequency'),
                          items: Frequency.values
                              .map((f) => DropdownMenuItem(
                                  value: f, child: Text(frequencyLabel(f))))
                              .toList(),
                          onChanged: (v) => setState(
                              () => _frequency = v ?? Frequency.monthly),
                        ),
                      ),
                      if (_frequency == Frequency.custom) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _intervalDaysController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Every N days'),
                            validator: (v) =>
                                _requiredInt(v, min: 1, label: 'Days'),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickStartDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                                labelText: 'First invoice date'),
                            child: Text(formatDate(
                                _startDate.toIso8601String().substring(0, 10))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _paymentTermsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Payment terms (days)'),
                          validator: (v) =>
                              _requiredInt(v, min: 0, label: 'Payment terms'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<EndType>(
                    initialValue: _endType,
                    decoration: const InputDecoration(labelText: 'Ends'),
                    items: const [
                      DropdownMenuItem(
                          value: EndType.never, child: Text('Never')),
                      DropdownMenuItem(
                          value: EndType.count,
                          child: Text('After a number of invoices')),
                      DropdownMenuItem(
                          value: EndType.date,
                          child: Text('On a specific date')),
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
                            labelText: 'Number of invoices'),
                        validator: (v) => _endType == EndType.count
                            ? _requiredInt(v, min: 1, label: 'Invoices')
                            : null,
                      ),
                    ),
                  if (_endType == EndType.date)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: InkWell(
                        onTap: _pickEndDate,
                        child: InputDecorator(
                          decoration:
                              const InputDecoration(labelText: 'End date'),
                          child: Text(_endDate == null
                              ? 'Choose a date'
                              : formatDate(_endDate!
                                  .toIso8601String()
                                  .substring(0, 10))),
                        ),
                      ),
                    ),
                  _sectionLabel('Other'),
                  if (state.taxRates.isEmpty)
                    const Text(
                        'No tax rates configured. Add them in Settings → Tax Rates.')
                  else
                    DropdownButtonFormField<int>(
                      key: ValueKey('template-tax-$_selectedTaxId'),
                      initialValue: state.taxRates
                              .any((r) => r.id == _selectedTaxId)
                          ? _selectedTaxId
                          : state.taxRates.first.id,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Tax rate',
                        prefixIcon: Icon(Icons.percent_rounded),
                      ),
                      items: state.taxRates
                          .where((r) => r.id != null)
                          .map((r) => DropdownMenuItem<int>(
                                value: r.id!,
                                child: Text(r.label),
                              ))
                          .toList(),
                      onChanged: (id) {
                        if (id == null) return;
                        setState(() => _selectedTaxId = id);
                      },
                      validator: (v) =>
                          v == null ? 'Choose a tax rate' : null,
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        labelText: 'Notes (shown on the invoice)'),
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
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Create recurring invoice'),
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
        child: Text(text.toUpperCase(),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(letterSpacing: 0.6, fontWeight: FontWeight.w600)),
      );

  Widget _itemRow(int index, _ItemDraft item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: item.descriptionController,
              decoration: const InputDecoration(
                  labelText: 'Description', isDense: true),
              validator: (v) {
                final hasAnyItemText = _items
                    .any((i) => i.descriptionController.text.trim().isNotEmpty);
                if (!hasAnyItemText && index == 0) return 'Required';
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextFormField(
              controller: item.quantityController,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Qty', isDense: true),
              validator: (v) => item.descriptionController.text.trim().isEmpty
                  ? null
                  : _requiredNumber(v, min: 0.01, label: 'Qty'),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextFormField(
              controller: item.priceController,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Price', isDense: true),
              validator: (v) => item.descriptionController.text.trim().isEmpty
                  ? null
                  : _requiredNumber(v, min: 0, label: 'Price'),
              onChanged: (_) => setState(() {}),
            ),
          ),
          IconButton(
            onPressed: _items.length == 1
                ? null
                : () => setState(() => _items.removeAt(index).dispose()),
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }

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
    final items = _items
        .where((i) => i.descriptionController.text.trim().isNotEmpty)
        .map((i) => InvoiceItem(
              description: i.descriptionController.text.trim(),
              quantity: double.tryParse(i.quantityController.text) ?? 0,
              unitPrice: double.tryParse(i.priceController.text) ?? 0,
            ))
        .toList();

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one line item.')));
      return;
    }
    if (_endType == EndType.date && _endDate == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Choose an end date.')));
      return;
    }

    setState(() => _saving = true);
    final startDateStr = _startDate.toIso8601String().substring(0, 10);
    final state = AppStateScope.of(context);

    final template = RecurringTemplate(
      clientId: _clientId!,
      items: items,
      taxRate: _resolveTax(state.taxRates)?.ratePercent ?? 0,
      frequency: _frequency,
      intervalDays: _frequency == Frequency.custom
          ? int.tryParse(_intervalDaysController.text)
          : null,
      startDate: startDateStr,
      nextDueDate: startDateStr,
      paymentTermsDays: int.tryParse(_paymentTermsController.text) ?? 14,
      endType: _endType,
      endValue: _endType == EndType.count
          ? _endValueController.text.trim()
          : _endType == EndType.date
              ? _endDate?.toIso8601String().substring(0, 10)
              : null,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    await state.addTemplate(template);
    // Immediately check whether the first invoice is already due (e.g.
    // the start date is today or in the past) so the user sees it right away.
    await state.runGenerationCheck();

    if (mounted) Navigator.pop(context);
  }

  String? _requiredInt(String? value,
      {required int min, required String label}) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null) return 'Enter a valid number';
    if (parsed < min) return '$label must be at least $min';
    return null;
  }

  String? _requiredNumber(String? value,
      {required double min, required String label}) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null) return 'Enter a valid number';
    if (parsed < min) return '$label must be at least $min';
    return null;
  }
}
