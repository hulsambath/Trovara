import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:trovara/core/services/ai/llm_api_exception.dart';

/// Result of resolving a usable Gemini model for an API key.
typedef GeminiModelChoice = ({String model, bool supportsStream});

/// Classifies Gemini SDK errors and resolves a supported model via the Gemini
/// ListModels endpoint.
///
/// Ported from the former monolithic `LlmClient` so [GeminiApiLlmProvider] can
/// recover when its configured model is unavailable for an API key (e.g. an
/// older `gemini-1.5-*` id that has since been retired).
class GeminiModelResolver {
  GeminiModelResolver._();

  static const String _modelsEndpoint = 'https://generativelanguage.googleapis.com/v1beta/models';

  static bool isModelNotFound(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('is not found for api version') ||
        message.contains('not supported for generatecontent') ||
        message.contains('not found');
  }

  static bool isStreamingNotSupported(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('streamgeneratecontent') &&
        (message.contains('not supported') || message.contains('not found') || message.contains('unsupported'));
  }

  static bool isAuthError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('api key not valid') ||
        message.contains('permission_denied') ||
        message.contains('permission denied') ||
        message.contains('unauthenticated') ||
        message.contains('authentication');
  }

  static bool isQuotaError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('quota') ||
        message.contains('rate limit') ||
        message.contains('resource_exhausted') ||
        message.contains('too many requests');
  }

  static String normalize(String name) {
    final trimmed = name.trim();
    return trimmed.startsWith('models/') ? trimmed.substring('models/'.length) : trimmed;
  }

  /// Wrap a raw Gemini SDK error into a typed [LlmApiException] with a code.
  static LlmApiException wrap(Object error) {
    final message = error.toString();
    if (isAuthError(error)) {
      return LlmApiException(statusCode: 401, message: message, type: 'gemini_error', code: 'auth_error');
    }
    if (isQuotaError(error)) {
      return LlmApiException(statusCode: 429, message: message, type: 'gemini_error', code: 'quota_exceeded');
    }
    if (isModelNotFound(error)) {
      return LlmApiException(statusCode: 404, message: message, type: 'gemini_error', code: 'model_not_found');
    }
    return LlmApiException(statusCode: 500, message: message, type: 'gemini_error', code: 'unknown');
  }

  /// Discover the best supported `generateContent` model for [apiKey].
  ///
  /// Throws [LlmApiException] if the listing fails or no model qualifies.
  static Future<GeminiModelChoice> resolveBest({required String apiKey}) async {
    final res = await http.get(Uri.parse('$_modelsEndpoint?key=$apiKey'));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw LlmApiException(
        statusCode: res.statusCode,
        message: 'Failed to list Gemini models: ${res.body}',
        type: 'gemini_error',
        code: 'list_models_failed',
      );
    }

    final decoded = jsonDecode(res.body);
    final models = (decoded is Map<String, dynamic>) ? decoded['models'] : null;
    if (models is! List) {
      throw LlmApiException(
        statusCode: 500,
        message: 'Unexpected Gemini ListModels response',
        type: 'gemini_error',
        code: 'list_models_failed',
      );
    }

    String? best;
    var bestSupportsStream = false;
    var bestScore = -1 << 30;

    for (final m in models) {
      if (m is! Map) continue;
      final name = m['name']?.toString();
      if (name == null || name.isEmpty) continue;

      final supported = m['supportedGenerationMethods'];
      if (supported is! List) continue;
      final methods = supported.map((e) => e.toString()).toSet();
      if (!methods.contains('generateContent')) continue;

      final supportsStream = methods.contains('streamGenerateContent');
      final score = _score(name: name, supportsStream: supportsStream);
      if (score > bestScore) {
        bestScore = score;
        best = name;
        bestSupportsStream = supportsStream;
      }
    }

    if (best == null) {
      throw LlmApiException(
        statusCode: 404,
        message: 'No Gemini models available for generateContent',
        type: 'gemini_error',
        code: 'model_not_found',
      );
    }

    return (model: normalize(best), supportsStream: bestSupportsStream);
  }

  static int _score({required String name, required bool supportsStream}) {
    final normalized = normalize(name).toLowerCase();
    var score = supportsStream ? 1000 : 0;

    // Prefer stable flash models for speed/cost, then pro, over previews/tools.
    const preferred = <String>[
      'gemini-2.5-flash',
      'gemini-2.0-flash',
      'gemini-1.5-flash',
      'gemini-2.5-pro',
      'gemini-1.5-pro',
      'gemini-1.0-pro',
      'gemini-pro',
    ];
    for (var i = 0; i < preferred.length; i++) {
      if (normalized.startsWith(preferred[i])) {
        score += 500 - i * 10;
        break;
      }
    }

    const avoidTokens = <String>[
      'preview',
      'exp',
      'experimental',
      'image',
      'vision',
      'deep-research',
      'computer-use',
      'audiogen',
      'tts',
    ];
    for (final t in avoidTokens) {
      if (normalized.contains(t)) score -= 50;
    }

    return score;
  }
}
