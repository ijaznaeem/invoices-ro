import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Compatibility reader for pre-Firestore databases and format-1 backups.
/// Never used for normal application reads or writes.
class LegacySqliteDatabase {
  LegacySqliteDatabase._internal();
  static final LegacySqliteDatabase instance = LegacySqliteDatabase._internal();

  Database? _db;
  static const cloudTables = <String>[
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
  ];

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
    final original = await databasePath;
    final path = '$original.firestore-import';
    // Upgrade a working copy; preserve the original ledger and any WAL bytes.
    if (!await File(path).exists()) {
      await File(original).copy(path);
      final wal = File('$original-wal');
      if (await wal.exists()) await wal.copy('$path-wal');
    }
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
          // onUpgrade already runs inside a sqflite transaction.
          final txn = db;
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
    final taxCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM tax_rates')) ??
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

  Future<Map<String, List<Map<String, Object?>>>> exportTables() async {
    final db = await database;
    return {
      for (final table in [...cloudTables, 'notifications'])
        table: await db.query(table),
    };
  }

  Future<bool> get exists async => File(await databasePath).exists();

  static Future<Map<String, List<Map<String, dynamic>>>> readSnapshot(
      String path) async {
    final db = await openDatabase(path, readOnly: true, singleInstance: false);
    try {
      final tables = <String, List<Map<String, dynamic>>>{};
      for (final table in [...cloudTables, 'notifications']) {
        tables[table] = (await db.query(table))
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
      }
      return tables;
    } finally {
      await db.close();
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
