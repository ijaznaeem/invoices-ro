import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

import '../db/database_helper.dart';
import '../firebase_server_client.dart';
import '../models/models.dart';
import 'public_file_service.dart';
import 'drive_backup_store.dart';

enum BackupFrequency { daily, weekly, custom }

class BackupPreferences {
  final BackupFrequency frequency;
  final int customDays;
  final int keepLast;
  final bool uploadToDrive;
  final DateTime? lastBackupAt;

  const BackupPreferences({
    this.frequency = BackupFrequency.daily,
    this.customDays = 3,
    this.keepLast = 7,
    this.uploadToDrive = false,
    this.lastBackupAt,
  });

  int get intervalDays => switch (frequency) {
        BackupFrequency.daily => 1,
        BackupFrequency.weekly => 7,
        BackupFrequency.custom => customDays,
      };

  BackupPreferences copyWith({
    BackupFrequency? frequency,
    int? customDays,
    int? keepLast,
    bool? uploadToDrive,
    DateTime? lastBackupAt,
  }) =>
      BackupPreferences(
        frequency: frequency ?? this.frequency,
        customDays: customDays ?? this.customDays,
        keepLast: keepLast ?? this.keepLast,
        uploadToDrive: uploadToDrive ?? this.uploadToDrive,
        lastBackupAt: lastBackupAt ?? this.lastBackupAt,
      );
}

class BackupService {
  BackupService._();
  static final instance = BackupService._();

  static const _frequencyKey = 'backup_frequency';
  static const _customDaysKey = 'backup_custom_days';
  static const _keepLastKey = 'backup_keep_last';
  static const _driveKey = 'backup_upload_drive';
  static const _driveEmailKey = 'backup_drive_email';
  static const _lastBackupKey = 'backup_last_at';
  static const _driveScope = drive.DriveApi.driveAppdataScope;
  static const _iosClientId =
      '788321164761-h6e8rp04jli0414uhtuvoqbcoi550lqp.apps.googleusercontent.com';

