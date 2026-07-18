import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/models.dart';

Future<Uint8List> buildProfessionalInvoicePdf({
  required InvoiceRecord invoice,
  Client? client,
  String paymentMethod = 'Bank Transfer',
  BusinessSettings? settings,
  List<PaymentOption> paymentOptions = const [],
}) async {
  final doc = pw.Document();
  final dateLabel = _fmtDate(invoice.issueDate);

  // Pre-load logo image from the saved file path, if any.
  pw.ImageProvider? logo;
  final logoPath = settings?.logoPath;
  if (logoPath != null && logoPath.isNotEmpty) {
    final file = File(logoPath);
    if (await file.exists()) {
      logo = pw.MemoryImage(await file.readAsBytes());
    }
  }
  final bizName = _safeAscii(settings?.businessName ?? 'INVOICES RO');
  final bizSubtitle =
      _safeAscii(settings?.businessSubtitle ?? 'Creative Agency Billing');

  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(34, 30, 34, 28),
        // PDF pages are transparent unless a background is explicitly
        // painted. Some image viewers render that transparency as black.
        buildBackground: (_) => pw.FullPage(
          ignoreMargins: true,
          child: pw.Container(color: PdfColors.white),
        ),
      ),
      build: (context) => [
        _header(invoice, dateLabel, bizName, bizSubtitle, logo),
        pw.SizedBox(height: 18),
        _clientAndMeta(invoice, client),
        pw.SizedBox(height: 18),
        _lineItemsTable(invoice, settings),
        pw.SizedBox(height: 16),
        _totals(invoice, settings),
        pw.SizedBox(height: 20),
        _paymentSection(paymentMethod, paymentOptions),
        pw.SizedBox(height: 20),
        _termsAndSignature(settings),
        pw.SizedBox(height: 14),
        _footer(settings),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _header(
  InvoiceRecord invoice,
  String issueDateLabel,
  String businessName,
  String businessSubtitle,
  pw.ImageProvider? logo,
) {
  final accent = PdfColor.fromHex('#2F6FC0');

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logo != null)
                pw.Image(logo, width: 44, height: 44, fit: pw.BoxFit.contain)
              else
                pw.Container(
                  width: 24,
                  height: 24,
                  decoration: const pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    gradient: pw.LinearGradient(
                      colors: [
                        PdfColor.fromInt(0xFF2F6FC0),
                        PdfColor.fromInt(0xFF5EA8F7),
                      ],
                    ),
                  ),
                ),
              pw.SizedBox(width: 8),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    businessName,
                    style: pw.TextStyle(
                        fontSize: 17, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    businessSubtitle,
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey700),
                  ),
                ],
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'INVOICE',
                style: pw.TextStyle(
                    fontSize: 26,
                    color: accent,
                    fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 2),
              pw.Text('Invoice no : ${invoice.invoiceNumber}',
                  style: const pw.TextStyle(fontSize: 11)),
              pw.Text(_safeAscii(issueDateLabel),
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey700)),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 10),
      pw.Container(height: 2, color: PdfColor.fromHex('#D8DDE6')),
    ],
  );
}

pw.Widget _clientAndMeta(InvoiceRecord invoice, Client? client) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Invoice to :',
                style:
                    const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.SizedBox(height: 6),
            pw.Text(
              _safeAscii(client?.name ?? invoice.clientName ?? 'Client'),
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            if ((client?.phone ?? '').trim().isNotEmpty)
              pw.Text(_safeAscii(client!.phone!),
                  style: const pw.TextStyle(fontSize: 10)),
            if ((client?.email ?? '').trim().isNotEmpty)
              pw.Text(_safeAscii(client!.email!),
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey700)),
            if ((client?.address ?? '').trim().isNotEmpty)
              pw.Text(_safeAscii(client!.address!),
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey700)),
          ],
        ),
      ),
      pw.SizedBox(width: 20),
      pw.Container(
        width: 170,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColor.fromHex('#D8DDE6')),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _metaRow('Issue Date', _safeAscii(_fmtDate(invoice.issueDate))),
            _metaRow('Due Date', _safeAscii(_fmtDate(invoice.dueDate))),
            _metaRow('Status', _safeAscii(invoice.status.label.toUpperCase())),
          ],
        ),
      ),
    ],
  );
}

pw.Widget _metaRow(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.Text(value,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
      ],
    ),
  );
}

