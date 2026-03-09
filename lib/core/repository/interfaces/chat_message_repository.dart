import 'package:trovara/models/chat_message.dart';

/// Interface for chat message repository operations.
///
/// Separates persistence of messages from business logic so that
/// ChatService can focus on sequencing and validation.
abstract class IChatMessageRepository {
  /// Initialize the repository.
  Future<void> initialize();

  /// Get all messages in a thread, ordered by [createdAt] ascending.
  List<ChatMessageEntity> getMessagesForThread(int threadId);

  /// Get the most recent N messages in a thread, ordered by [createdAt] ascending.
  List<ChatMessageEntity> getRecentMessagesForThread(int threadId, {int limit});

  /// Create a new message.
  Future<ChatMessageEntity> createMessage(ChatMessageEntity message);

  /// Update an existing message.
  Future<void> updateMessage(ChatMessageEntity message);

  /// Insert or update a message (used during import/sync).
  /// Unlike [createMessage], this preserves the message's existing ID.
  Future<void> upsertMessage(ChatMessageEntity message);

  /// Delete all messages belonging to a thread.
  Future<void> deleteMessagesForThread(int threadId);

  /// Delete a single message by ID.
  Future<void> deleteMessage(int id);

  /// Add a listener for data changes.
  void addListener(Function() listener);

  /// Remove a listener.
  void removeListener(Function() listener);

  /// Dispose the repository.
  void dispose();
}
