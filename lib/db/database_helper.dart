import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import '../util/date_utils.dart';
import 'legacy_sqlite_database.dart';

/// All live ledger records are stored under the signed-in Firebase Auth UID.
/// SQLite is used only by the compatibility importer.
class DatabaseHelper {
  DatabaseHelper._();
  static final instance = DatabaseHelper._();
  DatabaseHelper.forUser(FirebaseFirestore firestore, String uid)
      : _firestore = firestore,
        _uid = uid;

  FirebaseFirestore? _firestore;
  String? _uid;
  String? _dataset;
  String? _logoData;
  String? _logoPath;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _storageSubscription;
  void Function(Object)? _watchError;
  final _listeners = <void Function()>[];
  final _subscriptions =
      <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
  final _cache = <String, Future<List<Map<String, dynamic>>>>{};
  final _random = Random.secure();
  bool get connected => _uid != null;
  String? get uid => _uid;
  FirebaseFirestore get firestore =>
      _firestore ?? (throw StateError('Sign in before opening the ledger.'));
  DocumentReference<Map<String, dynamic>> get user =>
      firestore.collection('users').doc(_uid!);
  CollectionReference<Map<String, dynamic>> collection(String table) =>
      (_dataset == null ? user : user.collection('datasets').doc(_dataset!))
          .collection(table);
  DocumentReference<Map<String, dynamic>> doc(String table, int id) =>
      collection(table).doc('$id');

  static const cloudTables = [
    'clients',
    'expense_heads',
    'tax_rates',
    'payment_options',
    'business_settings',
    'templates',
    'invoices',
    'invoice_payments',
    'expenses',
    'cash_receipts',
    'ledger_entries',
    'notifications',
  ];
  // Remains exactly representable by Dart and JavaScript numbers.
  int newId() =>
      _random.nextInt(1 << 26) * (1 << 26) + _random.nextInt(1 << 26) + 1;
  void addChangeListener(void Function() listener) => _listeners.add(listener);
  void removeChangeListener(void Function() listener) =>
      _listeners.remove(listener);
  void invalidate() {
    _cache.clear();
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }

