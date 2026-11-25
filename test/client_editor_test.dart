import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoices_ro/models/models.dart';
import 'package:invoices_ro/state/app_state.dart';
import 'package:invoices_ro/widgets/client_editor.dart';

class ClientState extends AppState {
  int calls = 0;
  Client? saved;
  Completer<Client>? pending;
  bool fail = false;
  @override
  Future<Client> addClient(Client client) async {
    calls++;
    saved = client;
    if (fail) {
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    }
    if (pending != null) return await pending!.future;
    return client;
  }
}

void main() {
  Future<void> open(WidgetTester tester, ClientState state) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => ClientEditor(state: state)),
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'save guards duplicate taps and controllers survive closing animation',
      (tester) async {
    final state = ClientState()..pending = Completer<Client>();
    addTearDown(state.dispose);
    await open(tester, state);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'), 'New customer');
    await tester.tap(find.text('Add client'));
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(state.calls, 1);
    state.pending!.complete(state.saved!);
    await tester.pumpAndSettle();
    expect(find.byType(ClientEditor), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed save retains details and allows retry', (tester) async {
    final state = ClientState()..fail = true;
    addTearDown(state.dispose);
    await open(tester, state);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'), 'Retained customer');
    await tester.tap(find.text('Add client'));
    await tester.pumpAndSettle();
    expect(find.textContaining('unavailable'), findsOneWidget);
    expect(find.text('Retained customer'), findsOneWidget);
    state.fail = false;
    await tester.tap(find.text('Add client'));
    await tester.pumpAndSettle();
    expect(state.calls, 2);
    expect(find.byType(ClientEditor), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small screen and keyboard scroll without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.reset);
    final state = ClientState();
    addTearDown(state.dispose);
    await open(tester, state);
    await tester.ensureVisible(find.text('Add client'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
