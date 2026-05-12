import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/repository/interfaces/folder_repository.dart';
import 'package:trovara/core/repository/interfaces/note_repository.dart';
import 'package:trovara/core/services/ai/document_resolver_service.dart';
import 'package:trovara/core/services/ai/vector_search_service.dart';
import 'package:trovara/core/services/notes/note_service.dart';
import 'package:trovara/models/folder.dart';
import 'package:trovara/models/note.dart';
import 'package:trovara/models/note_embedding.dart';
import '../test_support.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  Minimal stubs for NoteService dependencies
// ═══════════════════════════════════════════════════════════════════════════

class StubNoteRepository implements INoteRepository {
  final Map<int, Note> _notes = {};

  void addNote(Note note) => _notes[note.id] = note;

  @override
  Note? getNoteById(int id) => _notes[id];

  @override
  Note? getNoteBySync(String syncId) => _notes.values.where((n) => n.syncId == syncId).firstOrNull;

  @override
  Future<void> initialize() async {}

  // ─── Unused stubs ───
  @override
  List<Note> getActiveNotes() => _notes.values.where((n) => !n.isDeleted).toList();
  @override
  List<Note> getActiveNotesForUser(String? userId) => getActiveNotes();
  @override
  List<Note> getAllNotes() => _notes.values.toList();
  @override
  List<Note> searchNotes(String query) => [];
  @override
  List<Note> searchNotesForUser(String? userId, String query) => [];
  @override
  List<Note> getNotesByFolder(String folderId) => [];
  @override
  List<Note> getNotesByFolderForUser(String? userId, String folderId) => [];
  @override
  List<Note> getFavoriteNotes() => [];
  @override
  List<Note> getFavoriteNotesForUser(String? userId) => [];
  @override
  List<Note> getArchivedNotes() => [];
  @override
  List<Note> getArchivedNotesForUser(String? userId) => [];
  @override
  List<Note> getNotesByTag(String tag) => [];
  @override
  List<String> getAllTags() => [];
  @override
  List<Note> getDeletedNotes() => [];
  @override
  List<Note> getDeletedNotesForUser(String? userId) => [];
  @override
  Future<Note> createNote({
    String? title,
    String? contentJson,
    String? folderId,
    List<int> customTagIds = const [],
    String? userId,
  }) => throw UnimplementedError();
  @override
  Future<Note> createNoteWithTimestamps({
    String? syncId,
    String? title,
    String? contentJson,
    String? folderId,
    List<int> customTagIds = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
    bool isFavorite = false,
    bool isArchived = false,
    bool isDeleted = false,
    DateTime? deletedAt,
    String? userId,
    String? driveFileId,
    List<String>? moodTags,
    List<String>? activityTags,
    List<String>? timeTags,
    List<String>? personalGrowthTags,
  }) => throw UnimplementedError();
  @override
  Future<void> updateNote(Note note, {bool preserveTimestamps = false}) async {}
  @override
  Future<void> deleteNote(int id) async {}
  @override
  int get totalNotes => _notes.length;
  @override
  int get totalWords => 0;
  @override
  int get totalCharacters => 0;
  @override
  void addListener(Function() listener) {}
  @override
  void removeListener(Function() listener) {}
  @override
  void dispose() {}
}

class StubFolderRepository implements IFolderRepository {
  final Map<String, Folder> _folders = {};

  void addFolder(Folder folder) => _folders[folder.folderId] = folder;

  @override
  Folder? getFolderById(String folderId) => _folders[folderId];

  @override
  Future<void> initialize() async {}

  // ─── Unused stubs ───
  @override
  List<Folder> getAllFolders() => _folders.values.toList();
  @override
  Future<Folder> createFolder({required String name, String? description, String? color}) => throw UnimplementedError();
  @override
  Future<Folder> createFolderWithTimestamps({
    required String folderId,
    required String name,
    String? description,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool isDefault = false,
    int noteCount = 0,
  }) => throw UnimplementedError();
  @override
  Future<void> updateFolder(Folder folder) async {}
  @override
  Future<void> deleteFolder(String folderId) async {}
  @override
  Folder? getDefaultFolder() => null;
  @override
  void addListener(Function() listener) {}
  @override
  void removeListener(Function() listener) {}
  @override
  void dispose() {}
}

// ═══════════════════════════════════════════════════════════════════════════
//  Test helpers
// ═══════════════════════════════════════════════════════════════════════════

ScoredEmbedding _scored({
  required int noteId,
  int chunkIndex = 0,
  required double score,
  String chunkText = 'chunk text',
}) => ScoredEmbedding(
  embedding: NoteEmbedding(
    noteId: noteId,
    chunkIndex: chunkIndex,
    chunkText: chunkText,
    embeddingData: NoteEmbedding.serializeEmbedding([0.1, 0.2, 0.3]),
    modelVersion: 'text-embedding-004',
    noteUpdatedAt: DateTime.now(),
  ),
  score: score,
);

