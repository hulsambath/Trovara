import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:logger/logger.dart';

/// Client for the Gemini generative model.
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
/// - Manage the Gemini `gemini-2.0-flash` generative model instance
/// - Provide single-turn generation ([generate])
/// - Provide streaming generation ([generateStream])
/// - Handle API errors gracefully
class LlmClient {
  static const String defaultModel = 'gemini-2.0-flash';

  /// Default generation parameters tuned for factual, grounded answers.
  static const double defaultTemperature = 0.3;
  static const double defaultTopP = 0.8;
  static const int defaultMaxOutputTokens = 1024;

  final String _apiKey;
  final String _modelName;
  final Logger _logger = Logger();

  GenerativeModel? _model;
  bool _isInitialized = false;

  LlmClient({required String apiKey, String modelName = defaultModel}) : _apiKey = apiKey, _modelName = modelName;

  /// Whether the client has been successfully initialized with a valid API key.
  bool get isAvailable => _isInitialized && _apiKey.isNotEmpty;

  /// The name of the underlying generative model.
  String get modelName => _modelName;

  // ═══════════════════════════════════════════════════════════════════════════
  //  Initialization
  // ═══════════════════════════════════════════════════════════════════════════

  /// Initialize the Gemini generative model.
  ///
  /// Must be called before [generate] or [generateStream]. If no API key
  /// was provided, initialization is skipped and [isAvailable] remains false.
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (_apiKey.isEmpty) {
      _logger.w('LlmClient: No API key provided — generation disabled');
      return;
    }

    _model = GenerativeModel(
      model: _modelName,
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: defaultTemperature,
        topP: defaultTopP,
        maxOutputTokens: defaultMaxOutputTokens,
      ),
    );

    _isInitialized = true;
    _logger.i('LlmClient initialized with model $_modelName');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Public API
  // ═══════════════════════════════════════════════════════════════════════════

  /// Generate a complete response (non-streaming).
  ///
  /// Sends the [prompt] to Gemini and waits for the full response.
  /// Returns the generated text or a fallback message if the response is empty.
  ///
  /// Throws if the API call fails — callers should handle errors.
  Future<String> generate(String prompt) async {
    if (!isAvailable) {
      throw StateError('LlmClient is not initialized or API key is missing');
    }

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);

      final text = response.text;
      if (text == null || text.isEmpty) {
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
  /// Sends the [prompt] to Gemini and yields text chunks as they arrive.
  /// Useful for real-time UI updates in the chat interface.
  ///
  /// Throws if the API call fails — callers should handle errors.
  Stream<String> generateStream(String prompt) async* {
    if (!isAvailable) {
      throw StateError('LlmClient is not initialized or API key is missing');
    }

    try {
      final response = _model!.generateContentStream([Content.text(prompt)]);

      await for (final chunk in response) {
        final text = chunk.text;
        if (text != null && text.isNotEmpty) {
          yield text;
        }
      }
    } catch (e) {
      _logger.e('LLM streaming error: $e');
      rethrow;
    }
  }
}
