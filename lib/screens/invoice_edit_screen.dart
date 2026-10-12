import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../state/app_state_scope.dart';
import '../theme/app_theme.dart';
import '../util/currency_utils.dart';
import '../util/date_utils.dart';
import '../widgets/searchable_dropdown.dart';
import 'accounts_screens.dart';

class _InvoiceItemDraft {
  final descriptionController = TextEditingController();
  final quantityController = TextEditingController(text: '1');
  final priceController = TextEditingController(text: '0');

  _InvoiceItemDraft();

  _InvoiceItemDraft.fromItem(InvoiceItem item) {
    descriptionController.text = item.description;
    quantityController.text = item.quantity.toString();
    priceController.text = item.unitPrice.toStringAsFixed(2);
  }

  void dispose() {
    descriptionController.dispose();
    quantityController.dispose();
    priceController.dispose();
  }
}

/// Full-screen create / edit invoice flow.
class InvoiceEditScreen extends StatefulWidget {
  final InvoiceRecord? invoice;

  const InvoiceEditScreen({super.key, this.invoice});

  @override
  State<InvoiceEditScreen> createState() => _InvoiceEditScreenState();
}

class _InvoiceEditScreenState extends State<InvoiceEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  late int? _clientId;
  late bool _saveAsClient;
  late DateTime _issueDate;
  late DateTime _dueDate;
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final List<_InvoiceItemDraft> _items;
  int? _selectedTaxId;
  bool _saving = false;
  bool _taxReady = false;

  InvoiceRecord? get _source => widget.invoice;
  bool get _isEditing => widget.invoice?.id != null;

  @override
  void initState() {
    super.initState();
    final inv = _source;
    _clientId = inv?.clientId;
    _saveAsClient = false;
    _issueDate = DateTime.tryParse(inv?.issueDate ?? '') ?? DateTime.now();
    _dueDate = DateTime.tryParse(inv?.dueDate ?? '') ??
        DateTime.now().add(const Duration(days: 14));
    _nameController = TextEditingController(text: inv?.clientName ?? '');
    _emailController = TextEditingController(text: inv?.clientEmail ?? '');
    _phoneController = TextEditingController(text: inv?.clientPhone ?? '');
    _addressController = TextEditingController(text: inv?.clientAddress ?? '');
    _items = (inv?.items ?? const <InvoiceItem>[]).isEmpty
        ? <_InvoiceItemDraft>[_InvoiceItemDraft()]
        : inv!.items.map(_InvoiceItemDraft.fromItem).toList();

    WidgetsBinding.instance.addPostFrameCallback((_) => _initTaxSelection());
  }

  Future<void> _initTaxSelection() async {
    final state = AppStateScope.of(context);
    if (state.taxRates.isEmpty) {
      await state.reloadTaxRates();
    }
    if (!mounted) return;
    final rates = state.taxRates;
    TaxRate? match;
    final inv = _source;
    if (inv != null && rates.isNotEmpty) {
      match = rates
          .where((r) => (r.ratePercent - inv.taxRatePercent).abs() < 0.0001)
          .firstOrNull;
    }
    final selected = match ?? state.defaultTaxRate;
    setState(() {
      _selectedTaxId = selected.id ?? rates.firstOrNull?.id;
      _taxReady = true;
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
    _scrollController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  double get _subtotal => _items.fold(0.0, (sum, item) {
        final quantity = double.tryParse(item.quantityController.text) ?? 0;
        final price = double.tryParse(item.priceController.text) ?? 0;
        return sum + quantity * price;
      });

  double _taxRateFor(List<TaxRate> rates) =>
      _resolveTax(rates)?.ratePercent ?? 0;
  double _taxAmountFor(List<TaxRate> rates) =>
      _subtotal * (_taxRateFor(rates) / 100);
  double _totalFor(List<TaxRate> rates) => _subtotal + _taxAmountFor(rates);

  String? _requiredNumber(String? value,
      {required double min, required String label}) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null) return 'Enter a valid number';
    if (parsed < min) return '$label must be at least $min';
    return null;
  }

  Future<void> _pickDate({
    required DateTime initialDate,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => onPicked(picked));
  }

  Future<void> _save(AppState state) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_dueDate.isBefore(_issueDate)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Due date cannot be before issue date.')));
      return;
    }
    final invoiceItems = _items
        .where((i) => i.descriptionController.text.trim().isNotEmpty)
        .map((i) => InvoiceItem(
              description: i.descriptionController.text.trim(),
              quantity: double.tryParse(i.quantityController.text) ?? 0,
              unitPrice: double.tryParse(i.priceController.text) ?? 0,
            ))
        .toList();
    if (invoiceItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one line item.')));
      return;
    }

    setState(() => _saving = true);
    try {
      final invoiceSubtotal =
          invoiceItems.fold(0.0, (sum, item) => sum + item.lineTotal);
      final taxRate = _resolveTax(state.taxRates)?.ratePercent ?? 0;
      final tax = invoiceSubtotal * (taxRate / 100);
      final issueDateString = _issueDate.toIso8601String().substring(0, 10);
      var invoiceClientId = _clientId;
      if (invoiceClientId == null && _saveAsClient) {
        final saved = await state.addClient(Client(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          address: _addressController.text.trim(),
        ));
        invoiceClientId = saved.id;
      }
      final record = InvoiceRecord(
        id: _isEditing ? _source!.id : null,
        templateId: _isEditing ? _source!.templateId : null,
        invoiceNumber: _isEditing
            ? _source!.invoiceNumber
            : await state.nextInvoiceNumber(issueDateString),
        clientId: invoiceClientId,
        clientName: _nameController.text.trim(),
        clientEmail: _emailController.text.trim(),
        clientPhone: _phoneController.text.trim(),
        clientAddress: _addressController.text.trim(),
        items: invoiceItems,
        subtotal: invoiceSubtotal,
        tax: tax,
        taxRatePercent: taxRate,
        total: invoiceSubtotal + tax,
        amountPaid: _isEditing ? _source!.amountPaid : 0,
        issueDate: issueDateString,
        dueDate: _dueDate.toIso8601String().substring(0, 10),
        status: _isEditing ? _source!.status : InvoiceStatus.pending,
        paidDate: _isEditing ? _source!.paidDate : null,
      );
      if (_isEditing) {
        await state.updateInvoice(record);
      } else {
        await state.addInvoice(record);
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final rates = state.taxRates;

    return Scaffold(
      appBar: AppBar(
        title:
            Text(_isEditing ? 'Edit ${_source!.invoiceNumber}' : 'New invoice'),
      ),
      body: DecoratedBox(
        decoration: AppTheme.backgroundDecoration(context),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    _sectionLabel('CLIENT'),
                    const SizedBox(height: 4),
                    Text(
                      'Pick a saved client or enter details for a walk-in. Saving the contact is optional.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    SearchableDropdown<int>(
                      label: 'Saved client (optional)',
                      hint: 'Walk-in / new client',
                      searchHint: 'Search clients…',
                      prefixIcon: Icons.person_search_rounded,
                      value: _clientId,
                      allowClear: true,
                      clearLabel: 'Walk-in / new client',
                      emptyMessage: 'No clients match your search',
                      items: state.clients.where((c) => c.id != null).map((c) {
                        final details = [
                          if (c.email?.trim().isNotEmpty == true) c.email!,
                          if (c.phone?.trim().isNotEmpty == true) c.phone!,
                        ].join(' · ');
                        return SearchableOption<int>(
                          value: c.id!,
                          label: c.name,
                          subtitle: details.isEmpty ? null : details,
                          searchText:
                              '${c.name} ${c.email ?? ''} ${c.phone ?? ''} ${c.address ?? ''}',
                        );
                      }).toList(),
                      onChanged: (id) {
                        final selected =
                            state.clients.where((c) => c.id == id).firstOrNull;
                        setState(() {
                          _clientId = id;
                          _saveAsClient = false;
                          if (selected != null) {
                            _nameController.text = selected.name;
                            _emailController.text = selected.email ?? '';
                            _phoneController.text = selected.phone ?? '';
                            _addressController.text = selected.address ?? '';
                          }
                        });
                      },
                    ),
                    if (_clientId == null)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _saveAsClient,
                        onChanged: (value) =>
                            setState(() => _saveAsClient = value ?? false),
                        title: const Text('Save client for future invoices'),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _nameController,
                      decoration:
                          const InputDecoration(labelText: 'Client name'),
                      validator: (v) => (v?.trim().isEmpty ?? true)
                          ? 'Enter a client name'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration:
                          const InputDecoration(labelText: 'Email (optional)'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration:
                          const InputDecoration(labelText: 'Phone (optional)'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText: 'Address (optional)'),
                    ),
                    const SizedBox(height: 22),
                    _sectionLabel('DATES'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickDate(
                              initialDate: _issueDate,
                              onPicked: (date) => _issueDate = date,
                            ),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                  labelText: 'Issue date'),
                              child: Text(formatDate(_issueDate
                                  .toIso8601String()
                                  .substring(0, 10))),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickDate(
                              initialDate: _dueDate,
                              onPicked: (date) => _dueDate = date,
                            ),
                            child: InputDecorator(
                              decoration:
                                  const InputDecoration(labelText: 'Due date'),
                              child: Text(formatDate(
                                  _dueDate.toIso8601String().substring(0, 10))),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _sectionLabel('LINE ITEMS'),
                    const SizedBox(height: 8),
                    ..._items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: item.descriptionController,
                                  decoration: const InputDecoration(
                                      labelText: 'Description', isDense: true),
                                  validator: (v) {
                                    final hasAny = _items.any((i) => i
                                        .descriptionController.text
                                        .trim()
                                        .isNotEmpty);
                                    if (!hasAny && index == 0) {
                                      return 'Required';
                                    }
                                    return null;
                                  },
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: item.quantityController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                            labelText: 'Qty', isDense: true),
                                        validator: (v) => item
                                                .descriptionController.text
                                                .trim()
                                                .isEmpty
                                            ? null
                                            : _requiredNumber(v,
                                                min: 0.01, label: 'Qty'),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        controller: item.priceController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                            labelText: 'Unit price',
                                            isDense: true),
                                        validator: (v) => item
                                                .descriptionController.text
                                                .trim()
                                                .isEmpty
                                            ? null
                                            : _requiredNumber(v,
                                                min: 0, label: 'Price'),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: _items.length == 1
                                          ? null
                                          : () => setState(() =>
                                              _items.removeAt(index).dispose()),
                                      icon: const Icon(Icons.close, size: 18),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () =>
                            setState(() => _items.add(_InvoiceItemDraft())),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add line item'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _sectionLabel('TAX'),
                    const SizedBox(height: 8),
                    if (!_taxReady)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: LinearProgressIndicator(),
                      )
                    else if (rates.isEmpty)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.percent_rounded),
                          title: const Text('No tax rates yet'),
                          subtitle: const Text(
                              'Add rates in Settings, then return here.'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const TaxRatesScreen()),
                            );
                            await _initTaxSelection();
                          },
                        ),
                      )
                    else
                      DropdownButtonFormField<int>(
                        key: ValueKey('tax-$_selectedTaxId'),
                        initialValue: rates.any((r) => r.id == _selectedTaxId)
                            ? _selectedTaxId
                            : rates.first.id,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Tax rate',
                          prefixIcon: Icon(Icons.percent_rounded),
                        ),
                        items: rates
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
                      ),
                    const SizedBox(height: 20),
                    _TotalsCard(
                      subtotal: _subtotal,
                      tax: _taxAmountFor(rates),
                      taxLabel: _resolveTax(rates)?.label ?? 'No Tax',
                      total: _totalFor(rates),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: FilledButton(
                    onPressed: _saving ? null : () => _save(state),
                    child: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isEditing ? 'Save changes' : 'Create invoice'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
      );
}

class _TotalsCard extends StatelessWidget {
  final double subtotal;
  final double tax;
  final String taxLabel;
  final double total;

  const _TotalsCard({
    required this.subtotal,
    required this.tax,
    required this.taxLabel,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        children: [
          _row(context, 'Subtotal', money(subtotal)),
          const SizedBox(height: 8),
          _row(context, 'Tax ($taxLabel)', money(tax)),
          const Divider(height: 20),
          _row(context, 'Total', money(total), emphasize: true),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value,
      {bool emphasize = false}) {
    final style = emphasize
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    );
  }
}
