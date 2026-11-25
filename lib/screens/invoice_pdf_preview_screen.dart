import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../services/public_file_service.dart';
import '../util/invoice_pdf.dart';
import '../services/whiztext_service.dart';
import 'whatsapp_send_screen.dart';

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
      appBar: AppTheme.screenBar(
        'PDF · ${widget.invoice.invoiceNumber}',
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Send via WhatsApp',
            icon: const Icon(Icons.chat_outlined),
            onSelected: _sendWhatsApp,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pdf', child: Text('WhatsApp PDF')),
              PopupMenuItem(value: 'image', child: Text('WhatsApp images')),
            ],
          ),
          PopupMenuButton<String>(
            tooltip: 'Download invoice',
            icon: const Icon(Icons.download_outlined),
            onSelected: (value) => value == 'pdf'
                ? _downloadPdf(context)
                : _downloadImages(context),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pdf', child: Text('Download PDF')),
              PopupMenuItem(value: 'image', child: Text('Download as image')),
            ],
          ),
          PopupMenuButton<String>(
            tooltip: 'Share invoice',
            icon: const Icon(Icons.share_outlined),
            onSelected: (value) =>
                value == 'pdf' ? _sharePdf(context) : _shareImages(context),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pdf', child: Text('Share PDF')),
              PopupMenuItem(value: 'image', child: Text('Share as image')),
            ],
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
  void _sendWhatsApp(String format) {
    Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => WhatsAppSendScreen(
                  recipient:
                      widget.client?.phone ?? widget.invoice.clientPhone ?? '',
                  invoiceNumber: widget.invoice.invoiceNumber,
                  formatLabel: format == 'pdf' ? 'PDF' : 'images',
                  prepareAttachments: () async {
                    if (format == 'pdf') {
                      return [
                        WhizTextAttachment(
                            bytes: await _getPdfBytes(),
                            fileName: _pdfFileName,
                            mimeType: 'application/pdf')
                      ];
                    }
                    final images = await _getInvoiceImages();
                    return [
                      for (var i = 0; i < images.length; i++)
                        WhizTextAttachment(
                            bytes: images[i],
                            fileName: _imageFileName(i, images.length),
                            mimeType: 'image/png')
                    ];
                  },
                )));
  }

  String _imageFileName(int page, int pageCount) =>
      'invoice_${widget.invoice.invoiceNumber}'
      '${pageCount == 1 ? '' : '_page_${page + 1}'}.png';

  Future<void> _downloadPdf(BuildContext context) async {
    try {
      final bytes = await _getPdfBytes();
      final path = await PublicFileService.saveToDownloads(
        fileName: _pdfFileName,
        mimeType: 'application/pdf',
        bytes: bytes,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF saved to $path')),
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

  Future<List<Uint8List>> _getInvoiceImages() async {
    final pdf = await _getPdfBytes();
    final images = <Uint8List>[];
    await for (final page in Printing.raster(pdf, dpi: 180)) {
      images.add(await page.toPng());
    }
    if (images.isEmpty) throw StateError('The PDF contains no pages.');
    return images;
  }

  Future<void> _downloadImages(BuildContext context) async {
    try {
      final images = await _getInvoiceImages();
      String? lastPath;
      for (var i = 0; i < images.length; i++) {
        lastPath = await PublicFileService.saveToDownloads(
          fileName: _imageFileName(i, images.length),
          mimeType: 'image/png',
          bytes: images[i],
        );
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(images.length == 1
                ? 'Invoice image saved to $lastPath'
                : '${images.length} invoice page images saved to Downloads/Ledger'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download image: $e')),
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

  Future<void> _shareImages(BuildContext context) async {
    try {
      final images = await _getInvoiceImages();
      await SharePlus.instance.share(ShareParams(
        files: [
          for (var i = 0; i < images.length; i++)
            XFile.fromData(
              images[i],
              mimeType: 'image/png',
              name: _imageFileName(i, images.length),
            ),
        ],
        subject: 'Invoice ${widget.invoice.invoiceNumber}',
      ));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share image: $e')),
        );
      }
    }
  }
}
