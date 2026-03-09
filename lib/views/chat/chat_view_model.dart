import 'dart:async';

import 'package:logger/logger.dart';
import 'package:trovara/core/base/base_view_model.dart';
import 'package:trovara/core/di/service_locator.dart';
import 'package:trovara/core/services/chat_service.dart';
import 'package:trovara/core/services/rag_service.dart';
import 'package:trovara/models/chat_message.dart';
import 'package:trovara/models/chat_thread.dart';

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
  final Logger _logger = Logger();

  ChatViewModel({RagService? ragService, ChatService? chatService})
    : _ragService = ragService ?? ServiceLocator().ragService,
      _chatService = chatService ?? ServiceLocator().chatService;

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
    _currentThread = thread;
    _messages.clear();

    final entities = _chatService.getMessagesForThread(thread.id);
    for (final entity in entities) {
      _messages.add(_entityToUiMessage(entity));
    }

    notifyListeners();
  }

  /// Start a fresh conversation. The thread is lazily created on first message.
  void startNewChat() {
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
    if (trimmed.isEmpty || _isProcessing) return;

    final thread = await _ensureThread();

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

    // Stream the AI response
    final buffer = StringBuffer();
    List<String> sources = [];
    bool isError = false;

    try {
      await for (final chunk in _ragService.queryStream(trimmed)) {
        buffer.write(chunk);
        _updateMessage(aiMessageId, content: buffer.toString());
      }

      sources = await _ragService.getSourceTitles(trimmed);
      _updateMessage(aiMessageId, content: buffer.toString(), sourceNoteTitles: sources, isLoading: false);

      _logger.i('Chat response complete: ${buffer.length} chars, ${sources.length} sources');
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
    await _chatService.addAssistantMessage(thread, buffer.toString(), sourceNoteTitles: sources);

    _isProcessing = false;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Clear / delete
  // ═══════════════════════════════════════════════════════════════════════════

  /// Clear the current conversation and start fresh.
  /// The old thread remains in history (accessible from the drawer).
  void clearConversation() {
    _currentThread = null;
    _messages.clear();
    notifyListeners();
  }

  /// Delete a thread from history entirely.
  Future<void> deleteThread(int threadId) async {
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
    sourceNoteTitles: entity.sourceNoteTitles,
  );

  void _updateMessage(String id, {String? content, List<String>? sourceNoteTitles, bool? isLoading, bool? isError}) {
    final index = _messages.indexWhere((m) => m.id == id);
    if (index != -1) {
      _messages[index] = _messages[index].copyWith(
        content: content,
        sourceNoteTitles: sourceNoteTitles,
        isLoading: isLoading,
        isError: isError,
      );
      notifyListeners();
    }
  }

  String _generateId() => DateTime.now().microsecondsSinceEpoch.toString();

  bool _shouldMarkRagMessageAsError(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('authentication failed')) return true;
    if (normalized.contains('quota exceeded')) return true;
    if (normalized.contains('unable to process')) return true;
    if (normalized.contains('something went wrong')) return true;
    return false;
  }
}
