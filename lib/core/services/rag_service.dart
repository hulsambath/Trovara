import 'package:logger/logger.dart';
import 'package:trovara/core/services/embedding_service.dart';
import 'package:trovara/core/services/llm_client.dart';
import 'package:trovara/core/services/prompt_builder_service.dart';
import 'package:trovara/core/services/vector_search_service.dart';

/// Result of a RAG query, containing the answer and source metadata.
class RagResult {
  /// The LLM-generated answer text.
  final String answer;

  /// Titles of notes used as context for the answer.
  /// Useful for source attribution in the chat UI.
  final List<String> sourceNoteTitles;

  /// The augmented prompt that was sent to the LLM.
  /// Available for debugging and logging; not displayed to the user.
  final String prompt;

  /// Number of embedding chunks that matched the query.
  final int matchedChunks;

  RagResult({required this.answer, required this.sourceNoteTitles, required this.prompt, required this.matchedChunks});

  @override
  String toString() =>
      'RagResult(sources: ${sourceNoteTitles.length}, '
      'chunks: $matchedChunks, '
      'answer: ${answer.length} chars)';
}

/// Orchestrates the full RAG pipeline:
///
/// ```
/// User Question
///     │
///     ▼
/// Step 1: EmbeddingService.embedQuery()       → query vector
///     │
///     ▼
/// Step 2: VectorSearchService.search()        → scored chunks
///     │
///     ▼
/// Steps 3+4: PromptBuilderService.buildFromChunks() → augmented prompt
///     │
///     ▼
/// Step 5: LlmClient.generate() / generateStream() → answer
///     │
///     ▼
/// RagResult (answer + source titles)
/// ```
///
/// This service wires together all RAG components and provides two main
/// entry points:
/// - [query] — returns a complete [RagResult] (non-streaming)
/// - [queryStream] — yields answer tokens for real-time UI
///
/// It also exposes [isAvailable] to let the UI show/hide the chat
/// feature depending on whether the pipeline is ready.
class RagService {
  final EmbeddingService _embeddingService;
  final VectorSearchService _vectorSearchService;
  final PromptBuilderService _promptBuilderService;
  final LlmClient _llmClient;
  final Logger _logger = Logger();

  /// Default number of chunks to retrieve from vector search.
  static const int defaultSearchTopK = 10;

  /// Minimum similarity score for a chunk to be considered relevant.
  static const double defaultMinScore = 0.3;

  /// Maximum number of notes to include in the prompt.
  static const int defaultMaxNotes = 5;

  RagService({
    required EmbeddingService embeddingService,
    required VectorSearchService vectorSearchService,
    required PromptBuilderService promptBuilderService,
    required LlmClient llmClient,
  }) : _embeddingService = embeddingService,
       _vectorSearchService = vectorSearchService,
       _promptBuilderService = promptBuilderService,
       _llmClient = llmClient;

  /// Whether the full RAG pipeline is ready for queries.
  ///
  /// Requires both the embedding service and the LLM client to be available.
  bool get isAvailable => _embeddingService.isAvailable && _llmClient.isAvailable;

  // ═══════════════════════════════════════════════════════════════════════════
  //  Public API
  // ═══════════════════════════════════════════════════════════════════════════

