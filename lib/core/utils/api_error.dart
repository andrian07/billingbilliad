import 'package:dio/dio.dart';

import '../constants/api_endpoints.dart';

/// Turns a [DioException] into a message the cashier can act on (or read
/// out to support), instead of one generic "can't connect" text for every
/// failure.
///
/// - Server answered with an error status (e.g. HTTP 500 from a PHP/database
///   error): shows the status and the server's own message — for
///   CodeIgniter's HTML error pages, the text of its heading/paragraphs
///   (e.g. "Unknown column 'promo_cafe_id' in 'field list'").
/// - No answer at all: says so, naming the server address being used.
String describeDioError(DioException e) {
  final response = e.response;
  if (response != null) {
    final status = response.statusCode;
    final detail = _serverMessage(response.data);
    final prefix = "Server error (HTTP ${status ?? '-'})";
    return detail == null ? prefix : "$prefix: $detail";
  }

  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return "Server tidak merespons (timeout) - ${ApiEndpoints.baseUrl}";
    case DioExceptionType.connectionError:
      return "Tidak dapat terhubung ke server ${ApiEndpoints.baseUrl}. "
          "Pastikan Apache (XAMPP) menyala.";
    default:
      final reason = e.message ?? e.error?.toString();
      return "Tidak dapat terhubung ke server ${ApiEndpoints.baseUrl}"
          "${reason != null && reason.isNotEmpty ? ' ($reason)' : ''}";
  }
}

String? _serverMessage(Object? data) {
  if (data is Map) {
    final message = data['message'] ?? data['result'];
    return message?.toString();
  }
  if (data is! String || data.trim().isEmpty) return null;

  // CodeIgniter / PHP error pages are HTML: keep the visible text of the
  // heading and paragraphs, which carry the error number/message/file.
  final blocks = RegExp(
    r'<(h1|h4|p)[^>]*>(.*?)</\1>',
    caseSensitive: false,
    dotAll: true,
  ).allMatches(data).map((m) => _plain(m.group(2)!)).where((t) => t.isNotEmpty);
  final text = blocks.isNotEmpty ? blocks.join(' | ') : _plain(data);
  return text.length > 400 ? "${text.substring(0, 400)}..." : text;
}

String _plain(String html) => html
    .replaceAll(RegExp(r'<[^>]+>'), ' ')
    .replaceAll('&quot;', '"')
    .replaceAll('&#039;', "'")
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
