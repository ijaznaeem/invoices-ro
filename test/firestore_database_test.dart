import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoices_ro/db/database_helper.dart';
import 'package:invoices_ro/db/generation_engine.dart';
import 'package:invoices_ro/models/models.dart';
import 'package:invoices_ro/services/sqlite_migration_service.dart';
import 'package:invoices_ro/util/date_utils.dart';

InvoiceRecord invoice(String number, {double total = 110}) => InvoiceRecord(
      invoiceNumber: number,
      clientId: null,
      clientName: 'Client',
      items: [],
      subtotal: total / 1.1,
      tax: total - total / 1.1,
      total: total,
      issueDate: todayStr(),
      dueDate: todayStr(),
    );

Map<String, List<Map<String, dynamic>>> emptyTables() => {
      for (final table in DatabaseHelper.cloudTables) table: [],
    };

class _FailingUploadFirestore extends FakeFirebaseFirestore {
  int _batches = 0;
  @override
  WriteBatch batch() => ++_batches == 2 ? _FailedBatch() : super.batch();
}

class _FailedBatch implements WriteBatch {
  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {}
  @override
  Future<void> commit() async => throw StateError('Simulated upload failure');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeFirebaseFirestore firestore;
  late DatabaseHelper db;
  setUp(() {
    firestore = FakeFirebaseFirestore();
    db = DatabaseHelper.forUser(firestore, 'alice');
  });

  test('CRUD and reads are isolated by Firebase UID', () async {
    final client = await db.insertClient(Client(name: 'Alice client'));
    final other = DatabaseHelper.forUser(firestore, 'bob');
    expect(await other.getClients(), isEmpty);
    await db.updateClient(client.copyWith(name: 'Changed'));
    expect((await db.getClients()).single.name, 'Changed');
    await db.deleteClient(client.id!);
    expect(await db.getClients(), isEmpty);
  });

  test(
      'invoice creation posts a balanced journal and rejects duplicate numbers',
      () async {
    await db.insertInvoice(invoice('INV-2026-0001'));
    final before = await db.getLedgerEntries();
    expect(before.length, 3);
    expect(before.fold<double>(0, (balance, e) => balance + e.debit - e.credit),
        closeTo(0, .00001));
    await expectLater(
        db.insertInvoice(invoice('INV-2026-0001')), throwsStateError);
    expect(await db.countInvoices(), 1);
    expect((await db.getLedgerEntries()).length, 3);
  });

  test(
      'payments use current server balance and commit receipt and journal together',
      () async {
    final saved = await db.insertInvoice(invoice('INV-2026-0001'));
    await db.recordPayment(saved.id!, 40, todayStr(), 'Cash', null);
    expect((await db.getInvoice(saved.id!))!.status, InvoiceStatus.partial);
    await db.recordPayment(saved.id!, 1000, todayStr(), 'Bank', 'Settlement');
    final paid = (await db.getInvoice(saved.id!))!;
    expect(paid.amountPaid, closeTo(110, .00001));
    expect(paid.status, InvoiceStatus.paid);
    expect(await db.cashReceiptsTotal(), closeTo(110, .00001));
    expect((await db.getPaymentsForInvoice(saved.id!)).length, 2);
    expect((await db.ledgerAccountBalances())['Accounts Receivable'],
        closeTo(0, .00001));
    await expectLater(db.recordPayment(saved.id!, 1, todayStr(), 'Cash', null),
        throwsStateError);
    expect((await db.getPaymentsForInvoice(saved.id!)).length, 2);
    await expectLater(
        db.deleteCashReceipt((await db.getCashReceipts()).first.id!),
        throwsStateError);
  });

  test('failed financial operations do not create partial records', () async {
    await expectLater(
        db.insertExpense(
            ExpenseRecord(headId: 999, amount: 5, expenseDate: todayStr())),
        throwsStateError);
    expect(await db.getExpenses(), isEmpty);
    expect(await db.getLedgerEntries(), isEmpty);
    await expectLater(
        db.recordPayment(999, 5, todayStr(), 'Cash', null), throwsStateError);
    expect(await db.getCashReceipts(), isEmpty);
  });

