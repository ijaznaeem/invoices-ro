import 'package:flutter_test/flutter_test.dart';
import 'package:invoices_ro/models/models.dart';
import 'package:invoices_ro/util/date_utils.dart';

void main() {
  group('advanceDate', () {
    test('monthly from month-end clamps instead of overflowing', () {
      expect(advanceDate('2026-01-31', Frequency.monthly, null), '2026-02-28');
      expect(advanceDate('2024-01-31', Frequency.monthly, null), '2024-02-29');
    });

    test('monthKey and inMonth', () {
      expect(monthKey(DateTime(2026, 9, 20)), '2026-09');
      expect(inMonth('2026-09-03', '2026-09'), isTrue);
      expect(inMonth('2026-10-01', '2026-09'), isFalse);
    });

    test('weekly adds seven days', () {
      expect(advanceDate('2026-09-01', Frequency.weekly, null), '2026-09-08');
    });

    test('custom interval uses intervalDays', () {
      expect(advanceDate('2026-09-01', Frequency.custom, 10), '2026-09-11');
    });
  });

  group('recurrenceHasEnded', () {
    test('count end stops once generated reaches the limit', () {
      expect(
        recurrenceHasEnded(
          endType: EndType.count,
          endValue: '3',
          occurrencesGenerated: 3,
          nextDueDate: '2026-09-01',
        ),
        isTrue,
      );
      expect(
        recurrenceHasEnded(
          endType: EndType.count,
          endValue: '3',
          occurrencesGenerated: 2,
          nextDueDate: '2026-09-01',
        ),
        isFalse,
      );
    });

    test('date end stops only after the end date', () {
      expect(
        recurrenceHasEnded(
          endType: EndType.date,
          endValue: '2026-09-15',
          occurrencesGenerated: 0,
          nextDueDate: '2026-09-16',
        ),
        isTrue,
      );
      expect(
        recurrenceHasEnded(
          endType: EndType.date,
          endValue: '2026-09-15',
          occurrencesGenerated: 0,
          nextDueDate: '2026-09-15',
        ),
        isFalse,
      );
    });

    test('never does not end', () {
      expect(
        recurrenceHasEnded(
          endType: EndType.never,
          endValue: null,
          occurrencesGenerated: 99,
          nextDueDate: '2026-09-01',
        ),
        isFalse,
      );
    });
  });
}
