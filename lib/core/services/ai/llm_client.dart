import 'package:logger/logger.dart';
import 'package:trovara/core/services/ai/_providers/gemini_api_llm_provider.dart';
import 'package:trovara/core/services/ai/_providers/llm_chat_backend.dart';
import 'package:trovara/core/services/ai/_providers/openai_compatible_llm_provider.dart';

export 'package:trovara/core/services/ai/llm_api_exception.dart';

enum LlmProvider { openAiCompatible, gemini }

/// One prior turn for [LlmClient.generateWithMessages] / [generateStreamWithMessages].
///
/// Roles must be `user` or `assistant` (OpenAI-compatible).
class LlmChatMessage {
  final String role;
  final String content;

  const LlmChatMessage({required this.role, required this.content});

  ChatTurn _toTurn() => (role: role, content: content);
}

/// Provider-agnostic facade over an [LlmChatBackend].
///
/// **Step 5** of the RAG pipeline — receives an augmented prompt and produces
/// an answer. Selects the concrete backend ([GeminiApiLlmProvider] or
/// [OpenAiCompatibleLlmProvider]) in [initialize] based on [LlmProvider], then
/// delegates every call. New providers (Open/Closed) implement [LlmChatBackend]
/// and are wired here — callers keep depending only on [LlmClient].
class LlmClient {
  static const String defaultBaseUrl = 'https://openrouter.ai/api/v1';

  /// Default model for OpenRouter (provider/model format).
  static const String defaultModel = 'openai/gpt-3.5-turbo';

  /// Default model for Gemini.
  static const String defaultGeminiModel = 'gemini-1.5-flash';

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

  LlmChatBackend? _backend;
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
  String get modelName => _modelName;

  /// Build the concrete backend for the configured provider.
  ///
  /// Must be called before generation. If no API key was provided,
  /// initialization is skipped and [isAvailable] remains false.
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (_apiKey.isEmpty) {
      _logger.w('LlmClient: No API key provided — generation disabled');
      return;
    }

    _backend = switch (_provider) {
      LlmProvider.gemini => GeminiApiLlmProvider(
        apiKey: _apiKey,
        modelName: _modelName,
        temperature: _temperature,
        topP: _topP,
        maxOutputTokens: _maxOutputTokens,
      ),
      LlmProvider.openAiCompatible => OpenAiCompatibleLlmProvider(
        apiKey: _apiKey,
        baseUrl: _baseUrl,
        modelName: _modelName,
        siteUrl: _siteUrl,
        appName: _appName,
        temperature: _temperature,
        topP: _topP,
        maxOutputTokens: _maxOutputTokens,
      ),
    };
    _isInitialized = true;
    _logger.i('LlmClient initialized ($_provider, model=$_modelName)');
  }

  /// Generate a complete response (non-streaming) for a bare prompt.
  Future<String> generate(String prompt) =>
      generateWithMessages(systemPrompt: '', history: const [], userMessage: prompt);

  /// Non-streaming chat completion with optional system prompt and history.
  ///
  /// [history] must use roles `user` and `assistant` only. The final user turn
  /// is [userMessage] (e.g. RAG payload for the current question).
  Future<String> generateWithMessages({
    required String systemPrompt,
    required List<LlmChatMessage> history,
    required String userMessage,
  }) async {
    _ensureAvailable();
    final msg = userMessage.trim();
    if (msg.isEmpty) {
      _logger.w('LLM: empty user message');
      return 'No response generated.';
    }

    try {
      final text = await _backend!.generate(
        systemPrompt: systemPrompt,
        history: history.map((m) => m._toTurn()).toList(),
        userMessage: msg,
      );
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

  /// Stream a response token-by-token for a bare prompt.
  Stream<String> generateStream(String prompt) =>
      generateStreamWithMessages(systemPrompt: '', history: const [], userMessage: prompt);

  /// Streaming chat completion with optional system prompt and history.
  Stream<String> generateStreamWithMessages({
    required String systemPrompt,
    required List<LlmChatMessage> history,
    required String userMessage,
  }) async* {
    _ensureAvailable();
    final msg = userMessage.trim();
    if (msg.isEmpty) return;

    try {
      yield* _backend!.generateStream(
        systemPrompt: systemPrompt,
        history: history.map((m) => m._toTurn()).toList(),
        userMessage: msg,
      );
    } catch (e) {
      _logger.e('LLM streaming error: $e');
      rethrow;
    }
  }

  void _ensureAvailable() {
    if (!isAvailable || _backend == null) {
      throw StateError('LlmClient is not initialized or API key is missing');
    }
  }
}
