import 'package:trovara/core/repository/base/base_repository.dart';
import 'package:trovara/core/repository/base/objectbox_store_manager.dart';
import 'package:trovara/core/repository/interfaces/igraph_repository.dart';
import 'package:trovara/models/graph_node.dart';
import 'package:trovara/models/graph_edge.dart';
import 'package:trovara/models/citation.dart';
import 'package:trovara/objectbox.g.dart';

class ObjectBoxGraphRepository extends BaseRepository implements IGraphRepository {
  final ObjectBoxStoreManager storeManager;

  ObjectBoxGraphRepository(this.storeManager);

  @override
  Future<GraphNode> getOrCreateNode(int noteId) async {
    final store = await storeManager.store;
    final box = store.box<GraphNode>();

    final query = box.query(GraphNode_.noteId.equals(noteId)).build();
    final existing = query.findFirst();
    query.close();

    if (existing != null) return existing;

    final node = GraphNode(noteId: noteId);
    box.put(node);
    return node;
  }

  @override
  Future<GraphNode?> getNode(int nodeId) async {
    final store = await storeManager.store;
    final box = store.box<GraphNode>();
    return box.get(nodeId);
  }

  @override
  Future<List<GraphEdge>> getOutgoingEdges(int sourceNodeId) async {
    final store = await storeManager.store;
    final box = store.box<GraphEdge>();

    final query = box.query(GraphEdge_.sourceNode.equals(sourceNodeId))
        .order(GraphEdge_.strength, flags: Order.descending)
        .build();
    final results = query.find();
    query.close();

    return results;
  }

  @override
  Future<List<GraphEdge>> getIncomingEdges(int targetNodeId) async {
    final store = await storeManager.store;
    final box = store.box<GraphEdge>();

    final query = box.query(GraphEdge_.targetNode.equals(targetNodeId))
        .order(GraphEdge_.strength, flags: Order.descending)
        .build();
    final results = query.find();
    query.close();

    return results;
  }

  @override
  Future<GraphEdge> createOrUpdateEdge({
    required int sourceNodeId,
    required int targetNodeId,
    required String edgeType,
    double strength = 1.0,
    String? metadata,
  }) async {
    final store = await storeManager.store;
    final box = store.box<GraphEdge>();

    final query = box.query(
      GraphEdge_.sourceNode.equals(sourceNodeId)
          .and(GraphEdge_.targetNode.equals(targetNodeId))
          .and(GraphEdge_.edgeType.equals(edgeType)),
    ).build();
    final existing = query.findFirst();
    query.close();

    if (existing != null) {
      existing.strength = strength;
      existing.metadata = metadata;
      box.put(existing);
      notifyListeners();
      return existing;
    }

    final edge = GraphEdge(
      edgeType: edgeType,
      strength: strength,
      metadata: metadata,
    );
    // Set relationships
    final sourceNode = await getNode(sourceNodeId);
    final targetNode = await getNode(targetNodeId);

    if (sourceNode != null && targetNode != null) {
      edge.sourceNode.target = sourceNode;
      edge.targetNode.target = targetNode;
      box.put(edge);
      notifyListeners();
      return edge;
    }

    throw StateError(
      'Source ($sourceNodeId) or target ($targetNodeId) node not found',
    );
  }

  @override
  Future<void> deleteEdge(int edgeId) async {
    final store = await storeManager.store;
    final box = store.box<GraphEdge>();
    box.remove(edgeId);
    notifyListeners();
  }

