import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:invoices_ro/services/drive_backup_store.dart';

http.Response jsonResponse(String body, int status) => http.Response(
      body,
      status,
      headers: {'content-type': 'application/json'},
    );

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('drive-backup-test-');
  });

  tearDown(() async {
    await temp.delete(recursive: true);
  });

  test('lists all pages from only the private Ledger backup folder', () async {
    var calls = 0;
    final client = MockClient((request) async {
      final query = request.url.queryParameters;
      expect(query['spaces'], 'appDataFolder');
      expect(query['q'], contains("key='ledgerBackup'"));
      expect(query['q'], contains('trashed = false'));
      expect(query['orderBy'], 'createdTime desc');
      calls++;
      if (calls == 1) {
        expect(query['pageToken'], isNull);
        return jsonResponse(
            jsonEncode({
              'nextPageToken': 'second-page',
              'files': [
                {'id': 'newest', 'name': 'new.zip'}
              ],
            }),
            200);
      }
      expect(query['pageToken'], 'second-page');
      return jsonResponse('{"files":[{"id":"oldest"}]}', 200);
    });
    addTearDown(client.close);

    final files = await DriveBackupStore(drive.DriveApi(client)).list();
    expect(files.map((file) => file.id), ['newest', 'oldest']);
    expect(calls, 2);
  });

  test('uploads a private zip then prunes across all result pages', () async {
    final deleted = <String>[];
    var uploaded = false;
    var pages = 0;
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        expect(request.body, contains('appDataFolder'));
        expect(request.body, contains('ledgerBackup'));
        expect(request.body, contains('application/zip'));
        expect(
            request.body, contains(base64Encode(utf8.encode('test archive'))));
        uploaded = true;
        return jsonResponse('{"id":"new"}', 200);
      }
      expect(uploaded, isTrue);
      if (request.method == 'DELETE') {
        expect(pages, 2);
        deleted.add(request.url.pathSegments.last);
        return jsonResponse('', 204);
      }
      pages++;
      return jsonResponse(
          pages == 1
              ? '{"files":[{"id":"new"},{"id":"old1"}],"nextPageToken":"next"}'
              : '{"files":[{"id":"old2"}]}',
          200);
    });
    addTearDown(client.close);
    final backup =
        await File('${temp.path}/backup.zip').writeAsString('test archive');

    await DriveBackupStore(drive.DriveApi(client)).upload(backup, keepLast: 1);
    expect(deleted, ['old1', 'old2']);
  });

  test('failed upload does not prune any existing backups', () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      expect(request.method, 'POST');
      return jsonResponse('{"error":{"code":403,"message":"Denied"}}', 403);
    });
    addTearDown(client.close);
    final backup =
        await File('${temp.path}/backup.zip').writeAsString('archive');

    await expectLater(
      DriveBackupStore(drive.DriveApi(client)).upload(backup, keepLast: 1),
      throwsA(isA<drive.DetailedApiRequestError>()),
    );
    expect(requests, 1);
  });

  test('downloads the original archive bytes', () async {
    final bytes = [80, 75, 3, 4, 0, 255, 42];
    final client = MockClient((request) async {
      expect(request.url.pathSegments.last, 'backup-id');
      expect(request.url.queryParameters['alt'], 'media');
      return http.Response.bytes(bytes, 200,
          headers: {'content-type': 'application/zip'});
    });
    addTearDown(client.close);
    final target = File('${temp.path}/download.zip');

    await DriveBackupStore(drive.DriveApi(client))
        .download('backup-id', target);
    expect(await target.readAsBytes(), bytes);
  });

  test('a broken download removes the incomplete archive', () async {
    final client = MockClient.streaming((request, body) async {
      return http.StreamedResponse(
          Stream<List<int>>.error(
            const SocketException('Connection lost'),
          ),
          200,
          headers: {'content-type': 'application/zip'});
    });
    addTearDown(client.close);
    final target = File('${temp.path}/download.zip');

    await expectLater(
      DriveBackupStore(drive.DriveApi(client)).download('backup-id', target),
      throwsA(isA<SocketException>()),
    );
    expect(await target.exists(), isFalse);
  });
}
