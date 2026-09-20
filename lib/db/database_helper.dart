import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import '../util/date_utils.dart';

/// Singleton wrapper around the on-device SQLite database.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  Database? _db;

  Future<String> get databasePath async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'ledger.db');
  }

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = await databasePath;
    return openDatabase(
      path,
      version: 6,
      onCreate: (db, version) async {
        await _createV5Core(db);
        await _createV6Tables(db);
        await _seedV6Defaults(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS business_settings (
              id INTEGER PRIMARY KEY,
              business_name TEXT NOT NULL DEFAULT 'INVOICES RO',
              business_subtitle TEXT,
              phone TEXT,
              email TEXT,
              address TEXT,
              logo_path TEXT,
              payment_bank_name TEXT,
              payment_account_number TEXT,
              payment_swift TEXT,
              payment_card_url TEXT,
              signature_name TEXT,
              signature_title TEXT,
              terms TEXT
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS payment_options (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              label TEXT NOT NULL,
              details TEXT NOT NULL DEFAULT '',
              sort_order INTEGER NOT NULL DEFAULT 0
            )
          ''');
        }
        if (oldVersion < 4) {
          await _addColumnIfMissing(
            db,
            'business_settings',
            'currency_code',
            "TEXT NOT NULL DEFAULT 'USD'",
          );
          await _addColumnIfMissing(
            db,
            'business_settings',
            'currency_symbol',
            "TEXT NOT NULL DEFAULT '\$'",
          );
        }
        if (oldVersion < 5) {
          await db.transaction((txn) async {
            await txn.execute('''
              CREATE TABLE invoices_v5 (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                template_id INTEGER REFERENCES templates(id),
                invoice_number TEXT NOT NULL UNIQUE,
                client_id INTEGER REFERENCES clients(id),
                client_name TEXT NOT NULL DEFAULT '',
                client_email TEXT,
                client_phone TEXT,
                client_address TEXT,
                items_json TEXT NOT NULL,
                subtotal REAL NOT NULL,
                tax REAL NOT NULL,
                total REAL NOT NULL,
                issue_date TEXT NOT NULL,
                due_date TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'Pending',
                paid_date TEXT
              )
            ''');
            await txn.execute('''
              INSERT INTO invoices_v5 (
                id, template_id, invoice_number, client_id,
                client_name, client_email, client_phone, client_address,
                items_json, subtotal, tax, total, issue_date, due_date,
                status, paid_date
              )
              SELECT i.id, i.template_id, i.invoice_number, i.client_id,
                COALESCE(c.name, ''), c.email, c.phone, c.address,
                i.items_json, i.subtotal, i.tax, i.total, i.issue_date,
                i.due_date, i.status, i.paid_date
              FROM invoices i
              LEFT JOIN clients c ON c.id = i.client_id
            ''');
            await txn.execute('DROP TABLE invoices');
            await txn.execute('ALTER TABLE invoices_v5 RENAME TO invoices');
          });
        }
        if (oldVersion < 6) {
          await _addColumnIfMissing(
            db,
            'invoices',
            'amount_paid',
            'REAL NOT NULL DEFAULT 0',
          );
          await _addColumnIfMissing(
            db,
            'invoices',
            'tax_rate_percent',
            'REAL NOT NULL DEFAULT 0',
          );
          await db.execute(
            "UPDATE invoices SET amount_paid = total WHERE status = 'Paid'",
          );
          await _createV6Tables(db);
          await _seedV6Defaults(db);
        }
      },
    );
  }

  Future<void> _createV5Core(Database db) async {
    await db.execute('''
      CREATE TABLE clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        address TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id INTEGER NOT NULL REFERENCES clients(id),
        items_json TEXT NOT NULL,
        tax_rate REAL NOT NULL DEFAULT 0,
        frequency TEXT NOT NULL,
        interval_days INTEGER,
        start_date TEXT NOT NULL,
        next_due_date TEXT NOT NULL,
        payment_terms_days INTEGER NOT NULL DEFAULT 14,
        end_type TEXT NOT NULL DEFAULT 'never',
        end_value TEXT,
        occurrences_generated INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'active',
        notes TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        template_id INTEGER REFERENCES templates(id),
        invoice_number TEXT NOT NULL UNIQUE,
        client_id INTEGER REFERENCES clients(id),
        client_name TEXT NOT NULL DEFAULT '',
        client_email TEXT,
        client_phone TEXT,
        client_address TEXT,
        items_json TEXT NOT NULL,
        subtotal REAL NOT NULL,
        tax REAL NOT NULL,
        tax_rate_percent REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL,
        amount_paid REAL NOT NULL DEFAULT 0,
        issue_date TEXT NOT NULL,
        due_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'Pending',
        paid_date TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        message TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_read INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE business_settings (
        id INTEGER PRIMARY KEY,
        business_name TEXT NOT NULL DEFAULT 'INVOICES RO',
        business_subtitle TEXT,
        phone TEXT,
        email TEXT,
        address TEXT,
        logo_path TEXT,
        currency_code TEXT NOT NULL DEFAULT 'USD',
        currency_symbol TEXT NOT NULL DEFAULT '\$',
        payment_bank_name TEXT,
        payment_account_number TEXT,
        payment_swift TEXT,
        payment_card_url TEXT,
        signature_name TEXT,
        signature_title TEXT,
        terms TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE payment_options (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        label TEXT NOT NULL,
        details TEXT NOT NULL DEFAULT '',
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _createV6Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tax_rates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        rate_percent REAL NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoice_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL REFERENCES invoices(id),
        amount REAL NOT NULL,
        payment_date TEXT NOT NULL,
        method TEXT NOT NULL DEFAULT 'Cash',
        notes TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expense_heads (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        head_id INTEGER NOT NULL REFERENCES expense_heads(id),
        amount REAL NOT NULL,
        expense_date TEXT NOT NULL,
        notes TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cash_receipts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        receipt_date TEXT NOT NULL,
        received_from TEXT NOT NULL DEFAULT '',
        notes TEXT,
        invoice_id INTEGER REFERENCES invoices(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ledger_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entry_date TEXT NOT NULL,
        account TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        debit REAL NOT NULL DEFAULT 0,
        credit REAL NOT NULL DEFAULT 0,
        ref_type TEXT,
        ref_id INTEGER
      )
    ''');
  }

  Future<void> _seedV6Defaults(Database db) async {
    final taxCount =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM tax_rates')) ??
            0;
    if (taxCount == 0) {
      await db.insert('tax_rates', {
        'name': 'No Tax',
        'rate_percent': 0,
        'sort_order': 0,
      });
      await db.insert('tax_rates', {
        'name': 'VAT 5%',
        'rate_percent': 5,
        'sort_order': 1,
      });
      await db.insert('tax_rates', {
        'name': 'VAT 10%',
        'rate_percent': 10,
        'sort_order': 2,
      });
      await db.insert('tax_rates', {
        'name': 'VAT 15%',
        'rate_percent': 15,
        'sort_order': 3,
      });
    }

    final headCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM expense_heads')) ??
        0;
    if (headCount == 0) {
      const heads = [
        'Office',
        'Travel',
        'Utilities',
        'Supplies',
        'Marketing',
        'Other',
      ];
      for (var i = 0; i < heads.length; i++) {
        await db.insert('expense_heads', {
          'name': heads[i],
          'sort_order': i,
        });
      }
    }
  }

  Future<void> createSnapshot(String destinationPath) async {
    final db = await database;
    final destination = File(destinationPath);
    if (await destination.exists()) await destination.delete();
    final escaped = destinationPath.replaceAll("'", "''");
    await db.execute("VACUUM INTO '$escaped'");
  }

  Future<void> restoreSnapshot(String sourcePath) async {
    await _db?.close();
    _db = null;
    final target = File(await databasePath);
    await target.parent.create(recursive: true);
    await File(sourcePath).copy(target.path);
    await database;
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final exists = info.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  // ---------- Clients ----------

  Future<Client> insertClient(Client client) async {
    final db = await database;
    final id = await db.insert('clients', client.toMap());
    return client.copyWith(id: id);
  }

  Future<void> updateClient(Client client) async {
    final db = await database;
    await db.update('clients', client.toMap(),
        where: 'id = ?', whereArgs: [client.id]);
  }

  Future<void> deleteClient(int id) async {
    final db = await database;
    await db.delete('templates', where: 'client_id = ?', whereArgs: [id]);
    await db.delete('clients', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Client>> getClients() async {
    final db = await database;
    final rows = await db.query('clients', orderBy: 'name ASC');
    return rows.map((r) => Client.fromMap(r)).toList();
  }

  Future<Client?> getClient(int id) async {
    final db = await database;
    final rows =
        await db.query('clients', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Client.fromMap(rows.first);
  }

  // ---------- Recurring templates ----------

  Future<RecurringTemplate> insertTemplate(RecurringTemplate template) async {
    final db = await database;
    final id = await db.insert('templates', template.toMap());
    return template.withId(id);
  }

  Future<List<RecurringTemplate>> getTemplates() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT t.*, c.name as client_name
      FROM templates t JOIN clients c ON c.id = t.client_id
      ORDER BY t.next_due_date ASC
    ''');
    return rows.map((r) => RecurringTemplate.fromMap(r)).toList();
  }

  Future<List<RecurringTemplate>> getActiveDueTemplates(String today) async {
    final db = await database;
    final rows = await db.query(
      'templates',
      where: "status = 'active' AND next_due_date <= ?",
      whereArgs: [today],
    );
    return rows.map((r) => RecurringTemplate.fromMap(r)).toList();
  }

  Future<void> updateTemplateStatus(int id, TemplateStatus status) async {
    final db = await database;
    await db.update('templates', {'status': status.name},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateTemplateProgress(
      int id, String nextDueDate, int occurrencesGenerated) async {
    final db = await database;
    await db.update(
      'templates',
      {
        'next_due_date': nextDueDate,
        'occurrences_generated': occurrencesGenerated
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteTemplate(int id) async {
    final db = await database;
    await db.delete('templates', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Invoices ----------

  Future<InvoiceRecord> insertInvoice(InvoiceRecord invoice) async {
    final db = await database;
    final id = await db.insert('invoices', invoice.toMap());
    return invoice.copyWith(id: id);
  }

  Future<void> updateInvoice(InvoiceRecord invoice) async {
    final db = await database;
    await db.update(
      'invoices',
      invoice.toMap(),
      where: 'id = ?',
      whereArgs: [invoice.id],
    );
  }

  Future<InvoiceRecord?> getInvoice(int id) async {
    final db = await database;
    final rows =
        await db.query('invoices', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return InvoiceRecord.fromMap(rows.first);
  }

  Future<int> countInvoices() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as c FROM invoices');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<InvoiceRecord>> getInvoices({String? status}) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT i.*
      FROM invoices i
      ORDER BY i.due_date DESC
    ''');
    var invoices = rows.map((r) => InvoiceRecord.fromMap(r)).toList();
    if (status != null && status != 'All') {
      final today = todayStr();
      invoices =
          invoices.where((inv) => inv.displayStatus(today) == status).toList();
    }
    return invoices;
  }

  Future<void> setInvoiceStatus(int id, InvoiceStatus status) async {
    final db = await database;
    final paidDate = status == InvoiceStatus.paid ? todayStr() : null;
    final updates = <String, Object?>{
      'status': status.label,
      if (paidDate != null) 'paid_date': paidDate,
    };
    if (status == InvoiceStatus.paid) {
      final inv = await getInvoice(id);
      if (inv != null) updates['amount_paid'] = inv.total;
    }
    await db.update('invoices', updates, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateInvoicePaymentState({
    required int invoiceId,
    required double amountPaid,
    required InvoiceStatus status,
    String? paidDate,
  }) async {
    final db = await database;
    await db.update(
      'invoices',
      {
        'amount_paid': amountPaid,
        'status': status.label,
        'paid_date': paidDate,
      },
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
  }

  // ---------- Invoice payments ----------

  Future<InvoicePayment> insertInvoicePayment(InvoicePayment payment) async {
    final db = await database;
    final id = await db.insert('invoice_payments', payment.toMap());
    return InvoicePayment(
      id: id,
      invoiceId: payment.invoiceId,
      amount: payment.amount,
      paymentDate: payment.paymentDate,
      method: payment.method,
      notes: payment.notes,
    );
  }

  Future<List<InvoicePayment>> getPaymentsForInvoice(int invoiceId) async {
    final db = await database;
    final rows = await db.query(
      'invoice_payments',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
      orderBy: 'payment_date DESC, id DESC',
    );
    return rows.map((r) => InvoicePayment.fromMap(r)).toList();
  }

  // ---------- Tax rates ----------

  Future<List<TaxRate>> getTaxRates() async {
    final db = await database;
    final rows = await db.query('tax_rates', orderBy: 'sort_order ASC, id ASC');
    return rows.map((r) => TaxRate.fromMap(r)).toList();
  }

  Future<TaxRate> insertTaxRate(TaxRate rate) async {
    final db = await database;
    final id = await db.insert('tax_rates', rate.toMap());
    return TaxRate(
      id: id,
      name: rate.name,
      ratePercent: rate.ratePercent,
      sortOrder: rate.sortOrder,
    );
  }

  Future<void> updateTaxRate(TaxRate rate) async {
    final db = await database;
    await db.update('tax_rates', rate.toMap(),
        where: 'id = ?', whereArgs: [rate.id]);
  }

  Future<void> deleteTaxRate(int id) async {
    final db = await database;
    await db.delete('tax_rates', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Expense heads / expenses ----------

  Future<List<ExpenseHead>> getExpenseHeads() async {
    final db = await database;
    final rows =
        await db.query('expense_heads', orderBy: 'sort_order ASC, id ASC');
    return rows.map((r) => ExpenseHead.fromMap(r)).toList();
  }

  Future<ExpenseHead> insertExpenseHead(ExpenseHead head) async {
    final db = await database;
    final id = await db.insert('expense_heads', head.toMap());
    return ExpenseHead(id: id, name: head.name, sortOrder: head.sortOrder);
  }

  Future<void> updateExpenseHead(ExpenseHead head) async {
    final db = await database;
    await db.update('expense_heads', head.toMap(),
        where: 'id = ?', whereArgs: [head.id]);
  }

  Future<void> deleteExpenseHead(int id) async {
    final db = await database;
    await db.delete('expenses', where: 'head_id = ?', whereArgs: [id]);
    await db.delete('expense_heads', where: 'id = ?', whereArgs: [id]);
  }

  Future<ExpenseRecord> insertExpense(ExpenseRecord expense) async {
    final db = await database;
    final id = await db.insert('expenses', expense.toMap());
    return ExpenseRecord(
      id: id,
      headId: expense.headId,
      headName: expense.headName,
      amount: expense.amount,
      expenseDate: expense.expenseDate,
      notes: expense.notes,
    );
  }

  Future<void> deleteExpense(int id) async {
    final db = await database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ExpenseRecord>> getExpenses() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT e.*, h.name as head_name
      FROM expenses e
      JOIN expense_heads h ON h.id = e.head_id
      ORDER BY e.expense_date DESC, e.id DESC
    ''');
    return rows.map((r) => ExpenseRecord.fromMap(r)).toList();
  }

  Future<double> expensesTotal() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COALESCE(SUM(amount), 0) as s FROM expenses');
    return (result.first['s'] as num?)?.toDouble() ?? 0;
  }

  // ---------- Cash receipts ----------

  Future<CashReceipt> insertCashReceipt(CashReceipt receipt) async {
    final db = await database;
    final id = await db.insert('cash_receipts', receipt.toMap());
    return CashReceipt(
      id: id,
      amount: receipt.amount,
      receiptDate: receipt.receiptDate,
      receivedFrom: receipt.receivedFrom,
      notes: receipt.notes,
      invoiceId: receipt.invoiceId,
      invoiceNumber: receipt.invoiceNumber,
    );
  }

  Future<void> deleteCashReceipt(int id) async {
    final db = await database;
    await db.delete('cash_receipts', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<CashReceipt>> getCashReceipts() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT r.*, i.invoice_number
      FROM cash_receipts r
      LEFT JOIN invoices i ON i.id = r.invoice_id
      ORDER BY r.receipt_date DESC, r.id DESC
    ''');
    return rows.map((r) => CashReceipt.fromMap(r)).toList();
  }

  Future<double> cashReceiptsTotal() async {
    final db = await database;
    final result = await db
        .rawQuery('SELECT COALESCE(SUM(amount), 0) as s FROM cash_receipts');
    return (result.first['s'] as num?)?.toDouble() ?? 0;
  }

  // ---------- Ledger ----------

  Future<void> insertLedgerEntries(List<LedgerEntry> entries) async {
    if (entries.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final entry in entries) {
      batch.insert('ledger_entries', entry.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<LedgerEntry>> getLedgerEntries({int limit = 200}) async {
    final db = await database;
    final rows = await db.query(
      'ledger_entries',
      orderBy: 'entry_date DESC, id DESC',
      limit: limit,
    );
    return rows.map((r) => LedgerEntry.fromMap(r)).toList();
  }

  Future<List<LedgerEntry>> getLedgerEntriesForAccount(String account) async {
    final db = await database;
    final rows = await db.query(
      'ledger_entries',
      where: 'account = ?',
      whereArgs: [account],
      orderBy: 'entry_date ASC, id ASC',
    );
    return rows.map((r) => LedgerEntry.fromMap(r)).toList();
  }

  Future<List<CashReceipt>> getCashReceiptsForMonth(String monthKey) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT r.*, i.invoice_number
      FROM cash_receipts r
      LEFT JOIN invoices i ON i.id = r.invoice_id
      WHERE substr(r.receipt_date, 1, 7) = ?
      ORDER BY r.receipt_date ASC, r.id ASC
    ''', [monthKey]);
    return rows.map((r) => CashReceipt.fromMap(r)).toList();
  }

  Future<List<ExpenseRecord>> getExpensesForMonth(String monthKey) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT e.*, h.name as head_name
      FROM expenses e
      JOIN expense_heads h ON h.id = e.head_id
      WHERE substr(e.expense_date, 1, 7) = ?
      ORDER BY e.expense_date ASC, e.id ASC
    ''', [monthKey]);
    return rows.map((r) => ExpenseRecord.fromMap(r)).toList();
  }

  Future<Map<String, double>> ledgerAccountBalances() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT account,
             COALESCE(SUM(debit), 0) as debit_sum,
             COALESCE(SUM(credit), 0) as credit_sum
      FROM ledger_entries
      GROUP BY account
      ORDER BY account ASC
    ''');
    final map = <String, double>{};
    for (final row in rows) {
      final account = row['account'] as String;
      final debit = (row['debit_sum'] as num?)?.toDouble() ?? 0;
      final credit = (row['credit_sum'] as num?)?.toDouble() ?? 0;
      map[account] = debit - credit;
    }
    return map;
  }

  // ---------- Notifications ----------

  Future<void> insertNotification(String message) async {
    final db = await database;
    await db.insert('notifications', {
      'message': message,
      'created_at': DateTime.now().toIso8601String(),
      'is_read': 0,
    });
  }

  Future<List<AppNotification>> getNotifications({int limit = 30}) async {
    final db = await database;
    final rows = await db.query('notifications',
        orderBy: 'created_at DESC', limit: limit);
    return rows.map((r) => AppNotification.fromMap(r)).toList();
  }

  Future<int> countUnreadNotifications() async {
    final db = await database;
    final result = await db
        .rawQuery('SELECT COUNT(*) as c FROM notifications WHERE is_read = 0');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> markAllNotificationsRead() async {
    final db = await database;
    await db.update('notifications', {'is_read': 1}, where: 'is_read = 0');
  }

  // ---------- Dashboard aggregates ----------

  Future<double> outstandingTotal() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(total - amount_paid), 0) as s
      FROM invoices
      WHERE status IN ('Pending', 'Partial')
    ''');
    return (result.first['s'] as num?)?.toDouble() ?? 0;
  }

  Future<int> overdueCount(String today) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as c FROM invoices
      WHERE status IN ('Pending', 'Partial') AND due_date < ?
      ''',
      [today],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> dueThisWeekCount(String today, String weekOut) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as c FROM invoices
      WHERE status IN ('Pending', 'Partial') AND due_date BETWEEN ? AND ?
      ''',
      [today, weekOut],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> activeTemplatesCount() async {
    final db = await database;
    final result = await db.rawQuery(
        "SELECT COUNT(*) as c FROM templates WHERE status = 'active'");
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<RecurringTemplate>> upcomingTemplates({int limit = 8}) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT t.*, c.name as client_name
      FROM templates t JOIN clients c ON c.id = t.client_id
      WHERE t.status = 'active'
      ORDER BY t.next_due_date ASC LIMIT ?
    ''', [limit]);
    return rows.map((r) => RecurringTemplate.fromMap(r)).toList();
  }

  Future<Map<String, int>> invoiceStatusCounts() async {
    final invoices = await getInvoices();
    final today = todayStr();
    final map = <String, int>{
      'Pending': 0,
      'Partial': 0,
      'Paid': 0,
      'Cancelled': 0,
      'Overdue': 0,
    };
    for (final inv in invoices) {
      final key = inv.displayStatus(today);
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  Future<List<MonthlyAmount>> monthlyInvoiceTotals({int months = 6}) async {
    final db = await database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - (months - 1), 1);
    final startKey =
        '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}';
    final rows = await db.rawQuery('''
      SELECT substr(issue_date, 1, 7) as month_key,
             COALESCE(SUM(total), 0) as amount
      FROM invoices
      WHERE status != 'Cancelled' AND substr(issue_date, 1, 7) >= ?
      GROUP BY month_key
      ORDER BY month_key ASC
    ''', [startKey]);
    final byMonth = {
      for (final row in rows)
        row['month_key'] as String: (row['amount'] as num?)?.toDouble() ?? 0.0
    };
    return _fillMonthlySeries(months, byMonth);
  }

  Future<List<MonthlyAmount>> monthlyExpenseTotals({int months = 6}) async {
    final db = await database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - (months - 1), 1);
    final startKey =
        '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}';
    final rows = await db.rawQuery('''
      SELECT substr(expense_date, 1, 7) as month_key,
             COALESCE(SUM(amount), 0) as amount
      FROM expenses
      WHERE substr(expense_date, 1, 7) >= ?
      GROUP BY month_key
      ORDER BY month_key ASC
    ''', [startKey]);
    final byMonth = {
      for (final row in rows)
        row['month_key'] as String: (row['amount'] as num?)?.toDouble() ?? 0.0
    };
    return _fillMonthlySeries(months, byMonth);
  }

  Future<List<MonthlyAmount>> monthlyCashReceived({int months = 6}) async {
    final db = await database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - (months - 1), 1);
    final startKey =
        '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}';
    final rows = await db.rawQuery('''
      SELECT substr(receipt_date, 1, 7) as month_key,
             COALESCE(SUM(amount), 0) as amount
      FROM cash_receipts
      WHERE substr(receipt_date, 1, 7) >= ?
      GROUP BY month_key
      ORDER BY month_key ASC
    ''', [startKey]);
    final byMonth = {
      for (final row in rows)
        row['month_key'] as String: (row['amount'] as num?)?.toDouble() ?? 0.0
    };
    return _fillMonthlySeries(months, byMonth);
  }

  List<MonthlyAmount> _fillMonthlySeries(
      int months, Map<String, double> byMonth) {
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
    final result = <MonthlyAmount>[];
    for (var i = months - 1; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final key =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
      result.add(MonthlyAmount(
        monthKey: key,
        label: labels[date.month - 1],
        amount: byMonth[key] ?? 0,
      ));
    }
    return result;
  }

  // ---------- Business settings ----------

  Future<BusinessSettings> getBusinessSettings() async {
    final db = await database;
    final rows = await db.query(
      'business_settings',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (rows.isEmpty) return const BusinessSettings();
    return BusinessSettings.fromMap(rows.first);
  }

  Future<void> saveBusinessSettings(BusinessSettings settings) async {
    final db = await database;
    await db.insert(
      'business_settings',
      settings.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---------- Payment options ----------

  Future<List<PaymentOption>> getPaymentOptions() async {
    final db = await database;
    final rows = await db.query(
      'payment_options',
      orderBy: 'sort_order ASC, id ASC',
    );
    return rows.map((r) => PaymentOption.fromMap(r)).toList();
  }

  Future<PaymentOption> insertPaymentOption(PaymentOption option) async {
    final db = await database;
    final id = await db.insert('payment_options', option.toMap());
    return PaymentOption(
      id: id,
      label: option.label,
      details: option.details,
      sortOrder: option.sortOrder,
    );
  }

  Future<void> updatePaymentOption(PaymentOption option) async {
    final db = await database;
    await db.update(
      'payment_options',
      option.toMap(),
      where: 'id = ?',
      whereArgs: [option.id],
    );
  }

  Future<void> deletePaymentOption(int id) async {
    final db = await database;
    await db.delete('payment_options', where: 'id = ?', whereArgs: [id]);
  }
}
