import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:invoices_ro/services/whiztext_service.dart';

void main() {
  WhizTextAttachment file([String mime = 'application/pdf']) =>
      WhizTextAttachment(
          bytes: Uint8List.fromList([37, 80, 68, 70]),
          fileName: mime == 'image/png' ? 'invoice.png' : 'invoice.pdf',
          mimeType: mime);

  for (final mime in ['application/pdf', 'image/png']) {
    test('uploads $mime using the documented multipart contract', () async {
      var calls = 0;
      final service = WhizTextService(client: MockClient((request) async {
        calls++;
        expect(request.url.toString(), 'https://api.whiztext.com/v1/send');
        expect(request.method, 'POST');
        expect(request.headers['X-API-Key'], 'gateway-test');
        expect(request.headers['content-type'],
            startsWith('multipart/form-data; boundary='));
        final body = latin1.decode(request.bodyBytes);
        expect(body, contains('name="to"\r\n\r\n+923001234567'));
        expect(body, contains('name="message"\r\n\r\nInvoice 123'));
        expect(body, contains('name="media"; filename="invoice.'));
        expect(body, contains('content-type: $mime'));
        expect(body, isNot(contains('name="file"')));
        expect(body, isNot(contains('name="caption"')));
        return http.Response(
            '{"success":true,"messageId":null,"status":"queued"}', 200);
      }));
      addTearDown(service.close);
      final result = await service.send(
          apiKey: ' gateway-test ',
          recipient: '0092 (300) 123-4567',
          attachment: file(mime),
          message: 'Invoice 123');
      expect(result.status, 'queued');
      expect(result.messageId, isNull);
      expect(calls, 1);
    });
  }

  test('rejects invalid recipient and oversized files before HTTP', () async {
    var calls = 0;
    final service = WhizTextService(client: MockClient((_) async {
      calls++;
      return http.Response('{}', 200);
    }));
    addTearDown(service.close);
    await expectLater(
        service.send(
            apiKey: 'key', recipient: '03001234567', attachment: file()),
        throwsA(isA<WhizTextException>()));
    await expectLater(
        service.send(
            apiKey: 'key',
            recipient: '+923001234567',
            attachment: WhizTextAttachment(
                bytes: Uint8List(WhizTextService.maxFileBytes + 1),
                fileName: 'big.pdf',
                mimeType: 'application/pdf')),
        throwsA(isA<WhizTextException>()));
    expect(calls, 0);
  });

  for (final code in [400, 401, 403, 413, 429, 500, 200, 302]) {
    test('handles HTTP $code without retrying or exposing the key', () async {
      var calls = 0;
      final service = WhizTextService(client: MockClient((_) async {
        calls++;
        return http.Response(
            '{"success":false,"error":"bad secret-key"}', code);
      }));
      addTearDown(service.close);
      await expectLater(
          service.send(
              apiKey: 'secret-key',
              recipient: '+923001234567',
              attachment: file()),
          throwsA(isA<WhizTextException>()
              .having(
                  (e) => e.message, 'redacted', isNot(contains('secret-key')))
              .having((e) => e.deliveryUncertain, 'uncertainty',
                  code == 500 || code == 200 || code == 302)));
      expect(calls, 1);
    });
  }

  test('timeout is ambiguous and is never retried', () async {
    var calls = 0;
    final service = WhizTextService(
        timeout: const Duration(milliseconds: 10),
        client: MockClient((_) {
          calls++;
          return Completer<http.Response>().future;
        }));
    addTearDown(service.close);
    await expectLater(
        service.send(
            apiKey: 'key', recipient: '+923001234567', attachment: file()),
        throwsA(isA<WhizTextException>()
            .having((e) => e.deliveryUncertain, 'uncertain', true)));
    expect(calls, 1);
  });
}
