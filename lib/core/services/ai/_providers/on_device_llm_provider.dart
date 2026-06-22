import 'package:trovara/core/services/ai/_providers/llm_chat_backend.dart';

/// Free-tier on-device chat backend.
///
/// STUB: returns a deterministic placeholder. Plan B replaces the body with a
/// MediaPipe LLM Inference runtime; the [LlmChatBackend] contract stays identical
/// so no caller changes when the real engine lands.
class OnDeviceLlmProvider implements LlmChatBackend {
  static const String comingSoonAnswer =
      'On-device AI is being prepared on your device. Please try again shortly.';

  @override
  Future<String> generate({
    required String systemPrompt,
    required List<ChatTurn> history,
    required String userMessage,
  }) async => comingSoonAnswer;

  @override
  Stream<String> generateStream({
    required String systemPrompt,
    required List<ChatTurn> history,
    required String userMessage,
  }) async* {
    yield comingSoonAnswer;
  }
}
