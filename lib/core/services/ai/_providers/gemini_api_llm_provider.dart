import 'package:google_generative_ai/google_generative_ai.dart';
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
class GeminiApiLlmProvider implements LlmChatBackend {
  static const String defaultModel = 'gemini-2.5-flash-lite';

  final String apiKey;
  final String modelName;
  final double temperature;
  final double topP;
  final int maxOutputTokens;

  GeminiApiLlmProvider({
    required this.apiKey,
    this.modelName = defaultModel,
    required this.temperature,
    required this.topP,
    required this.maxOutputTokens,
  });

  /// Non-streaming chat completion. Returns the model's text or empty string.
  @override
  Future<String> generate({
    required String systemPrompt,
    required List<ChatTurn> history,
    required String userMessage,
  }) async {
    final model = _buildModel(systemPrompt);
    final res = await model.generateContent(_buildContents(history, userMessage));
    return res.text ?? '';
  }

  /// Streaming chat completion. Yields non-empty text deltas.
  @override
  Stream<String> generateStream({
    required String systemPrompt,
    required List<ChatTurn> history,
    required String userMessage,
  }) async* {
    final model = _buildModel(systemPrompt);
    final stream = model.generateContentStream(_buildContents(history, userMessage));
    await for (final res in stream) {
      final text = res.text ?? '';
      if (text.isNotEmpty) yield text;
    }
  }

  // The model is rebuilt per request because `systemInstruction` is baked in
  // at construction time and varies per call. Construction makes no network
  // call, so this is cheap.
  GenerativeModel _buildModel(String systemPrompt) {
    final sys = systemPrompt.trim();
    return GenerativeModel(
      model: modelName,
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
