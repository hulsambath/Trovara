import 'package:trovara/core/services/ai/_providers/chat_turn.dart';

export 'package:trovara/core/services/ai/_providers/chat_turn.dart';

/// Common contract for an LLM chat backend behind [LlmClient].
///
/// Implemented by every provider in this folder so [LlmClient] can hold a
/// single backend reference and dispatch without branching on the provider
/// enum. New providers (Open/Closed) only need to implement this interface.
abstract interface class LlmChatBackend {
  /// Non-streaming chat completion. Returns the model's text or empty string.
  Future<String> generate({required String systemPrompt, required List<ChatTurn> history, required String userMessage});

  /// Streaming chat completion. Yields non-empty text deltas.
  Stream<String> generateStream({
    required String systemPrompt,
    required List<ChatTurn> history,
    required String userMessage,
  });
}
