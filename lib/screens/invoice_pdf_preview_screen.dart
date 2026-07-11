import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

import '../models/models.dart';
import '../util/invoice_pdf.dart';

class InvoicePdfPreviewScreen extends StatefulWidget {
  final InvoiceRecord invoice;
  final Client? client;
  final String paymentMethod;
  final BusinessSettings? settings;
  final List<PaymentOption> paymentOptions;

  const InvoicePdfPreviewScreen({
    super.key,
    required this.invoice,
    required this.client,
    required this.paymentMethod,
    this.settings,
    this.paymentOptions = const [],
  });

  @override
  State<InvoicePdfPreviewScreen> createState() =>
      _InvoicePdfPreviewScreenState();
}

class _InvoicePdfPreviewScreenState extends State<InvoicePdfPreviewScreen> {
  Uint8List? _pdfBytes;
  Object? _pdfError;

  @override
  void initState() {
    super.initState();
    _preparePdf();
  }

  Future<void> _preparePdf() async {
    try {
      final bytes = await buildProfessionalInvoicePdf(
        invoice: widget.invoice,
        client: widget.client,
        paymentMethod: widget.paymentMethod,
        settings: widget.settings,
        paymentOptions: widget.paymentOptions,
      );
      if (!mounted) return;
      setState(() {
        _pdfBytes = bytes;
        _pdfError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pdfError = e;
      });
    }
  }

  Future<Uint8List> _getPdfBytes() async {
    if (_pdfBytes != null) return _pdfBytes!;
    final bytes = await buildProfessionalInvoicePdf(
      invoice: widget.invoice,
      client: widget.client,
      paymentMethod: widget.paymentMethod,
      settings: widget.settings,
      paymentOptions: widget.paymentOptions,
    );
    _pdfBytes = bytes;
    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PDF Preview - ${widget.invoice.invoiceNumber}'),
        actions: [
          IconButton(
            tooltip: 'Download PDF',
            onPressed: () => _downloadPdf(context),
            icon: const Icon(Icons.download_outlined),
          ),
          IconButton(
            tooltip: 'Share PDF',
            onPressed: () => _sharePdf(context),
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: _buildPreviewBody(),
    );
  }

  Widget _buildPreviewBody() {
    if (_pdfError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 36),
              const SizedBox(height: 10),
              Text(
                'Unable to render preview.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'You can still download or share the PDF from the top-right actions.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _preparePdf,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Preview'),
              ),
            ],
          ),
        ),
      );
    }

    if (_pdfBytes == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return PdfPreview(
      useActions: false,
      canChangePageFormat: false,
      canChangeOrientation: false,
      allowPrinting: false,
      allowSharing: false,
      pdfFileName: _pdfFileName,
      build: (format) async => _pdfBytes!,
    );
  }

  String get _pdfFileName => 'invoice_${widget.invoice.invoiceNumber}.pdf';

  Future<void> _downloadPdf(BuildContext context) async {
    try {
      final bytes = await _getPdfBytes();
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}${Platform.pathSeparator}$_pdfFileName');
      await file.writeAsBytes(bytes, flush: true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF saved to ${file.path}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download PDF: $e')),
        );
      }
    }
  }

  Future<void> _sharePdf(BuildContext context) async {
    try {
      final bytes = await _getPdfBytes();
      await Printing.sharePdf(bytes: bytes, filename: _pdfFileName);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share PDF: $e')),
        );
      }
    }
  }
}
