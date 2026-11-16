import 'dart:io';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as p;

/// Stores only Ledger archives in this application's private Drive folder.
class DriveBackupStore {
  DriveBackupStore(this.api);

  final drive.DriveApi api;

  Future<List<drive.File>> list() async {
    final files = <drive.File>[];
    String? pageToken;
    do {
      final page = await api.files.list(
        spaces: 'appDataFolder',
        q: "trashed = false and appProperties has { key='ledgerBackup' and value='true' }",
        orderBy: 'createdTime desc',
        pageSize: 100,
        pageToken: pageToken,
        $fields: 'nextPageToken,files(id,name,createdTime,size)',
      );
      files.addAll(page.files ?? <drive.File>[]);
      pageToken = page.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);
    return files;
  }

  Future<void> upload(File backup, {required int keepLast}) async {
    if (keepLast < 1) throw ArgumentError.value(keepLast, 'keepLast');
    await api.files.create(
      drive.File()
        ..name = p.basename(backup.path)
        ..mimeType = 'application/zip'
        ..parents = ['appDataFolder']
        ..appProperties = {'ledgerBackup': 'true'},
      uploadMedia: drive.Media(backup.openRead(), await backup.length()),
    );
    // Fetch all pages before deleting so pagination cannot skip older files.
    final backups = await list();
    for (final old in backups.skip(keepLast)) {
      if (old.id != null) await api.files.delete(old.id!);
    }
  }

  Future<void> download(String id, File target) async {
    final media = await api.files.get(
      id,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;
    try {
      await media.stream.pipe(target.openWrite());
    } catch (_) {
      if (await target.exists()) await target.delete();
      rethrow;
    }
  }
}
