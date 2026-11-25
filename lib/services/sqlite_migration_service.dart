import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../db/database_helper.dart';
import '../db/legacy_sqlite_database.dart';

/// Deterministic IDs make a failed import resumable without overwriting another
/// device's integer IDs. All foreign keys and journal references move together.
class SqliteMigrationPlan {
  static Map<String, List<Map<String, dynamic>>> build(
    Map<String, List<Map<String, dynamic>>> source,
    String installation, {
    required bool preserveIds,
    Set<String> existingInvoiceNumbers = const {},
    bool keepCloudSettings = false,
  }) {
    int id(String table, int old) => preserveIds
        ? old
        : int.parse(
                const Uuid()
                    .v5(Namespace.url.value, '$installation/$table/$old')
                    .replaceAll('-', '')
                    .substring(0, 13),
                radix: 16) +
            1;
    const references = {
      'client_id': 'clients',
      'template_id': 'templates',
      'invoice_id': 'invoices',
      'head_id': 'expense_heads'
    };
    const journalReferences = {
      'invoice': 'invoices',
      'payment': 'invoice_payments',
      'expense': 'expenses',
      'cash_receipt': 'cash_receipts'
    };
    return {
      for (final table in DatabaseHelper.cloudTables)
        table: [
          for (final original in source[table] ?? <Map<String, dynamic>>[])
            if (!(table == 'business_settings' && keepCloudSettings))
              (() {
                final row = Map<String, dynamic>.from(original);
                final oldId = row['id'];
                if (oldId is! int) {
                  throw FormatException('Missing ID in $table.');
                }
                row['id'] = table == 'business_settings' ? 1 : id(table, oldId);
                for (final reference in references.entries) {
                  final old = row[reference.key];
                  if (old is int) row[reference.key] = id(reference.value, old);
                }
                final refTable = journalReferences[row['ref_type']];
                if (refTable != null && row['ref_id'] is int) {
                  row['ref_id'] = id(refTable, row['ref_id'] as int);
                }
                if (table == 'invoices' &&
                    !preserveIds &&
                    existingInvoiceNumbers.contains(row['invoice_number'])) {
                  row['legacy_invoice_number'] = row['invoice_number'];
                  row['invoice_number'] =
                      '${row['invoice_number']}-M${installation.replaceAll('-', '').substring(0, 8)}';
                }
                return row;
              })(),
        ],
    };
  }
}

class SqliteMigrationService {
  SqliteMigrationService(this.db);
  final DatabaseHelper db;