  /// Execute a full RAG query and return the complete result.
  ///
  /// Steps:
  /// 1. Embed the user question
  /// 2. Search for relevant note chunks
  /// 3. Resolve chunks to documents and build an augmented prompt
  /// 4. Send the prompt to the LLM
  /// 5. Return the answer with source attribution
  ///
  /// Returns a user-friendly error message in [RagResult.answer] if any
  /// step fails gracefully (no embedding, no results, etc.).
  Future<RagResult> query(
    String userQuestion, {
    int searchTopK = defaultSearchTopK,
    double minScore = defaultMinScore,
    int maxNotes = defaultMaxNotes,
  }) async {
    // Step 1: Embed the user query
    final queryVector = await _embeddingService.embedQuery(userQuestion);
    if (queryVector == null) {
      _logger.w('Failed to embed user query');

      final lastError = _embeddingService.lastError;
      if (lastError != null && lastError.isAuthFailure) {
        return RagResult(
          answer:
              'Gemini authentication failed while creating embeddings. '
              'Please verify `GEMINI_API_KEY` is set to a valid Gemini API key.',
          sourceNoteTitles: [],
          prompt: '',
          matchedChunks: 0,
        );
      }

      return RagResult(
        answer: 'Sorry, I was unable to process your question. Please try again.',
        sourceNoteTitles: [],
        prompt: '',
        matchedChunks: 0,
      );
    }

    final stats = _vectorSearchService.getStats();
    if (stats.totalChunks == 0) {
      return RagResult(
        answer:
            "Your notes haven't been indexed yet, so I can't search them. "
            'Try creating/editing a note (to trigger embedding), or run a re-embed of all notes.',
        sourceNoteTitles: [],
        prompt: '',
        matchedChunks: 0,
      );
    }

    if (stats.embeddingDimension != 0 && stats.embeddingDimension != queryVector.length) {
      return RagResult(
        answer:
            'Your saved note embeddings were created with a different embedding model. '
            'Please re-embed your notes so search works again.',
        sourceNoteTitles: [],
        prompt: '',
        matchedChunks: 0,
      );
    }

    // Step 2: Vector search
    final scoredChunks = _vectorSearchService.search(queryVector, topK: searchTopK, minScore: minScore);

    if (scoredChunks.isEmpty) {
      _logger.d('No relevant chunks found for query');
      return RagResult(
        answer:
            "I couldn't find any relevant notes for your question. "
            'Try asking about the note content (not just the title), or rephrase your question.',
        sourceNoteTitles: [],
        prompt: '',
        matchedChunks: 0,
      );
    }

    // Steps 3 + 4: Resolve to documents and build prompt
    final prompt = _promptBuilderService.buildFromChunks(
      userQuery: userQuestion,
      scoredChunks: scoredChunks,
      maxNotes: maxNotes,
    );

    if (prompt == null) {
      _logger.d('Prompt builder returned null (no resolvable documents)');
      return RagResult(
        answer: "I couldn't find any relevant notes for your question.",
        sourceNoteTitles: [],
        prompt: '',
        matchedChunks: scoredChunks.length,
      );
    }

    // Extract source titles for attribution
    final sourceTitles = _promptBuilderService.extractSourceTitles(scoredChunks: scoredChunks, maxNotes: maxNotes);

    // Step 5: Generate response
    try {
      final answer = await _llmClient.generate(prompt);

      _logger.i(
        'RAG query complete: ${scoredChunks.length} chunks, '
        '${sourceTitles.length} sources, '
        '${answer.length} char answer',
      );

      return RagResult(
        answer: answer,
        sourceNoteTitles: sourceTitles,
        prompt: prompt,
        matchedChunks: scoredChunks.length,
      );
    } catch (e) {
      _logger.e('LLM generation failed: $e');

      if (e is LlmApiException) {
        if (e.code == 'auth_error') {
          return RagResult(
            answer:
                'Gemini authentication failed while generating the answer. '
                'Please verify `GEMINI_API_KEY` is set to a valid Gemini API key.',
            sourceNoteTitles: sourceTitles,
            prompt: prompt,
            matchedChunks: scoredChunks.length,
          );
        }

        if (e.code == 'quota_exceeded' || e.isInsufficientQuota) {
          return RagResult(
            answer:
                'Gemini quota exceeded for this API key. Please check your Gemini plan/billing, '
                'or replace `GEMINI_API_KEY` with a key that has available quota.',
            sourceNoteTitles: sourceTitles,
            prompt: prompt,
            matchedChunks: scoredChunks.length,
          );
        }

        if (e.code == 'model_not_found') {
          return RagResult(
            answer:
                'The configured Gemini model is not available for this API key. '
                'Try a different Gemini model, or update the app to auto-select a supported model.',
            sourceNoteTitles: sourceTitles,
            prompt: prompt,
            matchedChunks: scoredChunks.length,
          );
        }
      }

      return RagResult(
        answer: 'Sorry, something went wrong generating the answer. Please try again.',
        sourceNoteTitles: sourceTitles,
        prompt: prompt,
        matchedChunks: scoredChunks.length,
      );
    }
  }

