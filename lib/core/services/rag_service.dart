import 'package:logger/logger.dart';
import 'package:trovara/core/services/document_resolver_service.dart';
import 'package:trovara/core/services/embedding_service.dart';
import 'package:trovara/core/services/llm_client.dart';
import 'package:trovara/core/services/multi_query_expansion_service.dart';
import 'package:trovara/core/services/prompt_builder_service.dart';
import 'package:trovara/core/services/query_rewrite_service.dart';
import 'package:trovara/core/services/rrf_key_score.dart';
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

/// Orchestrates the full RAG pipeline (single-turn, chunk-centric):
///
/// ```
/// User Question
///     │
///     ▼
/// Step 1: QueryRewriteService.rewrite()                 → rewritten query
///     │
///     ▼
/// Step 2: MultiQueryExpansionService.expand()           → expanded queries (variations)
///     │
///     ▼
/// Step 3: EmbeddingService.embedQuery() (per variation) → query vectors
///     │
///     ▼
/// Step 4: VectorSearchService.search() (per variation)  → ranked chunks per query
///     │
///     ▼
/// Step 5: Reciprocal Rank Fusion (RRF)                  → fused top chunks
///     │
///     ▼
/// Step 6: DocumentResolverService.resolveTopChunksToContext() → chunk context maps
///     │
///     ▼
/// Step 7: PromptBuilderService.buildSingleTurn()        → single-turn prompt
///     │
///     ▼
/// Step 8: LlmClient.generate() / generateStream()       → answer
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
/// Source attribution can be fetched separately after streaming via
/// [getSourceTitles]. Retrieval failures during attribution are treated as
/// non-fatal so the UI can preserve an already-generated answer.
///
/// It also exposes [isAvailable] to let the UI show/hide the chat
/// feature depending on whether the pipeline is ready.
class RagService {
  final EmbeddingService _embeddingService;
  final VectorSearchService _vectorSearchService;
  final DocumentResolverService _documentResolverService;
  final PromptBuilderService _promptBuilderService;
  final LlmClient _llmClient;
  final QueryRewriteService _queryRewriteService;
  final MultiQueryExpansionService _multiQueryExpansionService;
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

  /// Public, deterministic Reciprocal Rank Fusion (RRF) helper.
  ///
  /// This is intentionally exposed so fusion ordering can be unit-tested without
  /// depending on floating-point cosine similarity ties or sort stability.
  ///
  /// - [rankedKeysPerQuery]: each inner list is a ranked list (best first) of unique keys.
  /// - [similarityByKey]: best-known similarity per key across all queries (used for tie-break).
  /// - Tie-breaker (fully deterministic):
  ///   rrfScore desc → bestSimilarity desc → noteId asc → chunkIndex asc → key lex asc.
  static List<RrfKeyScore> rrfFuse({
    required List<List<String>> rankedKeysPerQuery,
    required Map<String, double> similarityByKey,
    int rrfK = 60,
  }) {
    final scoreByKey = <String, double>{};

    for (final ranked in rankedKeysPerQuery) {
      for (var i = 0; i < ranked.length; i++) {
        final key = ranked[i];
        scoreByKey[key] = (scoreByKey[key] ?? 0.0) + (1.0 / (rrfK + (i + 1)));
      }
    }

    final scored = scoreByKey.entries
        .map((e) => RrfKeyScore(key: e.key, rrfScore: e.value, bestSimilarity: similarityByKey[e.key] ?? 0.0))
        .toList();

    int parseNoteId(String key) => int.tryParse(key.split(':').first) ?? 0;
    int parseChunkIndex(String key) {
      final parts = key.split(':');
      return int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    }

    scored.sort((a, b) {
      final byRrf = b.rrfScore.compareTo(a.rrfScore);
      if (byRrf != 0) return byRrf;

      final bySim = b.bestSimilarity.compareTo(a.bestSimilarity);
      if (bySim != 0) return bySim;

      final byNote = parseNoteId(a.key).compareTo(parseNoteId(b.key));
      if (byNote != 0) return byNote;

      final byChunk = parseChunkIndex(a.key).compareTo(parseChunkIndex(b.key));
      if (byChunk != 0) return byChunk;

      // Final deterministic tie-breaker: lexicographic key comparison.
      return a.key.compareTo(b.key);
    });

    return scored;
  }

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
       _documentResolverService = documentResolverService,
       _promptBuilderService = promptBuilderService,
       _llmClient = llmClient,
       _queryRewriteService = queryRewriteService,
       _multiQueryExpansionService = multiQueryExpansionService;