Note _note({
  required int id,
  String title = 'Test Note',
  bool isDeleted = false,
  String folderId = 'default',
  List<String>? moodTags,
  List<String>? activityTags,
}) {
  final note = Note(
    title: title,
    contentJson: '[{"insert":"test content\\n"}]',
    folderId: folderId,
    isDeleted: isDeleted,
    moodTags: moodTags,
    activityTags: activityTags,
  );
  note.id = id;
  return note;
}

// ═══════════════════════════════════════════════════════════════════════════
//  Tests
// ═══════════════════════════════════════════════════════════════════════════

void main() {
  group('DocumentResolverService', () {
    late StubNoteRepository noteRepo;
    late StubFolderRepository folderRepo;
    late NoteService noteService;
    late DocumentResolverService resolver;

    setUp(() {
      noteRepo = StubNoteRepository();
      folderRepo = StubFolderRepository();
      noteService = NoteService(noteRepository: noteRepo, folderRepository: folderRepo);
      resolver = DocumentResolverService(noteService: noteService);
    });

    group('resolve', () {
      patrolTest('returns empty list for empty input', ($) async {
        final result = resolver.resolve([]);
        expect(result, isEmpty);
      });

      patrolTest('resolves a single chunk to a single document', ($) async {
        noteRepo.addNote(_note(id: 1, title: 'My Note'));

        final result = resolver.resolve([_scored(noteId: 1, score: 0.85)]);

        expect(result.length, 1);
        expect(result.first.note.id, 1);
        expect(result.first.note.title, 'My Note');
        expect(result.first.maxScore, closeTo(0.85, 0.001));
        expect(result.first.matchedChunkCount, 1);
      });

      patrolTest('groups multiple chunks from the same note', ($) async {
        noteRepo.addNote(_note(id: 1));

        final result = resolver.resolve([
          _scored(noteId: 1, chunkIndex: 0, score: 0.9, chunkText: 'chunk 0'),
          _scored(noteId: 1, chunkIndex: 1, score: 0.7, chunkText: 'chunk 1'),
        ]);

        expect(result.length, 1);
        expect(result.first.matchedChunkCount, 2);
        expect(result.first.maxScore, closeTo(0.9, 0.001));
        // Chunks in reading order
        expect(result.first.relevantChunks[0].embedding.chunkIndex, 0);
        expect(result.first.relevantChunks[1].embedding.chunkIndex, 1);
      });

      patrolTest('ranks documents by max score descending', ($) async {
        noteRepo.addNote(_note(id: 1, title: 'Low'));
        noteRepo.addNote(_note(id: 2, title: 'High'));
        noteRepo.addNote(_note(id: 3, title: 'Mid'));

        final result = resolver.resolve([
          _scored(noteId: 1, score: 0.3),
          _scored(noteId: 2, score: 0.95),
          _scored(noteId: 3, score: 0.6),
        ]);

        expect(result.length, 3);
        expect(result[0].note.id, 2);
        expect(result[1].note.id, 3);
        expect(result[2].note.id, 1);
      });

      patrolTest('filters out deleted notes', ($) async {
        noteRepo.addNote(_note(id: 1, isDeleted: true));
        noteRepo.addNote(_note(id: 2));

        final result = resolver.resolve([_scored(noteId: 1, score: 0.9), _scored(noteId: 2, score: 0.8)]);

        expect(result.length, 1);
        expect(result.first.note.id, 2);
      });

      patrolTest('filters out missing notes', ($) async {
        noteRepo.addNote(_note(id: 1));

        final result = resolver.resolve([_scored(noteId: 1, score: 0.8), _scored(noteId: 99, score: 0.95)]);

        expect(result.length, 1);
        expect(result.first.note.id, 1);
      });

      patrolTest('respects topN limit', ($) async {
        for (int i = 1; i <= 10; i++) {
          noteRepo.addNote(_note(id: i, title: 'Note $i'));
        }

        final chunks = List.generate(10, (i) => _scored(noteId: i + 1, score: 1.0 - i * 0.05));

        final result = resolver.resolve(chunks, topN: 3);

        expect(result.length, 3);
        expect(result[0].note.id, 1);
        expect(result[1].note.id, 2);
        expect(result[2].note.id, 3);
      });

      patrolTest('trims by maxTextLength', ($) async {
        noteRepo.addNote(_note(id: 1));
        noteRepo.addNote(_note(id: 2));

        final longText = 'x' * 5000;
        final result = resolver.resolve([
          _scored(noteId: 1, score: 0.9, chunkText: longText),
          _scored(noteId: 2, score: 0.8, chunkText: longText),
        ], maxTextLength: 6000);

        expect(result.length, 1);
        expect(result.first.note.id, 1);
      });

      patrolTest('always includes at least one document even if it exceeds maxTextLength', ($) async {
        noteRepo.addNote(_note(id: 1));

        final longText = 'x' * 10000;
        final result = resolver.resolve([_scored(noteId: 1, score: 0.9, chunkText: longText)], maxTextLength: 100);

        expect(result.length, 1);
      });

      patrolTest('uses max score when note has chunks with varying scores', ($) async {
        noteRepo.addNote(_note(id: 1));

        final result = resolver.resolve([
          _scored(noteId: 1, chunkIndex: 0, score: 0.4),
          _scored(noteId: 1, chunkIndex: 1, score: 0.9),
          _scored(noteId: 1, chunkIndex: 2, score: 0.6),
        ]);

        expect(result.first.maxScore, closeTo(0.9, 0.001));
      });
    });

    group('RetrievedDocument', () {
      patrolTest('combinedText joins chunks with double newline', ($) async {
        noteRepo.addNote(_note(id: 1));

        final result = resolver.resolve([
          _scored(noteId: 1, chunkIndex: 0, score: 0.9, chunkText: 'Hello'),
          _scored(noteId: 1, chunkIndex: 1, score: 0.8, chunkText: 'World'),
        ]);

        expect(result.first.combinedText, 'Hello\n\nWorld');
      });

      patrolTest('avgScore is computed correctly', ($) async {
        noteRepo.addNote(_note(id: 1));

        final result = resolver.resolve([
          _scored(noteId: 1, chunkIndex: 0, score: 0.8),
          _scored(noteId: 1, chunkIndex: 1, score: 0.6),
        ]);

        expect(result.first.avgScore, closeTo(0.7, 0.001));
      });
    });

    group('resolveToTitles', () {
      patrolTest('returns note titles in ranked order', ($) async {
        noteRepo.addNote(_note(id: 1, title: 'Alpha'));
        noteRepo.addNote(_note(id: 2, title: 'Beta'));

        final titles = resolver.resolveToTitles([_scored(noteId: 1, score: 0.5), _scored(noteId: 2, score: 0.9)]);

        expect(titles, ['Beta', 'Alpha']);
      });
    });

    group('resolveToContextMaps', () {
      patrolTest('returns context maps with metadata', ($) async {
        noteRepo.addNote(
          _note(id: 1, title: 'Morning Walk', folderId: 'journal', moodTags: ['happy'], activityTags: ['walking']),
        );
        folderRepo.addFolder(Folder(folderId: 'journal', name: 'Journal'));

        final maps = resolver.resolveToContextMaps([_scored(noteId: 1, score: 0.9, chunkText: 'Went for a walk')]);

        expect(maps.length, 1);
        expect(maps.first['title'], 'Morning Walk');
        expect(maps.first['folder'], 'Journal');
        expect(maps.first['tags'], contains('mood: happy'));
        expect(maps.first['tags'], contains('activity: walking'));
        expect(maps.first['text'], 'Went for a walk');
      });

      patrolTest('defaults folder name to Default when folder not found', ($) async {
        noteRepo.addNote(_note(id: 1, folderId: 'missing'));

        final maps = resolver.resolveToContextMaps([_scored(noteId: 1, score: 0.9)]);

        expect(maps.first['folder'], 'Default');
      });
    });

    group('resolveTopChunksToContext', () {
      patrolTest('fills topKChunks after filtering missing/deleted notes', ($) async {
        noteRepo.addNote(_note(id: 1, title: 'Deleted', isDeleted: true));
        noteRepo.addNote(_note(id: 2, title: 'Live A'));
        noteRepo.addNote(_note(id: 3, title: 'Live B'));
        noteRepo.addNote(_note(id: 4, title: 'Live C'));

        final chunks = [
          // These would previously consume the window and hide valid chunks later.
          _scored(noteId: 999, score: 0.99, chunkText: 'missing note'),
          _scored(noteId: 1, score: 0.98, chunkText: 'deleted note'),
          _scored(noteId: 998, score: 0.97, chunkText: 'missing note 2'),
          // Valid chunks later in the ranked list.
          _scored(noteId: 2, score: 0.50, chunkText: 'A1'),
          _scored(noteId: 3, score: 0.49, chunkText: 'B1'),
          _scored(noteId: 4, score: 0.48, chunkText: 'C1'),
        ];

        final ctx = resolver.resolveTopChunksToContext(chunks, topKChunks: 3);

        expect(ctx.length, 3);
        expect(ctx[0]['title'], 'Live A');
        expect(ctx[0]['text'], 'A1');
        expect(ctx[1]['title'], 'Live B');
        expect(ctx[2]['title'], 'Live C');
      });
    });
  });
}
