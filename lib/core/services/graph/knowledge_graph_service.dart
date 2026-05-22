import 'package:logger/logger.dart';
import 'package:trovara/core/repository/interfaces/igraph_repository.dart';
import 'package:trovara/core/repository/interfaces/embedding_repository.dart';
import 'package:trovara/core/services/ai/embedding_service.dart';
import 'package:trovara/core/services/graph/citation_extractor_service.dart';
import 'package:trovara/core/services/graph/similarity_matcher_service.dart';
import 'package:trovara/models/graph_node.dart';

class KnowledgeGraphService {
  final IGraphRepository graphRepository;
  final EmbeddingService embeddingService;
  final IEmbeddingRepository? embeddingRepository;
  final CitationExtractorService citationExtractor = CitationExtractorService();
  final SimilarityMatcherService similarityMatcher = SimilarityMatcherService();

  static final _logger = Logger();

  KnowledgeGraphService({
    required this.graphRepository,
    required this.embeddingService,
    this.embeddingRepository,
  });

  /// Analyze a note and build/update its graph representation
  /// Triggered on note save
  Future<void> analyzeNote(int noteId, String noteText) async {
    try {
      _logger.i('Analyzing note $noteId for graph...');

      // Step 1: Get or create node
      final node = await graphRepository.getOrCreateNode(noteId);

      // Step 2: Extract citations
      final citations = citationExtractor.extractCitations(noteText);
      for (final citation in citations) {
        await graphRepository.createOrUpdateCitation(
          source: citation.source,
          title: citation.title ?? citation.source,
          isConfirmed: citation.isInternal,
        );
      }

      // Step 3: Find semantically similar notes (deferred to query-time for MVP)
      List<double>? embedding;
      try {
        if (embeddingRepository != null) {
          final embeddings = embeddingRepository!.getEmbeddingsByNoteId(noteId);
          if (embeddings.isNotEmpty) {
            // Use the first chunk's embedding for MVP
            embedding = embeddings.first.embedding;
          }
        }
      } catch (e) {
        _logger.w('Failed to get embedding for note $noteId: $e');
        // Continue without embedding; graph still works with citations/hierarchical edges
      }

      if (embedding != null) {
        await _findAndLinkSimilarNotes(node, embedding);
      }

      _logger.i('Finished analyzing note $noteId');
    } catch (e) {
      _logger.e('Error analyzing note $noteId', error: e);
      rethrow;
    }
  }

  /// Find notes similar to the given embedding and create semantic edges (MVP: deferred)
  Future<void> _findAndLinkSimilarNotes(GraphNode sourceNode, List<double> embedding) async {
    // TODO: This requires querying all embeddings; for MVP, defer to query-time
    // (don't precompute all edges, only on-demand in semantic explorer)
  }

  /// Get stats for dashboard
  Future<GraphStats> getGraphStats() async {
    final topNodes = await graphRepository.getTopNodes(20);
    final allCitations = await graphRepository.getAllCitations();

    return GraphStats(
      topConcepts: topNodes.map((p) => (p.$1.noteId, p.$2)).toList(),
      totalCitations: allCitations.length,
      confirmedCitations: allCitations.where((c) => c.isConfirmed).length,
    );
  }

  /// Clean up graph when a note is deleted
  Future<void> deleteNodeForNote(int noteId) async {
    await graphRepository.deleteNodeForNote(noteId);
    _logger.i('Deleted graph node for note $noteId');
  }
}

class GraphStats {
  final List<(int noteId, int inDegree)> topConcepts;
  final int totalCitations;
  final int confirmedCitations;

  GraphStats({
    required this.topConcepts,
    required this.totalCitations,
    required this.confirmedCitations,
  });
}
