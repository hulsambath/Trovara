import 'package:logger/logger.dart';
import 'package:trovara/core/services/ai/document_resolver_service.dart';
import 'package:trovara/core/services/ai/embedding_service.dart';
import 'package:trovara/core/services/ai/llm_client.dart';
import 'package:trovara/core/services/ai/multi_query_expansion_service.dart';
import 'package:trovara/core/services/ai/prompt_builder_service.dart';
import 'package:trovara/core/services/ai/query_rewrite_service.dart';
import 'package:trovara/core/services/ai/rag_attribution.dart';
import 'package:trovara/core/services/ai/rag_chat_memory.dart';
import 'package:trovara/core/services/ai/rag_result.dart';
import 'package:trovara/core/services/ai/rag_retriever.dart';
import 'package:trovara/core/services/ai/retrieval_depth.dart';
import 'package:trovara/core/services/ai/rag_support.dart';
import 'package:trovara/core/services/ai/rrf_key_score.dart';
import 'package:trovara/core/services/ai/vector_search_service.dart';
import 'package:trovara/models/note.dart';

export 'package:trovara/core/services/ai/rag_result.dart' show RagResult;
export 'package:trovara/core/services/ai/rag_retriever.dart' show RagQueryException, RagRetriever, RagRetrieval;

/// Orchestrates the full RAG pipeline (chunk-centric retrieval; optional chat memory):
///
/// ```
/// User Question
///     │
///     ▼ RagRetriever.retrieve()  (rewrite → expand → embed → search → RRF → resolve)
///     │
///     ▼ PromptBuilderService.buildSingleTurnUserPayload()  → RAG user message
///     │
///     ▼ LlmClient.generateWithMessages() / generateStreamWithMessages()  → answer
///     │
///     ▼ RagResult (answer + source titles)
/// ```
///
/// Provides two generation entry points — [query] (non-streaming) and
/// [queryStream] (token stream) — and delegates source attribution to
/// [RagAttribution] via [getSourceTitles] / [getSourceDebugNotes].
///
/// [isAvailable] lets the UI show/hide the chat feature depending on whether
/// the pipeline is ready.
class RagService {
  final EmbeddingService _embeddingService;
  final VectorSearchService _vectorSearchService;
  final PromptBuilderService _promptBuilderService;
  final LlmClient _llmClient;
  final RagRetriever _retriever;
  final RagAttribution _attribution;
  final Logger _logger = Logger();

  /// Default fusion pool size per expanded query.
  ///
  /// This is NOT the final number of chunks used as context (that remains 3).
  /// It controls how many candidates each expanded query contributes before RRF fusion.
  static const int defaultSearchTopK = 5;

  /// Minimum similarity score for a chunk to be considered relevant.
  static const double defaultMinScore = 0.3;

  /// Legacy parameter from the previous note-centric prompt builder.
  ///
  /// Kept for API compatibility; ignored by the single-turn chunk-centric pipeline.
  static const int defaultMaxNotes = 5;

  /// Deterministic Reciprocal Rank Fusion (RRF) helper.
  ///
  /// Kept here as a stable, unit-testable entry point; delegates to
  /// [RagRetriever.rrfFuse].
  static List<RrfKeyScore> rrfFuse({
    required List<List<String>> rankedKeysPerQuery,
    required Map<String, double> similarityByKey,
    int rrfK = 60,
  }) => RagRetriever.rrfFuse(
    rankedKeysPerQuery: rankedKeysPerQuery,
    similarityByKey: similarityByKey,
    rrfK: rrfK,
  );

