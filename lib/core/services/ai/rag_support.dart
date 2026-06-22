import 'package:trovara/core/services/ai/llm_client.dart';
import 'package:trovara/core/services/ai/rag_chat_memory.dart';
import 'package:trovara/core/services/ai/rag_result.dart';

/// Truncated chat history prepared for a RAG turn: a rewrite-context string and
/// the LLM message history.
typedef PreparedChatMemory = ({String rewriteContext, List<LlmChatMessage> llmHistory});

/// Stateless helpers shared by [RagService] and [RagAttribution]: user-facing
/// messages, error translation, chat-memory prep, and debug formatting.
///
/// Extracted from `RagService` (Recipe R2) to keep the orchestrator under the
/// file-size limit. None of these depend on instance state.
class RagSupport {
  RagSupport._();

  static const String notIndexedMessage =
      "Your notes haven't been indexed yet, so I can't search them. "
      'Try creating/editing a note (to trigger embedding), or run a re-embed of all notes.';

  static const String noResultsMessage =
      "I couldn't find any relevant notes for your question. "
      'Try asking about the note content (not just the title), or rephrase your question.';

  static RagResult emptyResult(String answer) =>
      RagResult(answer: answer, sourceNoteTitles: [], prompt: '', matchedChunks: 0);

  /// Maps a known [LlmApiException] to a user-facing message, or null if the
  /// error is not a recognized API failure (caller falls back to a generic msg).
  static String? llmErrorMessage(Object e) {
    if (e is! LlmApiException) return null;
    if (e.code == 'auth_error') {
      return 'Authentication failed while generating the answer. '
          'Please verify your configured API key is valid and has not expired.';
    }
    if (e.code == 'quota_exceeded' || e.isInsufficientQuota) {
      return 'API quota exceeded for this key. Please check your plan/billing, '
          'or configure a different API key.';
    }
    if (e.code == 'model_not_found') {
      return 'The configured AI model is not available for this API key. '
          'Try a different model, or update the app to auto-select a supported model.';
    }
    return null;
  }

  static List<String> uniqueInOrder(Iterable<String> items) {
    final seen = <String>{};
    final out = <String>[];
    for (final s in items) {
      final key = s.trim();
      if (key.isEmpty) continue;
      if (seen.add(key)) out.add(key);
    }
    return out;
  }

  static PreparedChatMemory prepareChatMemory(List<RagChatTurn> priorTurns) {
    final truncated = RagChatMemory.truncate(priorTurns);
    final ctx = RagChatMemory.formatForQueryRewrite(truncated);
    final history = truncated.map((t) => LlmChatMessage(role: t.role, content: t.content)).toList();
    return (rewriteContext: ctx, llmHistory: history);
  }

  static String formatDebugMessages({
    required String systemPrompt,
    required List<LlmChatMessage> history,
    required String userMessage,
  }) {
    final b = StringBuffer();

    final sys = systemPrompt.trim();
    if (sys.isNotEmpty) {
      b.writeln('System: $sys');
    }

    for (final m in history) {
      final label = m.role == 'assistant' ? 'Assistant' : 'User';
      b.writeln('$label: ${m.content}');
    }

    final msg = userMessage.trim();
    if (msg.isNotEmpty) {
      b.writeln('User: $msg');
    }

    return b.toString().trimRight();
  }
}