  /// Whether the full RAG pipeline is ready for queries.
  ///
  /// Requires both the embedding service and the LLM client to be available.
  bool get isAvailable => _embeddingService.isAvailable && _llmClient.isAvailable;

  // ═══════════════════════════════════════════════════════════════════════════
  //  Public API
  // ═══════════════════════════════════════════════════════════════════════════

  /// Execute a full RAG query and return the complete result.
  ///
  /// High-level steps (single-turn, chunk-centric):
  /// 1. Rewrite the user question and expand it into multiple focused variants.
  /// 2. Embed each variant and run vector search per variant to get ranked chunks.
  /// 3. Apply Reciprocal Rank Fusion (RRF) across all variants to select top chunks.
  /// 4. Resolve those chunks into metadata-aware context maps.
  /// 5. Build a single-turn prompt from the chunk context and send it to the LLM.
  /// 6. Return the answer plus source attribution for the chunks used.
  ///
  /// Returns a user-friendly error message in [RagResult.answer] if any
  /// step fails gracefully (no embedding, no results, etc.).
  Future<RagResult> query(
    String userQuestion, {
    int searchTopK = defaultSearchTopK,
    double minScore = defaultMinScore,
    // ignore: unused_parameter
    int maxNotes = defaultMaxNotes, // ignored (single-turn chunk-centric mode)
  }) async {
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

    late final ({List<ScoredEmbedding> fusedChunks, List<Map<String, String>> chunkContexts}) retrieved;
    try {
      retrieved = await _retrieveTopChunksSingleTurn(
        userQuestion,
        fusionPoolSizePerQuery: searchTopK,
        minScore: minScore,
        expectedEmbeddingDim: stats.embeddingDimension,
      );
    } on RagQueryException catch (e) {
      return RagResult(answer: e.message, sourceNoteTitles: [], prompt: '', matchedChunks: 0);
    }

    if (retrieved.fusedChunks.isEmpty || retrieved.chunkContexts.isEmpty) {
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

    final prompt = _promptBuilderService.buildSingleTurn(
      userQuery: userQuestion,
      topChunkContexts: retrieved.chunkContexts,
    );

    if (prompt == null) {
      return RagResult(
        answer: "I couldn't find any relevant notes for your question.",
        sourceNoteTitles: [],
        prompt: '',
        matchedChunks: retrieved.fusedChunks.length,
      );
    }

    final sourceTitles = _uniqueInOrder(
      retrieved.chunkContexts.map((c) => c['title'] ?? '').where((t) => t.isNotEmpty),
    );

    // Step 5: Generate response
    try {
      final answer = await _llmClient.generate(prompt);

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

      if (e is LlmApiException) {
        if (e.code == 'auth_error') {
          return RagResult(
            answer:
                'Authentication failed while generating the answer. '
                'Please verify your configured API key is valid and has not expired.',
            sourceNoteTitles: sourceTitles,
            prompt: prompt,
            matchedChunks: retrieved.fusedChunks.length,
          );
        }

        if (e.code == 'quota_exceeded' || e.isInsufficientQuota) {
          return RagResult(
            answer:
                'API quota exceeded for this key. Please check your plan/billing, '
                'or configure a different API key.',
            sourceNoteTitles: sourceTitles,
            prompt: prompt,
            matchedChunks: retrieved.fusedChunks.length,
          );
        }

        if (e.code == 'model_not_found') {
          return RagResult(
            answer:
                'The configured AI model is not available for this API key. '
                'Try a different model, or update the app to auto-select a supported model.',
            sourceNoteTitles: sourceTitles,
            prompt: prompt,
            matchedChunks: retrieved.fusedChunks.length,
          );
        }
      }

      return RagResult(
        answer: 'Sorry, something went wrong generating the answer. Please try again.',
        sourceNoteTitles: sourceTitles,
        prompt: prompt,
        matchedChunks: retrieved.fusedChunks.length,
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
    // ignore: unused_parameter
    int maxNotes = defaultMaxNotes, // ignored (single-turn chunk-centric mode)
  }) async* {
    try {
      final stats = _vectorSearchService.getStats();
      if (stats.totalChunks == 0) {
        yield "Your notes haven't been indexed yet, so I can't search them. "
            'Try creating/editing a note (to trigger embedding), or run a re-embed of all notes.';
        return;
      }

      final retrieved = await _retrieveTopChunksSingleTurn(
        userQuestion,
        fusionPoolSizePerQuery: searchTopK,
        minScore: minScore,
        expectedEmbeddingDim: stats.embeddingDimension,
      );

      final prompt = _promptBuilderService.buildSingleTurn(
        userQuery: userQuestion,
        topChunkContexts: retrieved.chunkContexts,
      );

      if (prompt == null || retrieved.chunkContexts.isEmpty) {
        yield "I couldn't find any relevant notes for your question. "
            'Try asking about the note content (not just the title), or rephrase your question.';
        return;
      }

      // Note: `await for` (not `yield*`) is required so stream errors are caught here.
      await for (final chunk in _llmClient.generateStream(prompt)) {
        yield chunk;
      }
    } catch (e) {
      _logger.e('LLM streaming failed: $e');

      if (e is RagQueryException) {
        yield e.message;
        return;
      }

      if (e is LlmApiException) {
        if (e.code == 'auth_error') {
          yield 'Authentication failed while generating the answer. '
              'Please verify your configured API key is valid.';
          return;
        }

        if (e.code == 'model_not_found') {
          yield 'The configured AI model is not available for this API key. '
              'Please try a different model (or let the app auto-select one after updating).';
          return;
        }

        if (e.code == 'quota_exceeded' || e.isInsufficientQuota) {
          yield 'API quota exceeded for this key. Please check your plan/billing, '
              'or replace the configured API key with one that has available credits.';
          return;
        }
      }

      yield 'Sorry, something went wrong generating the answer. Please try again.';
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
    // ignore: unused_parameter
    int maxNotes = defaultMaxNotes, // ignored (single-turn chunk-centric mode)
  }) async {
    final stats = _vectorSearchService.getStats();
    if (stats.totalChunks == 0) return [];

    try {
      final retrieved = await _retrieveTopChunksSingleTurn(
        userQuestion,
        fusionPoolSizePerQuery: searchTopK,
        minScore: minScore,
        expectedEmbeddingDim: stats.embeddingDimension,
      );

      return _uniqueInOrder(retrieved.chunkContexts.map((c) => c['title'] ?? '').where((t) => t.isNotEmpty));
    } on RagQueryException catch (e) {
      // Source attribution happens after streaming completes; do not discard a
      // successful answer just because attribution retrieval failed.
      _logger.w('Source attribution retrieval failed: ${e.message}');
      return [];
    } catch (e) {
      _logger.w('Source attribution retrieval failed: $e');
      return [];
    }
  }

  ({List<ScoredEmbedding> fusedChunks, List<Map<String, String>> chunkContexts}) _fuseAndResolve({
    required List<List<ScoredEmbedding>> perQueryRankedChunks,
    required int topKChunks,
  }) {
    // Reciprocal Rank Fusion (RRF).
    // Score(item) = Σ 1 / (k + rank), where rank starts at 1.
    const rrfK = 60;
    final bestSimilarityByKey = <String, double>{};
    final itemByKey = <String, ScoredEmbedding>{};
    final rankedKeysPerQuery = <List<String>>[];

    for (final ranked in perQueryRankedChunks) {
      final rankedKeys = <String>[];
      for (var i = 0; i < ranked.length; i++) {
        final item = ranked[i];
        final key = '${item.embedding.noteId}:${item.embedding.chunkIndex}';
        rankedKeys.add(key);
        itemByKey[key] = item;
        final prevBest = bestSimilarityByKey[key];
        if (prevBest == null || item.score > prevBest) {
          bestSimilarityByKey[key] = item.score;
        }
      }
      rankedKeysPerQuery.add(rankedKeys);
    }

    final fusedResults = rrfFuse(
      rankedKeysPerQuery: rankedKeysPerQuery,
      similarityByKey: bestSimilarityByKey,
      rrfK: rrfK,
    );
    final fusedKeys = fusedResults.map((e) => e.key).toList();
    final rrfScoreByKey = <String, double>{for (final s in fusedResults) s.key: s.rrfScore};

    final fused = <ScoredEmbedding>[];
    for (final k in fusedKeys) {
      final item = itemByKey[k];
      if (item == null) continue;
      fused.add(item);
      if (fused.length >= topKChunks) break;
    }

    final contexts = _documentResolverService.resolveTopChunksToContext(fused, topKChunks: topKChunks);

    if (Logger.level.index <= Level.debug.index) {
      final lines = <String>[];
      for (final item in fused) {
        final id = '${item.embedding.noteId}:${item.embedding.chunkIndex}';
        final rrf = rrfScoreByKey[id] ?? 0.0;
        final sim = bestSimilarityByKey[id] ?? 0.0;
        lines.add('  - $id rrf=${rrf.toStringAsFixed(6)} sim=${sim.toStringAsFixed(4)}');
      }
      _logger.d('Final Top-$topKChunks chunks:\n${lines.join('\n')}');
    }

    return (fusedChunks: fused, chunkContexts: contexts);
  }

  Future<({List<ScoredEmbedding> fusedChunks, List<Map<String, String>> chunkContexts})> _retrieveTopChunksSingleTurn(
    String userQuestion, {
    required int fusionPoolSizePerQuery,
    required double minScore,
    required int expectedEmbeddingDim,
    int topKChunks = 3,
  }) async {
    final trimmed = userQuestion.trim();
    if (trimmed.isEmpty) {
      return (fusedChunks: <ScoredEmbedding>[], chunkContexts: <Map<String, String>>[]);
    }

    // 1) Rewrite
    final rewritten = await _queryRewriteService.rewrite(trimmed);

    // 2) Expand (3 variations)
    final expanded = await _multiQueryExpansionService.expand(rewritten, count: 3);
    final queries = expanded.isEmpty ? [rewritten] : expanded;

    // Avoid logging raw user query text (can contain sensitive data). If you
    // need deeper troubleshooting locally, use debug builds and add explicit
    // temporary logging.
    assert(() {
      if (Logger.level.index <= Level.debug.index) {
        _logger.d(
          'Query prepared (debug-only, sanitized): '
          'originalLen=${trimmed.length}, '
          'rewrittenLen=${rewritten.length}, '
          'expandedLens=[${queries.map((q) => q.length).join(',')}]',
        );
      }
      return true;
    }());

    // 3) Embed + search per query (in parallel)
    final perQueryRankedChunks = <List<ScoredEmbedding>>[];
    var anyVector = false;

    final vectors = await Future.wait(queries.map(_embeddingService.embedQuery));

    for (var i = 0; i < queries.length; i++) {
      final vec = vectors[i];
      if (vec == null) continue;
      anyVector = true;

      if (expectedEmbeddingDim != 0 && expectedEmbeddingDim != vec.length) {
        throw RagQueryException(
          'Your saved note embeddings were created with a different embedding model. '
          'Please re-embed your notes so search works again.',
        );
      }

      final ranked = _vectorSearchService.search(vec, topK: fusionPoolSizePerQuery, minScore: minScore);
      if (ranked.isNotEmpty) perQueryRankedChunks.add(ranked);
    }

    if (!anyVector) {
      final lastError = _embeddingService.lastError;
      if (lastError != null && lastError.isAuthFailure) {
        throw RagQueryException(
          'Authentication failed while creating embeddings. '
          'Please verify your configured API key is valid.',
        );
      }
      throw RagQueryException('Sorry, I was unable to process your question. Please try again.');
    }

    if (perQueryRankedChunks.isEmpty) {
      return (fusedChunks: <ScoredEmbedding>[], chunkContexts: <Map<String, String>>[]);
    }

    return _fuseAndResolve(perQueryRankedChunks: perQueryRankedChunks, topKChunks: topKChunks);
  }

  List<String> _uniqueInOrder(Iterable<String> items) {
    final seen = <String>{};
    final out = <String>[];
    for (final s in items) {
      final key = s.trim();
      if (key.isEmpty) continue;
      if (seen.add(key)) out.add(key);
    }
    return out;
  }
}

class RagQueryException implements Exception {
  final String message;
  RagQueryException(this.message);

  @override
  String toString() => message;
}
