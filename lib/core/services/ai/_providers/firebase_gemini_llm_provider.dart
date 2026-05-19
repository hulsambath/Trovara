import 'package:firebase_ai/firebase_ai.dart';
import 'package:trovara/core/services/ai/_providers/llm_chat_backend.dart';

/// LLM provider backed by Firebase AI (Gemini, keyless free tier).
///
/// Uses `FirebaseAI.googleAI()` — no API key in the binary; auth is provided
/// by Firebase project config (google-services.json / GoogleService-Info.plist).
/// Requires `Firebase.initializeApp()` to have been called first
/// (handled by `lib/initializer.dart`).
///
/// This is the fallback chat backend used when no `GEMINI_API_KEY` is set;
/// [GeminiApiLlmProvider] is preferred when a key is configured.
class FirebaseGeminiLlmProvider implements LlmChatBackend {
  /// Gemini model id. Must be the API identifier (`gemini-2.5-flash`), not the
  /// human-readable display name.
  static const String defaultModel = 'gemini-2.5-flash-lite';

  final String modelName;
  final double temperature;
  final double topP;
  final int maxOutputTokens;

  FirebaseGeminiLlmProvider({
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

  GenerativeModel _buildModel(String systemPrompt) {
    final sys = systemPrompt.trim();
    return FirebaseAI.googleAI().generativeModel(
      model: modelName,
      generationConfig: GenerationConfig(temperature: temperature, topP: topP, maxOutputTokens: maxOutputTokens),
      systemInstruction: sys.isEmpty ? null : Content.system(sys),
    );
  }

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