  Future<void> connect(FirebaseFirestore firestore, String uid) async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _storageSubscription?.cancel();
    _storageSubscription = null;
    _cache.clear();
    _firestore = firestore;
    _uid = uid;
    final storage = await user.collection('metadata').doc('storage').get();
    _dataset = storage.data()?['activeDataset'] as String?;
  }

  void watch({required void Function(Object) onError}) {
    if (_storageSubscription != null) return;
    _watchError = onError;
    _storageSubscription = user
        .collection('metadata')
        .doc('storage')
        .snapshots()
        .listen((snapshot) {
      final active = snapshot.data()?['activeDataset'] as String?;
      if (active != _dataset) {
        unawaited(_selectDataset(active));
      }
    }, onError: onError);
    _watchCollections();
  }

  void _watchCollections() {
    for (final table in cloudTables) {
      _subscriptions.add(collection(table)
          .snapshots()
          .listen((_) => invalidate(), onError: _watchError));
    }
  }

  Future<void> _selectDataset(String? dataset) async {
    // Set the pointer before awaiting cancellation so the metadata listener and
    // a local restore cannot subscribe twice to the same generation.
    if (_dataset == dataset) return;
    _dataset = dataset;
    _cache.clear();
    final old = List.of(_subscriptions);
    _subscriptions.clear();
    for (final subscription in old) {
      await subscription.cancel();
    }
    if (_watchError != null) _watchCollections();
    invalidate();
  }

  Future<List<Map<String, dynamic>>> rows(String table) =>
      _cache.putIfAbsent(table, () async {
        try {
          return (await collection(table).get())
              .docs
              .map((d) => d.data())
              .toList();
        } catch (_) {
          _cache.remove(table);
          rethrow;
        }
      });
  List<Map<String, dynamic>> sorted(
      Iterable<Map<String, dynamic>> rows, String field,
      {bool descending = false}) {
    final result = rows.toList();
    result.sort((a, b) {
      final av = a[field];
      final bv = b[field];
      final comparison =
          av is num && bv is num ? av.compareTo(bv) : '$av'.compareTo('$bv');
      final order = comparison == 0
          ? ((a['id'] as num?) ?? 0).compareTo((b['id'] as num?) ?? 0)
          : comparison;
      return descending ? -order : order;
    });
    return result;
  }

  /// Include the active generation in every read/write transaction. A restore
  /// on another device invalidates pending edits instead of splitting journals
  /// between the old and the newly restored ledger.
  Future<T> transaction<T>(Future<T> Function(Transaction tx) action) {
    final expected = _dataset;
    return firestore.runTransaction((tx) async {
      final storage = await tx.get(user.collection('metadata').doc('storage'));
      if (storage.data()?['activeDataset'] != expected) {
        throw StateError(
            'The ledger was restored on another device. Refresh before saving.');
      }
      return action(tx);
    });
  }

  Future<Map<String, dynamic>> insert(
      String table, Map<String, dynamic> row) async {
    final data = {...row, 'id': row['id'] ?? newId()};
    await transaction((tx) async {
      tx.set(doc(table, data['id'] as int), data);
    });
    invalidate();
    return data;
  }

  Future<void> update(String table, int? id, Map<String, dynamic> row) async {
    if (id == null) throw ArgumentError('A saved record ID is required.');
    await transaction((tx) async {
      tx.update(doc(table, id), row);
    });
    invalidate();
  }

  Future<void> delete(String table, int id) async {
    await transaction((tx) async {
      tx.delete(doc(table, id));
    });
    invalidate();
  }

  Future<void> seedDefaults() async {
    final marker = user.collection('metadata').doc('defaults');
    final taxes = await collection('tax_rates').limit(1).get();
    final heads = await collection('expense_heads').limit(1).get();
    await transaction((tx) async {
      if ((await tx.get(marker)).exists) return;
      if (taxes.docs.isEmpty) {
        for (var i = 0; i < 4; i++) {
          tx.set(
              doc('tax_rates', i + 1),
              TaxRate(
                      id: i + 1,
                      name: i == 0 ? 'No Tax' : 'VAT ${i * 5}%',
                      ratePercent: i * 5.0,
                      sortOrder: i)
                  .toMap());
        }
      }
      const names = [
        'Office',
        'Travel',
        'Utilities',
        'Supplies',
        'Marketing',
        'Other'
      ];
      if (heads.docs.isEmpty) {
        for (var i = 0; i < names.length; i++) {
          tx.set(doc('expense_heads', i + 1),
              ExpenseHead(id: i + 1, name: names[i], sortOrder: i).toMap());
        }
      }
      tx.set(marker, {'createdAt': FieldValue.serverTimestamp()});
    });
    invalidate();
  }

  Future<Client?> getClient(int id) async {
    final matches = (await rows('clients')).where((r) => r['id'] == id);
    return matches.isEmpty ? null : Client.fromMap(matches.first);
  }

  Future<void> deleteClient(int id) async {
    if ((await getTemplates()).any((t) => t.clientId == id)) {
      throw StateError('Delete this client’s recurring templates first.');
    }
    await delete('clients', id);
  }

  Future<List<RecurringTemplate>> getTemplates() async {
    final clients = {for (final c in await getClients()) c.id: c.name};
    return sorted(await rows('templates'), 'next_due_date')
        .map((r) => RecurringTemplate.fromMap(
            {...r, 'client_name': clients[r['client_id']] ?? ''}))
        .toList();
  }

  Future<List<RecurringTemplate>> getActiveDueTemplates(String today) async =>
      (await getTemplates())
          .where((t) =>
              t.status == TemplateStatus.active &&
              t.nextDueDate.compareTo(today) <= 0)
          .toList();
  Future<void> updateTemplateStatus(int id, TemplateStatus status) =>
      update('templates', id, {'status': status.name});
  Future<void> updateTemplateProgress(
          int id, String nextDueDate, int occurrencesGenerated) =>
      update('templates', id, {
        'next_due_date': nextDueDate,
        'occurrences_generated': occurrencesGenerated
      });
  Future<List<InvoiceRecord>> getInvoices({String? status}) async =>
      sorted(await rows('invoices'), 'due_date', descending: true)
          .map(InvoiceRecord.fromMap)
          .where((i) =>
              status == null ||
              status == 'All' ||
              i.displayStatus(todayStr()) == status)
          .toList();
  Future<InvoiceRecord?> getInvoice(int id) async {
    final snapshot = await doc('invoices', id).get();
    return snapshot.exists ? InvoiceRecord.fromMap(snapshot.data()!) : null;
  }

  Future<int> countInvoices() async => (await rows('invoices')).length;
  Future<String> nextInvoiceNumber(String issueDate) async {
    final counter = user.collection('metadata').doc('invoice_counter');
    final existing = await getInvoices();
    final floor = existing.fold<int>(0,
        (n, i) => max(n, int.tryParse(i.invoiceNumber.split('-').last) ?? 0));
    final next = await transaction((tx) async {
      final snapshot = await tx.get(counter);
      final n =
          max(floor, (snapshot.data()?['value'] as num?)?.toInt() ?? 0) + 1;
      tx.set(counter, {'value': n});
      return n;
    });
    return 'INV-${issueDate.substring(0, 4)}-${next.toString().padLeft(4, '0')}';
  }

  DocumentReference<Map<String, dynamic>> numberRef(String number) =>
      collection('invoice_numbers').doc(base64Url.encode(utf8.encode(number)));
  void postLedger(Transaction tx, List<LedgerEntry> entries) {
    for (final entry in entries) {
      final id = newId();
      tx.set(doc('ledger_entries', id), {...entry.toMap(), 'id': id});
    }
  }

  void postNotification(Transaction tx, String message) {
    final id = newId();
    tx.set(doc('notifications', id), {
      'id': id,
      'message': message,
      'created_at': DateTime.now().toIso8601String(),
      'is_read': 0
    });
  }

  void postInvoice(Transaction tx, InvoiceRecord invoice) {
    tx.set(numberRef(invoice.invoiceNumber), {'invoiceId': invoice.id});
    tx.set(doc('invoices', invoice.id!), invoice.toMap());
    postLedger(tx, [
      LedgerEntry(
          entryDate: invoice.issueDate,
          account: 'Accounts Receivable',
          description: 'Invoice ${invoice.invoiceNumber}',
          debit: invoice.total,
          refType: 'invoice',
          refId: invoice.id),
      LedgerEntry(
          entryDate: invoice.issueDate,
          account: 'Sales Revenue',
          description: 'Invoice ${invoice.invoiceNumber} — subtotal',
          credit: invoice.subtotal,
          refType: 'invoice',
          refId: invoice.id),
      if (invoice.tax > 0)
        LedgerEntry(
            entryDate: invoice.issueDate,
            account: 'Tax Payable',
            description: 'Invoice ${invoice.invoiceNumber} — tax',
            credit: invoice.tax,
            refType: 'invoice',
            refId: invoice.id),
    ]);
    postNotification(tx,
        'Invoice ${invoice.invoiceNumber} created for ${invoice.clientName ?? 'client'}');
  }

  Future<InvoiceRecord> insertInvoice(InvoiceRecord value) async {
    final invoice = value.copyWith(id: value.id ?? newId());
    await transaction((tx) async {
      if ((await tx.get(numberRef(invoice.invoiceNumber))).exists) {
        throw StateError(
            'Invoice number already exists. Please create the invoice again.');
      }
      postInvoice(tx, invoice);
    });
    invalidate();
    return invoice;
  }

  Future<void> updateInvoice(InvoiceRecord invoice) async {
    await transaction((tx) async {
      final snapshot = await tx.get(doc('invoices', invoice.id!));
      if (!snapshot.exists) throw StateError('Invoice no longer exists.');
      final previous = InvoiceRecord.fromMap(snapshot.data()!);
      if (previous.amountPaid > 0 || !previous.isOpen) {
        throw StateError('Only open invoices without payments can be edited.');
      }
      if (previous.invoiceNumber != invoice.invoiceNumber) {
        throw StateError('Invoice numbers cannot be changed.');
      }
      // Keep concurrent payment/status fields authoritative.
      tx.update(snapshot.reference, {
        ...invoice.toMap(),
        'amount_paid': previous.amountPaid,
        'status': previous.status.label,
        'paid_date': previous.paidDate
      });
      postLedger(tx, [
        LedgerEntry(
            entryDate: invoice.issueDate,
            account: 'Accounts Receivable',
            description: 'Invoice adjustment ${invoice.invoiceNumber}',
            debit: invoice.total - previous.total,
            refType: 'invoice',
            refId: invoice.id),
        LedgerEntry(
            entryDate: invoice.issueDate,
            account: 'Sales Revenue',
            description: 'Invoice adjustment ${invoice.invoiceNumber}',
            credit: invoice.subtotal - previous.subtotal,
            refType: 'invoice',
            refId: invoice.id),
        LedgerEntry(
            entryDate: invoice.issueDate,
            account: 'Tax Payable',
            description: 'Invoice adjustment ${invoice.invoiceNumber}',
            credit: invoice.tax - previous.tax,
            refType: 'invoice',
            refId: invoice.id),
      ]);
    });
    invalidate();
  }

  Future<void> setInvoiceStatus(int id, InvoiceStatus status) async {
    if (status == InvoiceStatus.paid) {
      final invoice = await getInvoice(id);
      if (invoice != null && invoice.balanceDue > 0) {
        await recordPayment(
            id, invoice.balanceDue, todayStr(), 'Full settlement', null);
      }
      return;
    }
    await transaction((tx) async {
      final snapshot = await tx.get(doc('invoices', id));
      if (!snapshot.exists) throw StateError('Invoice no longer exists.');
      final invoice = InvoiceRecord.fromMap(snapshot.data()!);
      if (invoice.status == status) return;
      if (invoice.amountPaid > 0) {
        throw StateError('An invoice with payments cannot be cancelled.');
      }
      if (status != InvoiceStatus.cancelled) {
        throw StateError('Unsupported status change.');
      }
      tx.update(snapshot.reference, {'status': status.label});
      postLedger(tx, [
        LedgerEntry(
            entryDate: todayStr(),
            account: 'Accounts Receivable',
            description: 'Cancelled ${invoice.invoiceNumber}',
            credit: invoice.total,
            refType: 'invoice',
            refId: id),
        LedgerEntry(
            entryDate: todayStr(),
            account: 'Sales Revenue',
            description: 'Cancelled ${invoice.invoiceNumber}',
            debit: invoice.subtotal,
            refType: 'invoice',
            refId: id),
        if (invoice.tax > 0)
          LedgerEntry(
              entryDate: todayStr(),
              account: 'Tax Payable',
              description: 'Cancelled ${invoice.invoiceNumber}',
              debit: invoice.tax,
              refType: 'invoice',
              refId: id),
      ]);
    });
    invalidate();
  }

  Future<void> recordPayment(int invoiceId, double amount, String date,
      String method, String? notes) async {
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError('Payment amount must be positive.');
    }
    await transaction((tx) async {
      final snapshot = await tx.get(doc('invoices', invoiceId));
      if (!snapshot.exists) throw StateError('Invoice no longer exists.');
      final invoice = InvoiceRecord.fromMap(snapshot.data()!);
      if (!invoice.isOpen) {
        throw StateError('This invoice is not open for payments.');
      }
      final applied = min(amount, invoice.balanceDue);
      if (applied <= 0) return;
      final paid = invoice.amountPaid + applied;
      final status = paid + 0.0001 >= invoice.total
          ? InvoiceStatus.paid
          : InvoiceStatus.partial;
      final paymentId = newId();
      final receiptId = newId();
      tx.set(
          doc('invoice_payments', paymentId),
          InvoicePayment(
                  id: paymentId,
                  invoiceId: invoiceId,
                  amount: applied,
                  paymentDate: date,
                  method: method,
                  notes: notes)
              .toMap());
      tx.update(snapshot.reference, {
        'amount_paid': paid,
        'status': status.label,
        'paid_date': status == InvoiceStatus.paid ? date : null
      });
      tx.set(
          doc('cash_receipts', receiptId),
          CashReceipt(
                  id: receiptId,
                  amount: applied,
                  receiptDate: date,
                  receivedFrom: invoice.clientName ?? 'Client',
                  notes: notes ?? 'Payment for ${invoice.invoiceNumber}',
                  invoiceId: invoiceId)
              .toMap());
      postLedger(tx, [
        LedgerEntry(
            entryDate: date,
            account: 'Cash',
            description: 'Payment received — ${invoice.invoiceNumber}',
            debit: applied,
            refType: 'payment',
            refId: paymentId),
        LedgerEntry(
            entryDate: date,
            account: 'Accounts Receivable',
            description: 'Payment applied — ${invoice.invoiceNumber}',
            credit: applied,
            refType: 'payment',
            refId: paymentId),
      ]);
      postNotification(tx, 'Received $applied for ${invoice.invoiceNumber}');
    });
    invalidate();
  }

  Future<List<InvoicePayment>> getPaymentsForInvoice(int id) async => sorted(
          (await rows('invoice_payments')).where((r) => r['invoice_id'] == id),
          'payment_date',
          descending: true)
      .map(InvoicePayment.fromMap)
      .toList();
  Future<void> deleteExpenseHead(int id) async {
    if ((await getExpenses()).any((e) => e.headId == id)) {
      throw StateError('This expense head is in use.');
    }
    await delete('expense_heads', id);
  }

  Future<ExpenseRecord> insertExpense(ExpenseRecord expense) async {
    if (!expense.amount.isFinite || expense.amount <= 0) {
      throw ArgumentError('Expense amount must be positive.');
    }
    final id = newId();
    await transaction((tx) async {
      final head = await tx.get(doc('expense_heads', expense.headId));
      if (!head.exists) throw StateError('Expense head no longer exists.');
      tx.set(doc('expenses', id), {...expense.toMap(), 'id': id});
      postLedger(tx, [
        LedgerEntry(
            entryDate: expense.expenseDate,
            account: 'Expense — ${head.data()!['name']}',
            description: expense.notes ?? 'Expense',
            debit: expense.amount,
            refType: 'expense',
            refId: id),
        LedgerEntry(
            entryDate: expense.expenseDate,
            account: 'Cash',
            description: expense.notes ?? 'Expense paid',
            credit: expense.amount,
            refType: 'expense',
            refId: id),
      ]);
    });
    invalidate();
    return ExpenseRecord.fromMap({...expense.toMap(), 'id': id});
  }

  Future<void> _deleteWithJournal(String table, int id, String type) async {
    final entries = await collection('ledger_entries')
        .where('ref_type', isEqualTo: type)
        .get();
    final linked = entries.docs.where((d) => d.data()['ref_id'] == id).toList();
    if (linked.length > 400) {
      throw StateError('Too many journal entries to delete in one operation.');
    }
    await transaction((tx) async {
      tx.delete(doc(table, id));
      for (final entry in linked) {
        tx.delete(entry.reference);
      }
    });
    invalidate();
  }

  Future<void> deleteExpense(int id) =>
      _deleteWithJournal('expenses', id, 'expense');
  Future<List<ExpenseRecord>> getExpenses() async {
    final heads = {for (final h in await getExpenseHeads()) h.id: h.name};
    return sorted(await rows('expenses'), 'expense_date', descending: true)
        .map((r) => ExpenseRecord.fromMap(
            {...r, 'head_name': heads[r['head_id']] ?? ''}))
        .toList();
  }

  Future<List<ExpenseRecord>> getExpensesForMonth(String key) async =>
      (await getExpenses())
          .where((e) => e.expenseDate.startsWith(key))
          .toList()
          .reversed
          .toList();
  Future<double> expensesTotal() async =>
      (await getExpenses()).fold<double>(0, (s, e) => s + e.amount);
  Future<CashReceipt> insertCashReceipt(CashReceipt receipt) async {
    if (!receipt.amount.isFinite || receipt.amount <= 0) {
      throw ArgumentError('Receipt amount must be positive.');
    }
    if (receipt.invoiceId != null) {
      throw ArgumentError('Use recordPayment for invoice receipts.');
    }
    final id = newId();
    await transaction((tx) async {
      tx.set(doc('cash_receipts', id), {...receipt.toMap(), 'id': id});
      postLedger(tx, [
        LedgerEntry(
            entryDate: receipt.receiptDate,
            account: 'Cash',
            description: 'Cash received from ${receipt.receivedFrom}',
            debit: receipt.amount,
            refType: 'cash_receipt',
            refId: id),
        LedgerEntry(
            entryDate: receipt.receiptDate,
            account: 'Other Income',
            description: receipt.notes ?? 'Cash receipt',
            credit: receipt.amount,
            refType: 'cash_receipt',
            refId: id),
      ]);
    });
    invalidate();
    return CashReceipt.fromMap({...receipt.toMap(), 'id': id});
  }

  Future<void> deleteCashReceipt(int id) async {
    final receipt = await doc('cash_receipts', id).get();
    if (receipt.data()?['invoice_id'] != null) {
      throw StateError(
          'Invoice payment receipts cannot be deleted separately.');
    }
    await _deleteWithJournal('cash_receipts', id, 'cash_receipt');
  }

  Future<List<CashReceipt>> getCashReceipts() async {
    final invoices = {
      for (final i in await getInvoices()) i.id: i.invoiceNumber
    };
    return sorted(await rows('cash_receipts'), 'receipt_date', descending: true)
        .map((r) => CashReceipt.fromMap(
            {...r, 'invoice_number': invoices[r['invoice_id']]}))
        .toList();
  }

  Future<List<CashReceipt>> getCashReceiptsForMonth(String key) async =>
      (await getCashReceipts())
          .where((r) => r.receiptDate.startsWith(key))
          .toList()
          .reversed
          .toList();
  Future<double> cashReceiptsTotal() async =>
      (await getCashReceipts()).fold<double>(0, (s, r) => s + r.amount);
  Future<List<LedgerEntry>> getLedgerEntries({int limit = 200}) async =>
      sorted(await rows('ledger_entries'), 'entry_date', descending: true)
          .take(limit)
          .map(LedgerEntry.fromMap)
          .toList();
  Future<List<LedgerEntry>> getLedgerEntriesForAccount(String account) async =>
      sorted(
              (await rows('ledger_entries'))
                  .where((r) => r['account'] == account),
              'entry_date')
          .map(LedgerEntry.fromMap)
          .toList();
  Future<Map<String, double>> ledgerAccountBalances() async {
    final result = <String, double>{};
    for (final row in await rows('ledger_entries')) {
      final entry = LedgerEntry.fromMap(row);
      result.update(entry.account, (n) => n + entry.debit - entry.credit,
          ifAbsent: () => entry.debit - entry.credit);
    }
    return result;
  }

  Future<void> insertNotification(String message) async {
    await insert('notifications', {
      'message': message,
      'created_at': DateTime.now().toIso8601String(),
      'is_read': 0
    });
  }

  Future<List<AppNotification>> getNotifications({int limit = 30}) async =>
      sorted(await rows('notifications'), 'created_at', descending: true)
          .take(limit)
          .map(AppNotification.fromMap)
          .toList();
  Future<int> countUnreadNotifications() async =>
      (await rows('notifications')).where((r) => r['is_read'] == 0).length;
  Future<void> markAllNotificationsRead() async {
    final unread =
        (await rows('notifications')).where((r) => r['is_read'] == 0).toList();
    for (var start = 0; start < unread.length; start += 400) {
      await transaction((tx) async {
        for (final row in unread.skip(start).take(400)) {
          tx.update(doc('notifications', row['id'] as int), {'is_read': 1});
        }
      });
    }
    invalidate();
  }

  Future<double> outstandingTotal() async => (await getInvoices())
      .where((i) => i.isOpen)
      .fold<double>(0, (s, i) => s + i.balanceDue);
  Future<int> overdueCount(String today) async => (await getInvoices())
      .where((i) => i.isOpen && i.dueDate.compareTo(today) < 0)
      .length;
  Future<int> dueThisWeekCount(String today, String weekOut) async =>
      (await getInvoices())
          .where((i) =>
              i.isOpen &&
              i.dueDate.compareTo(today) >= 0 &&
              i.dueDate.compareTo(weekOut) <= 0)
          .length;
  Future<int> activeTemplatesCount() async => (await getTemplates())
      .where((t) => t.status == TemplateStatus.active)
      .length;
  Future<List<RecurringTemplate>> upcomingTemplates({int limit = 8}) async =>
      (await getTemplates())
          .where((t) => t.status == TemplateStatus.active)
          .take(limit)
          .toList();
  Future<Map<String, int>> invoiceStatusCounts() async {
    final result = {
      for (final s in ['Pending', 'Partial', 'Paid', 'Cancelled', 'Overdue'])
        s: 0
    };
    for (final invoice in await getInvoices()) {
      result.update(invoice.displayStatus(todayStr()), (n) => n + 1,
          ifAbsent: () => 1);
    }
    return result;
  }

  Future<List<MonthlyAmount>> _monthly(
      String table, String dateField, String amountField, int months) async {
    final data = await rows(table);
    final now = DateTime.now();
    const labels = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return List.generate(months, (i) {
      final date = DateTime(now.year, now.month - months + i + 1);
      final key =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
      return MonthlyAmount(
          monthKey: key,
          label: labels[date.month - 1],
          amount: data
              .where((r) =>
                  '${r[dateField]}'.startsWith(key) &&
                  r['status'] != 'Cancelled')
              .fold<double>(
                  0, (s, r) => s + (r[amountField] as num).toDouble()));
    });
  }

  Future<List<MonthlyAmount>> monthlyInvoiceTotals({int months = 6}) =>
      _monthly('invoices', 'issue_date', 'total', months);
  Future<List<MonthlyAmount>> monthlyExpenseTotals({int months = 6}) =>
      _monthly('expenses', 'expense_date', 'amount', months);
  Future<List<MonthlyAmount>> monthlyCashReceived({int months = 6}) =>
      _monthly('cash_receipts', 'receipt_date', 'amount', months);
  Future<BusinessSettings> getBusinessSettings() async {
    final settings =
        (await rows('business_settings')).where((r) => r['id'] == 1);
    if (settings.isEmpty) return const BusinessSettings();
    final row = settings.first;
    final encoded = row['logo_base64'] as String?;
    var path = row['logo_path'] as String?;
    if (encoded != null) {
      if (_logoData != encoded ||
          _logoPath == null ||
          !await File(_logoPath!).exists()) {
        final documents = await getApplicationDocumentsDirectory();
        final file =
            File(p.join(documents.path, 'firestore_business_logo.png'));
        await file.writeAsBytes(base64Decode(encoded), flush: true);
        _logoData = encoded;
        _logoPath = file.path;
      }
      path = _logoPath;
    } else if (path != null && !await File(path).exists()) {
      path = null;
    }
    return BusinessSettings.fromMap({...row, 'logo_path': path});
  }

  Future<void> saveBusinessSettings(BusinessSettings settings) async {
    final data = settings.toMap();
    final path = settings.logoPath;
    if (path != null && await File(path).exists()) {
      final bytes = await File(path).readAsBytes();
      if (bytes.length > 650000) {
        throw StateError('Choose a business logo smaller than 650 KB.');
      }
      data['logo_base64'] = base64Encode(bytes);
    }
    await transaction((tx) async {
      tx.set(doc('business_settings', 1), data);
    });
    invalidate();
  }

  Future<Map<String, List<Map<String, dynamic>>>> exportCloudTables() async =>
      {for (final table in cloudTables) table: await rows(table)};
  Future<void> createSnapshot(String path) async {
    await File(path).writeAsString(
        jsonEncode({'schema': 7, 'tables': await exportCloudTables()}),
        flush: true);
  }

  Future<void> restoreSnapshot(String path, {bool legacy = false}) async {
    final Map<String, List<Map<String, dynamic>>> tables;
    if (legacy) {
      tables = await LegacySqliteDatabase.readSnapshot(path);
    } else {
      final decoded =
          jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
      if (decoded['schema'] != 7 || decoded['tables'] is! Map) {
        throw const FormatException('Unsupported ledger snapshot.');
      }
      tables = {
        for (final e in (decoded['tables'] as Map<String, dynamic>).entries)
          e.key: (e.value as List)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList()
      };
    }
    await replaceCloudTables(tables);
  }

  /// Stage an entire backup in an invisible generation, then publish one
  /// pointer atomically. Failed uploads never expose a half-restored ledger.
  Future<void> replaceCloudTables(
      Map<String, List<Map<String, dynamic>>> tables) async {
    final parsers = <String, Object Function(Map<String, dynamic>)>{
      'clients': Client.fromMap,
      'templates': RecurringTemplate.fromMap,
      'invoices': InvoiceRecord.fromMap,
      'invoice_payments': InvoicePayment.fromMap,
      'expense_heads': ExpenseHead.fromMap,
      'expenses': ExpenseRecord.fromMap,
      'cash_receipts': CashReceipt.fromMap,
      'ledger_entries': LedgerEntry.fromMap,
      'tax_rates': TaxRate.fromMap,
      'business_settings': BusinessSettings.fromMap,
      'payment_options': PaymentOption.fromMap,
      'notifications': AppNotification.fromMap,
    };
    for (final table in cloudTables) {
      if (!tables.containsKey(table)) {
        throw FormatException('Backup is missing $table.');
      }
      final ids = <int>{};
      for (final row in tables[table]!) {
        if (row['id'] is! int || !ids.add(row['id'] as int)) {
          throw FormatException('Invalid or duplicate record ID in $table.');
        }
        parsers[table]!(row);
      }
    }
    final invoiceNumbers = <String>{};
    for (final invoice in tables['invoices']!) {
      if (!invoiceNumbers.add(invoice['invoice_number'] as String)) {
        throw const FormatException('Duplicate invoice number in backup.');
      }
    }
    final generation = '${newId()}-${newId()}';
    final root = user.collection('datasets').doc(generation);
    final writes = <({
      DocumentReference<Map<String, dynamic>> ref,
      Map<String, dynamic> row
    })>[
      for (final table in cloudTables)
        for (final row in tables[table]!)
          (ref: root.collection(table).doc('${row['id']}'), row: row),
      for (final invoice in tables['invoices']!)
        (
          ref: root.collection('invoice_numbers').doc(base64Url
              .encode(utf8.encode(invoice['invoice_number'] as String))),
          row: {'invoiceId': invoice['id']}
        ),
    ];
    for (var start = 0; start < writes.length; start += 100) {
      final batch = firestore.batch();
      for (final write in writes.skip(start).take(100)) {
        batch.set(write.ref, write.row);
      }
      await batch.commit();
    }
    final previous = _dataset;
    final storage = user.collection('metadata').doc('storage');
    await transaction((tx) async {
      final current = await tx.get(storage);
      if (current.data()?['activeDataset'] != previous) {
        throw StateError(
            'Another device restored the ledger. Refresh before trying again.');
      }
      tx.set(storage, {
        'schema': 7,
        'activeDataset': generation,
        'updatedAt': FieldValue.serverTimestamp()
      });
    });
    await _selectDataset(generation);
  }

  Future<List<Client>> getClients() async =>
      sorted(await rows('clients'), 'name').map(Client.fromMap).toList();
  Future<Client> insertClient(Client value) async =>
      Client.fromMap(await insert('clients', value.toMap()));
  Future<void> updateClient(Client value) =>
      update('clients', value.id, value.toMap());
  Future<RecurringTemplate> insertTemplate(RecurringTemplate value) async =>
      RecurringTemplate.fromMap(await insert('templates', value.toMap()));
  Future<void> deleteTemplate(int id) => delete('templates', id);

  Future<List<TaxRate>> getTaxRates() async =>
      sorted(await rows('tax_rates'), 'sort_order')
          .map(TaxRate.fromMap)
          .toList();
  Future<TaxRate> insertTaxRate(TaxRate value) async =>
      TaxRate.fromMap(await insert('tax_rates', value.toMap()));
  Future<void> updateTaxRate(TaxRate value) =>
      update('tax_rates', value.id, value.toMap());
  Future<void> deleteTaxRate(int id) => delete('tax_rates', id);

  Future<List<ExpenseHead>> getExpenseHeads() async =>
      sorted(await rows('expense_heads'), 'sort_order')
          .map(ExpenseHead.fromMap)
          .toList();
  Future<ExpenseHead> insertExpenseHead(ExpenseHead value) async =>
      ExpenseHead.fromMap(await insert('expense_heads', value.toMap()));
  Future<void> updateExpenseHead(ExpenseHead value) =>
      update('expense_heads', value.id, value.toMap());

  Future<List<PaymentOption>> getPaymentOptions() async =>
      sorted(await rows('payment_options'), 'sort_order')
          .map(PaymentOption.fromMap)
          .toList();
  Future<PaymentOption> insertPaymentOption(PaymentOption value) async =>
      PaymentOption.fromMap(await insert('payment_options', value.toMap()));
  Future<void> updatePaymentOption(PaymentOption value) =>
      update('payment_options', value.id, value.toMap());
  Future<void> deletePaymentOption(int id) => delete('payment_options', id);
}
