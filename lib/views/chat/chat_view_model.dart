import 'dart:async';

import 'package:logger/logger.dart';
import 'package:trovara/core/base/base_view_model.dart';
import 'package:trovara/core/di/service_locator.dart';
import 'package:trovara/core/services/rag_service.dart';
import 'package:trovara/models/chat_message.dart';

/// ViewModel for the Chat UI (RAG Step 6).
///
/// Manages the conversation state: a list of [ChatMessage]s, processing
/// status, and communication with [RagService] for streaming answers.
///
/// ```
/// ChatView  ←→  ChatViewModel  ←→  RagService (Steps 1-5)
/// ```
class ChatViewModel extends BaseViewModel {
  final RagService _ragService;
  final Logger _logger = Logger();

  /// Creates a [ChatViewModel].
  ///
  /// If [ragService] is not provided, defaults to `ServiceLocator().ragService`.
  /// The optional parameter enables test injection without ServiceLocator.
  ChatViewModel({RagService? ragService}) : _ragService = ragService ?? ServiceLocator().ragService;

  final List<ChatMessage> _messages = [];
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

  /// The current list of chat messages (unmodifiable).
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  /// Whether the AI is currently generating a response.
  bool get isProcessing => _isProcessing;

  /// Whether the RAG pipeline is available for queries.
  bool get isAvailable => _ragService.isAvailable;

  /// Whether there are any messages in the conversation.
  bool get hasMessages => _messages.isNotEmpty;

  // ═══════════════════════════════════════════════════════════════════════════
  //  Public API
  // ═══════════════════════════════════════════════════════════════════════════

  /// Send a user question and stream the AI response.
  ///
  /// 1. Adds the user message to the list
  /// 2. Adds a loading placeholder for the AI response
  /// 3. Streams the response from [RagService.queryStream]
  /// 4. Fetches source titles after the stream completes
  /// 5. Updates the AI message with the final content and sources
  Future<void> sendMessage(String question) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty || _isProcessing) return;

    // Add user message
    final userMessage = ChatMessage(id: _generateId(), content: trimmed, isUser: true);
    _messages.add(userMessage);

    // Add AI placeholder
    final aiMessageId = _generateId();
    _messages.add(ChatMessage(id: aiMessageId, content: '', isUser: false, isLoading: true));

    _isProcessing = true;
    notifyListeners();

    // Stream the response
    final buffer = StringBuffer();
    try {
      await for (final chunk in _ragService.queryStream(trimmed)) {
        buffer.write(chunk);
        _updateMessage(aiMessageId, content: buffer.toString());
      }

      // Fetch source titles
      final sources = await _ragService.getSourceTitles(trimmed);

      _updateMessage(aiMessageId, content: buffer.toString(), sourceNoteTitles: sources, isLoading: false);

      _logger.i(
        'Chat response complete: ${buffer.length} chars, '
        '${sources.length} sources',
      );
    } on RagQueryException catch (e) {
      final shouldMarkAsError = _shouldMarkRagMessageAsError(e.message);
      if (shouldMarkAsError) {
        _logger.e('Chat streaming error: $e');
      } else {
        _logger.i('Chat completed with no results: ${e.message}');
      }

      _updateMessage(aiMessageId, content: e.message, isLoading: false, isError: shouldMarkAsError);
    } catch (e) {
      _logger.e('Chat streaming error: $e');
      _updateMessage(
        aiMessageId,
        content: 'Sorry, something went wrong. Please try again.',
        isLoading: false,
        isError: true,
      );
    }

    _isProcessing = false;
    notifyListeners();
  }

  /// Clear all messages and reset the conversation.
  void clearConversation() {
    _messages.clear();
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Private helpers
  // ═══════════════════════════════════════════════════════════════════════════

  /// Update an existing message by ID.
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

  /// Generate a unique message ID.
  String _generateId() => DateTime.now().microsecondsSinceEpoch.toString();

  bool _shouldMarkRagMessageAsError(String message) {
    final normalized = message.toLowerCase();

    // Treat only actionable failures as "error" styling.
    if (normalized.contains('authentication failed')) return true;
    if (normalized.contains('quota exceeded')) return true;
    if (normalized.contains('unable to process')) return true;
    if (normalized.contains('something went wrong')) return true;

    // Everything else is shown as a normal assistant reply.
    return false;
  }
}
