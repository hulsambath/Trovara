import 'dart:async';

import 'package:logger/logger.dart';
import 'package:trovara/core/base/base_view_model.dart';
import 'package:trovara/core/di/service_locator.dart';
import 'package:trovara/core/services/ai/rag_chat_memory.dart';
import 'package:trovara/core/services/ai/rag_service.dart';
import 'package:trovara/core/services/chat/chat_service.dart';
import 'package:trovara/core/services/notes/note_service.dart';
import 'package:trovara/models/chat_message.dart';
import 'package:trovara/models/chat_source_note.dart';
import 'package:trovara/models/chat_thread.dart';
import 'package:trovara/models/note.dart';

/// ViewModel for the Chat UI with auto-save history (ChatGPT architecture).
///
/// Each conversation maps to a [ChatThread] in the database. Messages are
/// persisted to ObjectBox immediately as they are sent/received so history
/// survives app restarts and syncs to Google Drive.
///
/// Architecture:
/// ```
/// ChatView  ←→  ChatViewModel  ←→  ChatService (persistence)
///                                  ←→  RagService  (AI answers)
/// ```
class ChatViewModel extends BaseViewModel {
  final RagService _ragService;
  final ChatService _chatService;
  final NoteService _noteService;
  final Logger _logger = Logger();

  ChatViewModel({RagService? ragService, ChatService? chatService, NoteService? noteService})
    : _ragService = ragService ?? ServiceLocator().ragService,
      _chatService = chatService ?? ServiceLocator().chatService,
      _noteService = noteService ?? ServiceLocator().noteService;

  // ═══════════════════════════════════════════════════════════════════════════
  //  State
  // ═══════════════════════════════════════════════════════════════════════════

  /// In-memory message list for the UI (includes transient loading states).
  final List<ChatMessage> _messages = [];

  /// The currently active thread. Null when no conversation has been started.
  ChatThread? _currentThread;

  bool _isProcessing = false;

