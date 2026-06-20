import 'package:logger/logger.dart';
import 'package:trovara/core/services/ai/document_resolver_service.dart';
import 'package:trovara/core/services/ai/embedding_service.dart';
import 'package:trovara/core/services/ai/multi_query_expansion_service.dart';
import 'package:trovara/core/services/ai/query_rewrite_service.dart';
import 'package:trovara/core/services/ai/rrf_key_score.dart';
import 'package:trovara/core/services/ai/vector_search_service.dart';

/// Output of the retrieval phase: the fused top chunks plus their resolved
/// metadata-aware context maps (ready for [PromptBuilderService]).
typedef RagRetrieval = ({List<ScoredEmbedding> fusedChunks, List<Map<String, String>> chunkContexts});

/// Owns the retrieval half of the RAG pipeline: query rewrite → multi-query
/// expansion → per-query embed + vector search → Reciprocal Rank Fusion (RRF)
/// → document resolution.
///
/// Extracted from [RagService] (Recipe R2) so the orchestrator stays focused on
/// LLM generation + error translation. Constructed internally by [RagService]
/// from the same injected services, so DI wiring is unchanged.
class RagRetriever {
  final EmbeddingService _embeddingService;
  final VectorSearchService _vectorSearchService;
  final DocumentResolverService _documentResolverService;
  final QueryRewriteService _queryRewriteService;
  final MultiQueryExpansionService _multiQueryExpansionService;
  final Logger _logger = Logger();

  RagRetriever({
    required EmbeddingService embeddingService,
    required VectorSearchService vectorSearchService,
    required DocumentResolverService documentResolverService,
    required QueryRewriteService queryRewriteService,
    required MultiQueryExpansionService multiQueryExpansionService,
  }) : _embeddingService = embeddingService,
       _vectorSearchService = vectorSearchService,
       _documentResolverService = documentResolverService,
       _queryRewriteService = queryRewriteService,
       _multiQueryExpansionService = multiQueryExpansionService;

  /// Public, deterministic Reciprocal Rank Fusion (RRF) helper.
  ///
  /// Exposed so fusion ordering can be unit-tested without depending on
  /// floating-point cosine similarity ties or sort stability.
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

  /// Run the single-turn chunk-centric retrieval pipeline for [userQuestion].
  ///
  /// Throws [RagQueryException] for user-facing failures (embedding-dimension
  /// mismatch, embedding auth failure, total embedding failure).
  Future<RagRetrieval> retrieve(
    String userQuestion, {
    required int fusionPoolSizePerQuery,
    required double minScore,
    required int expectedEmbeddingDim,
    String? conversationContext,
    int topKChunks = 3,
  }) async {
    final trimmed = userQuestion.trim();
    if (trimmed.isEmpty) {
      return (fusedChunks: <ScoredEmbedding>[], chunkContexts: <Map<String, String>>[]);
    }

    // 1) Rewrite
    final rewritten = await _queryRewriteService.rewrite(trimmed, conversationContext: conversationContext);

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

  RagRetrieval _fuseAndResolve({
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
}

/// Raised for user-facing retrieval failures; [message] is shown directly.
class RagQueryException implements Exception {
  final String message;
  RagQueryException(this.message);

  @override
  String toString() => message;
}
