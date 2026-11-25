import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/models.dart';
import '../state/app_state_scope.dart';
import '../theme/app_theme.dart';
import '../util/currency_utils.dart';
import 'accounts_screens.dart';
import 'payment_options_screen.dart';
import 'whatsapp_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  final BusinessSettings initialSettings;

  const SettingsScreen({super.key, required this.initialSettings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  late final TextEditingController _businessNameCtrl;
  late final TextEditingController _businessSubtitleCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _signatureNameCtrl;
  late final TextEditingController _signatureTitleCtrl;
  late final TextEditingController _termsCtrl;

  String? _logoPath;
  late String _currencyCode;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.initialSettings;
    _businessNameCtrl = TextEditingController(text: s.businessName);
    _businessSubtitleCtrl = TextEditingController(text: s.businessSubtitle);
    _phoneCtrl = TextEditingController(text: s.phone ?? '');
    _emailCtrl = TextEditingController(text: s.email ?? '');
    _addressCtrl = TextEditingController(text: s.address ?? '');
    _signatureNameCtrl = TextEditingController(text: s.signatureName);
    _signatureTitleCtrl = TextEditingController(text: s.signatureTitle);
    _termsCtrl = TextEditingController(text: s.terms ?? '');
    _logoPath = s.logoPath;
    _currencyCode = currencyOptionForCode(s.currencyCode).code;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _businessNameCtrl.dispose();
    _businessSubtitleCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _signatureNameCtrl.dispose();
    _signatureTitleCtrl.dispose();
    _termsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
    );
    if (picked != null) {
      setState(() => _logoPath = picked.path);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final settings = BusinessSettings(
      businessName: _businessNameCtrl.text.trim().isEmpty
          ? 'INVOICES RO'
          : _businessNameCtrl.text.trim(),
      businessSubtitle: _businessSubtitleCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      address:
          _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      logoPath: _logoPath,
      currencyCode: _currencyCode,
      currencySymbol: currencyOptionForCode(_currencyCode).symbol,
      signatureName: _signatureNameCtrl.text.trim().isEmpty
          ? 'Administrator'
          : _signatureNameCtrl.text.trim(),
      signatureTitle: _signatureTitleCtrl.text.trim().isEmpty
          ? 'Administrator'
          : _signatureTitleCtrl.text.trim(),
      terms: _termsCtrl.text.trim().isEmpty ? null : _termsCtrl.text.trim(),
    );
    try {
      await AppStateScope.of(context).saveBusinessSettings(settings);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTheme.screenBar('Settings'),
      body: DecoratedBox(
        decoration: AppTheme.backgroundDecoration(context),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ScrollConfiguration(
              behavior: const MaterialScrollBehavior().copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                  PointerDeviceKind.stylus,
                },
              ),
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: ListView(
                  controller: _scrollController,
                  primary: false,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    20,
                    16,
                    20,
                    MediaQuery.of(context).viewInsets.bottom + 40,
                  ),
                  children: [
                    // ─── Business Identity ──────────────────────────────────
                    _sectionLabel('Business Identity'),
                    _logoPickerCard(),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _businessNameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Business Name'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _businessSubtitleCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Tagline / Subtitle'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _currencyCode,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Currency'),
                      items: currencyOptions
                          .map((option) => DropdownMenuItem(
                                value: option.code,
                                child: Text(option.label),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _currencyCode = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Phone'),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(labelText: 'Address'),
                      maxLines: 2,
                    ),

                    // ─── Tax rates ───────────────────────────────────────────
                    const SizedBox(height: 28),
                    _sectionLabel('Tax Rates'),
                    const SizedBox(height: 4),
                    Text(
                      'Percentages selectable on invoices. Default is No Tax (0%).',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (ctx) {
                        final count = AppStateScope.of(ctx).taxRates.length;
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.percent_rounded),
                            title: const Text('Manage Tax Rates'),
                            subtitle: Text(
                              count == 0
                                  ? 'No tax rates yet'
                                  : '$count rate${count == 1 ? '' : 's'} configured',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const TaxRatesScreen()),
                            ),
                          ),
                        );
                      },
                    ),

                    // ─── Expense heads ──────────────────────────────────────
                    const SizedBox(height: 28),
                    _sectionLabel('Expense Heads'),
                    const SizedBox(height: 4),
                    Text(
                      'Categories used when recording business expenses.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (ctx) {
                        final count = AppStateScope.of(ctx).expenseHeads.length;
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.category_outlined),
                            title: const Text('Manage Expense Heads'),
                            subtitle: Text(
                              count == 0
                                  ? 'No heads configured yet'
                                  : '$count head${count == 1 ? '' : 's'} configured',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ExpenseHeadsScreen()),
                            ),
                          ),
                        );
                      },
                    ),

                    // ─── Payment Options link ───────────────────────────────
                    const SizedBox(height: 28),
                    _sectionLabel('Payment Options'),
                    const SizedBox(height: 4),
                    Text(
                      'Bank transfer, card, and other methods printed on invoice PDFs.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (ctx) {
                        final count =
                            AppStateScope.of(ctx).paymentOptions.length;
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.account_balance_outlined),
                            title: const Text('Manage Payment Options'),
                            subtitle: Text(
                              count == 0
                                  ? 'No options configured yet'
                                  : '$count option${count == 1 ? '' : 's'} configured',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const PaymentOptionsScreen()),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),
                    Card(
                        child: ListTile(
                      leading: const Icon(Icons.chat_outlined),
                      title: const Text('WhatsApp settings'),
                      subtitle: const Text('WhizText gateway API key'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => const WhatsAppSettingsScreen())),
                    )),

                    // ─── Invoice Signature ──────────────────────────────────
                    const SizedBox(height: 28),
                    _sectionLabel('Invoice Signature'),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _signatureNameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Signatory Name'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _signatureTitleCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Signatory Title'),
                    ),

                    // ─── Terms ─────────────────────────────────────────────
                    const SizedBox(height: 28),
                    _sectionLabel('Terms and Conditions'),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _termsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Terms',
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                    ),

                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Settings'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Payment option list tile ───────────────────────────────────────────

  Widget _logoPickerCard() {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Business Logo',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _logoPath != null
                      ? Image.file(
                          File(_logoPath!),
                          width: 72,
                          height: 72,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => _logoPlaceholder(),
                        )
                      : _logoPlaceholder(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickLogo,
                        icon:
                            const Icon(Icons.photo_library_outlined, size: 16),
                        label: Text(
                            _logoPath != null ? 'Change Logo' : 'Pick Logo'),
                      ),
                      if (_logoPath != null) ...[
                        const SizedBox(height: 6),
                        TextButton.icon(
                          onPressed: () => setState(() => _logoPath = null),
                          icon: const Icon(Icons.delete_outline,
                              size: 16, color: Colors.red),
                          label: const Text('Remove',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        'PNG or JPEG, max 400 x 400 px.\nShown in the invoice PDF header.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _logoPlaceholder() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.asset(
          'assets/icons/ledger_app_icon.png',
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.image_outlined, size: 32),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
              ),
        ),
      );
}
