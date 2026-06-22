import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:trovara/core/services/ai/_providers/gemini_model_resolver.dart';
import 'package:trovara/core/services/ai/_providers/llm_chat_backend.dart';

/// LLM provider backed by the Gemini Developer API (`google_generative_ai`).
///
/// Uses an explicit `GEMINI_API_KEY` (injected at build time via
/// `--dart-define`). This is the default chat backend whenever a key is
/// configured; [FirebaseGeminiLlmProvider] is the keyless fallback otherwise.
///
/// `firebase_ai` is intentionally not reused here — the keyless Firebase path
/// and the API-key path are kept as separate providers so `ServiceLocator`
/// can select between them. The model id must be the API identifier
/// (`gemini-2.5-flash`), not the human-readable display name.
///
/// If the configured model is unavailable for the key, the provider resolves a
/// supported model once via [GeminiModelResolver] and retries — and falls back
/// to non-streaming when the resolved model lacks `streamGenerateContent`.
class GeminiApiLlmProvider implements LlmChatBackend {
  static const String defaultModel = 'gemini-2.5-flash-lite';

  final String apiKey;
  final String modelName;
  final double temperature;
  final double topP;
  final int maxOutputTokens;

  String _activeModel;
  bool? _supportsStream;

  GeminiApiLlmProvider({
    required this.apiKey,
    this.modelName = defaultModel,
    required this.temperature,
    required this.topP,
    required this.maxOutputTokens,
  }) : _activeModel = modelName;

  @override
  Future<String> generate({
    required String systemPrompt,
    required List<ChatTurn> history,
    required String userMessage,
  }) async {
    final contents = _buildContents(history, userMessage);
    try {
      return (await _buildModel(systemPrompt).generateContent(contents)).text ?? '';
    } catch (e) {
      if (!GeminiModelResolver.isModelNotFound(e)) throw GeminiModelResolver.wrap(e);
      await _resolve();
      try {
        return (await _buildModel(systemPrompt).generateContent(contents)).text ?? '';
      } catch (e2) {
        throw GeminiModelResolver.wrap(e2);
      }
    }
  }

  @override
  Stream<String> generateStream({
    required String systemPrompt,
    required List<ChatTurn> history,
    required String userMessage,
  }) async* {
    if (_supportsStream == false) {
      yield await generate(systemPrompt: systemPrompt, history: history, userMessage: userMessage);
      return;
    }

    final contents = _buildContents(history, userMessage);
    var yieldedAny = false;
    try {
      await for (final res in _buildModel(systemPrompt).generateContentStream(contents)) {
        final text = res.text ?? '';
        if (text.isNotEmpty) {
          yieldedAny = true;
          yield text;
        }
      }
    } catch (e) {
      if (yieldedAny || !(GeminiModelResolver.isStreamingNotSupported(e) || GeminiModelResolver.isModelNotFound(e))) {
        throw GeminiModelResolver.wrap(e);
      }
      await _resolve();
      if (_supportsStream == false) {
        yield await generate(systemPrompt: systemPrompt, history: history, userMessage: userMessage);
        return;
      }
      try {
        await for (final res in _buildModel(systemPrompt).generateContentStream(contents)) {
          final text = res.text ?? '';
          if (text.isNotEmpty) yield text;
        }
      } catch (e2) {
        if (GeminiModelResolver.isStreamingNotSupported(e2)) {
          _supportsStream = false;
          yield await generate(systemPrompt: systemPrompt, history: history, userMessage: userMessage);
          return;
        }
        throw GeminiModelResolver.wrap(e2);
      }
    }
  }

  Future<void> _resolve() async {
    final choice = await GeminiModelResolver.resolveBest(apiKey: apiKey);
    _activeModel = choice.model;
    _supportsStream = choice.supportsStream;
  }

  // The model is rebuilt per request because `systemInstruction` is baked in
  // at construction time and varies per call. Construction makes no network
  // call, so this is cheap.
  GenerativeModel _buildModel(String systemPrompt) {
    final sys = systemPrompt.trim();
    return GenerativeModel(
      model: _activeModel,
      apiKey: apiKey,
      generationConfig: GenerationConfig(temperature: temperature, topP: topP, maxOutputTokens: maxOutputTokens),
      systemInstruction: sys.isEmpty ? null : Content.system(sys),
    );
  }

  // Mirrors FirebaseGeminiLlmProvider._buildContents; cannot be shared because
  // the two SDKs expose distinct (identically named) `Content` types.
  List<Content> _buildContents(List<ChatTurn> history, String userMessage) {
    final contents = <Content>[];
    for (final turn in history) {
      final role = turn.role.trim().toLowerCase();
      if (role == 'assistant') {
        contents.add(Content('model', [TextPart(turn.content)]));
      } else {
        contents.add(Content.text(turn.content));
      }
    }
    contents.add(Content.text(userMessage));
    return contents;
  }
}
