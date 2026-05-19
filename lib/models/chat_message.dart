import 'package:objectbox/objectbox.dart';
import 'package:trovara/models/chat_source_note.dart';

/// Represents a single persisted message in a chat thread.
///
/// This is the ObjectBox entity used for local/Drive-backed history.
/// The UI-facing chat model is defined below as [ChatMessage] and kept
/// separate to avoid mixing persistence concerns into the view layer.
@Entity()
class ChatMessageEntity {
  int id;

  /// Foreign key reference to [ChatThread.id].
  int threadId;

  /// Role of the message author: 'user', 'assistant', or 'system'.
  String role;

  /// Raw markdown/plaintext content of the message.
  String content;

  /// Optional titles of notes used as context when generating
  /// the assistant response. Only populated for assistant messages.
  List<String> sourceNoteTitles;

  /// Optional note IDs used as context when generating the assistant response.
  /// Only populated for assistant messages.
  List<int> sourceNoteIds;

  /// Optional labels (tags) used to describe source notes.
  /// Only populated for assistant messages.
  List<String> sourceNoteLabels;

  /// Optional token counts for analytics / debugging.
  int? promptTokens;
  int? completionTokens;

  DateTime createdAt;
  DateTime updatedAt;

  ChatMessageEntity({
    this.id = 0,
    required this.threadId,
    required this.role,
    required this.content,
    List<String>? sourceNoteTitles,
    List<int>? sourceNoteIds,
    List<String>? sourceNoteLabels,
    this.promptTokens,
    this.completionTokens,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : sourceNoteTitles = sourceNoteTitles ?? const [],
       sourceNoteIds = sourceNoteIds ?? const [],
       sourceNoteLabels = sourceNoteLabels ?? const [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  void touch() {
    updatedAt = DateTime.now();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'threadId': threadId,
    'role': role,
    'content': content,
    'sourceNoteTitles': sourceNoteTitles,
    'sourceNoteIds': sourceNoteIds,
    'sourceNoteLabels': sourceNoteLabels,
    'promptTokens': promptTokens,
    'completionTokens': completionTokens,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory ChatMessageEntity.fromJson(Map<String, dynamic> json) => ChatMessageEntity(
    id: json['id'] as int? ?? 0,
    threadId: json['threadId'] as int,
    role: json['role'] as String? ?? 'user',
    content: json['content'] as String? ?? '',
    sourceNoteTitles: List<String>.from(json['sourceNoteTitles'] as List? ?? const []),
    sourceNoteIds: List<int>.from(json['sourceNoteIds'] as List? ?? const []),
    sourceNoteLabels: List<String>.from(json['sourceNoteLabels'] as List? ?? const []),
    promptTokens: json['promptTokens'] as int?,
    completionTokens: json['completionTokens'] as int?,
    createdAt: _parseDate(json['createdAt']),
    updatedAt: _parseDate(json['updatedAt']),
  );

  static DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }
}

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
  final List<ChatSourceNote> sourceNotes;

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
    this.sourceNotes = const [],
    this.isLoading = false,
    this.isError = false,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create a copy with updated fields.
  ChatMessage copyWith({String? content, List<ChatSourceNote>? sourceNotes, bool? isLoading, bool? isError}) =>
      ChatMessage(
        id: id,
        content: content ?? this.content,
        isUser: isUser,
        timestamp: timestamp,
        sourceNotes: sourceNotes ?? this.sourceNotes,
        isLoading: isLoading ?? this.isLoading,
        isError: isError ?? this.isError,
      );

  @override
  String toString() =>
      'ChatMessage(${isUser ? 'user' : 'ai'}, '
      '${content.length} chars'
      '${isLoading ? ', loading' : ''})';
}
