import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/repository/interfaces/embedding_repository.dart';
import 'package:trovara/core/repository/interfaces/folder_repository.dart';
import 'package:trovara/core/repository/interfaces/note_repository.dart';
import 'package:trovara/core/services/ai/document_resolver_service.dart';
import 'package:trovara/core/services/ai/embedding_service.dart';
import 'package:trovara/core/services/ai/llm_client.dart';
import 'package:trovara/core/services/ai/multi_query_expansion_service.dart';
import 'package:trovara/core/services/ai/prompt_builder_service.dart';
import 'package:trovara/core/services/ai/query_rewrite_service.dart';
import 'package:trovara/core/services/ai/rag_chat_memory.dart';
import 'package:trovara/core/services/ai/rag_service.dart';
import 'package:trovara/core/services/ai/retrieval_depth.dart';
import 'package:trovara/core/services/ai/vector_search_service.dart';
import 'package:trovara/core/services/notes/note_service.dart';
import 'package:trovara/models/folder.dart';
import 'package:trovara/models/note.dart';
import 'package:trovara/models/note_embedding.dart';
import '../test_support.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  Stubs — lightweight implementations for testing without ObjectBox or API
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

/// An embedding repository that stores embeddings in memory.
class StubEmbeddingRepository implements IEmbeddingRepository {
  final List<NoteEmbedding> _embeddings = [];

  void seed(List<NoteEmbedding> embeddings) {
    _embeddings.addAll(embeddings);
  }

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

/// A fake EmbeddingService that returns a fixed vector for queries
/// without calling the Gemini API.
class FakeEmbeddingService extends EmbeddingService {
  final List<double>? _queryVector;

  FakeEmbeddingService({required super.embeddingRepository, List<double>? queryVector})
    : _queryVector = queryVector,
      super(apiKey: 'fake-key');

  @override
  bool get isAvailable => true;

  @override
  Future<List<double>?> embedQuery(String query) async => _queryVector;
}

/// A fake EmbeddingService that simulates being unavailable (no API key).
class UnavailableEmbeddingService extends EmbeddingService {
  UnavailableEmbeddingService({required super.embeddingRepository}) : super(apiKey: '');

  @override
  bool get isAvailable => false;

  @override
  Future<List<double>?> embedQuery(String query) async => null;
}

/// A fake LlmClient that returns a fixed response without calling the API.
///
/// Extends [LlmClient] so it can be passed directly to [RagService].
/// Overrides [isAvailable], [generate], and [generateStream] to bypass
/// the real Gemini API.
class FakeLlmClient extends LlmClient {
  final String _fakeResponse;
  final bool _shouldThrow;
  bool generateCalled = false;
  String? lastPrompt;
  List<LlmChatMessage>? lastHistory;

  FakeLlmClient({String response = 'Test answer', bool shouldThrow = false})
    : _fakeResponse = response,
      _shouldThrow = shouldThrow,
      super(apiKey: 'fake-key');

  @override
  bool get isAvailable => true;

  @override
  Future<String> generate(String prompt) =>
      generateWithMessages(systemPrompt: '', history: const [], userMessage: prompt);

  @override
  Future<String> generateWithMessages({
    required String systemPrompt,
    required List<LlmChatMessage> history,
    required String userMessage,
  }) async {
    generateCalled = true;
    lastHistory = List<LlmChatMessage>.from(history);
    lastPrompt = userMessage;
    if (_shouldThrow) throw Exception('LLM API error');
    return _fakeResponse;
  }

  @override
  Stream<String> generateStream(String prompt) =>
      generateStreamWithMessages(systemPrompt: '', history: const [], userMessage: prompt);

  @override
  Stream<String> generateStreamWithMessages({
    required String systemPrompt,
    required List<LlmChatMessage> history,
    required String userMessage,
  }) async* {
    lastHistory = List<LlmChatMessage>.from(history);
    lastPrompt = userMessage;
    if (_shouldThrow) throw Exception('LLM streaming error');
    final words = _fakeResponse.split(' ');
    for (final word in words) {
      yield '$word ';
    }
  }
}

class FakeQueryRewriteService extends QueryRewriteService {
  final String Function(String) _fn;
  int calls = 0;
  String? lastConversationContext;

