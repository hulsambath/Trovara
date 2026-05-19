import 'dart:convert';

/// Typed exception for embedding API failures.
///
/// Lives in its own file (extracted from [EmbeddingService]) to keep that
/// file under 300 LOC per `docs/style_guide/File_Organization_Rules.md`.
class EmbeddingApiException implements Exception {
  final int? statusCode;
  final String message;
  final String? code;

  EmbeddingApiException({required this.statusCode, required this.message, this.code});

  bool get isAuthFailure => statusCode == 401 || statusCode == 403;

  static EmbeddingApiException fromHttp({required int statusCode, required String body}) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is Map) {
        final err = decoded['error'] as Map;
        return EmbeddingApiException(
          statusCode: statusCode,
          message: err['message']?.toString() ?? body,
          code: err['code']?.toString(),
        );
      }
    } catch (_) {}

    final truncated = body.length > 500 ? '${body.substring(0, 500)}…' : body;
    return EmbeddingApiException(statusCode: statusCode, message: truncated);
  }

  @override
  String toString() {
    final parts = <String>['Embedding API error'];
    if (statusCode != null) parts.add('($statusCode)');
    parts.add(': $message');
    if (code != null && code!.isNotEmpty) parts.add('code=$code');
    return parts.join(' ');
  }
}
