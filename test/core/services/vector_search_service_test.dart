import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/repository/interfaces/embedding_repository.dart';
import 'package:trovara/core/services/vector_search_service.dart';
import 'package:trovara/models/note_embedding.dart';

/// A mock implementation of [IEmbeddingRepository] for testing.
class MockEmbeddingRepository implements IEmbeddingRepository {
  final List<NoteEmbedding> _embeddings = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> saveEmbedding(NoteEmbedding embedding) async {
    _embeddings.add(embedding);
  }

  @override
  Future<void> saveEmbeddings(List<NoteEmbedding> embeddings) async {
    _embeddings.addAll(embeddings);
  }

  @override
  List<NoteEmbedding> getEmbeddingsByNoteId(int noteId) => _embeddings.where((e) => e.noteId == noteId).toList();

  @override
  List<NoteEmbedding> getAllEmbeddings() => List.unmodifiable(_embeddings);

  @override
  Future<void> deleteByNoteId(int noteId) async {
    _embeddings.removeWhere((e) => e.noteId == noteId);
  }

  @override
  Future<void> deleteAll() async {
    _embeddings.clear();
  }

  @override
  int get totalEmbeddings => _embeddings.length;

  @override
  void dispose() {}

  void addTestEmbedding({
    required int noteId,
    required List<double> vector,
    int chunkIndex = 0,
    String chunkText = 'test chunk',
  }) {
    _embeddings.add(
      NoteEmbedding(
        noteId: noteId,
        chunkIndex: chunkIndex,
        chunkText: chunkText,
        embeddingData: NoteEmbedding.serializeEmbedding(vector),
        modelVersion: 'text-embedding-004',
        noteUpdatedAt: DateTime.now(),
      ),
    );
  }
}