  Future<void> migrate() async {
    final legacy = LegacySqliteDatabase.instance;
    if (!await legacy.exists) return;
    final prefs = await SharedPreferences.getInstance();
    final boundUser = prefs.getString('sqlite_migration_owner');
    if (boundUser != null && boundUser != db.uid) return;
    var installation = prefs.getString('sqlite_migration_installation');
    if (installation == null) {
      installation = const Uuid().v4();
      await prefs.setString('sqlite_migration_installation', installation);
    }
    final completeKey = 'sqlite_migration_complete_${db.uid}_$installation';
    if (prefs.getBool(completeKey) == true) return;
    final marker = db.user.collection('migrations').doc('sqlite_$installation');
    final state = await marker.get(const GetOptions(source: Source.server));
    if (state.data()?['complete'] == true) {
      await prefs.setString('sqlite_migration_owner', db.uid!);
      await prefs.setBool(completeKey, true);
      return;
    }
    // Freeze the source on disk before any remote writes. Retries always use
    // this exact plan, even after an app restart or a partially committed batch.
    final planKey = 'sqlite_migration_plan_${db.uid}';
    final savedPlan = prefs.getString(planKey);
    final Map<String, List<Map<String, dynamic>>> tables;
    if (savedPlan != null) {
      final json = jsonDecode(savedPlan) as Map<String, dynamic>;
      tables = {
        for (final entry in json.entries)
          entry.key: (entry.value as List)
              .map((row) => Map<String, dynamic>.from(row as Map))
              .toList()
      };
    } else {
      final exported = await legacy.exportTables();
      await legacy.close();
      final source = {
        for (final entry in exported.entries)
          entry.key:
              entry.value.map((r) => Map<String, dynamic>.from(r)).toList()
      };
      final remote = <String, List<Map<String, dynamic>>>{};
      for (final table in DatabaseHelper.cloudTables) {
        remote[table] = (await db
                .collection(table)
                .get(const GetOptions(source: Source.server)))
            .docs
            .map((d) => d.data())
            .toList();
      }
      final empty = remote.values.every((rows) => rows.isEmpty);
      final mirrored = source.entries
          .where((entry) => entry.key != 'notifications')
          .every((entry) => entry.value.every((row) =>
              (remote[entry.key] ?? []).any((other) => mapEquals(row, other))));
      tables = SqliteMigrationPlan.build(
        source,
        installation,
        preserveIds: empty || mirrored,
        existingInvoiceNumbers: remote['invoices']!
            .map((r) => r['invoice_number'] as String)
            .toSet(),
        keepCloudSettings:
            !empty && !mirrored && remote['business_settings']!.isNotEmpty,
      );
      for (final settings in tables['business_settings']!) {
        final path = settings['logo_path'] as String?;
        if (path != null && await File(path).exists()) {
          final bytes = await File(path).readAsBytes();
          if (bytes.length > 650000) {
            throw StateError(
                'The business logo exceeds 650 KB. Resize it before importing; the SQLite ledger is preserved.');
          }
          settings['logo_base64'] = base64Encode(bytes);
        }
      }
      await prefs.setString(planKey, jsonEncode(tables));
      // Bind before the first upload so switching Google accounts cannot leak
      // this device's old ledger into an unrelated account.
      await prefs.setString('sqlite_migration_owner', db.uid!);
    }
    final count = await importTables(tables);
    await marker.set({
      'complete': true,
      'schema': 7,
      'records': count,
      'completedAt': FieldValue.serverTimestamp()
    });
    await prefs.setBool(completeKey, true);
    await prefs.remove(planKey);
    db.invalidate();
  }

  /// Idempotently uploads a frozen plan. All reads precede writes in each chunk.
  Future<int> importTables(
      Map<String, List<Map<String, dynamic>>> tables) async {
    final records = [
      for (final table in DatabaseHelper.cloudTables)
        for (final row in tables[table]!) (table: table, row: row)
    ];
    for (var start = 0; start < records.length; start += 100) {
      final chunk = records.skip(start).take(100).toList();
      await db.transaction((tx) async {
        final snapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
        for (final record in chunk) {
          snapshots
              .add(await tx.get(db.doc(record.table, record.row['id'] as int)));
        }
        // Read all documents before writing; never overwrite a conflicting row.
        for (var i = 0; i < chunk.length; i++) {
          final record = chunk[i];
          final snapshot = snapshots[i];
          if (snapshot.exists) {
            if (!mapEquals(snapshot.data(), record.row)) {
              final withoutLogo = Map<String, dynamic>.from(record.row)
                ..remove('logo_base64');
              if (record.table == 'business_settings' &&
                  mapEquals(snapshot.data(), withoutLogo)) {
                tx.set(snapshot.reference, record.row);
              } else {
                throw StateError(
                    'Import conflict in ${record.table}. The original SQLite file is preserved.');
              }
            }
          } else {
            tx.set(snapshot.reference, record.row);
          }
        }
      });
    }
    // Reserve imported numbers before enabling normal writes.
    for (final invoice in tables['invoices']!) {
      final ref = db.numberRef(invoice['invoice_number'] as String);
      await db.transaction((tx) async {
        final current = await tx.get(ref);
        if (current.exists && current.data()?['invoiceId'] != invoice['id']) {
          throw StateError(
              'An imported invoice number conflicts with the cloud ledger.');
        }
        tx.set(ref, {'invoiceId': invoice['id']});
      });
    }
    db.invalidate();
    return records.length;
  }
}