  test('expense deletion also removes its accounting entries', () async {
    final head = await db.insertExpenseHead(const ExpenseHead(name: 'Travel'));
    final expense = await db.insertExpense(
        ExpenseRecord(headId: head.id!, amount: 25, expenseDate: todayStr()));
    expect((await db.ledgerAccountBalances())['Cash'], -25);
    await expectLater(db.deleteExpenseHead(head.id!), throwsStateError);
    await db.deleteExpense(expense.id!);
    expect(await db.getLedgerEntries(), isEmpty);
  });

  test('invoice number allocation continues beyond imported invoice suffixes',
      () async {
    await db.insertInvoice(invoice('INV-2026-0042'));
    expect(await db.nextInvoiceNumber('2026-11-24'), 'INV-2026-0043');
    expect(await db.nextInvoiceNumber('2026-11-24'), 'INV-2026-0044');
  });

  test('recurring occurrence and journal are created once', () async {
    final client = await db.insertClient(Client(name: 'Recurring client'));
    final template = await db.insertTemplate(RecurringTemplate(
      clientId: client.id!,
      items: [InvoiceItem(description: 'Service', quantity: 1, unitPrice: 100)],
      frequency: Frequency.monthly,
      startDate: todayStr(),
      nextDueDate: todayStr(),
    ));
    expect(await GenerationEngine(db).run(), 1);
    expect(await GenerationEngine(db).run(), 0);
    expect(await db.countInvoices(), 1);
    expect((await db.getTemplates()).single.occurrencesGenerated, 1);
    expect((await db.getInvoices()).single.templateId, template.id);
    expect((await db.getLedgerEntries()).length, 2);
  });

  test('migration remaps every foreign key deterministically', () {
    final source = emptyTables();
    source['clients'] = [Client(id: 1, name: 'Old').toMap()];
    source['invoices'] = [
      {...invoice('INV-2026-0001').toMap(), 'id': 1, 'client_id': 1}
    ];
    source['invoice_payments'] = [
      InvoicePayment(id: 1, invoiceId: 1, amount: 10, paymentDate: todayStr())
          .toMap()
    ];
    source['cash_receipts'] = [
      CashReceipt(
              id: 1,
              amount: 10,
              receiptDate: todayStr(),
              invoiceId: 1,
              receivedFrom: 'Old')
          .toMap()
    ];
    source['ledger_entries'] = [
      LedgerEntry(
              id: 1,
              entryDate: todayStr(),
              account: 'Cash',
              description: 'Imported payment',
              refType: 'payment',
              refId: 1)
          .toMap()
    ];
    final plan = SqliteMigrationPlan.build(source, 'installation-123',
        preserveIds: false, existingInvoiceNumbers: {'INV-2026-0001'});
    expect(
        plan,
        SqliteMigrationPlan.build(source, 'installation-123',
            preserveIds: false, existingInvoiceNumbers: {'INV-2026-0001'}));
    expect(plan['clients']!.single['id'], isNot(1));
    expect(
        plan['invoices']!.single['client_id'], plan['clients']!.single['id']);
    expect(plan['invoice_payments']!.single['invoice_id'],
        plan['invoices']!.single['id']);
    expect(plan['cash_receipts']!.single['invoice_id'],
        plan['invoices']!.single['id']);
    expect(plan['ledger_entries']!.single['ref_id'],
        plan['invoice_payments']!.single['id']);
    expect(plan['invoices']!.single['legacy_invoice_number'], 'INV-2026-0001');
    expect(source['invoices']!.single['invoice_number'], 'INV-2026-0001');
  });

