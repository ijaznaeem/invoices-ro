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

enum InvoiceStatus { pending, paid, cancelled }

InvoiceStatus invoiceStatusFromString(String s) => InvoiceStatus.values
    .firstWhere((e) => e.name.toLowerCase() == s.toLowerCase(),
        orElse: () => InvoiceStatus.pending);

extension InvoiceStatusLabel on InvoiceStatus {
  String get label {
    switch (this) {
      case InvoiceStatus.pending:
        return 'Pending';
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
  final String? clientName; // populated by joined queries, not persisted
  final List<InvoiceItem> items;
  final double taxRate;
  final Frequency frequency;
  final int? intervalDays;
  final String startDate; // yyyy-MM-dd
  final String nextDueDate; // yyyy-MM-dd
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
  final int clientId;
  final String? clientName; // populated by joined queries
  final List<InvoiceItem> items;
  final double subtotal;
  final double tax;
  final double total;
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
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.issueDate,
    required this.dueDate,
    this.status = InvoiceStatus.pending,
    this.paidDate,
  });

  /// Pending invoices whose due date has passed are shown as Overdue,
  /// mirroring the web app's derived "display status".
  String displayStatus(String today) {
    if (status == InvoiceStatus.pending && dueDate.compareTo(today) < 0) {
      return 'Overdue';
    }
    return status.label;
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'template_id': templateId,
        'invoice_number': invoiceNumber,
        'client_id': clientId,
        'items_json': InvoiceItem.encodeList(items),
        'subtotal': subtotal,
        'tax': tax,
        'total': total,
        'issue_date': issueDate,
        'due_date': dueDate,
        'status': status.label,
        'paid_date': paidDate,
      };

  factory InvoiceRecord.fromMap(Map<String, dynamic> map) => InvoiceRecord(
        id: map['id'] as int?,
        templateId: map['template_id'] as int?,
        invoiceNumber: map['invoice_number'] as String,
        clientId: map['client_id'] as int,
        clientName: map['client_name'] as String?,
        items: InvoiceItem.decodeList(map['items_json'] as String),
        subtotal: (map['subtotal'] as num).toDouble(),
        tax: (map['tax'] as num).toDouble(),
        total: (map['total'] as num).toDouble(),
        issueDate: map['issue_date'] as String,
        dueDate: map['due_date'] as String,
        status: invoiceStatusFromString(map['status'] as String),
        paidDate: map['paid_date'] as String?,
      );
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

/// Stores the issuing business's identity, payment details, and signature
/// that appear on every generated invoice PDF.
class BusinessSettings {
  final String businessName;
  final String businessSubtitle;
  final String? phone;
  final String? email;
  final String? address;
  final String? logoPath;
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
        signatureName: map['signature_name'] as String? ?? 'Administrator',
        signatureTitle: map['signature_title'] as String? ?? 'Administrator',
        terms: map['terms'] as String?,
      );
}

/// ---------- Payment Option ----------

/// A single payment method entry configured by the business owner.
/// Displayed as a card in Settings and rendered in invoice PDFs.
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