  /// Suggested questions shown when the chat is empty.
  static const List<String> suggestedQuestions = [
    'What have I been writing about this week?',
    'What activities made me happiest recently?',
    'Summarize my morning routines',
    'What goals have I mentioned in my notes?',
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  //  Public getters
  // ═══════════════════════════════════════════════════════════════════════════

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isProcessing => _isProcessing;
  bool get isAvailable => _ragService.isAvailable;
  bool get hasMessages => _messages.isNotEmpty;
  ChatThread? get currentThread => _currentThread;

  // ═══════════════════════════════════════════════════════════════════════════
  //  Thread management
  // ═══════════════════════════════════════════════════════════════════════════

  /// Load an existing thread and restore its messages into the UI.
  Future<void> loadThread(ChatThread thread) async {
    _logger.d('Chat action: load thread ${thread.id} (${thread.title ?? 'New conversation'})');
    _currentThread = thread;
    _messages.clear();

    final entities = _chatService.getMessagesForThread(thread.id);
    for (final entity in entities) {
      _messages.add(_entityToUiMessage(entity));
    }

    _logger.d('Chat action: loaded ${_messages.length} messages for thread ${thread.id}');
    notifyListeners();
  }

  /// Start a fresh conversation. The thread is lazily created on first message.
  void startNewChat() {
    _logger.d('Chat action: start new chat (currentThread=${_currentThread?.id})');
    _currentThread = null;
    _messages.clear();
    notifyListeners();
  }

  /// Ensure a thread exists for the current conversation.
  /// Creates one on-demand if needed (lazy thread creation).
  Future<ChatThread> _ensureThread() async {
    if (_currentThread != null) return _currentThread!;

    _currentThread = await _chatService.startGlobalThread(title: null);
    _logger.i('Created new chat thread: ${_currentThread!.id}');
    return _currentThread!;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Send message (with auto-save)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Send a user question, persist it, stream the AI response, and persist that too.
  Future<void> sendMessage(String question) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty || _isProcessing) {
      _logger.d('Chat action: send message ignored (empty=${trimmed.isEmpty}, processing=$_isProcessing)');
      return;
    }

    final thread = await _ensureThread();
    _logger.d('Chat action: send message (thread=${thread.id}) text="$trimmed"');

    // Persist user message
    await _chatService.addUserMessage(thread, trimmed);

    // Auto-set thread title from first user message (ChatGPT behavior)
    if (thread.title == null || thread.title == 'New chat') {
      final title = trimmed.length > 50 ? '${trimmed.substring(0, 50)}...' : trimmed;
      thread.title = title;
      await _chatService.updateThread(thread);
    }

    // Add user message to UI
    final userMessage = ChatMessage(id: _generateId(), content: trimmed, isUser: true);
    _messages.add(userMessage);

    // Add AI loading placeholder to UI
    final aiMessageId = _generateId();
    _messages.add(ChatMessage(id: aiMessageId, content: '', isUser: false, isLoading: true));

    _isProcessing = true;
    notifyListeners();

    final priorEntities = _chatService.getMessagesForThread(thread.id);
    final priorTurns = priorEntities.length <= 1
        ? const <RagChatTurn>[]
        : RagChatMemory.turnsFromEntities(priorEntities.sublist(0, priorEntities.length - 1));

    // Stream the AI response
    final buffer = StringBuffer();
    List<ChatSourceNote> sources = [];
    bool isError = false;

    try {
      await for (final chunk in _ragService.queryStream(trimmed, priorTurns: priorTurns)) {
        buffer.write(chunk);
        _updateMessage(aiMessageId, content: buffer.toString());
      }

      final debugNotes = await _ragService.getSourceDebugNotes(trimmed, priorTurns: priorTurns);
      _logSourceDebug(debugNotes);
      final sourceNotes = _buildSourceNotes(debugNotes);
      sources = sourceNotes;
      _updateMessage(aiMessageId, content: buffer.toString(), sourceNotes: sourceNotes, isLoading: false);

      _logger.i('Chat response complete: ${buffer.length} chars, ${sourceNotes.length} sources');
    } on RagQueryException catch (e) {
      isError = _shouldMarkRagMessageAsError(e.message);
      buffer.clear();
      buffer.write(e.message);
      _updateMessage(aiMessageId, content: e.message, isLoading: false, isError: isError);

      if (isError) {
        _logger.e('Chat streaming error: $e');
      } else {
        _logger.i('Chat completed with no results: ${e.message}');
      }
    } catch (e) {
      isError = true;
      buffer.clear();
      buffer.write('Sorry, something went wrong. Please try again.');
      _updateMessage(aiMessageId, content: buffer.toString(), isLoading: false, isError: true);
      _logger.e('Chat streaming error: $e');
    }

    // Persist assistant message (including errors so user sees them in history)
    await _chatService.addAssistantMessage(thread, buffer.toString(), sourceNotes: sources);

    _isProcessing = false;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Clear / delete
  // ═══════════════════════════════════════════════════════════════════════════

  /// Clear the current conversation and start fresh.
  /// The old thread remains in history (accessible from the drawer).
  void clearConversation() {
    _logger.d('Chat action: clear conversation (currentThread=${_currentThread?.id})');
    _currentThread = null;
    _messages.clear();
    notifyListeners();
  }

  /// Delete a thread from history entirely.
  Future<void> deleteThread(int threadId) async {
    _logger.d('Chat action: delete thread $threadId');
    await _chatService.deleteThread(threadId);

    if (_currentThread?.id == threadId) {
      _currentThread = null;
      _messages.clear();
    }

    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Helpers
  // ═══════════════════════════════════════════════════════════════════════════

  /// Convert a persisted [ChatMessageEntity] to a UI [ChatMessage].
  ChatMessage _entityToUiMessage(ChatMessageEntity entity) => ChatMessage(
    id: entity.id.toString(),
    content: entity.content,
    isUser: entity.role == 'user',
    timestamp: entity.createdAt,
    sourceNotes: _resolveSourceNotes(entity),
  );

  void _updateMessage(String id, {String? content, List<ChatSourceNote>? sourceNotes, bool? isLoading, bool? isError}) {
    final index = _messages.indexWhere((m) => m.id == id);
    if (index != -1) {
      _messages[index] = _messages[index].copyWith(
        content: content,
        sourceNotes: sourceNotes,
        isLoading: isLoading,
        isError: isError,
      );
      notifyListeners();
    }
  }

  String _generateId() => DateTime.now().microsecondsSinceEpoch.toString();

  void _logSourceDebug(List<Note> notes) {
    if (notes.isEmpty) {
      _logger.d('Source debug: no notes resolved');
      return;
    }

    for (final note in notes) {
      _logger.d('Source debug note ${note.id}: ${note.toJson()}');
    }
  }

  List<ChatSourceNote> _buildSourceNotes(List<Note> notes) {
    final seenIds = <int>{};
    final out = <ChatSourceNote>[];
    final excludeNoteId = _currentThread?.noteId;

    for (final note in notes) {
      if (note.isDeleted || note.id == 0 || note.id == excludeNoteId || seenIds.contains(note.id)) continue;
      seenIds.add(note.id);
      out.add(ChatSourceNote(id: note.id, title: note.title, label: _bestLabelFor(note)));
    }

    return out;
  }

  List<ChatSourceNote> _resolveSourceNotes(ChatMessageEntity entity) {
    final out = <ChatSourceNote>[];
    final excludeNoteId = _currentThread?.noteId;

    if (entity.sourceNoteIds.isNotEmpty) {
      for (int i = 0; i < entity.sourceNoteIds.length; i++) {
        final id = entity.sourceNoteIds[i];
        if (id == excludeNoteId) continue;
        final note = _noteService.getNote(id);
        if (note == null || note.isDeleted) continue;
        final title = entity.sourceNoteTitles.length > i && entity.sourceNoteTitles[i].trim().isNotEmpty
            ? entity.sourceNoteTitles[i]
            : note.title;
        final storedLabel = entity.sourceNoteLabels.length > i ? entity.sourceNoteLabels[i] : '';
        final label = storedLabel.trim().isNotEmpty ? storedLabel : _bestLabelFor(note);
        out.add(ChatSourceNote(id: note.id, title: title, label: label));
      }
      return out;
    }

    for (final title in entity.sourceNoteTitles) {
      final resolved = _resolveNoteByTitle(title);
      if (resolved == null || resolved.id == excludeNoteId) continue;
      out.add(ChatSourceNote(id: resolved.id, title: resolved.title, label: _bestLabelFor(resolved)));
    }
    return out;
  }

  Note? _resolveNoteByTitle(String title) {
    if (title.trim().isEmpty) return null;
    final matches = _noteService.searchNotes(title);
    if (matches.isEmpty) return null;
    final exact = matches.firstWhere(
      (note) => note.title.toLowerCase().trim() == title.toLowerCase().trim(),
      orElse: () => matches.first,
    );
    return exact.isDeleted ? null : exact;
  }

  String _bestLabelFor(Note note) {
    if (note.customTagObjects.isNotEmpty) return note.customTagObjects.first.name;
    if (note.moodTagObjects.isNotEmpty) return note.moodTagObjects.first.label;
    if (note.activityTagObjects.isNotEmpty) return note.activityTagObjects.first.label;
    if (note.timeTagObjects.isNotEmpty) return note.timeTagObjects.first.label;
    if (note.personalGrowthTagObjects.isNotEmpty) return note.personalGrowthTagObjects.first.label;
    final folder = _noteService.getFolder(note.folderId);
    return folder?.name ?? '';
  }

  bool _shouldMarkRagMessageAsError(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('authentication failed')) return true;
    if (normalized.contains('quota exceeded')) return true;
    if (normalized.contains('unable to process')) return true;
    if (normalized.contains('something went wrong')) return true;
    return false;
  }
}