pw.Widget _lineItemsTable(InvoiceRecord invoice, BusinessSettings? settings) {
  final headerBg = PdfColor.fromHex('#2F6FC0');
  final stripe = PdfColor.fromHex('#EAF3FF');

  final rows = invoice.items.asMap().entries.map((entry) {
    final index = entry.key;
    final item = entry.value;
    return [
      '${index + 1}',
      _safeAscii(item.description),
      _fmtNum(item.quantity),
      _money(item.unitPrice, settings),
      _money(item.lineTotal, settings),
    ];
  }).toList();

  return pw.TableHelper.fromTextArray(
    headerDecoration: pw.BoxDecoration(color: headerBg),
    headerStyle: pw.TextStyle(
        color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
    cellStyle: const pw.TextStyle(fontSize: 10),
    cellAlignment: pw.Alignment.center,
    oddRowDecoration: pw.BoxDecoration(color: stripe),
    cellPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    headers: const ['NO', 'DESCRIPTION', 'QTY', 'PRICE', 'TOTAL'],
    data: rows,
    border: pw.TableBorder.all(color: PdfColor.fromHex('#C9DBF5'), width: 0.6),
    columnWidths: {
      0: const pw.FixedColumnWidth(28),
      1: const pw.FlexColumnWidth(3.8),
      2: const pw.FlexColumnWidth(1.1),
      3: const pw.FlexColumnWidth(1.6),
      4: const pw.FlexColumnWidth(1.8),
    },
    headerAlignments: const {
      0: pw.Alignment.center,
      1: pw.Alignment.centerLeft,
      2: pw.Alignment.center,
      3: pw.Alignment.centerRight,
      4: pw.Alignment.centerRight,
    },
    cellAlignments: const {
      0: pw.Alignment.center,
      1: pw.Alignment.centerLeft,
      2: pw.Alignment.center,
      3: pw.Alignment.centerRight,
      4: pw.Alignment.centerRight,
    },
  );
}

pw.Widget _totals(InvoiceRecord invoice, BusinessSettings? settings) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.end,
    children: [
      pw.Container(
        width: 220,
        child: pw.Column(
          children: [
            _totalRow('Sub Total :', _money(invoice.subtotal, settings)),
            _totalRow('Tax :', _money(invoice.tax, settings)),
            pw.SizedBox(height: 8),
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              color: PdfColor.fromHex('#2F6FC0'),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'GRAND TOTAL :',
                    style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    _money(invoice.total, settings),
                    style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

pw.Widget _totalRow(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
        pw.Text(value,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      ],
    ),
  );
}

pw.Widget _paymentSection(
    String paymentMethod, List<PaymentOption> paymentOptions) {
  final headingBg = PdfColor.fromHex('#2F6FC0');

  // Build per-option widget rows.
  final optionWidgets = <pw.Widget>[];
  if (paymentOptions.isEmpty) {
    optionWidgets.add(_asciiListRow('Contact us for payment details.'));
  } else {
    for (final opt in paymentOptions) {
      optionWidgets.add(pw.SizedBox(height: 5));
      optionWidgets.add(pw.Text(
        _safeAscii(opt.label),
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      ));
      if (opt.details.trim().isNotEmpty) {
        for (final line in opt.details.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty) optionWidgets.add(_asciiListRow(trimmed));
        }
      }
    }
  }

  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 210,
              color: headingBg,
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: pw.Text(
                'PAYMENT OPTIONS :',
                style: pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold),
              ),
            ),
            if (paymentMethod.trim().isNotEmpty) ...[
              pw.SizedBox(height: 8),
              pw.Text(
                'Preferred: ${_safeAscii(paymentMethod)}',
                style:
                    pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
            ],
            pw.SizedBox(height: 4),
            ...optionWidgets,
          ],
        ),
      ),
      pw.SizedBox(width: 14),
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColor.fromHex('#D8DDE6')),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Payment Notes',
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(
                'Please include the invoice number in your payment reference so we can match it quickly.',
                style:
                    const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

pw.Widget _termsAndSignature(BusinessSettings? settings) {
  final sigName = _safeAscii(settings?.signatureName ?? 'Administrator');
  final sigTitle = _safeAscii(settings?.signatureTitle ?? 'Administrator');
  final termsText = _safeAscii(
    settings?.terms ??
        'Please send payment within 30 days of receiving this invoice. A monthly late fee may apply to overdue balances.',
  );

  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Thank you for your business with us!',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Text('Term and Conditions :',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(
              termsText,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ],
        ),
      ),
      pw.SizedBox(width: 16),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(sigName,
              style:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
          pw.Text(sigTitle, style: const pw.TextStyle(fontSize: 11)),
        ],
      ),
    ],
  );
}

pw.Widget _footer(BusinessSettings? settings) {
  final accent = PdfColor.fromHex('#3BA7F2');

  return pw.Column(
    children: [
      pw.Container(height: 1.3, color: PdfColor.fromHex('#D8DDE6')),
      pw.SizedBox(height: 8),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _footerItem('Phone', _safeAscii(settings?.phone ?? ''), accent),
          _footerItem('Email', _safeAscii(settings?.email ?? ''), accent),
          _footerItem('Address', _safeAscii(settings?.address ?? ''), accent),
        ],
      ),
    ],
  );
}

pw.Widget _asciiListRow(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 2),
    child: pw.Text('- ${_safeAscii(text)}',
        style: const pw.TextStyle(fontSize: 10)),
  );
}

pw.Widget _footerItem(String label, String value, PdfColor accent) {
  return pw.Expanded(
    child: pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label.toUpperCase(),
              style: pw.TextStyle(
                  fontSize: 9, color: accent, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text(value,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        ],
      ),
    ),
  );
}

String _fmtDate(String date) {
  final dt = DateTime.tryParse(date);
  if (dt == null) return date;
  return DateFormat('dd MMMM yyyy').format(dt);
}

String _fmtNum(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(2);
}

String _money(double value, BusinessSettings? settings) =>
    NumberFormat.currency(
      symbol: settings?.currencySymbol ?? r'$',
      decimalDigits: 2,
    ).format(value);

String _safeAscii(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= 32 && rune <= 126) {
      buffer.writeCharCode(rune);
    } else {
      buffer.write('?');
    }
  }
  return buffer.toString();
}
