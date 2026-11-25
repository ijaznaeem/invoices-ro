import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A gateway key belongs to the signed-in account on this device. It is never
/// included in Firestore records, invoice exports, or Ledger ZIP backups.
class WhizTextCredentials {
  WhizTextCredentials({FlutterSecureStorage? storage, String? userId})
      : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                  accessibility:
                      KeychainAccessibility.first_unlock_this_device),
            ),
        _userId = userId;
  final FlutterSecureStorage _storage;
  final String? _userId;

  String get _key {
    final uid = _userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Sign in before configuring WhatsApp.');
    return 'whiztext_gateway_key_$uid';
  }

  Future<String?> read() => _storage.read(key: _key);
  Future<void> save(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.contains(RegExp(r'[\r\n]'))) {
      throw ArgumentError('Enter a gateway API key without line breaks.');
    }
    return _storage.write(key: _key, value: trimmed);
  }

  Future<void> clear() => _storage.delete(key: _key);
}
