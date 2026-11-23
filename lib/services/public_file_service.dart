import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Writes user-owned exports outside the application sandbox.
///
/// On Android the native implementation uses MediaStore, so no broad storage
/// permission is needed and the files remain after the app is uninstalled.
class PublicFileService {
  PublicFileService._();

  static const _channel = MethodChannel('com.octavions.invoices_ro/files');

  static Future<String> saveToDownloads({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) =>
      _save(
        fileName: fileName,
        mimeType: mimeType,
        bytes: bytes,
        collection: 'downloads',
        subfolder: 'Ledger',
      );

  static Future<String> saveBackupToDocuments({
    required String fileName,
    required Uint8List bytes,
  }) =>
      _save(
        fileName: fileName,
        mimeType: 'application/zip',
        bytes: bytes,
        collection: 'documents',
        subfolder: 'Ledger Backups',
      );

  static Future<String> _save({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
    required String collection,
    required String subfolder,
  }) async {
    if (Platform.isAndroid) {
      return (await _channel.invokeMethod<String>('savePublicFile', {
            'fileName': fileName,
            'mimeType': mimeType,
            'bytes': bytes,
            'collection': collection,
            'subfolder': subfolder,
          })) ??
          fileName;
    }

    // iOS does not allow creating ~/Downloads inside the app container.
    final base = Platform.isIOS
        ? await getApplicationDocumentsDirectory()
        : await getDownloadsDirectory() ??
            await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(base.path, subfolder));
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}
