import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/repository/interfaces/folder_repository.dart';
import 'package:trovara/core/repository/interfaces/note_repository.dart';
import 'package:trovara/core/services/document_resolver_service.dart';
import 'package:trovara/core/services/note_service.dart';
import 'package:trovara/core/services/prompt_builder_service.dart';
import 'package:trovara/core/services/vector_search_service.dart';
import 'package:trovara/models/folder.dart';
import 'package:trovara/models/note.dart';
import 'package:trovara/models/note_embedding.dart';
import 'package:trovara/models/retrieved_document.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  Stubs
// ═══════════════════════════════════════════════════════════════════════════

class StubNoteRepository implements INoteRepository {
  final Map<int, Note> _notes = {};

  void seed(List<Note> notes) {
    for (final n in notes) {
      _notes[n.id] = n;
    }
  }

  @override
  Note? getNoteById(int id) => _notes[id];

  @override
  Note? getNoteBySync(String syncId) => _notes.values.where((n) => n.syncId == syncId).firstOrNull;

  // ─── unused ────────────────────────────────────────────────────────────
  @override
  Future<void> initialize() async {}
  @override
  List<Note> getActiveNotes() => [];
  @override
  List<Note> getActiveNotesForUser(String? userId) => [];
  @override
  List<Note> getAllNotes() => [];
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
    List<int>? customTagIds,
    String? userId,
  }) async => Note(title: '', contentJson: '');
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
    List<String>? moodTags,
    List<String>? activityTags,
    List<String>? timeTags,
    List<String>? personalGrowthTags,
  }) async => Note(title: '', contentJson: '');
  @override
  Future<void> updateNote(Note note, {bool preserveTimestamps = false}) async {}
  @override
  Future<void> deleteNote(int id) async {}
  @override
  int get totalNotes => 0;
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

  void seed(List<Folder> folders) {
    for (final f in folders) {
      _folders[f.folderId] = f;
    }
  }

  @override
  Folder? getFolderById(String folderId) => _folders[folderId];

  // ─── unused ────────────────────────────────────────────────────────────
  @override
  Future<void> initialize() async {}
  @override
  List<Folder> getAllFolders() => [];
  @override
  Future<Folder> createFolder({required String name, String? description, String? color}) async =>
      Folder(folderId: '', name: '');
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
  }) async => Folder(folderId: '', name: '');
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
//  Test Helpers
// ═══════════════════════════════════════════════════════════════════════════

Note _makeNote({
  required int id,
  required String title,
  String folderId = 'default',
  List<String> moodTags = const [],
  List<String> activityTags = const [],
  List<String> timeTags = const [],
  List<String> personalGrowthTags = const [],
  bool isDeleted = false,
  DateTime? createdAt,
}) => Note(
  title: title,
  contentJson: '[]',
  folderId: folderId,
  moodTags: moodTags,
  activityTags: activityTags,
  timeTags: timeTags,
  personalGrowthTags: personalGrowthTags,
  isDeleted: isDeleted,
  createdAt: createdAt ?? DateTime(2026, 2, 20),
)..id = id;

ScoredEmbedding _makeChunk({
  required int noteId,
  int chunkIndex = 0,
  String chunkText = 'Some chunk text',
  double score = 0.85,
}) => ScoredEmbedding(
  embedding: NoteEmbedding(
    noteId: noteId,
    chunkIndex: chunkIndex,
    chunkText: chunkText,
    embeddingData: '0.1,0.2,0.3',
    modelVersion: 'test',
    noteUpdatedAt: DateTime(2026, 2, 20),
  ),
  score: score,
);

// ═══════════════════════════════════════════════════════════════════════════
//  Tests
// ═══════════════════════════════════════════════════════════════════════════

