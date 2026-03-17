import 'dart:async';
import 'dart:convert';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

enum LlmProvider { openAiCompatible, gemini }

/// Client for an OpenAI-compatible chat completions API.
///
/// Default target is OpenRouter (`https://openrouter.ai/api/v1`).
///
/// This is **Step 5** of the RAG pipeline — the LLM generator that
/// receives an augmented prompt (from Step 4) and produces an answer.
///
/// ```
/// Augmented prompt (Step 4)
///     │
///     ▼
/// LlmClient.generate() / generateStream()
///     │
///     ▼
/// Answer string (→ Step 6 Chat UI)
/// ```
///
/// Responsibilities:
/// - Call Chat Completions (OpenAI-compatible)
/// - Provide single-turn generation ([generate])
/// - Provide streaming generation ([generateStream])
/// - Handle API errors gracefully
class LlmClient {
  static const String defaultBaseUrl = 'https://openrouter.ai/api/v1';

  /// Default model for OpenRouter (provider/model format).
  ///
  /// Can be overridden via DI. Use `openrouter/auto` to let OpenRouter choose.
  static const String defaultModel = 'openai/gpt-3.5-turbo';

  /// Default model for Gemini.
  static const String defaultGeminiModel = 'gemini-1.5-flash';

  /// Gemini ListModels endpoint used for resolving available models.
  static const String _geminiModelsEndpoint = 'https://generativelanguage.googleapis.com/v1beta/models';

  /// Default generation parameters tuned for factual, grounded answers.
  static const double defaultTemperature = 0.3;
  static const double defaultTopP = 0.8;
  static const int defaultMaxOutputTokens = 1024;

  final LlmProvider _provider;
  final String _apiKey;
  final String _modelName;
  final String _baseUrl;
  final String? _siteUrl;
  final String? _appName;
  final double _temperature;
  final double _topP;
  final int _maxOutputTokens;
  final Logger _logger = Logger();

  http.Client? _client;
  GenerativeModel? _geminiModel;
  String? _resolvedGeminiModelName;
  bool? _resolvedGeminiSupportsStreaming;
  bool _isInitialized = false;

  LlmClient({
    LlmProvider provider = LlmProvider.openAiCompatible,
    required String apiKey,
    String modelName = defaultModel,
    String baseUrl = defaultBaseUrl,
    String? siteUrl,
    String? appName,
    double temperature = defaultTemperature,
    double topP = defaultTopP,
    int maxOutputTokens = defaultMaxOutputTokens,
  }) : _provider = provider,
       _apiKey = apiKey,
       _modelName = modelName,
       _baseUrl = baseUrl,
       _siteUrl = siteUrl,
       _appName = appName,
       _temperature = temperature,
       _topP = topP,
       _maxOutputTokens = maxOutputTokens;

  /// Whether the client has been successfully initialized with a valid API key.
  bool get isAvailable => _isInitialized && _apiKey.isNotEmpty;

  LlmProvider get provider => _provider;

  /// The name of the underlying generative model.
  String get modelName => _resolvedGeminiModelName ?? _modelName;

  // ═══════════════════════════════════════════════════════════════════════════
  //  Initialization
  // ═══════════════════════════════════════════════════════════════════════════

  /// Initialize the HTTP client.
  ///
  /// Must be called before [generate] or [generateStream]. If no API key
  /// was provided, initialization is skipped and [isAvailable] remains false.
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (_apiKey.isEmpty) {
      _logger.w('LlmClient: No API key provided — generation disabled');
      return;
    }

    switch (_provider) {
      case LlmProvider.openAiCompatible:
        _client = http.Client();
        _isInitialized = true;
        _logger.i('LlmClient initialized (OpenAI-compatible) (baseUrl=$_baseUrl, model=$_modelName)');
        return;
      case LlmProvider.gemini:
        _geminiModel = GenerativeModel(model: _modelName, apiKey: _apiKey);
        _isInitialized = true;
        _logger.i('LlmClient initialized (Gemini) (model=$modelName)');
        return;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Gemini helpers
  // ═══════════════════════════════════════════════════════════════════════════

  bool _isGeminiModelNotFound(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('is not found for api version') ||
        message.contains('not supported for generatecontent') ||
        message.contains('not found');
  }

  bool _isGeminiStreamingNotSupported(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('streamgeneratecontent') &&
        (message.contains('not supported') || message.contains('not found') || message.contains('unsupported'));
  }

  bool _isGeminiAuthError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('api key not valid') ||
        message.contains('permission_denied') ||
        message.contains('permission denied') ||
        message.contains('unauthenticated') ||
        message.contains('authentication');
  }

