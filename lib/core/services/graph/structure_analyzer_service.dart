import 'package:logger/logger.dart';
import 'package:trovara/core/repository/interfaces/igraph_repository.dart';
import 'package:trovara/models/graph_node.dart';

class StructureAnalyzerService {
  final IGraphRepository graphRepository;
  static final _logger = Logger();

  StructureAnalyzerService(this.graphRepository);

  /// Analyze a cluster of notes and infer hierarchical structure
  /// Used to suggest project organization
  Future<HierarchyCluster> analyzeCluster(List<int> noteIds) async {
    if (noteIds.isEmpty) {
      return HierarchyCluster(root: null, children: []);
    }

    final nodes = <GraphNode>[];
    for (final noteId in noteIds) {
      final node = await graphRepository.getOrCreateNode(noteId);
      nodes.add(node);
    }

    // Find most central node (highest in-degree within cluster)
    int? rootNoteId;
    int maxInDegree = -1;

    for (final node in nodes) {
      final incomingEdges = await graphRepository.getIncomingEdges(node.id);
      final edgesInCluster = incomingEdges
          .where((e) => noteIds.contains(e.sourceNodeId))
          .length;

      if (edgesInCluster > maxInDegree) {
        maxInDegree = edgesInCluster;
        rootNoteId = node.noteId;
      }
    }

    _logger.i('Analyzed cluster of ${noteIds.length} notes; root = $rootNoteId');

    return HierarchyCluster(
      root: rootNoteId,
      children: noteIds.where((id) => id != rootNoteId).toList(),
    );
  }

  /// Detect if a graph has cycles
  Future<bool> hasCycles(List<GraphNode> nodes) async {
    // TODO: implement DFS cycle detection if needed
    // For MVP, assume no cycles (user-created hierarchies are typically DAGs)
    return false;
  }

  /// Suggest natural groupings from semantic edges
  /// Used for "these notes form a cluster, make a project?" suggestion
  Future<List<Set<int>>> suggestClusters(List<int> noteIds, {double threshold = 0.7}) async {
    if (noteIds.length < 2) return [];

    final clusters = <Set<int>>[];
    final visited = <int>{};

    for (final noteId in noteIds) {
      if (visited.contains(noteId)) continue;

      final cluster = <int>{noteId};
      visited.add(noteId);

      // BFS to find all notes connected above threshold
      final queue = [noteId];
      while (queue.isNotEmpty) {
        final current = queue.removeAt(0);
        final node = await graphRepository.getOrCreateNode(current);

        // Outgoing edges
        final outgoing = await graphRepository.getOutgoingEdges(node.id);
        for (final edge in outgoing) {
          if (edge.edgeType == 'semantic' && edge.strength >= threshold) {
            if (!visited.contains(edge.targetNodeId)) {
              visited.add(edge.targetNodeId);
              cluster.add(edge.targetNodeId);
              queue.add(edge.targetNodeId);
            }
          }
        }

        // Incoming edges
        final incoming = await graphRepository.getIncomingEdges(node.id);
        for (final edge in incoming) {
          if (edge.edgeType == 'semantic' && edge.strength >= threshold) {
            if (!visited.contains(edge.sourceNodeId)) {
              visited.add(edge.sourceNodeId);
              cluster.add(edge.sourceNodeId);
              queue.add(edge.sourceNodeId);
            }
          }
        }
      }

      if (cluster.length > 1) {
        clusters.add(cluster);
      }
    }

    _logger.i('Found ${clusters.length} natural clusters');
    return clusters;
  }
}

class HierarchyCluster {
  final int? root; // Most central note ID
  final List<int> children; // All other note IDs

  HierarchyCluster({
    required this.root,
    required this.children,
  });
}
