/// Represents a single message in the chat conversation.
///
/// Used by [ChatViewModel] to manage the message list displayed in the
/// Chat UI (RAG Step 6). Messages are immutable — when a streaming
/// response updates, a new [ChatMessage] instance replaces the old one.
class ChatMessage {
  /// Unique identifier for this message.
  final String id;

  /// The text content of the message.
  final String content;

  /// Whether this message was sent by the user (`true`) or the AI (`false`).
  final bool isUser;

  /// When the message was created.
  final DateTime timestamp;

  /// Titles of source notes used to generate this answer.
  /// Only populated for AI messages after generation completes.
  final List<String> sourceNoteTitles;

  /// Whether the AI is still generating this message.
  /// Used by the UI to show a typing indicator.
  final bool isLoading;

  /// Whether this message is an error response.
  final bool isError;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    DateTime? timestamp,
    this.sourceNoteTitles = const [],
    this.isLoading = false,
    this.isError = false,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create a copy with updated fields.
  ChatMessage copyWith({String? content, List<String>? sourceNoteTitles, bool? isLoading, bool? isError}) =>
      ChatMessage(
        id: id,
        content: content ?? this.content,
        isUser: isUser,
        timestamp: timestamp,
        sourceNoteTitles: sourceNoteTitles ?? this.sourceNoteTitles,
        isLoading: isLoading ?? this.isLoading,
        isError: isError ?? this.isError,
      );

  @override
  String toString() =>
      'ChatMessage(${isUser ? 'user' : 'ai'}, '
      '${content.length} chars'
      '${isLoading ? ', loading' : ''})';
}
