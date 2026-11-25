import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class WhizTextAttachment {
  const WhizTextAttachment(
      {required this.bytes, required this.fileName, required this.mimeType});
  final Uint8List bytes;
  final String fileName;
  final String mimeType;
}

class WhizTextAcceptance {
  const WhizTextAcceptance({this.messageId, required this.status});
  final String? messageId;
  final String status;
}

class WhizTextException implements Exception {
  const WhizTextException(this.message, {this.deliveryUncertain = false});
  final String message;
  final bool deliveryUncertain;
  @override
  String toString() => message;
}

/// WhizText gateway contract from https://portal.whiztext.com/api-docs.
/// Sends exactly once: an accepted or timed-out request must not be auto-retried.
class WhizTextService {
  WhizTextService(
      {http.Client? client, this.timeout = const Duration(seconds: 30)})
      : _client = client ?? http.Client();
  final http.Client _client;
  final Duration timeout;
  static final sendUri = Uri.parse('https://api.whiztext.com/v1/send');
  static const maxFileBytes = 16 * 1024 * 1024;

  static String normalizeRecipient(String input) {
    var number = input.trim().replaceAll(RegExp(r'[\s()\-]'), '');
    if (number.startsWith('00')) number = '+${number.substring(2)}';
    if (!RegExp(r'^\+?[1-9][0-9]{7,14}$').hasMatch(number)) {
      throw const WhizTextException(
          'Enter a phone number with its country code, such as +923001234567.');
    }
    return number.startsWith('+') ? number : '+$number';
  }

  static void validateAttachment(WhizTextAttachment file) {
    if (file.bytes.isEmpty) {
      throw const WhizTextException('The invoice file is empty.');
    }
    if (file.bytes.length > maxFileBytes) {
      throw const WhizTextException(
          'WhizText accepts files up to 16 MiB. Choose PDF or a smaller image.');
    }
    if (file.mimeType != 'application/pdf' && file.mimeType != 'image/png') {
      throw const WhizTextException('Choose a PDF or PNG invoice.');
    }
  }

  Future<WhizTextAcceptance> send(
      {required String apiKey,
      required String recipient,
      required WhizTextAttachment attachment,
      String message = ''}) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw const WhizTextException(
          'Set your WhizText gateway API key in WhatsApp settings first.');
    }
    if (key.contains(RegExp(r'[\r\n]'))) {
      throw const WhizTextException(
          'The API key contains an invalid line break.');
    }
    final to = normalizeRecipient(recipient);
    validateAttachment(attachment);
    final request = http.MultipartRequest('POST', sendUri)
      ..followRedirects = false
      ..headers['X-API-Key'] = key
      ..fields['to'] = to;
    if (message.trim().isNotEmpty) request.fields['message'] = message.trim();
    request.files.add(http.MultipartFile.fromBytes('media', attachment.bytes,
        filename:
            attachment.fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_'),
        contentType: MediaType.parse(attachment.mimeType)));
    try {
      final response = await (() async =>
              http.Response.fromStream(await _client.send(request)))()
          .timeout(timeout);
      Map<String, dynamic>? data;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } on FormatException {/* Handle non-JSON errors without echoing HTML. */}
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data?['success'] == true) {
        return WhizTextAcceptance(
            messageId: data?['messageId']?.toString(),
            status: data?['status']?.toString() ?? 'accepted');
      }
      final code = response.statusCode;
      var error = switch (code) {
        401 => 'WhizText rejected the API key. Update it in WhatsApp settings.',
        403 => 'WhizText denied access for this gateway key.',
        413 => 'WhizText rejected the file size. The limit is 16 MiB.',
        429 => 'Your WhizText quota or rate limit has been reached.',
        _ => 'WhizText could not accept the invoice (HTTP $code).',
      };
      final detail = data?['error'] ?? data?['message'];
      if (detail is String && detail.isNotEmpty && code != 401 && code != 429) {
        final safe = detail.replaceAll(key, '[redacted]');
        error =
            '$error ${safe.length > 300 ? '${safe.substring(0, 300)}…' : safe}';
      }
      final uncertain = code >= 500 ||
          (code >= 200 && code < 300) ||
          (code >= 300 && code < 400);
      throw WhizTextException(error, deliveryUncertain: uncertain);
    } on TimeoutException {
      throw const WhizTextException(
          'WhizText did not respond in time. Check message history before resending; the request may have been accepted.',
          deliveryUncertain: true);
    } on IOException {
      throw const WhizTextException(
          'The connection was interrupted. Check WhizText message history before resending.',
          deliveryUncertain: true);
    } on http.ClientException {
      throw const WhizTextException(
          'The connection was interrupted. Check WhizText message history before resending.',
          deliveryUncertain: true);
    }
  }

  void close() => _client.close();
}
