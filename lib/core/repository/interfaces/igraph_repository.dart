import 'package:trovara/models/graph_node.dart';
import 'package:trovara/models/graph_edge.dart';
import 'package:trovara/models/citation.dart';

abstract class IGraphRepository {
  /// Get or create node for note ID
  Future<GraphNode> getOrCreateNode(int noteId);

  /// Get node by ID
  Future<GraphNode?> getNode(int nodeId);

  /// Get all edges from source node
  Future<List<GraphEdge>> getOutgoingEdges(int sourceNodeId);

  /// Get all edges to target node
  Future<List<GraphEdge>> getIncomingEdges(int targetNodeId);

  /// Create or update edge (upsert by sourceId+targetId+edgeType)
  Future<GraphEdge> createOrUpdateEdge({
    required int sourceNodeId,
    required int targetNodeId,
    required String edgeType,
    double strength = 1.0,
    String? metadata,
  });

  /// Delete edge by ID
  Future<void> deleteEdge(int edgeId);

  /// Find nodes similar to given node (cosine similarity > threshold)
  Future<List<(GraphNode node, double similarity)>> findSimilarNodes(
    int nodeId, {
    double threshold = 0.7,
    int limit = 20,
  });

  /// Get top N nodes by in-degree (most referenced)
  Future<List<(GraphNode node, int inDegree)>> getTopNodes(int limit);

  /// Delete all edges and node for a note (cleanup when note deleted)
  Future<void> deleteNodeForNote(int noteId);

  /// Add or update citation
  Future<Citation> createOrUpdateCitation({
    required String source,
    required String title,
    String? author,
    String? datePublished,
    String format = 'APA',
    bool isConfirmed = true,
  });

  /// Get citation by source
  Future<Citation?> getCitationBySource(String source);

  /// Get all citations
  Future<List<Citation>> getAllCitations();

  /// Delete citation by ID
  Future<void> deleteCitation(int citationId);
}