  RagService({
    required EmbeddingService embeddingService,
    required VectorSearchService vectorSearchService,
    required DocumentResolverService documentResolverService,
    required PromptBuilderService promptBuilderService,
    required LlmClient llmClient,
    required QueryRewriteService queryRewriteService,
    required MultiQueryExpansionService multiQueryExpansionService,
  }) : _embeddingService = embeddingService,
       _vectorSearchService = vectorSearchService,
       _promptBuilderService = promptBuilderService,
       _llmClient = llmClient,
       _retriever = RagRetriever(
         embeddingService: embeddingService,
         vectorSearchService: vectorSearchService,
         documentResolverService: documentResolverService,
         queryRewriteService: queryRewriteService,
         multiQueryExpansionService: multiQueryExpansionService,
       ),
       _attribution = RagAttribution(
         retriever: RagRetriever(
           embeddingService: embeddingService,
           vectorSearchService: vectorSearchService,
           documentResolverService: documentResolverService,
           queryRewriteService: queryRewriteService,
           multiQueryExpansionService: multiQueryExpansionService,
         ),
         vectorSearchService: vectorSearchService,
         documentResolverService: documentResolverService,
       );

  /// Whether the full RAG pipeline is ready for queries.
  ///
  /// Requires both the embedding service and the LLM client to be available.
  bool get isAvailable => _embeddingService.isAvailable && _llmClient.isAvailable;

  /// Execute a full RAG query and return the complete result.
  ///
  /// Returns a user-friendly error message in [RagResult.answer] if any
  /// step fails gracefully (no embedding, no results, etc.).
  Future<RagResult> query(
    String userQuestion, {
    List<RagChatTurn> priorTurns = const [],
    int searchTopK = defaultSearchTopK,
    double minScore = defaultMinScore,
    // ignore: unused_parameter
    int maxNotes = defaultMaxNotes, // ignored (single-turn chunk-centric mode)
    RetrievalDepth depth = RetrievalDepth.free,
  }) async {
    final stats = _vectorSearchService.getStats();
    if (stats.totalChunks == 0) {
      return RagSupport.emptyResult(RagSupport.notIndexedMessage);
    }

    final memory = RagSupport.prepareChatMemory(priorTurns);

    late final RagRetrieval retrieved;
    try {
      retrieved = await _retriever.retrieve(
        userQuestion,
        fusionPoolSizePerQuery: depth.fusionPoolSizePerQuery,
        minScore: minScore,
        expectedEmbeddingDim: stats.embeddingDimension,
        conversationContext: memory.rewriteContext.isEmpty ? null : memory.rewriteContext,
        topKChunks: depth.topKChunks,
        expansionCount: depth.expansionCount,
      );
    } on RagQueryException catch (e) {
      return RagSupport.emptyResult(e.message);
    }

    if (retrieved.fusedChunks.isEmpty || retrieved.chunkContexts.isEmpty) {
      _logger.d('No relevant chunks found for query');
      return RagSupport.emptyResult(RagSupport.noResultsMessage);
    }

    final userPayload = _promptBuilderService.buildSingleTurnUserPayload(
      userQuery: userQuestion,
      topChunkContexts: retrieved.chunkContexts,
    );

    if (userPayload == null) {
      return RagResult(
        answer: "I couldn't find any relevant notes for your question.",
        sourceNoteTitles: [],
        prompt: '',
        matchedChunks: retrieved.fusedChunks.length,
      );
    }

    final prompt = RagSupport.formatDebugMessages(
      systemPrompt: PromptBuilderService.singleTurnSystemPrompt,
      history: memory.llmHistory,
      userMessage: userPayload,
    );

    final sourceTitles = RagSupport.uniqueInOrder(
      retrieved.chunkContexts.map((c) => c['title'] ?? '').where((t) => t.isNotEmpty),
    );

    try {
      final answer = await _llmClient.generateWithMessages(
        systemPrompt: PromptBuilderService.singleTurnSystemPrompt,
        history: memory.llmHistory,
        userMessage: userPayload,
      );

      _logger.i(
        'RAG query complete: ${retrieved.fusedChunks.length} chunks, '
        '${sourceTitles.length} sources, '
        '${answer.length} char answer',
      );

      return RagResult(
        answer: answer,
        sourceNoteTitles: sourceTitles,
        prompt: prompt,
        matchedChunks: retrieved.fusedChunks.length,
      );
    } catch (e) {
      _logger.e('LLM generation failed: $e');
      return RagResult(
        answer: RagSupport.llmErrorMessage(e) ?? 'Sorry, something went wrong generating the answer. Please try again.',
        sourceNoteTitles: sourceTitles,
        prompt: prompt,
        matchedChunks: retrieved.fusedChunks.length,
      );
    }
  }

