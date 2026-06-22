import 'package:logger/logger.dart';
import 'package:trovara/core/services/ai/document_resolver_service.dart';
import 'package:trovara/core/services/ai/rag_chat_memory.dart';
import 'package:trovara/core/services/ai/rag_retriever.dart';
import 'package:trovara/core/services/ai/rag_support.dart';
import 'package:trovara/core/services/ai/vector_search_service.dart';
import 'package:trovara/models/note.dart';

/// Source-attribution side of the RAG pipeline: resolves which notes back an
/// answer, without generating one. Extracted from `RagService` (Recipe R2).
///
/// Retrieval failures are non-fatal here — attribution runs after a streamed
/// answer is already on screen, so we must not discard it.
class RagAttribution {
  final RagRetriever _retriever;
  final VectorSearchService _vectorSearchService;
  final DocumentResolverService _documentResolverService;
  final Logger _logger = Logger();

  RagAttribution({
    required RagRetriever retriever,
    required VectorSearchService vectorSearchService,
    required DocumentResolverService documentResolverService,
  }) : _retriever = retriever,
       _vectorSearchService = vectorSearchService,
       _documentResolverService = documentResolverService;

  /// Source note titles for [userQuestion] without generating an answer.
  Future<List<String>> sourceTitles(
    String userQuestion, {
    required List<RagChatTurn> priorTurns,
    required int searchTopK,
    required double minScore,
  }) async {
    final stats = _vectorSearchService.getStats();
    if (stats.totalChunks == 0) return [];

    final memory = RagSupport.prepareChatMemory(priorTurns);

    try {
      final retrieved = await _retriever.retrieve(
        userQuestion,
        fusionPoolSizePerQuery: searchTopK,
        minScore: minScore,
        expectedEmbeddingDim: stats.embeddingDimension,
        conversationContext: memory.rewriteContext.isEmpty ? null : memory.rewriteContext,
      );

      return RagSupport.uniqueInOrder(retrieved.chunkContexts.map((c) => c['title'] ?? '').where((t) => t.isNotEmpty));
    } on RagQueryException catch (e) {
      _logger.w('Source attribution retrieval failed: ${e.message}');
      return [];
    } catch (e) {
      _logger.w('Source attribution retrieval failed: $e');
      return [];
    }
  }

  /// Fully-hydrated note entities used as sources, for debugging.
  Future<List<Note>> sourceDebugNotes(
    String userQuestion, {
    required List<RagChatTurn> priorTurns,
    required int searchTopK,
    required double minScore,
    required int maxNotes,
  }) async {
    final stats = _vectorSearchService.getStats();
    if (stats.totalChunks == 0) return [];

    final memory = RagSupport.prepareChatMemory(priorTurns);

    try {
      final retrieved = await _retriever.retrieve(
        userQuestion,
        fusionPoolSizePerQuery: searchTopK,
        minScore: minScore,
        expectedEmbeddingDim: stats.embeddingDimension,
        conversationContext: memory.rewriteContext.isEmpty ? null : memory.rewriteContext,
      );

      if (retrieved.fusedChunks.isEmpty) return [];

      final documents = _documentResolverService.resolve(retrieved.fusedChunks, topN: maxNotes);
      return documents.map((doc) => doc.note).toList();
    } on RagQueryException catch (e) {
      _logger.w('Source debug retrieval failed: ${e.message}');
      return [];
    } catch (e) {
      _logger.w('Source debug retrieval failed: $e');
      return [];
    }
  }
}
