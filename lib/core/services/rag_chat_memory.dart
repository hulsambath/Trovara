import 'package:trovara/models/chat_message.dart';

/// One prior dialogue turn for RAG (retrieval + generation).
class RagChatTurn {
  /// `user` or `assistant` only.
  final String role;
  final String content;

  const RagChatTurn({required this.role, required this.content});

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
}

/// Bounds for how much prior chat is sent to the model and rewrite step.
class RagChatMemoryLimits {
  RagChatMemoryLimits._();

  /// Maximum prior messages (user + assistant) after truncation.
  static const int maxPriorMessages = 20;

  /// Total character budget for prior message bodies (roles + labels excluded).
  static const int maxPriorChars = 6000;
}

/// Builds bounded prior-turn lists for RAG from persisted chat rows.
class RagChatMemory {
  RagChatMemory._();

  /// Maps entities to [RagChatTurn], keeping only `user` and `assistant`.
  static List<RagChatTurn> turnsFromEntities(List<ChatMessageEntity> entities) {
    final out = <RagChatTurn>[];
    for (final e in entities) {
      final r = e.role.trim().toLowerCase();
      if (r != 'user' && r != 'assistant') continue;
      final text = e.content.trim();
      if (text.isEmpty) continue;
      out.add(RagChatTurn(role: r, content: text));
    }
    return out;
  }

  /// Keeps a suffix of [turns] within [RagChatMemoryLimits].
  static List<RagChatTurn> truncate(List<RagChatTurn> turns) {
    if (turns.isEmpty) return const [];

    final maxMsg = RagChatMemoryLimits.maxPriorMessages;
    final maxChars = RagChatMemoryLimits.maxPriorChars;

    var slice = turns.length > maxMsg ? turns.sublist(turns.length - maxMsg) : List<RagChatTurn>.from(turns);
    while (slice.isNotEmpty) {
      final total = slice.fold<int>(0, (sum, t) => sum + t.content.length);
      if (total <= maxChars) return slice;
      slice = slice.sublist(1);
    }
    return const [];
  }

  /// Plain transcript for [QueryRewriteService.rewrite] conversation context.
  static String formatForQueryRewrite(List<RagChatTurn> turns) {
    if (turns.isEmpty) return '';
    final b = StringBuffer();
    for (final t in turns) {
      final label = t.isAssistant ? 'Assistant' : 'User';
      b.writeln('$label: ${t.content}');
    }
    return b.toString().trimRight();
  }
}
