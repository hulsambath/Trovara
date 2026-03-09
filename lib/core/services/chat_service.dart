import 'package:logger/logger.dart';
import 'package:trovara/core/repository/interfaces/chat_message_repository.dart';
import 'package:trovara/core/repository/interfaces/chat_thread_repository.dart';
import 'package:trovara/models/chat_message.dart';
import 'package:trovara/models/chat_thread.dart';

/// Service layer for chat thread and message operations.
///
/// Coordinates between [IChatThreadRepository] and [IChatMessageRepository]
/// and encapsulates business rules (thread reuse, message limits, export/import).
class ChatService {
  final IChatThreadRepository _threadRepository;
  final IChatMessageRepository _messageRepository;
  final Logger _logger = Logger();

  ChatService({required IChatThreadRepository threadRepository, required IChatMessageRepository messageRepository})
    : _threadRepository = threadRepository,
      _messageRepository = messageRepository;

  Future<void> initialize() async {
    await _threadRepository.initialize();
    await _messageRepository.initialize();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Thread operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get or create a thread for a specific note.
  ///
  /// If a non-deleted thread already exists for [noteId], it is returned.
  /// Otherwise a new per-note thread is created.
  Future<ChatThread> startPerNoteThread(int noteId) async {
    final existing = _threadRepository.getThreadsByNote(noteId);
    if (existing.isNotEmpty) return existing.first;

    return await _threadRepository.createThread(type: 'per_note', noteId: noteId, title: null);
  }

  /// Create a new global chat thread (not tied to any note).
  Future<ChatThread> startGlobalThread({String? title}) async =>
      _threadRepository.createThread(type: 'global', title: title ?? 'New chat');

  List<ChatThread> getThreadsByNote(int noteId) => _threadRepository.getThreadsByNote(noteId);

  List<ChatThread> getGlobalThreads() => _threadRepository.getGlobalThreads();

  ChatThread? getThreadById(int id) => _threadRepository.getThreadById(id);

  Future<void> updateThread(ChatThread thread) async => await _threadRepository.updateThread(thread);

  // ═══════════════════════════════════════════════════════════════════════════
  //  Message operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Append a user message to a thread.
  Future<ChatMessageEntity> addUserMessage(ChatThread thread, String text) async {
    final message = ChatMessageEntity(threadId: thread.id, role: 'user', content: text);

    final saved = await _messageRepository.createMessage(message);

    thread.updatedAt = DateTime.now();
    await _threadRepository.updateThread(thread);

    return saved;
  }

  /// Append an assistant message to a thread.
  Future<ChatMessageEntity> addAssistantMessage(
    ChatThread thread,
    String content, {
    List<String> sourceNoteTitles = const [],
    int? promptTokens,
    int? completionTokens,
  }) async {
    final message = ChatMessageEntity(
      threadId: thread.id,
      role: 'assistant',
      content: content,
      sourceNoteTitles: sourceNoteTitles,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
    );

    final saved = await _messageRepository.createMessage(message);

    thread.updatedAt = DateTime.now();
    await _threadRepository.updateThread(thread);

    return saved;
  }

  List<ChatMessageEntity> getMessagesForThread(int threadId) => _messageRepository.getMessagesForThread(threadId);

  List<ChatMessageEntity> getRecentMessages(int threadId, {int limit = 50}) =>
      _messageRepository.getRecentMessagesForThread(threadId, limit: limit);

  // ═══════════════════════════════════════════════════════════════════════════
  //  Delete / clear
  // ═══════════════════════════════════════════════════════════════════════════

  /// Delete a thread and all its messages.
  Future<void> deleteThread(int threadId) async {
    await _messageRepository.deleteMessagesForThread(threadId);
    await _threadRepository.deleteThread(threadId);
  }

  /// Clear all messages in a thread but keep the thread itself.
  Future<void> clearThreadHistory(int threadId) async {
    await _messageRepository.deleteMessagesForThread(threadId);
    final thread = _threadRepository.getThreadById(threadId);
    if (thread != null) {
      thread.updatedAt = DateTime.now();
      await _threadRepository.updateThread(thread);
    }
  }

  /// Truncate messages in a thread to keep only the most recent [maxMessages].
  Future<void> truncateThread(int threadId, {int maxMessages = 100}) async {
    final all = _messageRepository.getMessagesForThread(threadId);
    if (all.length <= maxMessages) return;

    final toRemove = all.sublist(0, all.length - maxMessages);
    for (final msg in toRemove) {
      await _messageRepository.deleteMessage(msg.id);
    }

    _logger.i('Truncated thread $threadId: removed ${toRemove.length} old messages');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Export / Import (for Google Drive backup)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Export all non-deleted threads (global and per-note) and their messages to JSON.
  Map<String, dynamic> exportAllToJson() {
    final threads = <Map<String, dynamic>>[];
    final messages = <Map<String, dynamic>>[];

    final allThreads = _threadRepository.getAllThreads();
    for (final thread in allThreads) {
      threads.add(thread.toJson());
      final threadMessages = _messageRepository.getMessagesForThread(thread.id);
      for (final msg in threadMessages) {
        messages.add(msg.toJson());
      }
    }

    return {'version': 1, 'exportedAt': DateTime.now().toIso8601String(), 'threads': threads, 'messages': messages};
  }

  /// Import threads and messages from JSON (upsert semantics).
  Future<void> importAllFromJson(Map<String, dynamic> json) async {
    final threadsRaw = json['threads'] as List<dynamic>? ?? [];
    final messagesRaw = json['messages'] as List<dynamic>? ?? [];

    _logger.i('Chat import: ${threadsRaw.length} threads, ${messagesRaw.length} messages');

    for (final t in threadsRaw) {
      final importThread = ChatThread.fromJson(Map<String, dynamic>.from(t as Map));
      final existing = _threadRepository.getThreadById(importThread.id);
      if (existing != null) {
        if (importThread.updatedAt.isAfter(existing.updatedAt)) {
          existing
            ..title = importThread.title
            ..type = importThread.type
            ..noteId = importThread.noteId
            ..isDeleted = importThread.isDeleted
            ..deletedAt = importThread.deletedAt
            ..updatedAt = importThread.updatedAt;
          await _threadRepository.updateThread(existing);
        }
      } else {
        await _threadRepository.upsertThread(importThread);
      }
    }

    for (final m in messagesRaw) {
      final importMsg = ChatMessageEntity.fromJson(Map<String, dynamic>.from(m as Map));
      final existingMessages = _messageRepository.getMessagesForThread(importMsg.threadId);
      final existing = existingMessages.where((e) => e.id == importMsg.id).firstOrNull;

      if (existing != null) {
        if (importMsg.updatedAt.isAfter(existing.updatedAt)) {
          existing
            ..content = importMsg.content
            ..role = importMsg.role
            ..sourceNoteTitles = importMsg.sourceNoteTitles
            ..promptTokens = importMsg.promptTokens
            ..completionTokens = importMsg.completionTokens
            ..updatedAt = importMsg.updatedAt;
          await _messageRepository.updateMessage(existing);
        }
      } else {
        await _messageRepository.upsertMessage(importMsg);
      }
    }

    _logger.i('Chat import complete');
  }

  /// Merge local data with remote data (latest updatedAt wins).
  Map<String, dynamic> mergeWithRemoteData(Map<String, dynamic> remoteData) {
    final localData = exportAllToJson();

    final mergedThreads = _mergeEntities(
      local: localData['threads'] as List<Map<String, dynamic>>,
      remote: (remoteData['threads'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      keyFn: (t) => '${t['id']}',
      updatedAtKey: 'updatedAt',
    );

    final mergedMessages = _mergeEntities(
      local: localData['messages'] as List<Map<String, dynamic>>,
      remote: (remoteData['messages'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      keyFn: (m) => '${m['threadId']}_${m['id']}',
      updatedAtKey: 'updatedAt',
    );

    return {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'threads': mergedThreads,
      'messages': mergedMessages,
    };
  }

  List<Map<String, dynamic>> _mergeEntities({
    required List<Map<String, dynamic>> local,
    required List<Map<String, dynamic>> remote,
    required String Function(Map<String, dynamic>) keyFn,
    required String updatedAtKey,
  }) {
    final localMap = <String, Map<String, dynamic>>{};
    for (final item in local) {
      localMap[keyFn(item)] = item;
    }

    final remoteMap = <String, Map<String, dynamic>>{};
    for (final item in remote) {
      remoteMap[keyFn(item)] = item;
    }

    final allKeys = <String>{...localMap.keys, ...remoteMap.keys};
    final merged = <Map<String, dynamic>>[];

    for (final key in allKeys) {
      final l = localMap[key];
      final r = remoteMap[key];

      if (l == null) {
        merged.add(r!);
      } else if (r == null) {
        merged.add(l);
      } else {
        final localTime = DateTime.tryParse(l[updatedAtKey] as String? ?? '');
        final remoteTime = DateTime.tryParse(r[updatedAtKey] as String? ?? '');

        if (remoteTime != null && localTime != null && remoteTime.isAfter(localTime)) {
          merged.add(r);
        } else {
          merged.add(l);
        }
      }
    }

    return merged;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Lifecycle
  // ═══════════════════════════════════════════════════════════════════════════

  void addListener(Function() listener) {
    _threadRepository.addListener(listener);
    _messageRepository.addListener(listener);
  }

  void removeListener(Function() listener) {
    _threadRepository.removeListener(listener);
    _messageRepository.removeListener(listener);
  }

  void dispose() {
    _threadRepository.dispose();
    _messageRepository.dispose();
  }
}
