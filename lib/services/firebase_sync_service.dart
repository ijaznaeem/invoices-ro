import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/database_helper.dart';
import '../firebase_options.dart';
import '../models/models.dart';
import 'backup_service.dart';

/// Mirrors the on-device SQLite ledger to Firestore for the signed-in user.
///
/// SQLite stays the source of truth while the app is open. A local edit is
/// uploaded shortly after it is saved. On launch, a newer cloud copy replaces
/// the phone only when this phone has no unsynced edits.
class FirebaseSyncService extends ChangeNotifier {
  FirebaseSyncService._();
  static final instance = FirebaseSyncService._();

  static const _enabledKey = 'firebase_sync_enabled';
  static const _revisionKey = 'firebase_revision';
  static const _dirtyKey = 'firebase_dirty';
  static const _syncedAtKey = 'firebase_last_sync';
  static const _emailKey = 'firebase_sync_email';
  static const _schema = 6;
  static const _logoLimit = 900000;

  final DatabaseHelper _db = DatabaseHelper.instance;

  bool ready = false;
  bool enabled = false;
  bool syncing = false;
  DateTime? lastSync;
  String? email;
  String? lastError;

  int _epoch = 0;
  bool _dirty = false;
  Timer? _pushTimer;
  Future<void> _queue = Future<void>.value();

  Future<void> ensureInitialized() async {
    final prefs = await SharedPreferences.getInstance();
    enabled = prefs.getBool(_enabledKey) ?? false;
    _dirty = prefs.getBool(_dirtyKey) ?? false;
    lastSync = DateTime.tryParse(prefs.getString(_syncedAtKey) ?? '');
    email = prefs.getString(_emailKey);
    try {
      final options = DefaultFirebaseOptions.currentPlatform;
      await Firebase.initializeApp(options: options);
      FirebaseFirestore.instance.settings =
          const Settings(persistenceEnabled: true);
      ready = true;
    } catch (error) {
      ready = false;
      debugPrint('Firebase is not configured: $error');
    }
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
    notifyListeners();
    if (value) await sync(interactive: true);
  }

  /// Called after every local ledger write.
  void schedulePush() {
    _epoch++;
    _dirty = true;
    unawaited(_persistDirty(true));
    if (!ready || !enabled) return;
    _pushTimer?.cancel();
    _pushTimer = Timer(const Duration(seconds: 2), () {
      unawaited(_run(() async {
        try {
          await _push(interactive: false);
        } catch (error) {
          lastError = _friendly(error);
          notifyListeners();
        }
      }));
    });
  }

  /// Uploads or downloads before the UI reads SQLite. Returns true when the
  /// local database was replaced.
  Future<bool> syncOnLaunch() async {
    if (!ready || !enabled) return false;
    try {
      return await sync(interactive: false);
    } catch (error) {
      lastError = _friendly(error);
      notifyListeners();
      return false;
    }
  }

  Future<bool> sync({required bool interactive}) {
    if (!ready) {
      if (interactive) {
        throw StateError(
          'Firebase is not configured yet. Run flutterfire configure.',
        );
      }
      return Future.value(false);
    }
    return _run(() => _sync(interactive: interactive));
  }

