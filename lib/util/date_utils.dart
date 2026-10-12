import 'package:intl/intl.dart';
import '../models/models.dart';

final DateFormat _isoDate = DateFormat('yyyy-MM-dd');

String todayStr() => _isoDate.format(DateTime.now());

/// `yyyy-MM` key used for monthly cash/expense grouping.
String monthKey([DateTime? date]) {
  final d = date ?? DateTime.now();
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
}

String monthTitle(DateTime month) => DateFormat('MMMM yyyy').format(month);

bool inMonth(String isoDate, String key) =>
    isoDate.length >= 7 && isoDate.substring(0, 7) == key;

String formatDate(String isoDate) {
  try {
    return DateFormat('MMM d, yyyy').format(_isoDate.parse(isoDate));
  } catch (_) {
    return isoDate;
  }
}

String addDays(String isoDate, int days) {
  final d = _isoDate.parse(isoDate).add(Duration(days: days));
  return _isoDate.format(d);
}

String advanceDate(String isoDate, Frequency frequency, int? intervalDays) {
  final d = _isoDate.parse(isoDate);
  switch (frequency) {
    case Frequency.weekly:
      return _isoDate.format(d.add(const Duration(days: 7)));
    case Frequency.monthly:
      return _isoDate.format(_addMonths(d, 1));
    case Frequency.quarterly:
      return _isoDate.format(_addMonths(d, 3));
    case Frequency.yearly:
      return _isoDate.format(DateTime(d.year + 1, d.month, d.day));
    case Frequency.custom:
      return _isoDate.format(d.add(Duration(days: intervalDays ?? 30)));
  }
}

/// Adds [months] calendar months to [d], clamping the day if the target
/// month is shorter (e.g. Jan 31 + 1 month -> Feb 28/29, not Mar 3).
DateTime _addMonths(DateTime d, int months) {
  final totalMonth = d.month - 1 + months;
  final year = d.year + totalMonth ~/ 12;
  final month = totalMonth % 12 + 1;
  final daysInTargetMonth = DateTime(year, month + 1, 0).day;
  final day = d.day > daysInTargetMonth ? daysInTargetMonth : d.day;
  return DateTime(year, month, day);
}

String invoiceTypeLabel(InvoiceRecord invoice) =>
    invoice.templateId != null ? 'Scheduled' : 'One-off';

String frequencyLabel(Frequency f) {
  switch (f) {
    case Frequency.weekly:
      return 'Weekly';
    case Frequency.monthly:
      return 'Monthly';
    case Frequency.quarterly:
      return 'Quarterly';
    case Frequency.yearly:
      return 'Yearly';
    case Frequency.custom:
      return 'Custom';
  }
}

/// Shared end-condition checks used by invoice and expense generation.
bool recurrenceHasEnded({
  required EndType endType,
  required String? endValue,
  required int occurrencesGenerated,
  required String nextDueDate,
}) {
  if (endType == EndType.count) {
    final limit = int.tryParse(endValue ?? '') ?? 0;
    return occurrencesGenerated >= limit;
  }
  if (endType == EndType.date && endValue != null) {
    return nextDueDate.compareTo(endValue) > 0;
  }
  return false;
}
