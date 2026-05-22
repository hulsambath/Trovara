import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/services/graph/knowledge_graph_service.dart';
import 'package:trovara/core/repository/interfaces/igraph_repository.dart';
import 'package:trovara/core/repository/interfaces/embedding_repository.dart';
import 'package:trovara/core/services/ai/embedding_service.dart';
import 'package:trovara/models/graph_node.dart';
import 'package:trovara/models/graph_edge.dart';
import 'package:trovara/models/citation.dart';
import 'package:trovara/models/note_embedding.dart';
import '../../test_support.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  Stub implementations for testing
// ═══════════════════════════════════════════════════════════════════════════

class StubGraphRepository implements IGraphRepository {
  final Map<int, GraphNode> _nodes = {};
  final List<Citation> _citations = [];
  int _nodeCreatedCount = 0;

  int get nodeCreatedCount => _nodeCreatedCount;

  @override
  Future<GraphNode> getOrCreateNode(int noteId) async {
    _nodeCreatedCount++;
    if (!_nodes.containsKey(noteId)) {
      final node = GraphNode(noteId: noteId);
      _nodes[noteId] = node;
    }
    return _nodes[noteId]!;
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
    final citation = Citation(
      source: source,
      title: title,
      author: author,
      datePublished: datePublished,
      format: format,
      isConfirmed: isConfirmed,
    );
    _citations.add(citation);
    return citation;
  }

  @override
  Future<GraphNode?> getNode(int nodeId) async => null;
  @override
  Future<List<GraphEdge>> getOutgoingEdges(int sourceNodeId) async => [];
  @override
  Future<List<GraphEdge>> getIncomingEdges(int targetNodeId) async => [];
  @override
  Future<GraphEdge> createOrUpdateEdge({
    required int sourceNodeId,
    required int targetNodeId,
    required String edgeType,
    double strength = 1.0,
    String? metadata,
  }) async => GraphEdge(edgeType: edgeType, strength: strength, metadata: metadata);
  @override
  Future<void> deleteEdge(int edgeId) async {}
  @override
  Future<List<(GraphNode node, double similarity)>> findSimilarNodes(
    int nodeId, {
    double threshold = 0.7,
    int limit = 20,
  }) async => [];
  @override
  Future<List<(GraphNode node, int inDegree)>> getTopNodes(int limit) async => [];
  @override
  Future<void> deleteNodeForNote(int noteId) async {}
  @override
  Future<Citation?> getCitationBySource(String source) async => null;
  @override
  Future<List<Citation>> getAllCitations() async => _citations;
  @override
  Future<void> deleteCitation(int citationId) async {}
}

class StubEmbeddingRepository implements IEmbeddingRepository {
  final Map<int, List<NoteEmbedding>> _embeddings = {};

  void addEmbedding(int noteId, NoteEmbedding embedding) {
    _embeddings.putIfAbsent(noteId, () => []).add(embedding);
  }

  @override
  List<NoteEmbedding> getEmbeddingsByNoteId(int noteId) => _embeddings[noteId] ?? [];

  @override
  Future<void> deleteByNoteId(int noteId) async => _embeddings.remove(noteId);

  @override
  List<NoteEmbedding> getAllEmbeddings() => _embeddings.values.expand((e) => e).toList();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> saveEmbedding(NoteEmbedding embedding) async => addEmbedding(embedding.noteId, embedding);

  @override
  Future<void> saveEmbeddings(List<NoteEmbedding> embeddings) async {
    for (final emb in embeddings) {
      addEmbedding(emb.noteId, emb);
    }
  }

  @override
  Future<void> deleteAll() async => _embeddings.clear();

  @override
  int get totalEmbeddings => _embeddings.values.fold(0, (sum, list) => sum + list.length);

  @override
  void dispose() {}
}

class FakeEmbeddingService extends EmbeddingService {
  FakeEmbeddingService() : super(
    embeddingRepository: StubEmbeddingRepository(),
    provider: EmbeddingProvider.gemini,
    apiKey: 'fake-key',
  );

  @override
  Future<void> initialize() async {
    // Fake initialization
  }

  @override
  Future<void> embedNote(covariant Object note) async {
    // Fake embedding
  }

  @override
  Future<List<double>?> embedQuery(String query) async => null;

  @override
  Future<void> deleteEmbeddingsForNote(int noteId) async {}

  @override
  Future<bool> isNoteStale(covariant Object note) async => false;

  @override
  Future<void> reembedStaleNotes(List<Object> notes) async {}

  @override
  Future<void> processPendingEmbeddings() async {}

  @override
  Future<void> reembedAll(List<Object> notes) async {}

  @override
  List<String> buildEmbeddingInputs(covariant Object note) => [];
}

void main() {
  group('KnowledgeGraphService', () {
    late KnowledgeGraphService service;
    late StubGraphRepository stubGraphRepo;
    late StubEmbeddingRepository stubEmbeddingRepo;
    late EmbeddingService stubEmbeddingService;

    setUp(() {
      stubGraphRepo = StubGraphRepository();
      stubEmbeddingRepo = StubEmbeddingRepository();
      stubEmbeddingService = FakeEmbeddingService();
      service = KnowledgeGraphService(
        graphRepository: stubGraphRepo,
        embeddingService: stubEmbeddingService,
        embeddingRepository: stubEmbeddingRepo,
      );
    });

    test('creates node on analyzeNote', () async {
      const noteId = 1;

      await service.analyzeNote(noteId, 'Sample text [citation: https://example.com]');

      expect(stubGraphRepo.nodeCreatedCount, 1);
    });

    test('extracts and stores citations', () async {
      const noteId = 1;
      const citationUrl = 'https://example.com/paper.pdf';

      await service.analyzeNote(noteId, 'Check [citation: $citationUrl]');

      final citations = await stubGraphRepo.getAllCitations();
      expect(citations.where((c) => c.source == citationUrl), isNotEmpty);
    });

    test('handles missing embeddings gracefully', () async {
      const noteId = 1;

      // Should not throw even with no embeddings available
      await service.analyzeNote(noteId, 'Text without embeddings');

      expect(stubGraphRepo.nodeCreatedCount, 1);
    });
  });
}