  final DatabaseHelper _db = DatabaseHelper.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: Platform.isIOS ? _iosClientId : null,
    serverClientId: firebaseAndroidServerClientId.isEmpty
        ? null
        : firebaseAndroidServerClientId,
    scopes: [_driveScope],
  );
  String? lastCloudError;

  Future<Directory> get backupDirectory async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(documents.path, 'backups'));
    await directory.create(recursive: true);
    return directory;
  }

  Future<BackupPreferences> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final frequencyName = prefs.getString(_frequencyKey) ?? 'daily';
    return BackupPreferences(
      frequency: BackupFrequency.values.firstWhere(
        (value) => value.name == frequencyName,
        orElse: () => BackupFrequency.daily,
      ),
      customDays: (prefs.getInt(_customDaysKey) ?? 3).clamp(1, 365),
      keepLast: (prefs.getInt(_keepLastKey) ?? 7).clamp(1, 100),
      uploadToDrive: prefs.getBool(_driveKey) ?? false,
      lastBackupAt: DateTime.tryParse(prefs.getString(_lastBackupKey) ?? ''),
    );
  }

  Future<void> savePreferences(BackupPreferences value) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_frequencyKey, value.frequency.name),
      prefs.setInt(_customDaysKey, value.customDays.clamp(1, 365)),
      prefs.setInt(_keepLastKey, value.keepLast.clamp(1, 100)),
      prefs.setBool(_driveKey, value.uploadToDrive),
    ]);
  }

  Future<List<File>> listBackups() async {
    final directory = await backupDirectory;
    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.zip'))
        .toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  Future<File?> createBackupIfDue() async {
    final preferences = await loadPreferences();
    final last = preferences.lastBackupAt;
    if (last != null &&
        DateTime.now().difference(last) <
            Duration(days: preferences.intervalDays)) {
      return null;
    }
    return createBackup(preferences: preferences);
  }

  Future<File> createBackup({BackupPreferences? preferences}) async {
    lastCloudError = null;
    final config = preferences ?? await loadPreferences();
    final now = DateTime.now();
    final stamp =
        now.toUtc().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final temp = await Directory.systemTemp.createTemp('ledger-backup-');
    try {
      final snapshot = File(p.join(temp.path, 'ledger.db'));
      await _db.createSnapshot(snapshot.path);
      final archive = Archive()
        ..addFile(ArchiveFile('ledger.db', await snapshot.length(),
            await snapshot.readAsBytes()));

      final settings = await _db.getBusinessSettings();
      String? logoEntry;
      if (settings.logoPath != null) {
        final logo = File(settings.logoPath!);
        if (await logo.exists()) {
          logoEntry = 'logo${p.extension(logo.path).toLowerCase()}';
          archive.addFile(ArchiveFile(
              logoEntry, await logo.length(), await logo.readAsBytes()));
        }
      }
      final manifest = utf8.encode(jsonEncode({
        'format': 1,
        'databaseVersion': 6,
        'createdAt': now.toUtc().toIso8601String(),
        'app': 'Ledger',
        'logo': logoEntry,
      }));
      archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));

      final output = File(
          p.join((await backupDirectory).path, 'Ledger-backup-$stamp.zip'));
      await output.writeAsBytes(ZipEncoder().encode(archive), flush: true);
      // Keep an additional user-owned copy outside the app sandbox. Android
      // does not remove this Documents/Ledger Backups copy on uninstall.
      // iOS already stores the backup in the app Documents folder.
      if (Platform.isAndroid) {
        await PublicFileService.saveBackupToDocuments(
          fileName: p.basename(output.path),
          bytes: await output.readAsBytes(),
        );
      }
      await _markBackupComplete(now);
      await _pruneLocal(config.keepLast);
      if (config.uploadToDrive) {
        try {
          await uploadToGoogleDrive(output, keepLast: config.keepLast);
        } catch (error) {
          // A cloud outage must never invalidate a completed local backup.
          lastCloudError = '$error';
        }
      }
      return output;
    } finally {
      await temp.delete(recursive: true);
    }
  }

  Future<void> exportBackup(File backup) async {
    final target = await FilePicker.saveFile(
      dialogTitle: 'Export Ledger backup',
      fileName: p.basename(backup.path),
      mimeType: 'application/zip',
      bytes: await backup.readAsBytes(),
    );
    if (target == null) return;
  }

  Future<File?> pickBackup() async {
    final picked = await FilePicker.pickFile(
      dialogTitle: 'Select a Ledger backup',
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (picked == null) return null;
    if (picked.path != null) return File(picked.path!);
    final file = File(
        p.join((await Directory.systemTemp.createTemp()).path, picked.name));
    return file..writeAsBytesSync(await picked.readAsBytes());
  }

  Future<void> restoreBackup(File backup) async {
    final decoded = ZipDecoder().decodeBytes(await backup.readAsBytes());
    final databaseEntry = decoded.findFile('ledger.db');
    final manifestEntry = decoded.findFile('manifest.json');
    if (databaseEntry == null || manifestEntry == null) {
      throw const FormatException('This is not a valid Ledger backup.');
    }
    final manifest = jsonDecode(utf8.decode(manifestEntry.content as List<int>))
        as Map<String, dynamic>;
    if ((manifest['format'] as num? ?? 0).toInt() != 1) {
      throw const FormatException('Unsupported backup format.');
    }

    final temp = await Directory.systemTemp.createTemp('ledger-restore-');
    try {
      final snapshot = File(p.join(temp.path, 'ledger.db'));
      await snapshot.writeAsBytes(databaseEntry.content as List<int>,
          flush: true);
      await _db.restoreSnapshot(snapshot.path);

      final logoName = manifest['logo'] as String?;
      final logoEntry = logoName == null ? null : decoded.findFile(logoName);
      if (logoEntry != null) {
        final documents = await getApplicationDocumentsDirectory();
        final logo = File(p.join(
            documents.path, 'restored_business_logo${p.extension(logoName!)}'));
        await logo.writeAsBytes(logoEntry.content as List<int>, flush: true);
        final old = await _db.getBusinessSettings();
        await _db.saveBusinessSettings(BusinessSettings(
          businessName: old.businessName,
          businessSubtitle: old.businessSubtitle,
          phone: old.phone,
          email: old.email,
          address: old.address,
          logoPath: logo.path,
          currencyCode: old.currencyCode,
          currencySymbol: old.currencySymbol,
          signatureName: old.signatureName,
          signatureTitle: old.signatureTitle,
          terms: old.terms,
        ));
      }
    } finally {
      await temp.delete(recursive: true);
    }
  }

  Future<String> connectGoogleDrive() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw StateError('Google Drive sign-in was cancelled.');
      }
      await _rememberDrive(true, email: account.email);
      return account.email;
    } on PlatformException catch (error) {
      final details = '${error.message ?? ''} ${error.details ?? ''}';
      if (error.code == 'sign_in_failed' &&
          (details.contains('10') || details.contains('DEVELOPER_ERROR'))) {
        throw StateError(
          'Google OAuth configuration mismatch (Android error 10). '
          'Register package com.octavions.invoices_ro with this APK signing '
          'SHA-1 in Google Cloud or Firebase, then reinstall the app.',
        );
      }
      rethrow;
    }
  }

  Future<void> disconnectGoogleDrive() async {
    await _googleSignIn.disconnect();
    await _rememberDrive(false);
  }

  /// Email saved with the Drive switch, even before the session is restored.
  Future<String?> get savedDriveEmail async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_driveKey) != true) return null;
    final email = prefs.getString(_driveEmailKey);
    if (email == null || email.trim().isEmpty) return null;
    return email;
  }

  /// Google account used for Drive backups and Firebase Auth.
  Future<GoogleSignInAccount?> signInForCloud({required bool interactive}) async {
    final current = _googleSignIn.currentUser;
    if (current != null) return current;
    final silent = await _googleSignIn.signInSilently(reAuthenticate: true);
    if (silent != null || !interactive) return silent;
    return _googleSignIn.signIn();
  }

  /// Restores the previous Google session without showing the sign-in sheet.
  Future<GoogleSignInAccount?> restoreGoogleDrive() async {
    final current = _googleSignIn.currentUser;
    if (current != null) return current;
    return _googleSignIn.signInSilently(reAuthenticate: true);
  }

  Future<String?> get connectedGoogleAccount async {
    final account = await restoreGoogleDrive();
    if (account == null) return savedDriveEmail;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_driveKey) == true) {
      await prefs.setString(_driveEmailKey, account.email);
    }
    return account.email;
  }

  Future<void> _rememberDrive(bool enabled, {String? email}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_driveKey, enabled);
    if (!enabled) {
      await prefs.remove(_driveEmailKey);
      return;
    }
    if (email != null && email.trim().isNotEmpty) {
      await prefs.setString(_driveEmailKey, email.trim());
    }
  }

  Future<T> _withDrive<T>(
      Future<T> Function(DriveBackupStore store) action) async {
    final account = await restoreGoogleDrive();
    if (account == null) {
      throw StateError('Reconnect Google Drive from Backup & Restore.');
    }
    final granted = await _googleSignIn.requestScopes([_driveScope]);
    if (!granted) {
      throw StateError('Google Drive permission is required for backups.');
    }
    final client = await _googleSignIn.authenticatedClient();
    if (client == null) throw StateError('Could not authorize Google Drive.');
    try {
      return await action(DriveBackupStore(drive.DriveApi(client)));
    } finally {
      client.close();
    }
  }

  Future<void> uploadToGoogleDrive(File backup, {required int keepLast}) =>
      _withDrive((store) => store.upload(backup, keepLast: keepLast));

  Future<List<drive.File>> listGoogleDriveBackups() =>
      _withDrive((store) => store.list());

  /// The caller owns the temporary directory and must remove it after restore.
  Future<File> downloadGoogleDriveBackup(String id) async {
    final temp = await Directory.systemTemp.createTemp('ledger-drive-');
    final target = File(p.join(temp.path, 'backup.zip'));
    try {
      await _withDrive((store) => store.download(id, target));
      return target;
    } catch (_) {
      await temp.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> deleteBackup(File backup) => backup.delete();

  Future<void> _markBackupComplete(DateTime at) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastBackupKey, at.toUtc().toIso8601String());
  }

  Future<void> _pruneLocal(int keepLast) async {
    final files = await listBackups();
    for (final old in files.skip(keepLast)) {
      await old.delete();
    }
  }
}
