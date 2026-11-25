import 'dart:math';

import '../models/models.dart';
import '../util/date_utils.dart';
import 'database_helper.dart';

/// Re-reads and advances each template inside the invoice transaction. Firestore
/// retries concurrent edits; only one device can generate a given occurrence.
class GenerationEngine {
  final DatabaseHelper db;
  GenerationEngine(this.db);

  Future<int> run() async {
    final today = todayStr();
    final templates = await db.getActiveDueTemplates(today);
    if (templates.isEmpty) return 0;
    final existing = await db.getInvoices();
    final floor = existing.fold<int>(
        0,
        (value, invoice) => max(
            value, int.tryParse(invoice.invoiceNumber.split('-').last) ?? 0));
    var count = 0;
    for (final template in templates) {
      for (var guard = 0; guard < 500; guard++) {
        final created = await db.transaction((tx) async {
          final snapshot = await tx.get(db.doc('templates', template.id!));
          if (!snapshot.exists) return false;
          final current = RecurringTemplate.fromMap(snapshot.data()!);
          if (current.status != TemplateStatus.active ||
              current.nextDueDate.compareTo(today) > 0) {
            return false;
          }
          final ended = (current.endType == EndType.count &&
                  current.occurrencesGenerated >=
                      (int.tryParse(current.endValue ?? '') ?? 0)) ||
              (current.endType == EndType.date &&
                  current.endValue != null &&
                  current.nextDueDate.compareTo(current.endValue!) > 0);
          if (ended) {
            tx.update(
                snapshot.reference, {'status': TemplateStatus.ended.name});
            return false;
          }
          final clientSnapshot =
              await tx.get(db.doc('clients', current.clientId));
          if (!clientSnapshot.exists) {
            throw StateError(
                'A recurring template references a missing client.');
          }
          final counter = db.user.collection('metadata').doc('invoice_counter');
          final counterSnapshot = await tx.get(counter);
          final sequence = max(floor,
                  (counterSnapshot.data()?['value'] as num?)?.toInt() ?? 0) +
              1;
          final number =
              'INV-${current.nextDueDate.substring(0, 4)}-${sequence.toString().padLeft(4, '0')}';
          final numberSnapshot = await tx.get(db.numberRef(number));
          if (numberSnapshot.exists) {
            throw StateError('Invoice number already exists.');
          }
          final client = Client.fromMap(clientSnapshot.data()!);
          final subtotal = current.items
              .fold<double>(0, (sum, item) => sum + item.lineTotal);
          final tax = subtotal * current.taxRate / 100;
          final issueDate = current.nextDueDate;
          tx.set(counter, {'value': sequence});
          db.postInvoice(
              tx,
              InvoiceRecord(
                id: db.newId(),
                templateId: current.id,
                invoiceNumber: number,
                clientId: current.clientId,
                clientName: client.name,
                clientEmail: client.email,
                clientPhone: client.phone,
                clientAddress: client.address,
                items: current.items,
                subtotal: subtotal,
                tax: tax,
                taxRatePercent: current.taxRate,
                total: subtotal + tax,
                issueDate: issueDate,
                dueDate: addDays(issueDate, current.paymentTermsDays),
              ));
          tx.update(snapshot.reference, {
            'next_due_date':
                advanceDate(issueDate, current.frequency, current.intervalDays),
            'occurrences_generated': current.occurrencesGenerated + 1,
          });
          return true;
        });
        db.invalidate();
        if (!created) break;
        count++;
      }
    }
    return count;
  }
}
