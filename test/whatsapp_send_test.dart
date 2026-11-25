import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:invoices_ro/screens/whatsapp_send_screen.dart';
import 'package:invoices_ro/services/whiztext_credentials.dart';
import 'package:invoices_ro/services/whiztext_service.dart';

class TestCredentials extends WhizTextCredentials {
  @override
  Future<String?> read() async => 'test-key';
}

void main() {
  WhizTextAttachment page({int size = 1}) => WhizTextAttachment(
      bytes: Uint8List(size), fileName: 'page.png', mimeType: 'image/png');
  Future<void> open(WidgetTester tester, WhizTextService service,
      List<WhizTextAttachment> pages) async {
    await tester.pumpWidget(MaterialApp(
        home: WhatsAppSendScreen(
            recipient: '+923001234567',
            invoiceNumber: '123',
            formatLabel: 'images',
            credentials: TestCredentials(),
            service: service,
            prepareAttachments: () async => pages)));
    await tester.tap(find.text('Send images'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'partial send reports accepted pages and prevents duplicate resubmission',
      (tester) async {
    var requests = 0;
    final service = WhizTextService(client: MockClient((_) async {
      requests++;
      return requests == 1
          ? http.Response('{"success":true,"status":"queued"}', 200)
          : http.Response('{"error":"quota"}', 429);
    }));
    addTearDown(service.close);
    await open(tester, service, [page(), page(), page()]);
    expect(requests, 2);
    expect(find.textContaining('1 attachment(s) already accepted.'),
        findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
  });

  testWidgets('validates all pages before submitting any', (tester) async {
    var requests = 0;
    final service = WhizTextService(client: MockClient((_) async {
      requests++;
      return http.Response('{"success":true}', 200);
    }));
    addTearDown(service.close);
    await open(tester, service,
        [page(), page(size: WhizTextService.maxFileBytes + 1)]);
    expect(requests, 0);
    expect(find.textContaining('16 MiB'), findsOneWidget);
  });

  testWidgets('success says accepted and disables another send',
      (tester) async {
    final service = WhizTextService(
        client: MockClient((_) async =>
            http.Response('{"success":true,"status":"sending"}', 200)));
    addTearDown(service.close);
    await open(tester, service, [page()]);
    expect(find.textContaining('1 attachment accepted for sending.'),
        findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
  });
}