  bool _isGeminiQuotaError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('quota') ||
        message.contains('rate limit') ||
        message.contains('resource_exhausted') ||
        message.contains('too many requests');
  }

  String _normalizeGeminiModelName(String name) {
    final trimmed = name.trim();
    if (trimmed.startsWith('models/')) {
      return trimmed.substring('models/'.length);
    }
    return trimmed;
  }

  LlmApiException _wrapGeminiException(Object error) {
    final message = error.toString();
    if (_isGeminiAuthError(error)) {
      return LlmApiException(statusCode: 401, message: message, type: 'gemini_error', code: 'auth_error');
    }
    if (_isGeminiQuotaError(error)) {
      return LlmApiException(statusCode: 429, message: message, type: 'gemini_error', code: 'quota_exceeded');
    }
    if (_isGeminiModelNotFound(error)) {
      return LlmApiException(statusCode: 404, message: message, type: 'gemini_error', code: 'model_not_found');
    }
    return LlmApiException(statusCode: 500, message: message, type: 'gemini_error', code: 'unknown');
  }

  Future<void> _resolveGeminiModelForGeneration() async {
    if (_provider != LlmProvider.gemini) return;
    if (_resolvedGeminiModelName != null) return;

    // Try to discover a supported model for this API key.
    try {
      final uri = Uri.parse('$_geminiModelsEndpoint?key=$_apiKey');
      final res = await http.get(uri);

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

      int scoreModel({required String name, required bool supportsStream}) {
        final normalized = _normalizeGeminiModelName(name).toLowerCase();

        // Prefer stable text-generation models over previews/experiments/specialized tools.
        var score = 0;
        if (supportsStream) score += 1000;

        // Prefer flash models for speed/cost.
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

        // De-prioritize models that tend to be specialized or unstable for chat.
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

      String? best;
      bool bestSupportsStream = false;
      var bestScore = -1 << 30;

      for (final m in models) {
        if (m is! Map) continue;
        final name = m['name']?.toString();
        if (name == null || name.isEmpty) continue;

        final supported = m['supportedGenerationMethods'];
        if (supported is! List) continue;
        final methods = supported.map((e) => e.toString()).toSet();

        // Prefer models that support both streaming and non-streaming.
        final supportsGenerate = methods.contains('generateContent');
        final supportsStream = methods.contains('streamGenerateContent');
        if (!supportsGenerate) continue;

        final score = scoreModel(name: name, supportsStream: supportsStream);
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

      final normalized = _normalizeGeminiModelName(best);
      _resolvedGeminiModelName = normalized;
      _resolvedGeminiSupportsStreaming = bestSupportsStream;
      _geminiModel = GenerativeModel(model: normalized, apiKey: _apiKey);
      _logger.w(
        'Gemini model "$_modelName" unavailable; using "$normalized" instead '
        '(streaming=${bestSupportsStream ? 'yes' : 'no'})',
      );
    } catch (e) {
      // Keep original model and let the caller surface the error.
      if (e is LlmApiException) rethrow;
      throw _wrapGeminiException(e);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Public API
  // ═══════════════════════════════════════════════════════════════════════════

  /// Generate a complete response (non-streaming).
  ///
  /// Sends the [prompt] to the chat completions endpoint and waits for the full response.
  /// Returns the generated text or a fallback message if the response is empty.
  ///
  /// Throws if the API call fails — callers should handle errors.
  Future<String> generate(String prompt) async {
    if (!isAvailable) {
      throw StateError('LlmClient is not initialized or API key is missing');
    }

    try {
      if (_provider == LlmProvider.gemini) {
        try {
          final res = await _geminiModel!.generateContent(
            [Content.text(prompt)],
            generationConfig: GenerationConfig(
              temperature: _temperature,
              topP: _topP,
              maxOutputTokens: _maxOutputTokens,
            ),
          );
          final text = res.text ?? '';
          if (text.isEmpty) {
            _logger.w('LLM returned empty response');
            return 'No response generated.';
          }
          _logger.d('LLM generated ${text.length} chars');
          return text;
        } catch (e) {
          if (_isGeminiModelNotFound(e)) {
            await _resolveGeminiModelForGeneration();
            final res = await _geminiModel!.generateContent(
              [Content.text(prompt)],
              generationConfig: GenerationConfig(
                temperature: _temperature,
                topP: _topP,
                maxOutputTokens: _maxOutputTokens,
              ),
            );
            final text = res.text ?? '';
            if (text.isEmpty) {
              _logger.w('LLM returned empty response');
              return 'No response generated.';
            }
            _logger.d('LLM generated ${text.length} chars');
            return text;
          }

          throw _wrapGeminiException(e);
        }
      }

      final uri = Uri.parse('$_baseUrl/chat/completions');
      final res = await _client!.post(
        uri,
        headers: _buildHeaders(),
        body: jsonEncode({
          'model': _modelName,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'temperature': _temperature,
          'top_p': _topP,
          'max_tokens': _maxOutputTokens,
        }),
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw _parseApiError(statusCode: res.statusCode, body: res.body);
      }

      final decoded = jsonDecode(res.body);
      final choices = (decoded is Map<String, dynamic>) ? decoded['choices'] : null;
      if (choices is! List || choices.isEmpty) {
        _logger.w('LLM returned no choices');
        return 'No response generated.';
      }

      final message = (choices.first as Map)['message'];
      final content = (message is Map) ? message['content'] : null;
      final text = content?.toString() ?? '';
      if (text.isEmpty) {
        _logger.w('LLM returned empty response');
        return 'No response generated.';
      }

      _logger.d('LLM generated ${text.length} chars');
      return text;
    } catch (e) {
      _logger.e('LLM generation error: $e');
      rethrow;
    }
  }

  /// Stream a response token-by-token.
  ///
  /// Sends the [prompt] to the chat completions endpoint and yields text chunks as they arrive.
  /// Useful for real-time UI updates in the chat interface.
  ///
  /// Throws if the API call fails — callers should handle errors.
  Stream<String> generateStream(String prompt) async* {
    if (!isAvailable) {
      throw StateError('LlmClient is not initialized or API key is missing');
    }

    try {
      if (_provider == LlmProvider.gemini) {
        // If we already know streaming isn't supported for this API key/model,
        // fall back to non-streaming generation.
        if (_resolvedGeminiSupportsStreaming == false) {
          yield await generate(prompt);
          return;
        }

        var yieldedAny = false;
        try {
          await for (final res in _geminiModel!.generateContentStream(
            [Content.text(prompt)],
            generationConfig: GenerationConfig(
              temperature: _temperature,
              topP: _topP,
              maxOutputTokens: _maxOutputTokens,
            ),
          )) {
            final text = res.text ?? '';
            if (text.isNotEmpty) {
              yieldedAny = true;
              yield text;
            }
          }
          return;
        } catch (e) {
          // Only attempt a fallback if we haven't yielded any text yet.
          if (!yieldedAny && (_isGeminiStreamingNotSupported(e) || _isGeminiModelNotFound(e))) {
            await _resolveGeminiModelForGeneration();

            // If the resolved model doesn't support streaming, fall back.
            if (_resolvedGeminiSupportsStreaming == false) {
              yield await generate(prompt);
              return;
            }

            try {
              await for (final res in _geminiModel!.generateContentStream(
                [Content.text(prompt)],
                generationConfig: GenerationConfig(
                  temperature: _temperature,
                  topP: _topP,
                  maxOutputTokens: _maxOutputTokens,
                ),
              )) {
                final text = res.text ?? '';
                if (text.isNotEmpty) {
                  yield text;
                }
              }
              return;
            } catch (e2) {
              // If streaming still isn't supported (or becomes unsupported), fall back.
              if (_isGeminiStreamingNotSupported(e2)) {
                _resolvedGeminiSupportsStreaming = false;
                yield await generate(prompt);
                return;
              }
              throw _wrapGeminiException(e2);
            }
          }

          throw _wrapGeminiException(e);
        }
      }

      final uri = Uri.parse('$_baseUrl/chat/completions');
      final req = http.Request('POST', uri)
        ..headers.addAll(_buildHeaders())
        ..body = jsonEncode({
          'model': _modelName,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'temperature': _temperature,
          'top_p': _topP,
          'max_tokens': _maxOutputTokens,
          'stream': true,
        });

      final streamed = await _client!.send(req);
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        final body = await streamed.stream.bytesToString();
        throw _parseApiError(statusCode: streamed.statusCode, body: body);
      }

      final lines = streamed.stream.transform(utf8.decoder).transform(const LineSplitter());
      await for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        if (!trimmed.startsWith('data:')) continue;

        final data = trimmed.substring('data:'.length).trim();
        if (data == '[DONE]') {
          break;
        }

        dynamic chunk;
        try {
          chunk = jsonDecode(data);
        } catch (_) {
          continue;
        }

        if (chunk is! Map) continue;
        final choices = chunk['choices'];
        if (choices is! List || choices.isEmpty) continue;

        final delta = (choices.first as Map)['delta'];
        final content = (delta is Map) ? delta['content'] : null;
        final text = content?.toString() ?? '';
        if (text.isNotEmpty) {
          yield text;
        }
      }
    } catch (e) {
      _logger.e('LLM streaming error: $e');
      rethrow;
    }
  }

  Map<String, String> _buildHeaders() {
    if (_provider != LlmProvider.openAiCompatible) {
      throw StateError('_buildHeaders is only valid for OpenAI-compatible providers');
    }

    final headers = <String, String>{'Authorization': 'Bearer $_apiKey', 'Content-Type': 'application/json'};

    // Recommended by OpenRouter for attribution/analytics.
    if (_siteUrl != null && _siteUrl.trim().isNotEmpty) {
      headers['HTTP-Referer'] = _siteUrl.trim();
    }
    if (_appName != null && _appName.trim().isNotEmpty) {
      headers['X-Title'] = _appName.trim();
    }

    return headers;
  }

  LlmApiException _parseApiError({required int statusCode, required String body}) {
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
    } catch (_) {
      // Ignore JSON parse errors.
    }

    final truncated = body.length > 500 ? '${body.substring(0, 500)}…' : body;
    return LlmApiException(statusCode: statusCode, message: truncated);
  }
}

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

  @override
  String toString() {
    final parts = <String>['LLM API error ($statusCode): $message'];
    if (type != null && type!.isNotEmpty) parts.add('type=$type');
    if (code != null && code!.isNotEmpty) parts.add('code=$code');
    return parts.join(' ');
  }
}
