import 'package:flutter_test/flutter_test.dart';
import 'package:invoices_ro/models/models.dart';

void main() {
  test('RecurringTemplate can omit a registered client', () {
    final template = RecurringTemplate(
      clientId: null,
      clientName: 'Walk-in cafe',
      clientEmail: 'cafe@example.com',
      items: [
        InvoiceItem(description: 'Catering', quantity: 1, unitPrice: 100),
      ],
      frequency: Frequency.monthly,
      startDate: '2026-09-01',
      nextDueDate: '2026-09-01',
    );

    expect(template.clientId, isNull);
    expect(template.displayName, 'Walk-in cafe');
    expect(template.toMap()['client_id'], isNull);
    expect(template.toMap()['client_name'], 'Walk-in cafe');
  });

  test('RecurringExpense maps schedule fields', () {
    const expense = RecurringExpense(
      headId: 2,
      headName: 'Utilities',
      amount: 85.5,
      notes: 'Office internet',
      frequency: Frequency.monthly,
      startDate: '2026-09-01',
      nextDueDate: '2026-09-01',
    );

    final map = expense.toMap();
    expect(map['head_id'], 2);
    expect(map['amount'], 85.5);
    expect(map['frequency'], 'monthly');
    expect(expense.displayName, 'Office internet');

    final restored = RecurringExpense.fromMap({
      ...map,
      'id': 9,
      'head_name': 'Utilities',
    });
    expect(restored.id, 9);
    expect(restored.headName, 'Utilities');
    expect(restored.amount, 85.5);
  });
}
