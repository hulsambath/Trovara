import 'dart:convert';

/// Typed exception for LLM API failures.
///
/// Lives in its own file (extracted from [LlmClient]) to keep that file under
/// the 300 LOC limit in `docs/style_guide/File_Organization_Rules.md`.
class LlmApiException implements Exception {
  final int statusCode;
  final String message;
  final String? type;
  final String? code;

  LlmApiException({required this.statusCode, required this.message, this.type, this.code});

  bool get isInsufficientQuota =>
      statusCode == 429 &&
      (code == 'insufficient_quota' ||
          type == 'insufficient_quota' ||
          code == 'quota_exceeded' ||
          type == 'quota_exceeded');

  /// True when the request never reached the server (DNS failure, no
  /// connectivity, TLS handshake failure). Distinct from an HTTP error
  /// response — callers should show an "offline" message, not an API error.
  bool get isNetworkError => code == 'network_error';

  /// Build a network-error exception from a connectivity failure (a raw
  /// `SocketException` / `ClientException` thrown before any HTTP response).
  factory LlmApiException.network(String message) =>
      LlmApiException(statusCode: 0, message: message, type: 'network_error', code: 'network_error');

  /// Build from an OpenAI-compatible error envelope: `{ "error": { ... } }`.
  static LlmApiException fromHttp({required int statusCode, required String body}) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is Map) {
        final err = decoded['error'] as Map;
        return LlmApiException(
          statusCode: statusCode,
          message: err['message']?.toString() ?? 'Unknown error',
          type: err['type']?.toString(),
          code: err['code']?.toString(),
        );
      }
    } catch (_) {}

    final truncated = body.length > 500 ? '${body.substring(0, 500)}…' : body;
    return LlmApiException(statusCode: statusCode, message: truncated);
  }

  @override
  String toString() {
    final parts = <String>['LLM API error ($statusCode): $message'];
    if (type != null && type!.isNotEmpty) parts.add('type=$type');
    if (code != null && code!.isNotEmpty) parts.add('code=$code');
    return parts.join(' ');
  }
}
