import 'package:patrol/patrol.dart';
import 'package:trovara/core/repository/interfaces/embedding_repository.dart';
import 'package:trovara/core/services/ai/embedding_service.dart';
import 'package:trovara/models/note.dart';
import 'package:trovara/models/note_embedding.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  Stubs
// ═══════════════════════════════════════════════════════════════════════════

/// In-memory embedding repository for testing.
class StubEmbeddingRepository implements IEmbeddingRepository {
  final List<NoteEmbedding> _embeddings = [];

  void seed(List<NoteEmbedding> embeddings) => _embeddings.addAll(embeddings);

  @override
  Future<void> initialize() async {}
  @override
  Future<void> saveEmbedding(NoteEmbedding embedding) async => _embeddings.add(embedding);
  @override
  Future<void> saveEmbeddings(List<NoteEmbedding> embeddings) async => _embeddings.addAll(embeddings);
  @override
  List<NoteEmbedding> getEmbeddingsByNoteId(int noteId) => _embeddings.where((e) => e.noteId == noteId).toList();
  @override
  List<NoteEmbedding> getAllEmbeddings() => List.unmodifiable(_embeddings);
  @override
  Future<void> deleteByNoteId(int noteId) async => _embeddings.removeWhere((e) => e.noteId == noteId);
  @override
  Future<void> deleteAll() async => _embeddings.clear();
  @override
  int get totalEmbeddings => _embeddings.length;
  @override
  void dispose() {}
}

// ═══════════════════════════════════════════════════════════════════════════
//  Helpers
// ═══════════════════════════════════════════════════════════════════════════

const _testModel = 'text-embedding-test';

Note _makeNote({required int id, required String title, String contentJson = '[]', DateTime? updatedAt}) {
  final note = Note(title: title, contentJson: contentJson, updatedAt: updatedAt ?? DateTime(2026, 3, 1));
  note.id = id;
  return note;
}

/// Build a Quill Delta JSON list from plain text.
String _quillJson(String text) => '[{"insert":"$text\\n"}]';

/// Create an [EmbeddingService] wired to the given stub repository.
EmbeddingService _makeService(StubEmbeddingRepository repo, {String model = _testModel}) => EmbeddingService(
  embeddingRepository: repo,
  apiKey: 'test-key', // won't call API — we only test isNoteStale
  modelName: model,
);

// ═══════════════════════════════════════════════════════════════════════════
//  Tests
// ═══════════════════════════════════════════════════════════════════════════

