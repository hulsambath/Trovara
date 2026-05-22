import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trovara/core/services/graph/knowledge_graph_service.dart';
import 'package:trovara/core/repository/interfaces/igraph_repository.dart';
import 'package:trovara/core/services/ai/embedding_service.dart';
import 'package:trovara/models/graph_node.dart';
import 'package:trovara/models/citation.dart';

class MockGraphRepository extends Mock implements IGraphRepository {}
class MockEmbeddingService extends Mock implements EmbeddingService {}

void main() {
  group('KnowledgeGraphService', () {
    late KnowledgeGraphService service;
    late MockGraphRepository mockGraphRepo;
    late MockEmbeddingService mockEmbeddingService;

    setUp(() {
      mockGraphRepo = MockGraphRepository();
      mockEmbeddingService = MockEmbeddingService();
      service = KnowledgeGraphService(
        graphRepository: mockGraphRepo,
        embeddingService: mockEmbeddingService,
      );
    });

    test('creates node on analyzeNote', () async {
      const noteId = 1;
      final mockEmbedding = List<double>.filled(384, 0.1);

      when(() => mockEmbeddingService.getEmbedding(noteId))
          .thenAnswer((_) async => mockEmbedding);
      when(() => mockGraphRepo.getOrCreateNode(noteId))
          .thenAnswer((_) async => GraphNode(noteId: noteId));

      await service.analyzeNote(noteId, 'Sample text [citation: https://example.com]');

      verify(() => mockGraphRepo.getOrCreateNode(noteId)).called(1);
    });

    test('extracts and stores citations', () async {
      const noteId = 1;
      const citationUrl = 'https://example.com/paper.pdf';
      final mockEmbedding = List<double>.filled(384, 0.1);

      when(() => mockEmbeddingService.getEmbedding(noteId))
          .thenAnswer((_) async => mockEmbedding);
      when(() => mockGraphRepo.getOrCreateNode(noteId))
          .thenAnswer((_) async => GraphNode(noteId: noteId));
      when(() => mockGraphRepo.createOrUpdateCitation(
        source: any(named: 'source'),
        title: any(named: 'title'),
        author: any(named: 'author'),
        datePublished: any(named: 'datePublished'),
        format: any(named: 'format'),
        isConfirmed: any(named: 'isConfirmed'),
      )).thenAnswer((_) async => Citation(source: citationUrl, title: 'Paper'));

      await service.analyzeNote(noteId, 'Check [citation: $citationUrl]');

      verify(() => mockGraphRepo.createOrUpdateCitation(
        source: citationUrl,
        title: any(named: 'title'),
        author: any(named: 'author'),
        datePublished: any(named: 'datePublished'),
        format: any(named: 'format'),
        isConfirmed: any(named: 'isConfirmed'),
      )).called(1);
    });

    test('handles embedding service failure gracefully', () async {
      const noteId = 1;

      when(() => mockEmbeddingService.getEmbedding(noteId))
          .thenThrow(Exception('Embedding failed'));
      when(() => mockGraphRepo.getOrCreateNode(noteId))
          .thenAnswer((_) async => GraphNode(noteId: noteId));

      // Should not throw; should log and continue
      await service.analyzeNote(noteId, 'Text');

      verify(() => mockGraphRepo.getOrCreateNode(noteId)).called(1);
    });
  });
}