  FakeQueryRewriteService({required String Function(String) rewriteFn})
    : _fn = rewriteFn,
      super(llmClient: FakeLlmClient());

  @override
  Future<String> rewrite(String userQuery, {String? conversationContext}) async {
    calls++;
    lastConversationContext = conversationContext;
    return _fn(userQuery);
  }
}

class FakeMultiQueryExpansionService extends MultiQueryExpansionService {
  final List<String> Function(String) _fn;
  int calls = 0;
  FakeMultiQueryExpansionService({required List<String> Function(String) expandFn})
    : _fn = expandFn,
      super(llmClient: FakeLlmClient());

  @override
  Future<List<String>> expand(String rewrittenQuery, {int count = 3}) async {
    calls++;
    return _fn(rewrittenQuery);
  }
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
  bool isDeleted = false,
  DateTime? createdAt,
}) => Note(
  title: title,
  contentJson: '[]',
  folderId: folderId,
  moodTags: moodTags,
  activityTags: activityTags,
  isDeleted: isDeleted,
  createdAt: createdAt ?? DateTime(2026, 2, 20),
)..id = id;

NoteEmbedding _makeEmbedding({
  required int noteId,
  int chunkIndex = 0,
  String chunkText = 'Some chunk text',
  List<double> vector = const [0.5, 0.5, 0.5],
}) => NoteEmbedding(
  noteId: noteId,
  chunkIndex: chunkIndex,
  chunkText: chunkText,
  embeddingData: NoteEmbedding.serializeEmbedding(vector),
  modelVersion: 'test',
  noteUpdatedAt: DateTime(2026, 2, 20),
);

/// Build a RagService wired with test stubs.
///
/// The [queryVector] is what the fake embedding service returns for any query.
/// The [llmResponse] is what the fake LLM returns.
/// Returns the service along with the fake LLM client for assertions.
({RagService service, FakeLlmClient llm, FakeQueryRewriteService rewrite, FakeMultiQueryExpansionService expand})
_buildRagService({
  required StubNoteRepository noteRepo,
  required StubFolderRepository folderRepo,
  required StubEmbeddingRepository embeddingRepo,
  List<double>? queryVector,
  String llmResponse = 'Test answer from the LLM.',
  bool llmShouldThrow = false,
}) {
  final embeddingService = FakeEmbeddingService(embeddingRepository: embeddingRepo, queryVector: queryVector);
  final vectorSearch = VectorSearchService(repository: embeddingRepo);
  final noteService = NoteService(noteRepository: noteRepo, folderRepository: folderRepo);
  final docResolver = DocumentResolverService(noteService: noteService);
  final promptBuilder = PromptBuilderService(documentResolver: docResolver);

  final fakeLlm = FakeLlmClient(response: llmResponse, shouldThrow: llmShouldThrow);
  final rewrite = FakeQueryRewriteService(rewriteFn: (q) => q);
  final expand = FakeMultiQueryExpansionService(expandFn: (q) => [q]);

  final service = RagService(
    embeddingService: embeddingService,
    vectorSearchService: vectorSearch,
    documentResolverService: docResolver,
    promptBuilderService: promptBuilder,
    llmClient: fakeLlm,
    queryRewriteService: rewrite,
    multiQueryExpansionService: expand,
  );

  return (service: service, llm: fakeLlm, rewrite: rewrite, expand: expand);
}

// ═══════════════════════════════════════════════════════════════════════════
//  Tests
// ═══════════════════════════════════════════════════════════════════════════

