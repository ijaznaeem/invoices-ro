import 'package:flutter/material.dart';

import '../services/whiztext_credentials.dart';
import '../theme/app_theme.dart';

class WhatsAppSettingsScreen extends StatefulWidget {
  const WhatsAppSettingsScreen({super.key, this.credentials});
  final WhizTextCredentials? credentials;
  @override
  State<WhatsAppSettingsScreen> createState() => _WhatsAppSettingsScreenState();
}

class _WhatsAppSettingsScreenState extends State<WhatsAppSettingsScreen> {
  final _controller = TextEditingController();
  late final _credentials = widget.credentials ?? WhizTextCredentials();
  bool _loading = true;
  bool _saving = false;
  bool _visible = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await _credentials.read();
      if (!mounted) return;
      _controller.text = value ?? '';
    } catch (_) {
      _error = 'Could not open secure settings. Please try again.';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save({bool clear = false}) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (clear) {
        await _credentials.clear();
      } else {
        await _credentials.save(_controller.text);
      }
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              clear ? 'Gateway key removed.' : 'WhatsApp API key saved.')));
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is ArgumentError
            ? error.message?.toString()
            : 'Could not save the key securely. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppTheme.screenBar('WhatsApp settings'),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('WhizText gateway',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  const Text(
                      'Use a gateway key from WhizText’s API Keys page and connect your WhatsApp account in the portal.'),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _controller,
                    obscureText: !_visible,
                    enabled: !_saving,
                    autocorrect: false,
                    enableSuggestions: false,
                    enableIMEPersonalizedLearning: false,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                        labelText: 'Gateway API key',
                        suffixIcon: IconButton(
                            tooltip: _visible ? 'Hide key' : 'Show key',
                            onPressed: () =>
                                setState(() => _visible = !_visible),
                            icon: Icon(_visible
                                ? Icons.visibility_off
                                : Icons.visibility))),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                      'Stored securely on this device for your signed-in account. The key is excluded from invoice and database backups.'),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error))),
                  const SizedBox(height: 24),
                  FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Saving…' : 'Save API key')),
                  TextButton(
                      onPressed: _saving || _controller.text.isEmpty
                          ? null
                          : () => _save(clear: true),
                      child: const Text('Remove saved key')),
                  const SizedBox(height: 24),
                  const Text(
                      'Send an invoice from its PDF preview using “Send via WhatsApp.” A successful submission means accepted for processing; check the WhizText portal for delivery.'),
                ],
              ),
      );
}
