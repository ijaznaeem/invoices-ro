import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import '../util/date_utils.dart';

/// Singleton wrapper around the on-device SQLite database. Mirrors the
/// schema of the original Node/Express + SQLite version of this app so the
/// data model stays familiar, but everything now lives on the device.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ledger.db');
    return openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
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
            client_id INTEGER NOT NULL REFERENCES clients(id),
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
      },
    );
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

  Future<void> insertInvoice(InvoiceRecord invoice) async {
    final db = await database;
    await db.insert('invoices', invoice.toMap());
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

  Future<int> countInvoices() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as c FROM invoices');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<InvoiceRecord>> getInvoices({String? status}) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT i.*, c.name as client_name
      FROM invoices i LEFT JOIN clients c ON c.id = i.client_id
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
    await db.update(
      'invoices',
      {'status': status.label, if (paidDate != null) 'paid_date': paidDate},
      where: 'id = ?',
      whereArgs: [id],
    );
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
    final result = await db.rawQuery(
        "SELECT COALESCE(SUM(total), 0) as s FROM invoices WHERE status = 'Pending'");
    return (result.first['s'] as num?)?.toDouble() ?? 0;
  }

  Future<int> overdueCount(String today) async {
    final db = await database;
    final result = await db.rawQuery(
        "SELECT COUNT(*) as c FROM invoices WHERE status = 'Pending' AND due_date < ?",
        [today]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> dueThisWeekCount(String today, String weekOut) async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as c FROM invoices WHERE status = 'Pending' AND due_date BETWEEN ? AND ?",
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
