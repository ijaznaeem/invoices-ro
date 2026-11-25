import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';

/// Owns its controllers through the sheet's entire exit animation.
class ClientEditor extends StatefulWidget {
  const ClientEditor({super.key, this.client, required this.state});
  final Client? client;
  final AppState state;
  @override
  State<ClientEditor> createState() => _ClientEditorState();
}

class _ClientEditorState extends State<ClientEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.client?.name ?? '');
  late final _email = TextEditingController(text: widget.client?.email ?? '');
  late final _phone = TextEditingController(text: widget.client?.phone ?? '');
  late final _address =
      TextEditingController(text: widget.client?.address ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    String? optional(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    final client = Client(
        id: widget.client?.id,
        name: _name.text.trim(),
        email: optional(_email),
        phone: optional(_phone),
        address: optional(_address));
    try {
      if (widget.client == null) {
        await widget.state.addClient(client);
      } else {
        await widget.state.updateClient(client);
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is FirebaseException
              ? 'Could not save client (${error.code}). Check your connection and sign-in, then try again.'
              : 'Could not save client. Your details are kept here; please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving,
        child: Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
                key: _form,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(widget.client == null ? 'New client' : 'Edit client',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      TextFormField(
                          controller: _name,
                          enabled: !_saving,
                          decoration: const InputDecoration(labelText: 'Name'),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Required'
                              : null),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: _email,
                          enabled: !_saving,
                          keyboardType: TextInputType.emailAddress,
                          decoration:
                              const InputDecoration(labelText: 'Email')),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: _phone,
                          enabled: !_saving,
                          keyboardType: TextInputType.phone,
                          decoration:
                              const InputDecoration(labelText: 'Phone')),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: _address,
                          enabled: !_saving,
                          maxLines: 2,
                          decoration:
                              const InputDecoration(labelText: 'Address')),
                      if (_error != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(_error!,
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error))),
                      const SizedBox(height: 20),
                      FilledButton(
                          onPressed: _saving ? null : _save,
                          child: Text(_saving
                              ? 'Saving…'
                              : widget.client == null
                                  ? 'Add client'
                                  : 'Save changes')),
                    ])),
          ),
        ),
      );
}
