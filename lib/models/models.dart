import 'dart:convert';

/// ---------- Enums ----------

enum Frequency { weekly, monthly, quarterly, yearly, custom }

Frequency frequencyFromString(String s) => Frequency.values
    .firstWhere((f) => f.name == s, orElse: () => Frequency.monthly);

enum EndType { never, count, date }

EndType endTypeFromString(String s) =>
    EndType.values.firstWhere((e) => e.name == s, orElse: () => EndType.never);

enum TemplateStatus { active, paused, ended }

TemplateStatus templateStatusFromString(String s) => TemplateStatus.values
    .firstWhere((e) => e.name == s, orElse: () => TemplateStatus.active);

enum InvoiceStatus { pending, partial, paid, cancelled }

InvoiceStatus invoiceStatusFromString(String s) {
  final normalized = s.toLowerCase();
  if (normalized == 'partial' || normalized == 'partially paid') {
    return InvoiceStatus.partial;
  }
  return InvoiceStatus.values.firstWhere(
    (e) => e.name.toLowerCase() == normalized,
    orElse: () => InvoiceStatus.pending,
  );
}

extension InvoiceStatusLabel on InvoiceStatus {
  String get label {
    switch (this) {
      case InvoiceStatus.pending:
        return 'Pending';
      case InvoiceStatus.partial:
        return 'Partial';
      case InvoiceStatus.paid:
        return 'Paid';
      case InvoiceStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// ---------- Line item ----------

class InvoiceItem {
  final String description;
  final double quantity;
  final double unitPrice;

  InvoiceItem(
      {required this.description,
      required this.quantity,
      required this.unitPrice});

  double get lineTotal => quantity * unitPrice;

  Map<String, dynamic> toMap() => {
        'description': description,
        'quantity': quantity,
        'unit_price': unitPrice,
      };

  factory InvoiceItem.fromMap(Map<String, dynamic> map) => InvoiceItem(
        description: map['description'] as String? ?? '',
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
        unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0,
      );

  static String encodeList(List<InvoiceItem> items) =>
      jsonEncode(items.map((i) => i.toMap()).toList());

  static List<InvoiceItem> decodeList(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .map((e) => InvoiceItem.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}

/// ---------- Client ----------

class Client {
  final int? id;
  final String name;
  final String? email;
  final String? phone;
  final String? address;

  Client({this.id, required this.name, this.email, this.phone, this.address});

  Client copyWith(
          {int? id,
          String? name,
          String? email,
          String? phone,
          String? address}) =>
      Client(
        id: id ?? this.id,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        address: address ?? this.address,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
      };

  factory Client.fromMap(Map<String, dynamic> map) => Client(
        id: map['id'] as int?,
        name: map['name'] as String,
        email: map['email'] as String?,
        phone: map['phone'] as String?,
        address: map['address'] as String?,
      );
}

/// ---------- Recurring template ----------

class RecurringTemplate {
  final int? id;
  final int clientId;
  final String? clientName;
  final List<InvoiceItem> items;
  final double taxRate;
  final Frequency frequency;
  final int? intervalDays;
  final String startDate;
  final String nextDueDate;
  final int paymentTermsDays;
  final EndType endType;
  final String? endValue;
  final int occurrencesGenerated;
  final TemplateStatus status;
  final String? notes;

  RecurringTemplate({
    this.id,
    required this.clientId,
    this.clientName,
    required this.items,
    this.taxRate = 0,
    required this.frequency,
    this.intervalDays,
    required this.startDate,
    required this.nextDueDate,
    this.paymentTermsDays = 14,
    this.endType = EndType.never,
    this.endValue,
    this.occurrencesGenerated = 0,
    this.status = TemplateStatus.active,
    this.notes,
  });

  double get subtotal => items.fold(0.0, (s, i) => s + i.lineTotal);
  double get total => subtotal * (1 + taxRate / 100);

  RecurringTemplate withId(int newId) => RecurringTemplate(
        id: newId,
        clientId: clientId,
        clientName: clientName,
        items: items,
        taxRate: taxRate,
        frequency: frequency,
        intervalDays: intervalDays,
        startDate: startDate,
        nextDueDate: nextDueDate,
        paymentTermsDays: paymentTermsDays,
        endType: endType,
        endValue: endValue,
        occurrencesGenerated: occurrencesGenerated,
        status: status,
        notes: notes,
      );

  RecurringTemplate copyWith({
    String? nextDueDate,
    int? occurrencesGenerated,
    TemplateStatus? status,
  }) =>
      RecurringTemplate(
        id: id,
        clientId: clientId,
        clientName: clientName,
        items: items,
        taxRate: taxRate,
        frequency: frequency,
        intervalDays: intervalDays,
        startDate: startDate,
        nextDueDate: nextDueDate ?? this.nextDueDate,
        paymentTermsDays: paymentTermsDays,
        endType: endType,
        endValue: endValue,
        occurrencesGenerated: occurrencesGenerated ?? this.occurrencesGenerated,
        status: status ?? this.status,
        notes: notes,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'client_id': clientId,
        'items_json': InvoiceItem.encodeList(items),
        'tax_rate': taxRate,
        'frequency': frequency.name,
        'interval_days': intervalDays,
        'start_date': startDate,
        'next_due_date': nextDueDate,
        'payment_terms_days': paymentTermsDays,
        'end_type': endType.name,
        'end_value': endValue,
        'occurrences_generated': occurrencesGenerated,
        'status': status.name,
        'notes': notes,
      };

  factory RecurringTemplate.fromMap(Map<String, dynamic> map) =>
      RecurringTemplate(
        id: map['id'] as int?,
        clientId: map['client_id'] as int,
        clientName: map['client_name'] as String?,
        items: InvoiceItem.decodeList(map['items_json'] as String),
        taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 0,
        frequency: frequencyFromString(map['frequency'] as String),
        intervalDays: map['interval_days'] as int?,
        startDate: map['start_date'] as String,
        nextDueDate: map['next_due_date'] as String,
        paymentTermsDays: map['payment_terms_days'] as int? ?? 14,
        endType: endTypeFromString(map['end_type'] as String? ?? 'never'),
        endValue: map['end_value'] as String?,
        occurrencesGenerated: map['occurrences_generated'] as int? ?? 0,
        status: templateStatusFromString(map['status'] as String? ?? 'active'),
        notes: map['notes'] as String?,
      );
}

/// ---------- Invoice ----------

class InvoiceRecord {
  final int? id;
  final int? templateId;
  final String invoiceNumber;
  final int? clientId;
  final String? clientName;
  final String? clientEmail;
  final String? clientPhone;
  final String? clientAddress;
  final List<InvoiceItem> items;
  final double subtotal;
  final double tax;
  final double taxRatePercent;
  final double total;
  final double amountPaid;
  final String issueDate;
  final String dueDate;
  final InvoiceStatus status;
  final String? paidDate;

  InvoiceRecord({
    this.id,
    this.templateId,
    required this.invoiceNumber,
    required this.clientId,
    this.clientName,
    this.clientEmail,
    this.clientPhone,
    this.clientAddress,
    required this.items,
    required this.subtotal,
    required this.tax,
    this.taxRatePercent = 0,
    required this.total,
    this.amountPaid = 0,
    required this.issueDate,
    required this.dueDate,
    this.status = InvoiceStatus.pending,
    this.paidDate,
  });

  double get balanceDue => (total - amountPaid).clamp(0, total);

  bool get isOpen =>
      status == InvoiceStatus.pending || status == InvoiceStatus.partial;

  String displayStatus(String today) {
    if ((status == InvoiceStatus.pending || status == InvoiceStatus.partial) &&
        dueDate.compareTo(today) < 0) {
      return 'Overdue';
    }
    return status.label;
  }

  InvoiceRecord copyWith({
    int? id,
    double? amountPaid,
    InvoiceStatus? status,
    String? paidDate,
  }) =>
      InvoiceRecord(
        id: id ?? this.id,
        templateId: templateId,
        invoiceNumber: invoiceNumber,
        clientId: clientId,
        clientName: clientName,
        clientEmail: clientEmail,
        clientPhone: clientPhone,
        clientAddress: clientAddress,
        items: items,
        subtotal: subtotal,
        tax: tax,
        taxRatePercent: taxRatePercent,
        total: total,
        amountPaid: amountPaid ?? this.amountPaid,
        issueDate: issueDate,
        dueDate: dueDate,
        status: status ?? this.status,
        paidDate: paidDate ?? this.paidDate,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'template_id': templateId,
        'invoice_number': invoiceNumber,
        'client_id': clientId,
        'client_name': clientName ?? '',
        'client_email': clientEmail,
        'client_phone': clientPhone,
        'client_address': clientAddress,
        'items_json': InvoiceItem.encodeList(items),
        'subtotal': subtotal,
        'tax': tax,
        'tax_rate_percent': taxRatePercent,
        'total': total,
        'amount_paid': amountPaid,
        'issue_date': issueDate,
        'due_date': dueDate,
        'status': status.label,
        'paid_date': paidDate,
      };

  factory InvoiceRecord.fromMap(Map<String, dynamic> map) => InvoiceRecord(
        id: map['id'] as int?,
        templateId: map['template_id'] as int?,
        invoiceNumber: map['invoice_number'] as String,
        clientId: map['client_id'] as int?,
        clientName: map['client_name'] as String?,
        clientEmail: map['client_email'] as String?,
        clientPhone: map['client_phone'] as String?,
        clientAddress: map['client_address'] as String?,
        items: InvoiceItem.decodeList(map['items_json'] as String),
        subtotal: (map['subtotal'] as num).toDouble(),
        tax: (map['tax'] as num).toDouble(),
        taxRatePercent: (map['tax_rate_percent'] as num?)?.toDouble() ?? 0,
        total: (map['total'] as num).toDouble(),
        amountPaid: (map['amount_paid'] as num?)?.toDouble() ?? 0,
        issueDate: map['issue_date'] as String,
        dueDate: map['due_date'] as String,
        status: invoiceStatusFromString(map['status'] as String),
        paidDate: map['paid_date'] as String?,
      );
}

/// ---------- Invoice payment ----------

class InvoicePayment {
  final int? id;
  final int invoiceId;
  final double amount;
  final String paymentDate;
  final String method;
  final String? notes;

  const InvoicePayment({
    this.id,
    required this.invoiceId,
    required this.amount,
    required this.paymentDate,
    this.method = 'Cash',
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'invoice_id': invoiceId,
        'amount': amount,
        'payment_date': paymentDate,
        'method': method,
        'notes': notes,
      };

  factory InvoicePayment.fromMap(Map<String, dynamic> map) => InvoicePayment(
        id: map['id'] as int?,
        invoiceId: map['invoice_id'] as int,
        amount: (map['amount'] as num).toDouble(),
        paymentDate: map['payment_date'] as String,
        method: map['method'] as String? ?? 'Cash',
        notes: map['notes'] as String?,
      );
}

/// ---------- Tax rate ----------

class TaxRate {
  final int? id;
  final String name;
  final double ratePercent;
  final int sortOrder;

  const TaxRate({
    this.id,
    required this.name,
    required this.ratePercent,
    this.sortOrder = 0,
  });

  String get label {
    final pct = ratePercent.truncateToDouble() == ratePercent
        ? ratePercent.toStringAsFixed(0)
        : ratePercent.toStringAsFixed(2);
    return '$name ($pct%)';
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'rate_percent': ratePercent,
        'sort_order': sortOrder,
      };

  factory TaxRate.fromMap(Map<String, dynamic> map) => TaxRate(
        id: map['id'] as int?,
        name: map['name'] as String,
        ratePercent: (map['rate_percent'] as num).toDouble(),
        sortOrder: map['sort_order'] as int? ?? 0,
      );
}

/// ---------- Expense head / expense ----------

class ExpenseHead {
  final int? id;
  final String name;
  final int sortOrder;

  const ExpenseHead({
    this.id,
    required this.name,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'sort_order': sortOrder,
      };

  factory ExpenseHead.fromMap(Map<String, dynamic> map) => ExpenseHead(
        id: map['id'] as int?,
        name: map['name'] as String,
        sortOrder: map['sort_order'] as int? ?? 0,
      );
}

class ExpenseRecord {
  final int? id;
  final int headId;
  final String? headName;
  final double amount;
  final String expenseDate;
  final String? notes;

  const ExpenseRecord({
    this.id,
    required this.headId,
    this.headName,
    required this.amount,
    required this.expenseDate,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'head_id': headId,
        'amount': amount,
        'expense_date': expenseDate,
        'notes': notes,
      };

  factory ExpenseRecord.fromMap(Map<String, dynamic> map) => ExpenseRecord(
        id: map['id'] as int?,
        headId: map['head_id'] as int,
        headName: map['head_name'] as String?,
        amount: (map['amount'] as num).toDouble(),
        expenseDate: map['expense_date'] as String,
        notes: map['notes'] as String?,
      );
}

/// ---------- Cash receipt ----------

class CashReceipt {
  final int? id;
  final double amount;
  final String receiptDate;
  final String receivedFrom;
  final String? notes;
  final int? invoiceId;
  final String? invoiceNumber;

  const CashReceipt({
    this.id,
    required this.amount,
    required this.receiptDate,
    required this.receivedFrom,
    this.notes,
    this.invoiceId,
    this.invoiceNumber,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'amount': amount,
        'receipt_date': receiptDate,
        'received_from': receivedFrom,
        'notes': notes,
        'invoice_id': invoiceId,
      };

  factory CashReceipt.fromMap(Map<String, dynamic> map) => CashReceipt(
        id: map['id'] as int?,
        amount: (map['amount'] as num).toDouble(),
        receiptDate: map['receipt_date'] as String,
        receivedFrom: map['received_from'] as String? ?? '',
        notes: map['notes'] as String?,
        invoiceId: map['invoice_id'] as int?,
        invoiceNumber: map['invoice_number'] as String?,
      );
}

/// ---------- Accounts ledger ----------

class LedgerEntry {
  final int? id;
  final String entryDate;
  final String account;
  final String description;
  final double debit;
  final double credit;
  final String? refType;
  final int? refId;

  const LedgerEntry({
    this.id,
    required this.entryDate,
    required this.account,
    required this.description,
    this.debit = 0,
    this.credit = 0,
    this.refType,
    this.refId,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'entry_date': entryDate,
        'account': account,
        'description': description,
        'debit': debit,
        'credit': credit,
        'ref_type': refType,
        'ref_id': refId,
      };

  factory LedgerEntry.fromMap(Map<String, dynamic> map) => LedgerEntry(
        id: map['id'] as int?,
        entryDate: map['entry_date'] as String,
        account: map['account'] as String,
        description: map['description'] as String? ?? '',
        debit: (map['debit'] as num?)?.toDouble() ?? 0,
        credit: (map['credit'] as num?)?.toDouble() ?? 0,
        refType: map['ref_type'] as String?,
        refId: map['ref_id'] as int?,
      );
}

/// Monthly chart point used by the dashboard.
class MonthlyAmount {
  final String monthKey; // yyyy-MM
  final String label;
  final double amount;

  const MonthlyAmount({
    required this.monthKey,
    required this.label,
    required this.amount,
  });
}

/// ---------- Notification / activity feed entry ----------

class AppNotification {
  final int? id;
  final String message;
  final String createdAt;
  final bool isRead;

  AppNotification(
      {this.id,
      required this.message,
      required this.createdAt,
      this.isRead = false});

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'message': message,
        'created_at': createdAt,
        'is_read': isRead ? 1 : 0,
      };

  factory AppNotification.fromMap(Map<String, dynamic> map) => AppNotification(
        id: map['id'] as int?,
        message: map['message'] as String,
        createdAt: map['created_at'] as String,
        isRead: (map['is_read'] as int? ?? 0) == 1,
      );
}

/// ---------- Business Settings ----------

class BusinessSettings {
  final String businessName;
  final String businessSubtitle;
  final String? phone;
  final String? email;
  final String? address;
  final String? logoPath;
  final String currencyCode;
  final String currencySymbol;
  final String signatureName;
  final String signatureTitle;
  final String? terms;

  const BusinessSettings({
    this.businessName = 'INVOICES RO',
    this.businessSubtitle = 'Creative Agency Billing',
    this.phone,
    this.email,
    this.address,
    this.logoPath,
    this.currencyCode = 'USD',
    this.currencySymbol = r'$',
    this.signatureName = 'Administrator',
    this.signatureTitle = 'Administrator',
    this.terms,
  });

  Map<String, dynamic> toMap() => {
        'id': 1,
        'business_name': businessName,
        'business_subtitle': businessSubtitle,
        'phone': phone,
        'email': email,
        'address': address,
        'logo_path': logoPath,
        'currency_code': currencyCode,
        'currency_symbol': currencySymbol,
        'signature_name': signatureName,
        'signature_title': signatureTitle,
        'terms': terms,
      };

  factory BusinessSettings.fromMap(Map<String, dynamic> map) =>
      BusinessSettings(
        businessName: map['business_name'] as String? ?? 'INVOICES RO',
        businessSubtitle:
            map['business_subtitle'] as String? ?? 'Creative Agency Billing',
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        address: map['address'] as String?,
        logoPath: map['logo_path'] as String?,
        currencyCode: map['currency_code'] as String? ?? 'USD',
        currencySymbol: map['currency_symbol'] as String? ?? r'$',
        signatureName: map['signature_name'] as String? ?? 'Administrator',
        signatureTitle: map['signature_title'] as String? ?? 'Administrator',
        terms: map['terms'] as String?,
      );
}

/// ---------- Payment Option ----------

class PaymentOption {
  final int? id;
  final String label;
  final String details;
  final int sortOrder;

  const PaymentOption({
    this.id,
    required this.label,
    this.details = '',
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'label': label,
        'details': details,
        'sort_order': sortOrder,
      };

  factory PaymentOption.fromMap(Map<String, dynamic> map) => PaymentOption(
        id: map['id'] as int?,
        label: map['label'] as String,
        details: map['details'] as String? ?? '',
        sortOrder: map['sort_order'] as int? ?? 0,
      );
}