  Future<T> _run<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<bool> _sync({required bool interactive}) async {
    syncing = true;
    lastError = null;
    notifyListeners();
    try {
      final user = await _signIn(interactive: interactive);
      if (user == null) return false;
      email = user.email ?? email;
      final remote = await _readMeta(user.uid);
      final prefs = await SharedPreferences.getInstance();
      final localRevision = prefs.getInt(_revisionKey) ?? 0;
      final userRows = await _db.userRecordCount();

      if (remote == null) {
        if (userRows > 0 || _dirty) await _push(interactive: interactive);
        return false;
      }
      if (remote.schema > _schema) {
        throw StateError(
          'This ledger was saved by a newer version of the app. Update before syncing.',
        );
      }
      if (userRows == 0 && localRevision == 0 && !_dirty) {
        await _pull(user.uid, remote.revision);
        return true;
      }
      if (_dirty || localRevision > remote.revision) {
        await _push(interactive: interactive);
        return false;
      }
      if (remote.revision > localRevision) {
        await _pull(user.uid, remote.revision);
        return true;
      }
      return false;
    } catch (error) {
      lastError = _friendly(error);
      if (interactive) {
        notifyListeners();
        throw StateError(lastError!);
      }
      return false;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> _push({required bool interactive}) async {
    final epoch = _epoch;
    final user = await _signIn(interactive: interactive);
    if (user == null) return;
    final tables = await _db.exportCloudTables();
    final revision = DateTime.now().millisecondsSinceEpoch;
    final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final writes = <void Function(WriteBatch batch)>[];

    writes.add((batch) {
      batch.set(userDoc, {
        'revision': revision,
        'schema': _schema,
        'email': user.email,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    for (final table in DatabaseHelper.cloudTables) {
      final collection = userDoc.collection(table);
      final existing = await collection.get();
      final localIds = <String>{};
      for (final row in tables[table] ?? const <Map<String, Object?>>[]) {
        final id = row['id'];
        if (id == null) continue;
        final docId = id.toString();
        localIds.add(docId);
        final data = <String, Object?>{};
        for (final entry in row.entries) {
          final value = entry.value;
          if (value == null || value is num || value is String || value is bool) {
            data[entry.key] = value;
          }
        }
        writes.add((batch) => batch.set(collection.doc(docId), data));
      }
      for (final doc in existing.docs) {
        if (!localIds.contains(doc.id)) {
          writes.add((batch) => batch.delete(doc.reference));
        }
      }
    }

    await _commit(writes);
    await _pushLogo(userDoc);
    if (_epoch != epoch) return;

    _dirty = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dirtyKey, false);
    await prefs.setInt(_revisionKey, revision);
    lastSync = DateTime.now();
    email = user.email ?? email;
    await prefs.setString(_syncedAtKey, lastSync!.toIso8601String());
    if (email != null) await prefs.setString(_emailKey, email!);
    lastError = null;
    notifyListeners();
  }

  Future<void> _pull(String uid, int revision) async {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
    final tables = <String, List<Map<String, Object?>>>{};
    for (final table in DatabaseHelper.cloudTables) {
      final snapshot = await userDoc.collection(table).get();
      tables[table] = [
        for (final doc in snapshot.docs)
          Map<String, Object?>.from(doc.data()),
      ];
    }
    await _db.replaceCloudTables(tables);
    await _db.runWithoutNotify(() => _pullLogo(userDoc));

    _dirty = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dirtyKey, false);
    await prefs.setInt(_revisionKey, revision);
    lastSync = DateTime.now();
    await prefs.setString(_syncedAtKey, lastSync!.toIso8601String());
    lastError = null;
  }

  Future<void> _pushLogo(DocumentReference<Map<String, dynamic>> userDoc) async {
    final settings = await _db.getBusinessSettings();
    final logoDoc = userDoc.collection('files').doc('logo');
    final path = settings.logoPath;
    if (path == null || path.isEmpty || !File(path).existsSync()) {
      await logoDoc.delete();
      return;
    }
    final file = File(path);
    final length = await file.length();
    if (length > _logoLimit) return;
    await logoDoc.set({
      'name': p.basename(path),
      'bytes': Blob(await file.readAsBytes()),
    });
  }

  Future<void> _pullLogo(DocumentReference<Map<String, dynamic>> userDoc) async {
    final settings = await _db.getBusinessSettings();
    final snapshot = await userDoc.collection('files').doc('logo').get();
    if (!snapshot.exists) {
      final path = settings.logoPath;
      if (path != null && path.isNotEmpty && !File(path).existsSync()) {
        await _db.saveBusinessSettings(_settingsWithLogo(settings, null));
      }
      return;
    }
    final data = snapshot.data();
    final bytes = data?['bytes'];
    if (bytes is! Blob) return;
    final name = data?['name'] as String? ?? 'business_logo.png';
    final documents = await getApplicationDocumentsDirectory();
    final file = File(p.join(documents.path, 'firebase_$name'));
    await file.writeAsBytes(bytes.bytes, flush: true);
    await _db.saveBusinessSettings(_settingsWithLogo(settings, file.path));
  }

  BusinessSettings _settingsWithLogo(BusinessSettings settings, String? logoPath) {
    return BusinessSettings(
      businessName: settings.businessName,
      businessSubtitle: settings.businessSubtitle,
      phone: settings.phone,
      email: settings.email,
      address: settings.address,
      logoPath: logoPath,
      currencyCode: settings.currencyCode,
      currencySymbol: settings.currencySymbol,
      signatureName: settings.signatureName,
      signatureTitle: settings.signatureTitle,
      terms: settings.terms,
    );
  }

  Future<_RemoteMeta?> _readMeta(String uid) async {
    final snapshot =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!snapshot.exists) return null;
    final data = snapshot.data();
    if (data == null || data['revision'] == null) return null;
    return _RemoteMeta(
      revision: (data['revision'] as num).toInt(),
      schema: (data['schema'] as num?)?.toInt() ?? _schema,
    );
  }

  Future<User?> _signIn({required bool interactive}) async {
    final account =
        await BackupService.instance.signInForCloud(interactive: interactive);
    if (account == null) {
      if (interactive) {
        throw StateError('Sign in with Google to sync the ledger.');
      }
      return null;
    }
    final googleAuth = await account.authentication;
    final hasToken = (googleAuth.idToken != null && googleAuth.idToken!.isNotEmpty) ||
        (googleAuth.accessToken != null && googleAuth.accessToken!.isNotEmpty);
    if (!hasToken) {
      throw StateError(
        'Google did not return a Firebase token. Set firebaseAndroidServerClientId to the Web client ID, then reinstall the app.',
      );
    }
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final signedIn =
        await FirebaseAuth.instance.signInWithCredential(credential);
    return signedIn.user;
  }

  Future<void> _commit(List<void Function(WriteBatch batch)> writes) async {
    const chunk = 400;
    for (var start = 0; start < writes.length; start += chunk) {
      final batch = FirebaseFirestore.instance.batch();
      final end = start + chunk < writes.length ? start + chunk : writes.length;
      for (var i = start; i < end; i++) {
        writes[i](batch);
      }
      await batch.commit();
    }
  }

  Future<void> _persistDirty(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dirtyKey, value);
  }

  String _friendly(Object error) {
    final text = '$error';
    if (text.contains('permission-denied')) {
      return 'Firestore denied this account. Publish firestore.rules from the project, then try again.';
    }
    if (text.contains('unavailable') || text.contains('network')) {
      return 'Firebase is offline. This phone keeps the ledger and syncs when it reconnects.';
    }
    if (text.contains('id-token') ||
        text.contains('invalid-credential') ||
        text.contains('missing-id-token')) {
      return 'Google did not return a Firebase token. Set firebaseAndroidServerClientId to the Web client ID, then reinstall the app.';
    }
    if (error is StateError) return error.message;
    return text;
  }
}

class _RemoteMeta {
  const _RemoteMeta({required this.revision, required this.schema});
  final int revision;
  final int schema;
}
