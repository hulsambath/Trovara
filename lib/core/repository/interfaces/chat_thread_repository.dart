import 'package:trovara/models/chat_thread.dart';

/// Interface for chat thread repository operations.
///
/// Keeps the persistence layer for chat threads abstract so that
/// higher-level services (ChatService) depend only on this contract.
abstract class IChatThreadRepository {
  /// Initialize the repository.
  Future<void> initialize();

  /// Get a single thread by ID.
  ChatThread? getThreadById(int id);

  /// Get all non-deleted threads associated with a specific note.
  List<ChatThread> getThreadsByNote(int noteId);

  /// Get all non-deleted global threads (not tied to any note).
  List<ChatThread> getGlobalThreads();

  /// Get all non-deleted threads (both global and per-note).
  List<ChatThread> getAllThreads();

  /// Create a new chat thread.
  Future<ChatThread> createThread({required String type, int? noteId, String? title});

  /// Update an existing thread.
  Future<void> updateThread(ChatThread thread);

  /// Insert or update a thread (used during import/sync).
  /// Unlike [createThread], this preserves the thread's existing ID.
  Future<void> upsertThread(ChatThread thread);

  /// Soft-delete a thread and its messages at the repository level.
  ///
  /// Actual message deletion is handled by ChatService; this method
  /// only marks the thread as deleted or removes it, depending on
  /// implementation strategy.
  Future<void> deleteThread(int id);

  /// Add a listener for data changes.
  void addListener(Function() listener);

  /// Remove a listener.
  void removeListener(Function() listener);

  /// Dispose the repository.
  void dispose();
}
