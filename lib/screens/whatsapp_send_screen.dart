import 'package:flutter/material.dart';

import '../services/whiztext_credentials.dart';
import '../services/whiztext_service.dart';
import '../theme/app_theme.dart';
import 'whatsapp_settings_screen.dart';

class WhatsAppSendScreen extends StatefulWidget {
  const WhatsAppSendScreen(
      {super.key,
      required this.recipient,
      required this.invoiceNumber,
      required this.formatLabel,
      required this.prepareAttachments,
      this.credentials,
      this.service});
  final String recipient;
  final String invoiceNumber;
  final String formatLabel;
  final Future<List<WhizTextAttachment>> Function() prepareAttachments;
  final WhizTextCredentials? credentials;
  final WhizTextService? service;
  @override
  State<WhatsAppSendScreen> createState() => _WhatsAppSendScreenState();
}

class _WhatsAppSendScreenState extends State<WhatsAppSendScreen> {
  late final _phone = TextEditingController(text: widget.recipient);
  late final _message =
      TextEditingController(text: 'Invoice ${widget.invoiceNumber}');
  late final _credentials = widget.credentials ?? WhizTextCredentials();
  late final _service = widget.service ?? WhizTextService();
  bool _sending = false;
  bool _locked = false;
  String? _feedback;
  String _progress = '';

  @override
  void dispose() {
    _phone.dispose();
    _message.dispose();
    if (widget.service == null) _service.close();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || _locked) return;
    setState(() {
      _sending = true;
      _feedback = null;
      _progress = 'Preparing invoice…';
    });
    var accepted = 0;
    try {
      final recipient = WhizTextService.normalizeRecipient(_phone.text);
      final key = await _credentials.read();
      if (key == null || key.isEmpty) {
        throw const WhizTextException(
            'Add your gateway API key in WhatsApp settings first.');
      }
      final files = await widget.prepareAttachments();
      if (files.isEmpty) {
        throw const WhizTextException('No invoice pages were generated.');
      }
      // Validate every page before making the first request.
      for (final file in files) {
        WhizTextService.validateAttachment(file);
      }
      for (var i = 0; i < files.length; i++) {
        if (!mounted) return;
        setState(() => _progress = 'Submitting ${i + 1} of ${files.length}…');
        await _service.send(
            apiKey: key,
            recipient: recipient,
            attachment: files[i],
            message: _message.text);
        accepted++;
      }
      if (!mounted) return;
      setState(() {
        _locked = true;
        _feedback =
            '$accepted attachment${accepted == 1 ? '' : 's'} accepted for sending. Check WhizText message history for delivery.';
      });
    } catch (error) {
      if (!mounted) return;
      final uncertain = error is WhizTextException && error.deliveryUncertain;
      setState(() {
        _locked = accepted > 0 || uncertain;
        final reason = error is WhizTextException
            ? error.message
            : 'Could not prepare or send the invoice. Check your connection and settings.';
        _feedback =
            '${accepted > 0 ? '$accepted attachment(s) already accepted. ' : ''}$reason'
            '${_locked ? ' Check WhizText history before starting another send to avoid duplicates.' : ''}';
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_sending,
        child: Scaffold(
          appBar: AppTheme.screenBar('Send via WhatsApp'),
          body: ListView(padding: const EdgeInsets.all(20), children: [
            Text('Invoice ${widget.invoiceNumber}',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Attachment: ${widget.formatLabel}'),
            const SizedBox(height: 12),
            const Text(
                'Images are sent as one message per invoice page. Review the recipient before sending.'),
            const SizedBox(height: 20),
            TextField(
                controller: _phone,
                enabled: !_sending && !_locked,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'WhatsApp number',
                    helperText: 'Include country code, e.g. +923001234567')),
            const SizedBox(height: 16),
            TextField(
                controller: _message,
                enabled: !_sending && !_locked,
                maxLines: 3,
                decoration:
                    const InputDecoration(labelText: 'Message (optional)')),
            const SizedBox(height: 20),
            if (_sending) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(_progress)
            ],
            if (_feedback != null)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child:
                      Text(_feedback!, key: const ValueKey('send-feedback'))),
            FilledButton.icon(
                onPressed: _sending || _locked ? null : _send,
                icon: const Icon(Icons.send_outlined),
                label:
                    Text(_sending ? 'Sending…' : 'Send ${widget.formatLabel}')),
            TextButton(
                onPressed: _sending
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => WhatsAppSettingsScreen(
                                credentials: _credentials))),
                child: const Text('WhatsApp settings')),
          ]),
        ),
      );
}