  /// Execute a RAG query with streaming response.
  ///
  /// Yields answer text chunks as they arrive from the LLM. Source titles
  /// and the prompt are not available through the stream — use
  /// [getSourceTitles] after the stream completes if needed.
  ///
  /// Yields a single error message if any step fails.
  Stream<String> queryStream(
    String userQuestion, {
    int searchTopK = defaultSearchTopK,
    double minScore = defaultMinScore,
    int maxNotes = defaultMaxNotes,
  }) async* {
    // Step 1: Embed
    final queryVector = await _embeddingService.embedQuery(userQuestion);
    if (queryVector == null) {
      final lastError = _embeddingService.lastError;
      if (lastError != null && lastError.isAuthFailure) {
        throw RagQueryException(
          'Gemini authentication failed while creating embeddings. '
          'Please verify `GEMINI_API_KEY` is set to a valid Gemini API key.',
        );
      }

      throw RagQueryException('Sorry, I was unable to process your question. Please try again.');
    }

    final stats = _vectorSearchService.getStats();
    if (stats.totalChunks == 0) {
      throw RagQueryException(
        "Your notes haven't been indexed yet, so I can't search them. "
        'Try creating/editing a note (to trigger embedding), or run a re-embed of all notes.',
      );
    }

    if (stats.embeddingDimension != 0 && stats.embeddingDimension != queryVector.length) {
      throw RagQueryException(
        'Your saved note embeddings were created with a different embedding model. '
        'Please re-embed your notes so search works again.',
      );
    }

    // Step 2: Search
    final scoredChunks = _vectorSearchService.search(queryVector, topK: searchTopK, minScore: minScore);

    if (scoredChunks.isEmpty) {
      throw RagQueryException(
        "I couldn't find any relevant notes for your question. "
        'Try asking about the note content (not just the title), or rephrase your question.',
      );
    }

    // Steps 3 + 4: Resolve and build prompt
    final prompt = _promptBuilderService.buildFromChunks(
      userQuery: userQuestion,
      scoredChunks: scoredChunks,
      maxNotes: maxNotes,
    );

    if (prompt == null) {
      throw RagQueryException(
        "I couldn't find any relevant notes for your question. "
        'Try asking about the note content (not just the title), or rephrase your question.',
      );
    }

    // Step 5: Stream response
    // Note: `await for` (not `yield*`) is required so that stream errors
    // from the LLM are caught by the enclosing try-catch.
    try {
      await for (final chunk in _llmClient.generateStream(prompt)) {
        yield chunk;
      }
    } catch (e) {
      _logger.e('LLM streaming failed: $e');

      if (e is LlmApiException) {
        if (e.code == 'auth_error') {
          throw RagQueryException(
            'Gemini authentication failed while generating the answer. '
            'Please verify `GEMINI_API_KEY` is set to a valid Gemini API key.',
          );
        }

        if (e.code == 'model_not_found') {
          throw RagQueryException(
            'The configured Gemini model is not available for this API key. '
            'Please try a different Gemini model (or let the app auto-select one after updating).',
          );
        }

        if (e.code == 'quota_exceeded' || e.isInsufficientQuota) {
          if (_llmClient.provider == LlmProvider.gemini) {
            throw RagQueryException(
              'Gemini quota exceeded for this API key. Please check your Gemini plan/billing, '
              'or replace `GEMINI_API_KEY` with a key that has available quota.',
            );
          }

          throw RagQueryException(
            'OpenAI-compatible provider quota exceeded for this API key. Please check your plan/billing, '
            'or replace the configured API key with one that has available credits.',
          );
        }
      }

      throw RagQueryException('Sorry, something went wrong generating the answer. Please try again.');
    }
  }

  /// Get source note titles for a query without generating an answer.
  ///
  /// Useful for retrieving source attribution after a streaming query,
  /// or for previewing which notes would be referenced.
  Future<List<String>> getSourceTitles(
    String userQuestion, {
    int searchTopK = defaultSearchTopK,
    double minScore = defaultMinScore,
    int maxNotes = defaultMaxNotes,
  }) async {
    final queryVector = await _embeddingService.embedQuery(userQuestion);
    if (queryVector == null) return [];

    final scoredChunks = _vectorSearchService.search(queryVector, topK: searchTopK, minScore: minScore);

    if (scoredChunks.isEmpty) return [];

    return _promptBuilderService.extractSourceTitles(scoredChunks: scoredChunks, maxNotes: maxNotes);
  }
}

class RagQueryException implements Exception {
  final String message;
  RagQueryException(this.message);

  @override
  String toString() => message;
}
