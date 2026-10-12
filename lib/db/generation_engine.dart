import '../models/models.dart';
import '../util/currency_utils.dart';
import '../util/date_utils.dart';
import 'database_helper.dart';

/// Checks every active recurring invoice and expense schedule. For any whose
/// next due date has arrived, generates the next instance plus an activity
/// feed entry, then advances the schedule. Catches up on cycles missed while
/// the app was closed, up to a safety cap.
class GenerationEngine {
  final DatabaseHelper db;
  GenerationEngine(this.db);

  Future<GenerationRunResult> run() async {
    final invoices = await _generateInvoices();
    final expenses = await _generateExpenses();
    return GenerationRunResult(
      invoicesGenerated: invoices,
      expensesGenerated: expenses,
    );
  }

  Future<int> _generateInvoices() async {
    final today = todayStr();
    final dueTemplates = await db.getActiveDueTemplates(today);
    int generatedCount = 0;

    for (var template in dueTemplates) {
      var current = template;
      int guard = 0;

      while (current.nextDueDate.compareTo(today) <= 0 && guard < 500) {
        guard++;

        if (recurrenceHasEnded(
          endType: current.endType,
          endValue: current.endValue,
          occurrencesGenerated: current.occurrencesGenerated,
          nextDueDate: current.nextDueDate,
        )) {
          await db.updateTemplateStatus(current.id!, TemplateStatus.ended);
          break;
        }

        final subtotal = current.items.fold<double>(
          0,
          (s, i) => s + i.lineTotal,
        );
        final tax = subtotal * (current.taxRate / 100);
        final total = subtotal + tax;

        final issueDate = current.nextDueDate;
        final dueDate = addDays(issueDate, current.paymentTermsDays);

        final invoiceCount = await db.countInvoices();
        final invoiceNumber =
            'INV-${issueDate.substring(0, 4)}-${(invoiceCount + 1).toString().padLeft(4, '0')}';
        final client = current.clientId != null
            ? await db.getClient(current.clientId!)
            : null;
        final clientName = client?.name ?? current.clientName;
        final clientEmail = client?.email ?? current.clientEmail;
        final clientPhone = client?.phone ?? current.clientPhone;
        final clientAddress = client?.address ?? current.clientAddress;

        final saved = await db.insertInvoice(
          InvoiceRecord(
            templateId: current.id,
            invoiceNumber: invoiceNumber,
            clientId: current.clientId,
            clientName: clientName,
            clientEmail: clientEmail,
            clientPhone: clientPhone,
            clientAddress: clientAddress,
            items: current.items,
            subtotal: subtotal,
            tax: tax,
            taxRatePercent: current.taxRate,
            total: total,
            issueDate: issueDate,
            dueDate: dueDate,
            status: InvoiceStatus.pending,
          ),
        );

        final ledger = <LedgerEntry>[
          LedgerEntry(
            entryDate: issueDate,
            account: 'Accounts Receivable',
            description: 'Invoice $invoiceNumber',
            debit: total,
            refType: 'invoice',
            refId: saved.id,
          ),
          LedgerEntry(
            entryDate: issueDate,
            account: 'Sales Revenue',
            description: 'Invoice $invoiceNumber — subtotal',
            credit: subtotal,
            refType: 'invoice',
            refId: saved.id,
          ),
        ];
        if (tax > 0) {
          ledger.add(
            LedgerEntry(
              entryDate: issueDate,
              account: 'Tax Payable',
              description: 'Invoice $invoiceNumber — tax',
              credit: tax,
              refType: 'invoice',
              refId: saved.id,
            ),
          );
        }
        await db.insertLedgerEntries(ledger);

        await db.insertNotification(
          'Generated $invoiceNumber for ${clientName?.trim().isNotEmpty == true ? clientName : 'client'} — due $dueDate',
        );

        generatedCount++;

        final newOccurrences = current.occurrencesGenerated + 1;
        final newNextDue = advanceDate(
          current.nextDueDate,
          current.frequency,
          current.intervalDays,
        );
        await db.updateTemplateProgress(
          current.id!,
          newNextDue,
          newOccurrences,
        );

        current = current.copyWith(
          nextDueDate: newNextDue,
          occurrencesGenerated: newOccurrences,
        );
      }
    }

    return generatedCount;
  }

  Future<int> _generateExpenses() async {
    final today = todayStr();
    final dueSchedules = await db.getActiveDueRecurringExpenses(today);
    int generatedCount = 0;

    for (var schedule in dueSchedules) {
      var current = schedule;
      int guard = 0;

      while (current.nextDueDate.compareTo(today) <= 0 && guard < 500) {
        guard++;

        if (recurrenceHasEnded(
          endType: current.endType,
          endValue: current.endValue,
          occurrencesGenerated: current.occurrencesGenerated,
          nextDueDate: current.nextDueDate,
        )) {
          await db.updateRecurringExpenseStatus(
            current.id!,
            TemplateStatus.ended,
          );
          break;
        }

        final headName = current.headName ?? 'Expense';
        final saved = await db.insertExpense(
          ExpenseRecord(
            templateId: current.id,
            headId: current.headId,
            headName: headName,
            amount: current.amount,
            expenseDate: current.nextDueDate,
            notes: current.notes,
          ),
        );

        await db.insertLedgerEntries([
          LedgerEntry(
            entryDate: saved.expenseDate,
            account: 'Expense — $headName',
            description: saved.notes?.trim().isNotEmpty == true
                ? saved.notes!
                : 'Recurring expense under $headName',
            debit: saved.amount,
            refType: 'expense',
            refId: saved.id,
          ),
          LedgerEntry(
            entryDate: saved.expenseDate,
            account: 'Cash',
            description: 'Expense paid — $headName',
            credit: saved.amount,
            refType: 'expense',
            refId: saved.id,
          ),
        ]);

        await db.insertNotification(
          'Recorded recurring $headName expense of ${money(saved.amount)}',
        );

        generatedCount++;

        final newOccurrences = current.occurrencesGenerated + 1;
        final newNextDue = advanceDate(
          current.nextDueDate,
          current.frequency,
          current.intervalDays,
        );
        await db.updateRecurringExpenseProgress(
          current.id!,
          newNextDue,
          newOccurrences,
        );

        current = current.copyWith(
          nextDueDate: newNextDue,
          occurrencesGenerated: newOccurrences,
        );
      }
    }

    return generatedCount;
  }
}