  @override
  Future<List<(GraphNode node, double similarity)>> findSimilarNodes(
    int nodeId, {
    double threshold = 0.7,
    int limit = 20,
  }) async {
    final store = await storeManager.store;
    final edgeBox = store.box<GraphEdge>();

    // Find all semantic edges from this node with strength > threshold
    final query = edgeBox.query(
      GraphEdge_.sourceNode.equals(nodeId)
          .and(GraphEdge_.edgeType.equals('semantic'))
          .and(GraphEdge_.strength.greaterThan(threshold)),
    ).order(GraphEdge_.strength, flags: Order.descending)
        .build();
    final edges = query.find();
    query.close();

    if (edges.isEmpty) return [];

    final results = <(GraphNode, double)>[];

    for (final edge in edges.take(limit)) {
      final target = edge.targetNode.target;
      if (target != null) {
        results.add((target, edge.strength));
      }
    }

    return results;
  }

  @override
  Future<List<(GraphNode node, int inDegree)>> getTopNodes(int limit) async {
    final store = await storeManager.store;
    final nodeBox = store.box<GraphNode>();
    final edgeBox = store.box<GraphEdge>();

    final allNodes = nodeBox.getAll();
    final inDegrees = <int, int>{};

    final edgeQuery = edgeBox.query().build();
    final edges = edgeQuery.find();
    edgeQuery.close();

    for (final edge in edges) {
      final targetId = edge.targetNode.targetId;
      inDegrees[targetId] = (inDegrees[targetId] ?? 0) + 1;
    }

    final sorted = <(GraphNode, int)>[];
    for (final n in allNodes) {
      final inDegree = inDegrees[n.id] ?? 0;
      if (inDegree > 0) {
        sorted.add((n, inDegree));
      }
    }

    sorted.sort((a, b) => b.$2.compareTo(a.$2));
    return sorted.take(limit).toList();
  }

  @override
  Future<void> deleteNodeForNote(int noteId) async {
    final store = await storeManager.store;
    final nodeBox = store.box<GraphNode>();
    final edgeBox = store.box<GraphEdge>();

    final query = nodeBox.query(GraphNode_.noteId.equals(noteId)).build();
    final node = query.findFirst();
    query.close();

    if (node == null) return;

    // Delete all edges involving this node
    final outgoingQuery = edgeBox.query(GraphEdge_.sourceNode.equals(node.id)).build();
    final outgoing = outgoingQuery.find();
    outgoingQuery.close();

    final incomingQuery = edgeBox.query(GraphEdge_.targetNode.equals(node.id)).build();
    final incoming = incomingQuery.find();
    incomingQuery.close();

    final edgesToDelete = [...outgoing, ...incoming].map((e) => e.id).toList();
    edgeBox.removeMany(edgesToDelete);
    nodeBox.remove(node.id);
    notifyListeners();
  }

  @override
  Future<Citation> createOrUpdateCitation({
    required String source,
    required String title,
    String? author,
    String? datePublished,
    String format = 'APA',
    bool isConfirmed = true,
  }) async {
    final store = await storeManager.store;
    final box = store.box<Citation>();

    final query = box.query(Citation_.source.equals(source)).build();
    final existing = query.findFirst();
    query.close();

    if (existing != null) {
      existing.title = title;
      existing.author = author;
      existing.datePublished = datePublished;
      existing.format = format;
      existing.isConfirmed = isConfirmed;
      box.put(existing);
      notifyListeners();
      return existing;
    }

    final citation = Citation(
      source: source,
      title: title,
      author: author,
      datePublished: datePublished,
      format: format,
      isConfirmed: isConfirmed,
    );
    box.put(citation);
    notifyListeners();
    return citation;
  }

  @override
  Future<Citation?> getCitationBySource(String source) async {
    final store = await storeManager.store;
    final box = store.box<Citation>();

    final query = box.query(Citation_.source.equals(source)).build();
    final result = query.findFirst();
    query.close();

    return result;
  }

  @override
  Future<List<Citation>> getAllCitations() async {
    final store = await storeManager.store;
    final box = store.box<Citation>();
    return box.getAll();
  }

  @override
  Future<void> deleteCitation(int citationId) async {
    final store = await storeManager.store;
    final box = store.box<Citation>();
    box.remove(citationId);
    notifyListeners();
  }
}