void main() {
  late StubNoteRepository noteRepo;
  late StubFolderRepository folderRepo;
  late StubEmbeddingRepository embeddingRepo;

  setUp(() {
    noteRepo = StubNoteRepository();
    folderRepo = StubFolderRepository();
    embeddingRepo = StubEmbeddingRepository();
  });

  // ─────────────────────────────────────────────────────────────────────────
  //  RagResult model
  // ─────────────────────────────────────────────────────────────────────────

  group('RagResult', () {
    patrolTest('stores answer and source titles', ($) async {
      final result = RagResult(
        answer: 'The answer',
        sourceNoteTitles: ['Note A', 'Note B'],
        prompt: 'the prompt',
        matchedChunks: 3,
      );

      expect(result.answer, equals('The answer'));
      expect(result.sourceNoteTitles, equals(['Note A', 'Note B']));
      expect(result.matchedChunks, equals(3));
    });

    patrolTest('toString includes summary info', ($) async {
      final result = RagResult(answer: 'a' * 100, sourceNoteTitles: ['A', 'B'], prompt: '', matchedChunks: 5);

      final str = result.toString();
      expect(str, contains('sources: 2'));
      expect(str, contains('chunks: 5'));
      expect(str, contains('100 chars'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  //  RagService.query — full pipeline
  // ─────────────────────────────────────────────────────────────────────────

  group('RagService.query', () {
    patrolTest('returns error when embedding fails', ($) async {
      final note = _makeNote(id: 1, title: 'Seed');
      noteRepo.seed([note]);
      embeddingRepo.seed([
        _makeEmbedding(noteId: 1, vector: [0.5, 0.5, 0.5]),
      ]);

      final (:service, :llm, rewrite: _, expand: _) = _buildRagService(
        noteRepo: noteRepo,
        folderRepo: folderRepo,
        embeddingRepo: embeddingRepo,
        queryVector: null, // simulate embedding failure
      );

      final result = await service.query('test question');

      expect(result.answer, contains('unable to process'));
      expect(result.sourceNoteTitles, isEmpty);
      expect(result.matchedChunks, equals(0));
      expect(llm.generateCalled, isFalse);
    });

    patrolTest('returns message when no chunks match', ($) async {
      // No embeddings in repository → search returns empty
      final (:service, :llm, rewrite: _, expand: _) = _buildRagService(
        noteRepo: noteRepo,
        folderRepo: folderRepo,
        embeddingRepo: embeddingRepo,
        queryVector: [0.5, 0.5, 0.5],
      );

      final result = await service.query('test question');

      expect(result.answer, contains("haven't been indexed"));
      expect(result.matchedChunks, equals(0));
      expect(llm.generateCalled, isFalse);
    });

    patrolTest('returns message when notes are all deleted', ($) async {
      final deletedNote = _makeNote(id: 1, title: 'Deleted', isDeleted: true);
      noteRepo.seed([deletedNote]);
      embeddingRepo.seed([
        _makeEmbedding(noteId: 1, vector: [0.5, 0.5, 0.5]),
      ]);

      final (:service, :llm, rewrite: _, expand: _) = _buildRagService(
        noteRepo: noteRepo,
        folderRepo: folderRepo,
        embeddingRepo: embeddingRepo,
        queryVector: [0.5, 0.5, 0.5],
      );

      final result = await service.query('test question');

      expect(result.answer, contains("couldn't find"));
      expect(llm.generateCalled, isFalse);
    });

    patrolTest('full pipeline produces answer with sources', ($) async {
      final note = _makeNote(id: 1, title: 'Morning Meditation');
      noteRepo.seed([note]);
      embeddingRepo.seed([
        _makeEmbedding(noteId: 1, chunkText: 'Meditated for 20 minutes', vector: [0.5, 0.5, 0.5]),
      ]);

      final (:service, :llm, rewrite: _, expand: _) = _buildRagService(
        noteRepo: noteRepo,
        folderRepo: folderRepo,
        embeddingRepo: embeddingRepo,
        queryVector: [0.5, 0.5, 0.5],
        llmResponse: 'You meditated for 20 minutes.',
      );

      final result = await service.query('meditation?');

      expect(result.answer, equals('You meditated for 20 minutes.'));
      expect(result.sourceNoteTitles, contains('Morning Meditation'));
      expect(result.matchedChunks, equals(1));
      expect(result.prompt, isNotEmpty);
      expect(result.prompt, contains('Question:'));
      expect(result.prompt, contains('Information:'));
      expect(llm.generateCalled, isTrue);
    });

    patrolTest('includes multiple source notes ranked by score', ($) async {
      final noteA = _makeNote(id: 1, title: 'Low Relevance');
      final noteB = _makeNote(id: 2, title: 'High Relevance');
      noteRepo.seed([noteA, noteB]);

      // Use vectors with different *directions* so cosine similarity differs.
      // Query is [1,0,0]; noteA has lower cosine sim, noteB has higher.
      // Both must exceed minScore (0.3) to appear in results.
      embeddingRepo.seed([
        _makeEmbedding(noteId: 1, chunkText: 'chunk A', vector: [0.6, 0.8, 0.0]),
        _makeEmbedding(noteId: 2, chunkText: 'chunk B', vector: [0.95, 0.3, 0.0]),
      ]);

      final (:service, llm: _, rewrite: _, expand: _) = _buildRagService(
        noteRepo: noteRepo,
        folderRepo: folderRepo,
        embeddingRepo: embeddingRepo,
        queryVector: [1.0, 0.0, 0.0],
      );

      final result = await service.query('test');

      // Both notes should be included
      expect(result.sourceNoteTitles.length, equals(2));
      // Higher-relevance note should be first
      expect(result.sourceNoteTitles.first, equals('High Relevance'));
    });

    patrolTest('handles LLM generation error gracefully', ($) async {
      final note = _makeNote(id: 1, title: 'Note');
      noteRepo.seed([note]);
      embeddingRepo.seed([
        _makeEmbedding(noteId: 1, vector: [0.5, 0.5, 0.5]),
      ]);

      final (:service, llm: _, rewrite: _, expand: _) = _buildRagService(
        noteRepo: noteRepo,
        folderRepo: folderRepo,
        embeddingRepo: embeddingRepo,
        queryVector: [0.5, 0.5, 0.5],
        llmShouldThrow: true,
      );

      final result = await service.query('test');

      expect(result.answer, contains('something went wrong'));
      // Source titles should still be available even if LLM fails
      expect(result.sourceNoteTitles, isNotEmpty);
      expect(result.prompt, isNotEmpty);
    });

    patrolTest('ignores maxNotes parameter in single-turn mode', ($) async {
      final notes = List.generate(10, (i) => _makeNote(id: i + 1, title: 'Note ${i + 1}'));
      noteRepo.seed(notes);
      for (final n in notes) {
        embeddingRepo.seed([
          _makeEmbedding(noteId: n.id, vector: [0.5, 0.5, 0.5]),
        ]);
      }

      final (:service, llm: _, rewrite: _, expand: _) = _buildRagService(
        noteRepo: noteRepo,
        folderRepo: folderRepo,
        embeddingRepo: embeddingRepo,
        queryVector: [0.5, 0.5, 0.5],
      );

      final a = await service.query('test', maxNotes: 1);
      final b = await service.query('test', maxNotes: 10);

      expect(a.sourceNoteTitles, equals(b.sourceNoteTitles));
    });

    patrolTest('prompt contains user question', ($) async {
      final note = _makeNote(id: 1, title: 'Note');
      noteRepo.seed([note]);
      embeddingRepo.seed([
        _makeEmbedding(noteId: 1, vector: [0.5, 0.5, 0.5]),
      ]);

      final (:service, :llm, rewrite: _, expand: _) = _buildRagService(
        noteRepo: noteRepo,
        folderRepo: folderRepo,
        embeddingRepo: embeddingRepo,
        queryVector: [0.5, 0.5, 0.5],
      );

      await service.query('What about meditation?');

      expect(llm.lastPrompt, contains('Question:'));
      expect(llm.lastPrompt, contains('What about meditation?'));
    });

    patrolTest('invokes query rewrite and multi-query expansion', ($) async {
      final note = _makeNote(id: 1, title: 'Note');
      noteRepo.seed([note]);
      embeddingRepo.seed([
        _makeEmbedding(noteId: 1, chunkText: 'Meditated for 20 minutes', vector: [0.5, 0.5, 0.5]),
      ]);

      final (:service, :rewrite, :expand, llm: _) = _buildRagService(
        noteRepo: noteRepo,
        folderRepo: folderRepo,
        embeddingRepo: embeddingRepo,
        queryVector: [0.5, 0.5, 0.5],
      );

      await service.query('meditation?', depth: RetrievalDepth.pro);

      expect(rewrite.calls, equals(1));
      expect(expand.calls, equals(1));
    });

    patrolTest('free tier rewrites but skips multi-query expansion', ($) async {
      final note = _makeNote(id: 1, title: 'Note');
      noteRepo.seed([note]);
      embeddingRepo.seed([
        _makeEmbedding(noteId: 1, chunkText: 'Meditated for 20 minutes', vector: [0.5, 0.5, 0.5]),
      ]);

      final (:service, :rewrite, :expand, llm: _) = _buildRagService(
        noteRepo: noteRepo,
        folderRepo: folderRepo,
        embeddingRepo: embeddingRepo,
        queryVector: [0.5, 0.5, 0.5],
      );

      // Default depth is RetrievalDepth.free (expansionCount: 1) → expansion is skipped.
      await service.query('meditation?');

      expect(rewrite.calls, equals(1));
      expect(expand.calls, equals(0));
    });

    patrolTest('passes prior transcript to rewrite and LLM when priorTurns provided', ($) async {
      final note = _makeNote(id: 1, title: 'Note');
      noteRepo.seed([note]);
      embeddingRepo.seed([
        _makeEmbedding(noteId: 1, chunkText: 'Meditated for 20 minutes', vector: [0.5, 0.5, 0.5]),
      ]);

      final (:service, :llm, :rewrite, expand: _) = _buildRagService(
        noteRepo: noteRepo,
        folderRepo: folderRepo,
        embeddingRepo: embeddingRepo,
        queryVector: [0.5, 0.5, 0.5],
      );

      const prior = [
        RagChatTurn(role: 'user', content: 'earlier question'),
        RagChatTurn(role: 'assistant', content: 'earlier answer'),
      ];

      await service.query('follow-up', priorTurns: prior);

      expect(rewrite.lastConversationContext, isNotNull);
      expect(rewrite.lastConversationContext, contains('User:'));
      expect(rewrite.lastConversationContext, contains('earlier question'));
      expect(llm.lastHistory, hasLength(2));
      expect(llm.lastHistory![0].role, 'user');
      expect(llm.lastHistory![1].role, 'assistant');
    });

    patrolTest('rrfFuse selects expected top-3 from 3×5 pools', ($) async {
      // Three ranked lists (5 each). Key format is noteId:chunkIndex.
      final q1 = ['1:0', '2:0', '3:0', '4:0', '5:0'];
      final q2 = ['2:0', '6:0', '7:0', '1:0', '8:0'];
      final q3 = ['9:0', '2:0', '10:0', '1:0', '11:0'];

      // Similarities only matter for tie-breaks; provide a deterministic map.
      final sim = <String, double>{
        for (final k in {...q1, ...q2, ...q3}) k: 0.5,
      };

      final fused = RagService.rrfFuse(rankedKeysPerQuery: [q1, q2, q3], similarityByKey: sim);
      final top3 = fused.take(3).map((e) => e.key).toList();

      // `2:0` appears very high across lists, `1:0` appears in all lists,
      // and `9:0` wins as the strongest single-list head among remaining candidates.
      expect(top3, equals(['2:0', '1:0', '9:0']));
    });

    patrolTest('rrfFuse tie-breaks by noteId asc then chunkIndex asc', ($) async {
      final q1 = ['2:1', '1:2'];
      final q2 = ['1:2', '2:1'];
      final sim = {'1:2': 0.5, '2:1': 0.5};

      final fused = RagService.rrfFuse(rankedKeysPerQuery: [q1, q2], similarityByKey: sim);

      // RRF ties and similarity ties → noteId asc decides.
      expect(fused.first.key, equals('1:2'));
      expect(fused[1].key, equals('2:1'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  //  RagService.queryStream
  // ─────────────────────────────────────────────────────────────────────────

  group('RagService.queryStream', () {
    patrolTest('emits error message when embedding fails', ($) async {
      final note = _makeNote(id: 1, title: 'Seed');
      noteRepo.seed([note]);
      embeddingRepo.seed([
        _makeEmbedding(noteId: 1, vector: [0.5, 0.5, 0.5]),
      ]);

      final (:service, llm: _, rewrite: _, expand: _) = _buildRagService(
        noteRepo: noteRepo,
        folderRepo: folderRepo,
        embeddingRepo: embeddingRepo,
        queryVector: null,
      );

      final chunks = await service.queryStream('test').toList();
      expect(chunks.length, equals(1));
      expect(chunks.first, contains('unable to process'));
    });

    patrolTest('emits error message when no results found (no indexed notes)', ($) async {
      final (:service, llm: _, rewrite: _, expand: _) = _buildRagService(
        noteRepo: noteRepo,
        folderRepo: folderRepo,
        embeddingRepo: embeddingRepo,
        queryVector: [0.5, 0.5, 0.5],
      );

      final chunks = await service.queryStream('test').toList();
      expect(chunks.length, equals(1));
      expect(chunks.first, contains("haven't been indexed"));
    });

    patrolTest('streams answer tokens', ($) async {
      final note = _makeNote(id: 1, title: 'Note');
      noteRepo.seed([note]);
      embeddingRepo.seed([
        _makeEmbedding(noteId: 1, vector: [0.5, 0.5, 0.5]),
      ]);

      final (:service, llm: _, rewrite: _, expand: _) = _buildRagService(
        noteRepo: noteRepo,
        folderRepo: folderRepo,
        embeddingRepo: embeddingRepo,
        queryVector: [0.5, 0.5, 0.5],
        llmResponse: 'word1 word2 word3',
      );

      final chunks = await service.queryStream('test').toList();

      // FakeLlmClient yields each word separately
      expect(chunks.length, greaterThan(1));
      final combined = chunks.join('');
      expect(combined, contains('word1'));
      expect(combined, contains('word2'));
      expect(combined, contains('word3'));
    });

    patrolTest('emits error message when LLM stream fails', ($) async {
      final note = _makeNote(id: 1, title: 'Note');
      noteRepo.seed([note]);
      embeddingRepo.seed([
        _makeEmbedding(noteId: 1, vector: [0.5, 0.5, 0.5]),
      ]);

      final (:service, llm: _, rewrite: _, expand: _) = _buildRagService(
        noteRepo: noteRepo,
        folderRepo: folderRepo,
        embeddingRepo: embeddingRepo,
        queryVector: [0.5, 0.5, 0.5],
        llmShouldThrow: true,
      );

      final chunks = await service.queryStream('test').toList();
      expect(chunks.length, equals(1));
      expect(chunks.first, contains('something went wrong'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  //  RagService.getSourceTitles
  // ─────────────────────────────────────────────────────────────────────────

  group('RagService.getSourceTitles', () {
    patrolTest('returns empty when embedding fails', ($) async {
      final (:service, llm: _, rewrite: _, expand: _) = _buildRagService(
        noteRepo: noteRepo,
        folderRepo: folderRepo,
        embeddingRepo: embeddingRepo,
        queryVector: null,
      );

      final titles = await service.getSourceTitles('test');
      expect(titles, isEmpty);
    });

    patrolTest('returns titles for matching notes', ($) async {
      final note = _makeNote(id: 1, title: 'My Note');
      noteRepo.seed([note]);
      embeddingRepo.seed([
        _makeEmbedding(noteId: 1, vector: [0.5, 0.5, 0.5]),
      ]);

      final (:service, llm: _, rewrite: _, expand: _) = _buildRagService(
        noteRepo: noteRepo,
        folderRepo: folderRepo,
        embeddingRepo: embeddingRepo,
        queryVector: [0.5, 0.5, 0.5],
      );

      final titles = await service.getSourceTitles('test');
      expect(titles, equals(['My Note']));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  //  RagService.isAvailable
  // ─────────────────────────────────────────────────────────────────────────

  group('isAvailable', () {
    patrolTest('returns true when both services are available', ($) async {
      final (:service, llm: _, rewrite: _, expand: _) = _buildRagService(
        noteRepo: noteRepo,
        folderRepo: folderRepo,
        embeddingRepo: embeddingRepo,
        queryVector: [0.5, 0.5, 0.5],
      );

      expect(service.isAvailable, isTrue);
    });
  });
}