  test('backfilled recurring invoices retain their issue year', () async {
    final client = await db.insertClient(Client(name: 'Older schedule'));
    final previousYear = DateTime.now().year - 1;
    final date = '$previousYear-01-01';
    await db.insertTemplate(RecurringTemplate(
      clientId: client.id!,
      items: [],
      frequency: Frequency.monthly,
      startDate: date,
      nextDueDate: date,
      endType: EndType.count,
      endValue: '1',
    ));
    expect(await GenerationEngine(db).run(), 1);
    expect((await db.getInvoices()).single.invoiceNumber,
        startsWith('INV-$previousYear-'));
  });

  test('large import is idempotent and refuses conflicting cloud data',
      () async {
    final tables = emptyTables();
    tables['clients'] =
        List.generate(550, (i) => Client(id: i + 1, name: 'Client $i').toMap());
    final migration = SqliteMigrationService(db);
    expect(await migration.importTables(tables), 550);
    expect(await migration.importTables(tables), 550);
    expect((await db.getClients()).length, 550);
    await db.doc('clients', 1).update({'name': 'Remote edit'});
    await expectLater(migration.importTables(tables), throwsStateError);
    expect((await db.doc('clients', 1).get()).data()!['name'], 'Remote edit');
  });

  test(
      'restore switches a large ledger atomically and preserves old generation',
      () async {
    final old = await db.insertClient(Client(name: 'Old record'));
    final tables = emptyTables();
    tables['clients'] = List.generate(
        550, (i) => Client(id: i + 1, name: 'Restored $i').toMap());
    await db.replaceCloudTables(tables);
    expect((await db.getClients()).length, 550);
    expect((await firestore.doc('users/alice/clients/${old.id}').get()).exists,
        isTrue);
    final device = DatabaseHelper.forUser(firestore, 'alice');
    await device.connect(firestore, 'alice');
    expect((await device.getClients()).length, 550);
  });

  test('invalid restore leaves active cloud ledger untouched', () async {
    await db.insertClient(Client(name: 'Keep me'));
    final tables = emptyTables();
    tables['invoices'] = [
      {'id': 1, 'invoice_number': 'Invalid'}
    ];
    await expectLater(db.replaceCloudTables(tables), throwsA(anything));
    expect((await db.getClients()).single.name, 'Keep me');
    expect((await db.user.collection('metadata').doc('storage').get()).exists,
        isFalse);
  });

  test('upload failure after a staging batch keeps the original ledger active',
      () async {
    final backend = _FailingUploadFirestore();
    final repository = DatabaseHelper.forUser(backend, 'alice');
    await repository.insertClient(Client(name: 'Original'));
    final tables = emptyTables();
    tables['clients'] =
        List.generate(250, (i) => Client(id: i + 1, name: 'Staged $i').toMap());
    await expectLater(repository.replaceCloudTables(tables), throwsStateError);
    expect((await repository.getClients()).single.name, 'Original');
    expect(
        (await repository.user.collection('metadata').doc('storage').get())
            .exists,
        isFalse);
  });

  test('a device using the old generation cannot save after a restore',
      () async {
    final stale = DatabaseHelper.forUser(firestore, 'alice');
    await db.replaceCloudTables(emptyTables());
    await expectLater(
        stale.insertClient(Client(name: 'Stale write')), throwsStateError);
    expect(await db.getClients(), isEmpty);
  });

  test('rules reject unauthenticated and cross-account document access',
      () async {
    final guarded = FakeFirebaseFirestore(
        securityRules: File('firestore.rules')
            .readAsStringSync()
            .replaceFirst("rules_version = '2';", ''));
    final own = guarded.doc('users/alice/clients/1');
    await expectLater(own.set({'id': 1, 'name': 'A'}), throwsException);
    guarded.authObject.add({'uid': 'alice'});
    await Future<void>.delayed(Duration.zero);
    await own.set({'id': 1, 'name': 'A'});
    expect((await own.get()).exists, isTrue);
    await expectLater(
        guarded.doc('users/bob/clients/1').get(), throwsException);
    await expectLater(
        guarded.doc('users/bob/datasets/snapshot/invoices/1').set({'id': 1}),
        throwsException);
  });
}