void main() {
  late StubNoteRepository noteRepo;
  late StubFolderRepository folderRepo;
  late NoteService noteService;
  late DocumentResolverService resolver;
  late PromptBuilderService promptBuilder;

  setUp(() {
    noteRepo = StubNoteRepository();
    folderRepo = StubFolderRepository();
    noteService = NoteService(noteRepository: noteRepo, folderRepository: folderRepo);
    resolver = DocumentResolverService(noteService: noteService);
    promptBuilder = PromptBuilderService(documentResolver: resolver);
  });

  // ─────────────────────────────────────────────────────────────────────────
  //  buildFromDocuments
  // ─────────────────────────────────────────────────────────────────────────

  group('buildFromDocuments', () {
    test('returns null for empty document list', () {
      final result = promptBuilder.buildFromDocuments(userQuery: 'What about meditation?', documents: []);
      expect(result, isNull);
    });

    test('includes system prompt', () {
      final note = _makeNote(id: 1, title: 'Morning');
      noteRepo.seed([note]);

      final doc = RetrievedDocument(
        note: note,
        relevantChunks: [_makeChunk(noteId: 1, chunkText: 'Meditated today')],
        maxScore: 0.9,
      );

      final prompt = promptBuilder.buildFromDocuments(userQuery: 'meditation?', documents: [doc])!;

      expect(prompt, contains(PromptBuilderService.systemPrompt));
    });

    test('includes context delimiters', () {
      final note = _makeNote(id: 1, title: 'Note A');
      noteRepo.seed([note]);

      final doc = RetrievedDocument(note: note, relevantChunks: [_makeChunk(noteId: 1)], maxScore: 0.9);

      final prompt = promptBuilder.buildFromDocuments(userQuery: 'test', documents: [doc])!;

      expect(prompt, contains("USER'S NOTES (most relevant)"));
      expect(prompt, contains('END OF NOTES'));
    });

    test('includes note title, date, and folder', () {
      final note = _makeNote(id: 1, title: 'Morning Reflection', folderId: 'journal', createdAt: DateTime(2026, 2, 20));
      noteRepo.seed([note]);

      final doc = RetrievedDocument(note: note, relevantChunks: [_makeChunk(noteId: 1)], maxScore: 0.9);

      final prompt = promptBuilder.buildFromDocuments(userQuery: 'test', documents: [doc])!;

      expect(prompt, contains('Title: Morning Reflection'));
      expect(prompt, contains('Date: 2026-02-20'));
      expect(prompt, contains('Folder: journal'));
    });

    test('includes mood, activity, time, and growth tags', () {
      final note = _makeNote(
        id: 1,
        title: 'Tagged Note',
        moodTags: ['happy', 'grateful'],
        activityTags: ['meditation'],
        timeTags: ['morning'],
        personalGrowthTags: ['mindfulness'],
      );
      noteRepo.seed([note]);

      final doc = RetrievedDocument(note: note, relevantChunks: [_makeChunk(noteId: 1)], maxScore: 0.9);

      final prompt = promptBuilder.buildFromDocuments(userQuery: 'tags?', documents: [doc])!;

      expect(prompt, contains('mood: happy, grateful'));
      expect(prompt, contains('activity: meditation'));
      expect(prompt, contains('time: morning'));
      expect(prompt, contains('growth: mindfulness'));
    });

    test('omits Tags line when note has no tags', () {
      final note = _makeNote(id: 1, title: 'No Tags');
      noteRepo.seed([note]);

      final doc = RetrievedDocument(note: note, relevantChunks: [_makeChunk(noteId: 1)], maxScore: 0.9);

      final prompt = promptBuilder.buildFromDocuments(userQuery: 'test', documents: [doc])!;

      expect(prompt, isNot(contains('Tags:')));
    });

    test('includes combined chunk text as content', () {
      final note = _makeNote(id: 1, title: 'Multi-chunk');
      noteRepo.seed([note]);

      final doc = RetrievedDocument(
        note: note,
        relevantChunks: [
          _makeChunk(noteId: 1, chunkIndex: 0, chunkText: 'First chunk'),
          _makeChunk(noteId: 1, chunkIndex: 1, chunkText: 'Second chunk'),
        ],
        maxScore: 0.9,
      );

      final prompt = promptBuilder.buildFromDocuments(userQuery: 'test', documents: [doc])!;

      expect(prompt, contains('Content:'));
      expect(prompt, contains('First chunk'));
      expect(prompt, contains('Second chunk'));
    });

    test('includes user question at the end', () {
      final note = _makeNote(id: 1, title: 'Note');
      noteRepo.seed([note]);

      final doc = RetrievedDocument(note: note, relevantChunks: [_makeChunk(noteId: 1)], maxScore: 0.9);

      final prompt = promptBuilder.buildFromDocuments(
        userQuery: 'What did I write about meditation?',
        documents: [doc],
      )!;

      expect(prompt, contains('User question: What did I write about meditation?'));
    });

    test('numbers multiple notes sequentially', () {
      final noteA = _makeNote(id: 1, title: 'Alpha');
      final noteB = _makeNote(id: 2, title: 'Beta');
      noteRepo.seed([noteA, noteB]);

      final docs = [
        RetrievedDocument(note: noteA, relevantChunks: [_makeChunk(noteId: 1)], maxScore: 0.95),
        RetrievedDocument(note: noteB, relevantChunks: [_makeChunk(noteId: 2)], maxScore: 0.85),
      ];

      final prompt = promptBuilder.buildFromDocuments(userQuery: 'test', documents: docs)!;

      expect(prompt, contains('[Note 1]'));
      expect(prompt, contains('[Note 2]'));
    });

    test('prompt structure has correct ordering', () {
      final note = _makeNote(id: 1, title: 'Ordering Test');
      noteRepo.seed([note]);

      final doc = RetrievedDocument(
        note: note,
        relevantChunks: [_makeChunk(noteId: 1, chunkText: 'content here')],
        maxScore: 0.9,
      );

      final prompt = promptBuilder.buildFromDocuments(userQuery: 'my question', documents: [doc])!;

      // Verify ordering: system → context header → note → footer → question
      final systemIdx = prompt.indexOf('You are a helpful assistant');
      final headerIdx = prompt.indexOf("USER'S NOTES");
      final noteIdx = prompt.indexOf('[Note 1]');
      final footerIdx = prompt.indexOf('END OF NOTES');
      final questionIdx = prompt.indexOf('User question:');

      expect(systemIdx, lessThan(headerIdx));
      expect(headerIdx, lessThan(noteIdx));
      expect(noteIdx, lessThan(footerIdx));
      expect(footerIdx, lessThan(questionIdx));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  //  buildFromChunks
  // ─────────────────────────────────────────────────────────────────────────

  group('buildFromChunks', () {
    test('returns null for empty scored chunks', () {
      final result = promptBuilder.buildFromChunks(userQuery: 'test', scoredChunks: []);
      expect(result, isNull);
    });

    test('returns null when all notes are deleted', () {
      final deletedNote = _makeNote(id: 1, title: 'Deleted', isDeleted: true);
      noteRepo.seed([deletedNote]);

      final result = promptBuilder.buildFromChunks(userQuery: 'test', scoredChunks: [_makeChunk(noteId: 1)]);
      expect(result, isNull);
    });

    test('resolves chunks and builds prompt end-to-end', () {
      final note = _makeNote(id: 1, title: 'End to End');
      noteRepo.seed([note]);

      final prompt = promptBuilder.buildFromChunks(
        userQuery: 'meditation tips?',
        scoredChunks: [_makeChunk(noteId: 1, chunkText: 'Breathe deeply')],
      )!;

      expect(prompt, contains('End to End'));
      expect(prompt, contains('Breathe deeply'));
      expect(prompt, contains('User question: meditation tips?'));
    });

    test('respects maxNotes parameter', () {
      final notes = List.generate(10, (i) => _makeNote(id: i + 1, title: 'Note ${i + 1}'));
      noteRepo.seed(notes);

      final chunks = notes.map((n) => _makeChunk(noteId: n.id, score: 0.9 - n.id * 0.01)).toList();

      final prompt = promptBuilder.buildFromChunks(userQuery: 'test', scoredChunks: chunks, maxNotes: 3)!;

      // Should only include 3 note blocks
      expect('[Note 1]'.allMatches(prompt).length, equals(1));
      expect('[Note 2]'.allMatches(prompt).length, equals(1));
      expect('[Note 3]'.allMatches(prompt).length, equals(1));
      expect(prompt, isNot(contains('[Note 4]')));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  //  estimateTokenCount
  // ─────────────────────────────────────────────────────────────────────────

  group('estimateTokenCount', () {
    test('estimates ~4 chars per token', () {
      final prompt = 'a' * 400;
      expect(PromptBuilderService.estimateTokenCount(prompt), equals(100));
    });

    test('rounds up for non-exact division', () {
      final prompt = 'a' * 401;
      expect(PromptBuilderService.estimateTokenCount(prompt), equals(101));
    });

    test('returns 0 for empty string', () {
      expect(PromptBuilderService.estimateTokenCount(''), equals(0));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  //  extractSourceTitles
  // ─────────────────────────────────────────────────────────────────────────

  group('extractSourceTitles', () {
    test('returns titles in ranked order', () {
      final noteA = _makeNote(id: 1, title: 'Lower Score');
      final noteB = _makeNote(id: 2, title: 'Higher Score');
      noteRepo.seed([noteA, noteB]);

      final chunks = [_makeChunk(noteId: 1, score: 0.5), _makeChunk(noteId: 2, score: 0.9)];

      final titles = promptBuilder.extractSourceTitles(scoredChunks: chunks);

      expect(titles, equals(['Higher Score', 'Lower Score']));
    });

    test('respects maxNotes for titles', () {
      final notes = List.generate(5, (i) => _makeNote(id: i + 1, title: 'N${i + 1}'));
      noteRepo.seed(notes);

      final chunks = notes.map((n) => _makeChunk(noteId: n.id)).toList();

      final titles = promptBuilder.extractSourceTitles(scoredChunks: chunks, maxNotes: 2);

      expect(titles.length, equals(2));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  //  System prompt
  // ─────────────────────────────────────────────────────────────────────────

  group('systemPrompt', () {
    test('mentions Trovara by name', () {
      expect(PromptBuilderService.systemPrompt, contains('Trovara'));
    });

    test('instructs to answer only from notes', () {
      expect(PromptBuilderService.systemPrompt, contains('Answer ONLY based on the provided note context'));
    });

    test('includes fallback instruction', () {
      expect(PromptBuilderService.systemPrompt, contains("I couldn't find relevant information"));
    });
  });
}
