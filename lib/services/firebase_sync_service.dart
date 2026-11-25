import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../db/database_helper.dart';
import '../firebase_options.dart';
import '../firebase_server_client.dart';
import 'sqlite_migration_service.dart';

/// Initializes Firebase and opens the authenticated Firestore ledger. There is
/// no SQLite mirror or last-writer-wins whole-database synchronization.
class FirebaseSyncService extends ChangeNotifier {
  FirebaseSyncService._();
  static final instance = FirebaseSyncService._();
  bool ready = false;
  bool enabled = false;
  bool syncing = false;
  DateTime? lastSync;
  String? email;
  String? lastError;

  Future<void> ensureInitialized() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform);
      }
      FirebaseFirestore.instance.settings =
          const Settings(persistenceEnabled: true);
      ready = true;
      lastError = null;
    } catch (error) {
      ready = false;
      lastError = _friendly(error);
    }
    notifyListeners();
  }

  Future<bool> connect({required bool interactive}) async {
    syncing = true;
    lastError = null;
    notifyListeners();
    try {
      if (!ready) await ensureInitialized();
      if (!ready) throw StateError(lastError ?? 'Firebase is not configured.');
      var user = FirebaseAuth.instance.currentUser;
      if (user == null && interactive) {
        if (firebaseAndroidServerClientId.isEmpty) {
          throw StateError(
              'Google sign-in is not configured for this app yet.');
        }
        final google = GoogleSignIn(
          clientId: defaultTargetPlatform == TargetPlatform.iOS
              ? googleIosClientId
              : null,
          serverClientId: firebaseAndroidServerClientId.isEmpty
              ? null
              : firebaseAndroidServerClientId,
          scopes: ['email'],
        );
        final account = await google.signIn();
        if (account == null) throw StateError('Google sign-in was cancelled.');
        final tokens = await account.authentication;
        final result = await FirebaseAuth.instance.signInWithCredential(
            GoogleAuthProvider.credential(
                idToken: tokens.idToken, accessToken: tokens.accessToken));
        user = result.user;
      }
      if (user == null) return false;
      email = user.email;
      final db = DatabaseHelper.instance;
      await db.connect(FirebaseFirestore.instance, user.uid);
      // A migrated account may use its cached records offline. First-time
      // import and seed creation require server confirmation.
      final marker = db.user.collection('metadata').doc('storage');
      final state = await marker.get();
      if (state.data()?['schema'] != 7) {
        await SqliteMigrationService(db).migrate();
        await db.seedDefaults();
        await marker
            .set({'schema': 7, 'updatedAt': FieldValue.serverTimestamp()});
      } else {
        // Each newly installed device may have its own old SQLite ledger.
        await SqliteMigrationService(db).migrate();
      }
      db.watch(onError: (error) {
        lastError = _friendly(error);
        notifyListeners();
      });
      enabled = true;
      lastSync = DateTime.now();
      return true;
    } catch (error) {
      enabled = false;
      lastError = _friendly(error);
      rethrow;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<bool> sync({required bool interactive}) async {
    if (!enabled) return connect(interactive: interactive);
    syncing = true;
    lastError = null;
    notifyListeners();
    try {
      await FirebaseFirestore.instance
          .waitForPendingWrites()
          .timeout(const Duration(seconds: 20));
      DatabaseHelper.instance.invalidate();
      lastSync = DateTime.now();
      return true;
    } catch (error) {
      lastError = _friendly(error);
      rethrow;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  String _friendly(Object error) {
    if (error is PlatformException && error.code == 'sign_in_failed') {
      final details = '${error.message} ${error.details}';
      if (details.contains('12500') ||
          details.contains('SERVICE_INVALID') ||
          details.contains('SERVICE_MISSING')) {
        return 'Google sign-in is unavailable on this device. Use an Android phone or emulator with Google Play Store and working Google Play services.';
      }
      if (details.contains('ApiException: 10') ||
          details.contains('DEVELOPER_ERROR')) {
        return 'Google sign-in could not verify this app. Check the Google OAuth client and signing certificate configuration.';
      }
    }
    if (error is UnsupportedError) {
      return 'The cloud connection has not been configured for this app. Contact your app administrator.';
    }
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'This account cannot access the ledger. Check the Firestore security rules.';
        case 'unavailable':
          return 'Cannot reach Firebase. Connect to the internet and try again.';
        case 'operation-not-allowed':
          return 'Google sign-in is not enabled for this Firebase project.';
        case 'invalid-credential':
          return 'Google sign-in could not be verified. Check the Firebase app configuration.';
      }
      return error.message ?? error.code;
    }
    return error is StateError ? error.message.toString() : '$error';
  }
}