void main() {
  group('VectorSearchService', () {
    late MockEmbeddingRepository mockRepository;
    late VectorSearchService service;

    setUp(() {
      mockRepository = MockEmbeddingRepository();
      service = VectorSearchService(repository: mockRepository);
    });

    group('cosineSimilarity', () {
      test('identical vectors have similarity 1.0', () {
        final vector = [1.0, 0.0, 0.0];
        mockRepository.addTestEmbedding(noteId: 1, vector: vector);

        final results = service.search(vector, minScore: 0.0);

        expect(results.length, 1);
        expect(results.first.score, closeTo(1.0, 0.0001));
      });

      test('orthogonal vectors have similarity 0.0', () {
        // [1, 0] and [0, 1] are orthogonal
        mockRepository.addTestEmbedding(noteId: 1, vector: [1.0, 0.0]);

        final results = service.search([0.0, 1.0], minScore: 0.0);

        expect(results.length, 1);
        expect(results.first.score, closeTo(0.0, 0.0001));
      });

      test('opposite vectors have similarity -1.0', () {
        mockRepository.addTestEmbedding(noteId: 1, vector: [1.0, 0.0]);

        // Opposite direction - use very low minScore to capture negative similarity
        final results = service.search([-1.0, 0.0], minScore: -1.0);

        expect(results.length, 1);
        expect(results.first.score, closeTo(-1.0, 0.0001));
      });

      test('similar vectors have high similarity', () {
        mockRepository.addTestEmbedding(noteId: 1, vector: [1.0, 0.1, 0.0]);

        final results = service.search([1.0, 0.0, 0.0], minScore: 0.0);

        expect(results.length, 1);
        expect(results.first.score, greaterThan(0.9));
      });
    });

    group('search', () {
      test('returns empty list when no embeddings exist', () {
        final results = service.search([1.0, 0.0, 0.0]);
        expect(results, isEmpty);
      });

      test('returns results sorted by descending score', () {
        // Three vectors with decreasing similarity to [1, 0, 0]
        mockRepository.addTestEmbedding(noteId: 1, vector: [1.0, 0.0, 0.0]); // exact match
        mockRepository.addTestEmbedding(noteId: 2, vector: [0.9, 0.1, 0.0]); // close
        mockRepository.addTestEmbedding(noteId: 3, vector: [0.5, 0.5, 0.0]); // less similar

        final results = service.search([1.0, 0.0, 0.0], minScore: 0.0);

        expect(results.length, 3);
        expect(results[0].embedding.noteId, 1);
        expect(results[1].embedding.noteId, 2);
        expect(results[2].embedding.noteId, 3);
        expect(results[0].score, greaterThan(results[1].score));
        expect(results[1].score, greaterThan(results[2].score));
      });

      test('respects topK limit', () {
        for (int i = 1; i <= 10; i++) {
          mockRepository.addTestEmbedding(noteId: i, vector: [1.0, 0.0, 0.0]);
        }

        final results = service.search([1.0, 0.0, 0.0], topK: 3, minScore: 0.0);

        expect(results.length, 3);
      });

      test('filters by minScore', () {
        mockRepository.addTestEmbedding(noteId: 1, vector: [1.0, 0.0, 0.0]); // score ~1.0
        mockRepository.addTestEmbedding(noteId: 2, vector: [0.7, 0.7, 0.0]); // score ~0.7
        mockRepository.addTestEmbedding(noteId: 3, vector: [0.0, 1.0, 0.0]); // score ~0.0

        final results = service.search([1.0, 0.0, 0.0], minScore: 0.5);

        expect(results.length, 2);
        expect(results.every((r) => r.score >= 0.5), isTrue);
      });

      test('handles multiple chunks from same note', () {
        mockRepository.addTestEmbedding(noteId: 1, chunkIndex: 0, vector: [1.0, 0.0, 0.0], chunkText: 'chunk 0');
        mockRepository.addTestEmbedding(noteId: 1, chunkIndex: 1, vector: [0.9, 0.1, 0.0], chunkText: 'chunk 1');

        final results = service.search([1.0, 0.0, 0.0], minScore: 0.0);

        expect(results.length, 2);
        expect(results.every((r) => r.embedding.noteId == 1), isTrue);
      });
    });

    group('searchExcluding', () {
      test('excludes specified note IDs', () {
        mockRepository.addTestEmbedding(noteId: 1, vector: [1.0, 0.0, 0.0]);
        mockRepository.addTestEmbedding(noteId: 2, vector: [1.0, 0.0, 0.0]);
        mockRepository.addTestEmbedding(noteId: 3, vector: [1.0, 0.0, 0.0]);

        final results = service.searchExcluding([1.0, 0.0, 0.0], excludeNoteIds: {1, 2}, minScore: 0.0);

        expect(results.length, 1);
        expect(results.first.embedding.noteId, 3);
      });
    });

    group('findSimilarToNote', () {
      test('returns empty list if note has no embeddings', () {
        final results = service.findSimilarToNote(999);
        expect(results, isEmpty);
      });

      test('finds similar notes excluding the source note', () {
        // Source note (id: 1) with one chunk
        mockRepository.addTestEmbedding(noteId: 1, vector: [1.0, 0.0, 0.0]);
        // Similar note (id: 2)
        mockRepository.addTestEmbedding(noteId: 2, vector: [0.95, 0.05, 0.0]);
        // Less similar note (id: 3)
        mockRepository.addTestEmbedding(noteId: 3, vector: [0.5, 0.5, 0.0]);

        final results = service.findSimilarToNote(1, minScore: 0.0);

        expect(results.length, 2);
        expect(results.every((r) => r.embedding.noteId != 1), isTrue);
        expect(results[0].embedding.noteId, 2); // Most similar
      });

      test('averages multiple chunks from source note', () {
        // Source note with two chunks
        mockRepository.addTestEmbedding(noteId: 1, chunkIndex: 0, vector: [1.0, 0.0, 0.0]);
        mockRepository.addTestEmbedding(noteId: 1, chunkIndex: 1, vector: [0.0, 1.0, 0.0]);
        // Target note: average of source chunks is [0.5, 0.5, 0.0]
        mockRepository.addTestEmbedding(noteId: 2, vector: [0.5, 0.5, 0.0]);

        final results = service.findSimilarToNote(1, minScore: 0.0);

        expect(results.length, 1);
        expect(results.first.embedding.noteId, 2);
        expect(results.first.score, greaterThan(0.9));
      });
    });

    group('getStats', () {
      test('returns zeros when no embeddings exist', () {
        final stats = service.getStats();

        expect(stats.totalChunks, 0);
        expect(stats.uniqueNotes, 0);
        expect(stats.avgChunksPerNote, 0);
        expect(stats.embeddingDimension, 0);
      });

      test('correctly calculates statistics', () {
        // 3 chunks across 2 notes
        mockRepository.addTestEmbedding(noteId: 1, chunkIndex: 0, vector: [1.0, 0.0, 0.0]);
        mockRepository.addTestEmbedding(noteId: 1, chunkIndex: 1, vector: [0.9, 0.1, 0.0]);
        mockRepository.addTestEmbedding(noteId: 2, chunkIndex: 0, vector: [0.5, 0.5, 0.0]);

        final stats = service.getStats();

        expect(stats.totalChunks, 3);
        expect(stats.uniqueNotes, 2);
        expect(stats.avgChunksPerNote, 1.5);
        expect(stats.embeddingDimension, 3);
      });
    });
  });
}
