import '../models/models.dart';
import '../util/date_utils.dart';
import 'database_helper.dart';

/// Checks every active recurring template and, for any whose next due date
/// has arrived, generates the next invoice instance plus an activity-feed
/// entry, then advances the template to its following due date. Catches up
/// on any cycles missed while the app was closed, up to a safety cap.
class GenerationEngine {
  final DatabaseHelper db;
  GenerationEngine(this.db);

  Future<int> run() async {
    final today = todayStr();
    final dueTemplates = await db.getActiveDueTemplates(today);
    int generatedCount = 0;

    for (var template in dueTemplates) {
      var current = template;
      int guard = 0;

      while (current.nextDueDate.compareTo(today) <= 0 && guard < 500) {
        guard++;

        if (current.endType == EndType.count &&
            current.occurrencesGenerated >= (int.tryParse(current.endValue ?? '') ?? 0)) {
          await db.updateTemplateStatus(current.id!, TemplateStatus.ended);
          break;
        }
        if (current.endType == EndType.date &&
            current.endValue != null &&
            current.nextDueDate.compareTo(current.endValue!) > 0) {
          await db.updateTemplateStatus(current.id!, TemplateStatus.ended);
          break;
        }

        final subtotal = current.items.fold<double>(0, (s, i) => s + i.lineTotal);
        final tax = subtotal * (current.taxRate / 100);
        final total = subtotal + tax;

        final issueDate = current.nextDueDate;
        final dueDate = addDays(issueDate, current.paymentTermsDays);

        final invoiceCount = await db.countInvoices();
        final invoiceNumber = 'INV-${issueDate.substring(0, 4)}-${(invoiceCount + 1).toString().padLeft(4, '0')}';

        await db.insertInvoice(InvoiceRecord(
          templateId: current.id,
          invoiceNumber: invoiceNumber,
          clientId: current.clientId,
          items: current.items,
          subtotal: subtotal,
          tax: tax,
          total: total,
          issueDate: issueDate,
          dueDate: dueDate,
          status: InvoiceStatus.pending,
        ));

        final client = await db.getClient(current.clientId);
        await db.insertNotification('Generated $invoiceNumber for ${client?.name ?? 'client'} — due $dueDate');

        generatedCount++;

        final newOccurrences = current.occurrencesGenerated + 1;
        final newNextDue = advanceDate(current.nextDueDate, current.frequency, current.intervalDays);
        await db.updateTemplateProgress(current.id!, newNextDue, newOccurrences);

        current = current.copyWith(nextDueDate: newNextDue, occurrencesGenerated: newOccurrences);
      }
    }

    return generatedCount;
  }
}