void main() {
  late StubEmbeddingRepository repo;
  late EmbeddingService service;

  setUp(() {
    repo = StubEmbeddingRepository();
    service = _makeService(repo);
  });

  // ─────────────────────────────────────────────────────────────────────────
  //  buildEmbeddingInputs
  // ─────────────────────────────────────────────────────────────────────────

  group('buildEmbeddingInputs', () {
    patrolTest('returns empty list for empty note', () {
      final note = _makeNote(id: 1, title: '', contentJson: '[]');
      expect(service.buildEmbeddingInputs(note), isEmpty);
    });

    patrolTest('uses title when content is empty', () {
      final note = _makeNote(id: 1, title: 'My Title', contentJson: '[]');
      final inputs = service.buildEmbeddingInputs(note);

      expect(inputs.length, 1);
      expect(inputs.first, 'My Title');
    });

    patrolTest('prepends title when content is non-empty', () {
      final note = _makeNote(id: 1, title: 'My Title', contentJson: _quillJson('Body text here'));
      final inputs = service.buildEmbeddingInputs(note);

      expect(inputs.length, 1);
      expect(inputs.first, contains('Title: My Title'));
      expect(inputs.first, contains('Body text here'));
    });

    patrolTest('is deterministic — same note → same inputs', () {
      final note = _makeNote(id: 1, title: 'Stable', contentJson: _quillJson('Content'));
      final a = service.buildEmbeddingInputs(note);
      final b = service.buildEmbeddingInputs(note);

      expect(a, equals(b));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  //  computeContentSignature
  // ─────────────────────────────────────────────────────────────────────────

  group('computeContentSignature', () {
    patrolTest('is deterministic — same inputs → same hash', () {
      final inputs = ['Title: A\n\nBody'];
      final a = EmbeddingService.computeContentSignature(
        inputs,
        modelName: _testModel,
        maxChunkChars: 2000,
        overlapChars: 200,
      );
      final b = EmbeddingService.computeContentSignature(
        inputs,
        modelName: _testModel,
        maxChunkChars: 2000,
        overlapChars: 200,
      );
      expect(a, equals(b));
    });

    patrolTest('different content → different hash', () {
      final a = EmbeddingService.computeContentSignature(
        ['Title: A\n\nBody'],
        modelName: _testModel,
        maxChunkChars: 2000,
        overlapChars: 200,
      );
      final b = EmbeddingService.computeContentSignature(
        ['Title: B\n\nBody'],
        modelName: _testModel,
        maxChunkChars: 2000,
        overlapChars: 200,
      );
      expect(a, isNot(equals(b)));
    });

    patrolTest('different model → different hash', () {
      final inputs = ['same content'];
      final a = EmbeddingService.computeContentSignature(
        inputs,
        modelName: 'model-v1',
        maxChunkChars: 2000,
        overlapChars: 200,
      );
      final b = EmbeddingService.computeContentSignature(
        inputs,
        modelName: 'model-v2',
        maxChunkChars: 2000,
        overlapChars: 200,
      );
      expect(a, isNot(equals(b)));
    });

    patrolTest('normalizes \\r\\n to \\n', () {
      final a = EmbeddingService.computeContentSignature(
        ['line1\r\nline2'],
        modelName: _testModel,
        maxChunkChars: 2000,
        overlapChars: 200,
      );
      final b = EmbeddingService.computeContentSignature(
        ['line1\nline2'],
        modelName: _testModel,
        maxChunkChars: 2000,
        overlapChars: 200,
      );
      expect(a, equals(b));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  //  isNoteStale
  // ─────────────────────────────────────────────────────────────────────────

  group('isNoteStale', () {
    patrolTest('returns true when no embeddings exist', () async {
      final note = _makeNote(id: 1, title: 'New');
      expect(await service.isNoteStale(note), isTrue);
    });

    patrolTest('returns true when model version differs', () async {
      final note = _makeNote(id: 1, title: 'Note', contentJson: _quillJson('Body'));

      // Store embedding with a different model version
      final inputs = service.buildEmbeddingInputs(note);
      final sig = EmbeddingService.computeContentSignature(
        inputs,
        modelName: 'old-model',
        maxChunkChars: 2000,
        overlapChars: 200,
      );
      repo.seed([
        NoteEmbedding(
          noteId: 1,
          chunkIndex: 0,
          chunkText: 'Body',
          embeddingData: '0.1,0.2',
          modelVersion: 'old-model',
          contentSignature: sig,
          noteUpdatedAt: note.updatedAt,
        ),
      ]);

      expect(await service.isNoteStale(note), isTrue);
    });

    patrolTest('returns false when signature matches (same content)', () async {
      final note = _makeNote(id: 1, title: 'Stable', contentJson: _quillJson('Same content'));

      final inputs = service.buildEmbeddingInputs(note);
      final sig = EmbeddingService.computeContentSignature(
        inputs,
        modelName: _testModel,
        maxChunkChars: 2000,
        overlapChars: 200,
      );
      repo.seed([
        NoteEmbedding(
          noteId: 1,
          chunkIndex: 0,
          chunkText: 'Same content',
          embeddingData: '0.1,0.2',
          modelVersion: _testModel,
          contentSignature: sig,
          noteUpdatedAt: DateTime(2026, 1, 1), // old date — should not matter
        ),
      ]);

      expect(await service.isNoteStale(note), isFalse);
    });

    patrolTest('returns false when only updatedAt differs (signature match)', () async {
      final note = _makeNote(
        id: 1,
        title: 'Note',
        contentJson: _quillJson('Content'),
        updatedAt: DateTime(2026, 3, 20), // newer updatedAt
      );

      final inputs = service.buildEmbeddingInputs(note);
      final sig = EmbeddingService.computeContentSignature(
        inputs,
        modelName: _testModel,
        maxChunkChars: 2000,
        overlapChars: 200,
      );
      repo.seed([
        NoteEmbedding(
          noteId: 1,
          chunkIndex: 0,
          chunkText: 'Content',
          embeddingData: '0.1,0.2',
          modelVersion: _testModel,
          contentSignature: sig,
          noteUpdatedAt: DateTime(2026, 1, 1), // much older
        ),
      ]);

      // Should NOT be stale because content signature matches
      expect(await service.isNoteStale(note), isFalse);
    });

    patrolTest('returns true when content changes (signature mismatch)', () async {
      final note = _makeNote(id: 1, title: 'Note', contentJson: _quillJson('New content'));

      // Store embedding with a signature from OLD content
      final oldInputs = ['Title: Note\n\nOld content'];
      final oldSig = EmbeddingService.computeContentSignature(
        oldInputs,
        modelName: _testModel,
        maxChunkChars: 2000,
        overlapChars: 200,
      );
      repo.seed([
        NoteEmbedding(
          noteId: 1,
          chunkIndex: 0,
          chunkText: 'Old content',
          embeddingData: '0.1,0.2',
          modelVersion: _testModel,
          contentSignature: oldSig,
          noteUpdatedAt: note.updatedAt,
        ),
      ]);

      expect(await service.isNoteStale(note), isTrue);
    });

    patrolTest('returns true when title changes (signature mismatch)', () async {
      final note = _makeNote(id: 1, title: 'New Title', contentJson: _quillJson('Body'));

      // Store embedding with signature from OLD title
      final oldInputs = ['Title: Old Title\n\nBody'];
      final oldSig = EmbeddingService.computeContentSignature(
        oldInputs,
        modelName: _testModel,
        maxChunkChars: 2000,
        overlapChars: 200,
      );
      repo.seed([
        NoteEmbedding(
          noteId: 1,
          chunkIndex: 0,
          chunkText: 'Body',
          embeddingData: '0.1,0.2',
          modelVersion: _testModel,
          contentSignature: oldSig,
          noteUpdatedAt: note.updatedAt,
        ),
      ]);

      expect(await service.isNoteStale(note), isTrue);
    });

    // ─── Lazy fallback (empty contentSignature) ──────────────────────────

    patrolTest('lazy fallback: returns true when signature empty and updatedAt is newer', () async {
      final note = _makeNote(id: 1, title: 'Note', updatedAt: DateTime(2026, 3, 20));

      repo.seed([
        NoteEmbedding(
          noteId: 1,
          chunkIndex: 0,
          chunkText: 'text',
          embeddingData: '0.1,0.2',
          modelVersion: _testModel,
          contentSignature: '', // no signature
          noteUpdatedAt: DateTime(2026, 1, 1), // older
        ),
      ]);

      expect(await service.isNoteStale(note), isTrue);
    });

    patrolTest('lazy fallback: returns false when signature empty and updatedAt matches', () async {
      final timestamp = DateTime(2026, 3, 1);
      final note = _makeNote(id: 1, title: 'Note', updatedAt: timestamp);

      repo.seed([
        NoteEmbedding(
          noteId: 1,
          chunkIndex: 0,
          chunkText: 'text',
          embeddingData: '0.1,0.2',
          modelVersion: _testModel,
          contentSignature: '', // no signature
          noteUpdatedAt: timestamp, // same time
        ),
      ]);

      expect(await service.isNoteStale(note), isFalse);
    });
  });
}
