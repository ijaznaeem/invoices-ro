import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as p;

import '../services/backup_service.dart';
import '../services/firebase_sync_service.dart';
import '../state/app_state_scope.dart';
import '../theme/app_theme.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final _service = BackupService.instance;
  final _firebase = FirebaseSyncService.instance;
  final _customDaysController = TextEditingController();
  final _keepLastController = TextEditingController();
  BackupPreferences _preferences = const BackupPreferences();
  List<File> _backups = [];
  String? _googleAccount;
  bool _driveNeedsReconnect = false;
  List<drive.File> _driveBackups = [];
  String? _driveError;
  bool _driveLoaded = false;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _firebase.addListener(_onFirebase);
    _load();
  }

  @override
  void dispose() {
    _firebase.removeListener(_onFirebase);
    _customDaysController.dispose();
    _keepLastController.dispose();
    super.dispose();
  }

  void _onFirebase() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      _preferences = await _service.loadPreferences();
      _backups = await _service.listBackups();
      if (!mounted) return;
      _customDaysController.text = '${_preferences.customDays}';
      _keepLastController.text = '${_preferences.keepLast}';
      try {
        _googleAccount = await _service.savedDriveEmail;
        if (_preferences.uploadToDrive) {
          final restored = await _service.restoreGoogleDrive();
          _driveNeedsReconnect = restored == null;
          _googleAccount = restored?.email ?? _googleAccount;
          if (restored != null && mounted) {
            await _refreshDriveBackups();
          }
        }
      } catch (error) {
        _driveNeedsReconnect = _preferences.uploadToDrive;
        _driveError = 'Google Drive connection failed: $error';
      }
    } catch (error) {
      if (mounted) _showMessage('Could not load backups: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _savePreferences() async {
    final customDays = int.tryParse(_customDaysController.text) ?? 1;
    final keepLast = int.tryParse(_keepLastController.text) ?? 1;
    _preferences = _preferences.copyWith(
      customDays: customDays.clamp(1, 365),
      keepLast: keepLast.clamp(1, 100),
    );
    _customDaysController.text = '${_preferences.customDays}';
    _keepLastController.text = '${_preferences.keepLast}';
    await _service.savePreferences(_preferences);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup schedule saved.')),
      );
    }
  }

  Future<void> _createBackup() async {
    await _runBusy(() async {
      await _savePreferences();
      final backup = await _service.createBackup(preferences: _preferences);
      await _refreshBackups();
      if (_googleAccount != null) await _refreshDriveBackups();
      if (mounted) {
        final cloudError = _service.lastCloudError;
        _showMessage(cloudError == null
            ? 'Backup created: ${p.basename(backup.path)}'
            : 'Local backup created. Drive upload failed: $cloudError');
      }
    });
  }

  Future<void> _export(File backup) async {
    await _runBusy(() async {
      await _service.exportBackup(backup);
      if (mounted) _showMessage('Backup exported.');
    });
  }

  Future<void> _pickAndRestore() async {
    final backup = await _service.pickBackup();
    if (backup != null) await _confirmRestore(backup);
  }

  Future<void> _confirmRestore(File backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: const Text(
          'Current clients, invoices, schedules, payment options, and settings '
          'will be replaced for your account on all devices. Close the ledger on '
          'other devices during restore. A safety backup of the current data will be created first.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restore')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runBusy(() async {
      final temp =
          await Directory.systemTemp.createTemp('ledger-restore-source-');
      try {
        final source = await backup.copy(p.join(temp.path, 'backup.zip'));
        await _service.createBackup(
            preferences: _preferences.copyWith(uploadToDrive: false));
        await _service.restoreBackup(source);
      } finally {
        await temp.delete(recursive: true);
      }
      if (!mounted) return;
      await AppStateScope.of(context).bootstrap();
      await _refreshBackups();
      if (mounted) _showMessage('Backup restored successfully.');
    });
  }

  Future<void> _delete(File backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete backup?'),
        content: Text(p.basename(backup.path)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.deleteBackup(backup);
      await _refreshBackups();
    }
  }

  Future<void> _syncFirebaseNow() => _runBusy(() async {
        final replaced = await _firebase.sync(interactive: true);
        if (!mounted) return;
        if (replaced) await AppStateScope.of(context).bootstrap();
        _showMessage(_firebase.lastError == null
            ? 'Ledger synced with Firebase.'
            : _firebase.lastError!);
      });

  Future<void> _setDriveEnabled(bool enabled) => _runBusy(() async {
        if (enabled) {
          _googleAccount = await _service.connectGoogleDrive();
        } else {
          await _service.disconnectGoogleDrive();
          _googleAccount = null;
          _driveNeedsReconnect = false;
          _driveBackups = [];
          _driveError = null;
          _driveLoaded = false;
        }
        _preferences = _preferences.copyWith(uploadToDrive: enabled);
        _driveNeedsReconnect = false;
        await _service.savePreferences(_preferences);
        if (enabled) await _refreshDriveBackups();
      });

  Future<void> _refreshDriveBackups() async {
    try {
      final backups = await _service.listGoogleDriveBackups();
      if (!mounted) return;
      setState(() {
        _driveBackups = backups;
        _driveError = null;
        _driveLoaded = true;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _driveError = 'Could not load Drive backups: $error');
      }
    }
  }

  Future<void> _upload(File backup) => _runBusy(() async {
        await _service.uploadToGoogleDrive(backup,
            keepLast: _preferences.keepLast);
        await _refreshDriveBackups();
        if (mounted) _showMessage('Backup uploaded to Google Drive.');
      });

  Future<void> _restoreDrive(drive.File remote) async {
    File? downloaded;
    await _runBusy(() async {
      downloaded = await _service.downloadGoogleDriveBackup(remote.id!);
    });
    final backup = downloaded;
    if (backup == null) return;
    try {
      if (mounted) await _confirmRestore(backup);
    } finally {
      await backup.parent.delete(recursive: true);
    }
  }

  Future<void> _refreshBackups() async {
    _preferences = await _service.loadPreferences();
    _backups = await _service.listBackups();
    if (mounted) setState(() {});
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) _showMessage('Operation failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTheme.screenBar('Backup & Restore'),
      body: DecoratedBox(
        decoration: AppTheme.backgroundDecoration(context),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                children: [
                  _sectionTitle('Automatic local backup'),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          DropdownButtonFormField<BackupFrequency>(
                            initialValue: _preferences.frequency,
                            decoration:
                                const InputDecoration(labelText: 'Frequency'),
                            items: const [
                              DropdownMenuItem(
                                  value: BackupFrequency.daily,
                                  child: Text('Daily')),
                              DropdownMenuItem(
                                  value: BackupFrequency.weekly,
                                  child: Text('Weekly')),
                              DropdownMenuItem(
                                  value: BackupFrequency.custom,
                                  child: Text('Every N days')),
                            ],
                            onChanged: (value) => setState(() {
                              if (value != null) {
                                _preferences =
                                    _preferences.copyWith(frequency: value);
                              }
                            }),
                          ),
                          if (_preferences.frequency ==
                              BackupFrequency.custom) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _customDaysController,
                              decoration: const InputDecoration(
                                  labelText: 'Number of days'),
                              keyboardType: TextInputType.number,
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _keepLastController,
                            decoration: const InputDecoration(
                              labelText: 'Keep last N backups',
                              helperText:
                                  'Older local and Drive backups are removed automatically.',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                                onPressed: _busy ? null : _savePreferences,
                                child: const Text('Save schedule')),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle('Google Drive'),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          secondary: const Icon(Icons.add_to_drive_outlined),
                          title: const Text('Upload after each backup'),
                          subtitle: Text(
                              _googleAccount ?? 'Connect your Google account'),
                          value: _preferences.uploadToDrive,
                          onChanged: _busy ? null : _setDriveEnabled,
                        ),
                        const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                              'Backups are stored privately in your Google account. '
                              'Restore them here after reinstalling. Scheduled backups run when the app opens or resumes.'),
                        ),
                        if (_driveNeedsReconnect && _preferences.uploadToDrive)
                          TextButton(
                            onPressed:
                                _busy ? null : () => _setDriveEnabled(true),
                            child: const Text('Reconnect Google Drive'),
                          ),
                        if (_googleAccount != null)
                          TextButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _runBusy(_refreshDriveBackups),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh Drive backups'),
                          ),
                        if (_driveError != null)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(_driveError!),
                          ),
                        if (_driveLoaded && _driveBackups.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                                'No Drive backups yet. Tap Back up now to create one.'),
                          ),
                        ..._driveBackups.map((backup) => ListTile(
                              leading: const Icon(Icons.cloud_done_outlined),
                              title: Text(backup.createdTime == null
                                  ? (backup.name ?? 'Ledger backup')
                                  : DateFormat.yMMMd()
                                      .add_jm()
                                      .format(backup.createdTime!.toLocal())),
                              subtitle: Text(backup.name ?? 'Ledger backup'),
                              trailing: IconButton(
                                tooltip: 'Restore from Google Drive',
                                icon: const Icon(Icons.restore),
                                onPressed: _busy || backup.id == null
                                    ? null
                                    : () => _restoreDrive(backup),
                              ),
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle('Firebase'),
                  const SizedBox(height: 8),
                  Card(child: _firebaseCard()),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                          child: FilledButton.icon(
                        onPressed: _busy ? null : _createBackup,
                        icon: const Icon(Icons.backup_outlined),
                        label: const Text('Back up now'),
                      )),
                      const SizedBox(width: 12),
                      Expanded(
                          child: OutlinedButton.icon(
                        onPressed: _busy ? null : _pickAndRestore,
                        icon: const Icon(Icons.upload_file_outlined),
                        label: const Text('Import backup'),
                      )),
                    ],
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                  const SizedBox(height: 28),
                  _sectionTitle('Local backups (${_backups.length})'),
                  const SizedBox(height: 8),
                  if (_backups.isEmpty)
                    const Card(
                        child: ListTile(
                      leading: Icon(Icons.inventory_2_outlined),
                      title: Text('No backups yet'),
                      subtitle: Text(
                          'Your first backup is created automatically when due.'),
                    ))
                  else
                    ..._backups.map(_backupTile),
                ],
              ),
      ),
    );
  }

  Widget _backupTile(File file) {
    final modified = file.lastModifiedSync();
    final sizeMb = file.lengthSync() / (1024 * 1024);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.storage_outlined),
        title: Text(DateFormat.yMMMd().add_jm().format(modified)),
        subtitle:
            Text('${sizeMb.toStringAsFixed(2)} MB · ${p.basename(file.path)}'),
        onTap: _busy ? null : () => _confirmRestore(file),
        trailing: PopupMenuButton<String>(
          enabled: !_busy,
          onSelected: (action) {
            if (action == 'restore') _confirmRestore(file);
            if (action == 'export') _export(file);
            if (action == 'delete') _delete(file);
            if (action == 'upload') _upload(file);
          },
          itemBuilder: (_) => [
            if (_googleAccount != null)
              const PopupMenuItem(
                  value: 'upload', child: Text('Upload to Google Drive')),
            const PopupMenuItem(value: 'restore', child: Text('Restore')),
            const PopupMenuItem(value: 'export', child: Text('Export a copy')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }

  Widget _firebaseCard() => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cloud_done_outlined),
            title: const Text('Cloud Firestore'),
            subtitle: Text(_firebase.email ?? 'Signed-in account'),
          ),
          const Text(
              'Your ledger is stored in your Firebase account. Changes from other devices appear automatically.'),
          if (_firebase.lastError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_firebase.lastError!),
            ),
          TextButton.icon(
              onPressed: _busy ? null : _syncFirebaseNow,
              icon: const Icon(Icons.sync),
              label: const Text('Refresh cloud status')),
        ]),
      );

  Widget _sectionTitle(String text) => Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              letterSpacing: .8,
              fontWeight: FontWeight.w700,
            ),
      );
}