  /// Execute a RAG query with streaming response.
  ///
  /// Yields answer text chunks as they arrive from the LLM. Source titles and
  /// the prompt are not available through the stream — use [getSourceTitles]
  /// after the stream completes if needed. Yields a single error message if any
  /// step fails.
  Stream<String> queryStream(
    String userQuestion, {
    List<RagChatTurn> priorTurns = const [],
    int searchTopK = defaultSearchTopK,
    double minScore = defaultMinScore,
    // ignore: unused_parameter
    int maxNotes = defaultMaxNotes, // ignored (single-turn chunk-centric mode)
    RetrievalDepth depth = RetrievalDepth.free,
  }) async* {
    try {
      final stats = _vectorSearchService.getStats();
      if (stats.totalChunks == 0) {
        yield RagSupport.notIndexedMessage;
        return;
      }

      final memory = RagSupport.prepareChatMemory(priorTurns);

      final retrieved = await _retriever.retrieve(
        userQuestion,
        fusionPoolSizePerQuery: depth.fusionPoolSizePerQuery,
        minScore: minScore,
        expectedEmbeddingDim: stats.embeddingDimension,
        conversationContext: memory.rewriteContext.isEmpty ? null : memory.rewriteContext,
        topKChunks: depth.topKChunks,
        expansionCount: depth.expansionCount,
      );

      final userPayload = _promptBuilderService.buildSingleTurnUserPayload(
        userQuery: userQuestion,
        topChunkContexts: retrieved.chunkContexts,
      );

      if (userPayload == null || retrieved.chunkContexts.isEmpty) {
        yield RagSupport.noResultsMessage;
        return;
      }

      // Note: `await for` (not `yield*`) is required so stream errors are caught here.
      await for (final chunk in _llmClient.generateStreamWithMessages(
        systemPrompt: PromptBuilderService.singleTurnSystemPrompt,
        history: memory.llmHistory,
        userMessage: userPayload,
      )) {
        yield chunk;
      }
    } catch (e) {
      _logger.e('LLM streaming failed: $e');

      if (e is RagQueryException) {
        yield e.message;
        return;
      }

      yield RagSupport.llmErrorMessage(e) ?? 'Sorry, something went wrong generating the answer. Please try again.';
    }
  }

  /// Source note titles for a query without generating an answer.
  Future<List<String>> getSourceTitles(
    String userQuestion, {
    List<RagChatTurn> priorTurns = const [],
    int searchTopK = defaultSearchTopK,
    double minScore = defaultMinScore,
    // ignore: unused_parameter
    int maxNotes = defaultMaxNotes, // ignored (single-turn chunk-centric mode)
  }) => _attribution.sourceTitles(
    userQuestion,
    priorTurns: priorTurns,
    searchTopK: searchTopK,
    minScore: minScore,
  );

  /// Fully-hydrated note entities used as sources, for debugging.
  Future<List<Note>> getSourceDebugNotes(
    String userQuestion, {
    List<RagChatTurn> priorTurns = const [],
    int searchTopK = defaultSearchTopK,
    double minScore = defaultMinScore,
    int maxNotes = defaultMaxNotes,
  }) => _attribution.sourceDebugNotes(
    userQuestion,
    priorTurns: priorTurns,
    searchTopK: searchTopK,
    minScore: minScore,
    maxNotes: maxNotes,
  );
}
