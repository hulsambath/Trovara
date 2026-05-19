import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

/// Embedding provider for any OpenAI-compatible HTTP endpoint
/// (OpenAI, OpenRouter, self-hosted proxies).
///
/// Exposes both the raw vector and the last [http.Response] so the caller
/// can build a typed exception with status code + body context.
class OpenAiCompatibleEmbeddingProvider {
  final String apiKey;
  final String baseUrl;
  final String modelName;
  final String? siteUrl;
  final String? appName;

  final http.Client _client = http.Client();
  final Logger _logger = Logger();

  OpenAiCompatibleEmbeddingProvider({
    required this.apiKey,
    required this.baseUrl,
    required this.modelName,
    this.siteUrl,
    this.appName,
  });

  /// Returns `(vector, response)`. Either may be `null`:
  ///   - `vector == null` → request failed; check `response` for status/body
  ///   - `response == null` → exception thrown (network error, etc.)
  Future<(List<double>?, http.Response?)> embed(String text) async {
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/embeddings'),
        headers: _buildHeaders(),
        body: jsonEncode({'model': modelName, 'input': text}),
      );

      if (res.statusCode < 200 || res.statusCode >= 300) return (null, res);

      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return (null, res);
      final data = decoded['data'];
      if (data is! List || data.isEmpty) return (null, res);
      final first = data.first;
      if (first is! Map) return (null, res);
      final embedding = first['embedding'];
      if (embedding is! List) return (null, res);

      final vec = embedding.map((e) => (e as num).toDouble()).toList(growable: false);
      return (vec, res);
    } catch (e) {
      _logger.e('OpenAI-compatible embedding error: $e');
      return (null, null);
    }
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'};
    final site = siteUrl?.trim();
    final app = appName?.trim();
    if (site != null && site.isNotEmpty) headers['HTTP-Referer'] = site;
    if (app != null && app.isNotEmpty) headers['X-Title'] = app;
    return headers;
  }
}
