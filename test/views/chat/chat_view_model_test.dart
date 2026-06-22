import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/repository/interfaces/chat_message_repository.dart';
import 'package:trovara/core/repository/interfaces/chat_thread_repository.dart';
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
import 'package:trovara/core/services/chat/chat_service.dart';
import 'package:trovara/core/services/chat/chat_source_service.dart';
import 'package:trovara/core/services/notes/note_service.dart';
import 'package:trovara/models/chat_message.dart';
import 'package:trovara/models/chat_source_note.dart';
import 'package:trovara/models/chat_thread.dart';
import 'package:trovara/models/folder.dart';
import 'package:trovara/models/note.dart';
import 'package:trovara/models/note_embedding.dart';
import 'package:trovara/views/chat/chat_view_model.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  Stubs — copied from rag_service_test.dart for constructor satisfaction
// ═══════════════════════════════════════════════════════════════════════════

class _StubEmbeddingRepo implements IEmbeddingRepository {
  @override
  Future<void> initialize() async {}
  @override
  Future<void> saveEmbedding(NoteEmbedding embedding) async {}
  @override
  Future<void> saveEmbeddings(List<NoteEmbedding> embeddings) async {}
  @override
  List<NoteEmbedding> getEmbeddingsByNoteId(int noteId) => [];
  @override
  List<NoteEmbedding> getAllEmbeddings() => [];
  @override
  Future<void> deleteByNoteId(int noteId) async {}
  @override
  Future<void> deleteAll() async {}
  @override
  int get totalEmbeddings => 0;
  @override
  void dispose() {}
}

class _StubNoteRepo implements INoteRepository {
  @override
  Future<void> initialize() async {}
  @override
  List<Note> getActiveNotes() => [];
  @override
  List<Note> getActiveNotesForUser(String? userId) => [];
  @override
  List<Note> getAllNotes() => [];
  @override
  Note? getNoteById(int id) => null;

  @override
  Note? getNoteBySync(String syncId) => null;
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

class _StubFolderRepo implements IFolderRepository {
  @override
  Future<void> initialize() async {}
  @override
  List<Folder> getAllFolders() => [];
  @override
  Folder? getFolderById(String folderId) => null;
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

class _StubChatThreadRepo implements IChatThreadRepository {
  int _nextId = 1;
  final List<ChatThread> _threads = [];

  @override
  Future<void> initialize() async {}
  @override
  ChatThread? getThreadById(int id) => _threads.where((t) => t.id == id).firstOrNull;
  @override
  List<ChatThread> getThreadsByNote(int noteId) => _threads.where((t) => t.noteId == noteId && !t.isDeleted).toList();
  @override
  List<ChatThread> getGlobalThreads() => _threads.where((t) => t.type == 'global' && !t.isDeleted).toList();
  @override
  List<ChatThread> getAllThreads() => _threads.where((t) => !t.isDeleted).toList();
  @override
  Future<ChatThread> createThread({required String type, int? noteId, String? title}) async {
    final thread = ChatThread(id: _nextId++, type: type, noteId: noteId, title: title);
    _threads.add(thread);
    return thread;
  }

  @override
  Future<void> updateThread(ChatThread thread) async {}
  @override
  Future<void> upsertThread(ChatThread thread) async {
    _threads.removeWhere((t) => t.id == thread.id);
    _threads.add(thread);
  }

  @override
  Future<void> deleteThread(int id) async {
    _threads.removeWhere((t) => t.id == id);
  }

  @override
  void addListener(Function() listener) {}
  @override
  void removeListener(Function() listener) {}
  @override
  void dispose() {}
}

class _StubChatMessageRepo implements IChatMessageRepository {
  int _nextId = 1;
  final List<ChatMessageEntity> _messages = [];

  @override
  Future<void> initialize() async {}
  @override
  List<ChatMessageEntity> getMessagesForThread(int threadId) => _messages.where((m) => m.threadId == threadId).toList();
  @override
  List<ChatMessageEntity> getRecentMessagesForThread(int threadId, {int limit = 50}) =>
      getMessagesForThread(threadId).reversed.take(limit).toList().reversed.toList();
  @override
  Future<ChatMessageEntity> createMessage(ChatMessageEntity message) async {
    message.id = _nextId++;
    _messages.add(message);
    return message;
  }

  @override
  Future<void> updateMessage(ChatMessageEntity message) async {}
  @override
  Future<void> upsertMessage(ChatMessageEntity message) async {
    _messages.removeWhere((m) => m.id == message.id);
    _messages.add(message);
  }

  @override
  Future<void> deleteMessagesForThread(int threadId) async {
    _messages.removeWhere((m) => m.threadId == threadId);
  }

  @override
  Future<void> deleteMessage(int id) async {
    _messages.removeWhere((m) => m.id == id);
  }

  @override
  void addListener(Function() listener) {}
  @override
  void removeListener(Function() listener) {}
  @override
  void dispose() {}
}

// ═══════════════════════════════════════════════════════════════════════════
//  FakeRagService — overrides only the methods ChatViewModel calls
// ═══════════════════════════════════════════════════════════════════════════

class _FakeRagService extends RagService {
  final bool _available;
  final Stream<String> Function(String)? _onQueryStream;
  final Future<List<Note>> Function(String)? _onGetSourceNotes;

  String? lastQuery;
  List<RagChatTurn> lastPriorTurns = const [];

  _FakeRagService({
    bool available = true,
    Stream<String> Function(String)? onQueryStream,
    Future<List<Note>> Function(String)? onGetSourceNotes,
  }) : _available = available,
        _onQueryStream = onQueryStream,
        _onGetSourceNotes = onGetSourceNotes,
        super(
         embeddingService: EmbeddingService(embeddingRepository: _StubEmbeddingRepo(), apiKey: 'fake'),
         vectorSearchService: VectorSearchService(repository: _StubEmbeddingRepo()),
         documentResolverService: DocumentResolverService(
           noteService: NoteService(noteRepository: _StubNoteRepo(), folderRepository: _StubFolderRepo()),
         ),
         promptBuilderService: PromptBuilderService(
           documentResolver: DocumentResolverService(
             noteService: NoteService(noteRepository: _StubNoteRepo(), folderRepository: _StubFolderRepo()),
           ),
         ),
         llmClient: LlmClient(apiKey: 'fake'),
         queryRewriteService: QueryRewriteService(llmClient: LlmClient(apiKey: 'fake')),
         multiQueryExpansionService: MultiQueryExpansionService(llmClient: LlmClient(apiKey: 'fake')),
       );

  @override
  bool get isAvailable => _available;

  @override
  Stream<String> queryStream(
    String userQuestion, {
    List<RagChatTurn> priorTurns = const [],
    int searchTopK = 10,
    double minScore = 0.3,
    int maxNotes = 5,
    RetrievalDepth depth = RetrievalDepth.free,
  }) {
    lastQuery = userQuestion;
    lastPriorTurns = priorTurns;
    if (_onQueryStream != null) return _onQueryStream(userQuestion);
    return Stream.fromIterable(['Hello ', 'world']);
  }

  @override
  Future<List<Note>> getSourceDebugNotes(
    String userQuestion, {
    List<RagChatTurn> priorTurns = const [],
    int searchTopK = 10,
    double minScore = 0.3,
    int maxNotes = 5,
  }) {
    lastPriorTurns = priorTurns;
    if (_onGetSourceNotes != null) return _onGetSourceNotes(userQuestion);
    return Future.value([
      Note(id: 1, title: 'Note A', contentJson: '[{\"insert\":\"\\n\"}]'),
      Note(id: 2, title: 'Note B', contentJson: '[{\"insert\":\"\\n\"}]'),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Tests
// ═══════════════════════════════════════════════════════════════════════════

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  //  ChatMessage model
  // ─────────────────────────────────────────────────────────────────────────
  group('ChatMessage', () {
    test('stores all provided fields', () {
      final ts = DateTime(2025, 1, 15);
      final msg = ChatMessage(
        id: '1',
        content: 'Hello',
        isUser: true,
        timestamp: ts,
        sourceNotes: const [ChatSourceNote(id: 1, title: 'Note 1')],
        isLoading: true,
        isError: true,
      );

      expect(msg.id, '1');
      expect(msg.content, 'Hello');
      expect(msg.isUser, true);
      expect(msg.timestamp, ts);
      expect(msg.sourceNotes, const [ChatSourceNote(id: 1, title: 'Note 1')]);
      expect(msg.isLoading, true);
      expect(msg.isError, true);
    });

    test('defaults timestamp to now', () {
      final before = DateTime.now();
      final msg = ChatMessage(id: '1', content: '', isUser: false);
      final after = DateTime.now();

      expect(msg.timestamp.isAfter(before.subtract(const Duration(seconds: 1))), true);
      expect(msg.timestamp.isBefore(after.add(const Duration(seconds: 1))), true);
    });

    test('defaults sourceNotes to empty', () {
      final msg = ChatMessage(id: '1', content: '', isUser: false);
      expect(msg.sourceNotes, isEmpty);
    });

    test('defaults isLoading and isError to false', () {
      final msg = ChatMessage(id: '1', content: '', isUser: true);
      expect(msg.isLoading, false);
      expect(msg.isError, false);
    });

    test('copyWith preserves unchanged fields', () {
      final original = ChatMessage(
        id: '1',
        content: 'original',
        isUser: false,
        sourceNotes: const [ChatSourceNote(id: 1, title: 'A')],
        isLoading: true,
      );
      final copy = original.copyWith(content: 'updated');

      expect(copy.id, '1');
      expect(copy.content, 'updated');
      expect(copy.isUser, false);
      expect(copy.sourceNotes, const [ChatSourceNote(id: 1, title: 'A')]);
      expect(copy.isLoading, true);
    });

    test('copyWith updates all changeable fields', () {
      final original = ChatMessage(id: '1', content: 'a', isUser: false);
      final copy = original.copyWith(
        content: 'b',
        sourceNotes: const [ChatSourceNote(id: 1, title: 'X')],
        isLoading: true,
        isError: true,
      );

      expect(copy.content, 'b');
      expect(copy.sourceNotes, const [ChatSourceNote(id: 1, title: 'X')]);
      expect(copy.isLoading, true);
      expect(copy.isError, true);
    });

    test('toString shows role and content length', () {
      final user = ChatMessage(id: '1', content: 'Hi there', isUser: true);
      expect(user.toString(), contains('user'));
      expect(user.toString(), contains('8 chars'));

      final ai = ChatMessage(id: '2', content: 'Answer', isUser: false);
      expect(ai.toString(), contains('ai'));
      expect(ai.toString(), contains('6 chars'));
    });

    test('toString shows loading indicator', () {
      final msg = ChatMessage(id: '1', content: '', isUser: false, isLoading: true);
      expect(msg.toString(), contains('loading'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  //  ChatViewModel
  // ─────────────────────────────────────────────────────────────────────────
  group('ChatViewModel', () {
    late _FakeRagService fakeRag;
    late ChatService chatService;
    late NoteService noteService;
    late ChatSourceService chatSourceService;
    late ChatViewModel vm;

    setUp(() {
      fakeRag = _FakeRagService();
      chatService = ChatService(threadRepository: _StubChatThreadRepo(), messageRepository: _StubChatMessageRepo());
      noteService = NoteService(noteRepository: _StubNoteRepo(), folderRepository: _StubFolderRepo());
      chatSourceService = ChatSourceService(noteService: noteService);
      vm = ChatViewModel(ragService: fakeRag, chatService: chatService, chatSourceService: chatSourceService);
    });

    test('initial state is empty and not processing', () {
      expect(vm.messages, isEmpty);
      expect(vm.isProcessing, false);
      expect(vm.hasMessages, false);
    });

    test('isAvailable delegates to RagService', () {
      final available = ChatViewModel(
        ragService: _FakeRagService(available: true),
        chatService: chatService,
        chatSourceService: chatSourceService,
      );
      expect(available.isAvailable, true);

      final unavailable = ChatViewModel(
        ragService: _FakeRagService(available: false),
        chatService: chatService,
        chatSourceService: chatSourceService,
      );
      expect(unavailable.isAvailable, false);
    });

    test('suggestedQuestions has 4 items', () {
      expect(ChatViewModel.suggestedQuestions, hasLength(4));
    });

    test('sendMessage adds user + AI messages', () async {
      await vm.sendMessage('What did I write?');

      expect(vm.messages, hasLength(2));
      expect(vm.messages[0].isUser, true);
      expect(vm.messages[0].content, 'What did I write?');
      expect(vm.messages[1].isUser, false);
      expect(vm.messages[1].content, 'Hello world');
    });

    test('second sendMessage passes prior turns to RAG for memory', () async {
      await vm.sendMessage('First question');
      expect(fakeRag.lastPriorTurns, isEmpty);

      await vm.sendMessage('Follow-up');
      expect(fakeRag.lastPriorTurns, hasLength(2));
      expect(fakeRag.lastPriorTurns[0].role, 'user');
      expect(fakeRag.lastPriorTurns[0].content, 'First question');
      expect(fakeRag.lastPriorTurns[1].role, 'assistant');
      expect(fakeRag.lastPriorTurns[1].content, 'Hello world');
    });

    test('sendMessage populates source notes', () async {
      await vm.sendMessage('test');

      final aiMessage = vm.messages[1];
      expect(aiMessage.sourceNotes.map((s) => s.title).toList(), ['Note A', 'Note B']);
      expect(aiMessage.isLoading, false);
    });

    test('sendMessage trims whitespace', () async {
      await vm.sendMessage('  hello  ');

      expect(vm.messages[0].content, 'hello');
      expect(fakeRag.lastQuery, 'hello');
    });

    test('sendMessage ignores empty input', () async {
      await vm.sendMessage('');
      await vm.sendMessage('   ');

      expect(vm.messages, isEmpty);
    });

    test('sendMessage handles stream error', () async {
      final errorRag = _FakeRagService(onQueryStream: (_) => Stream<String>.error(Exception('API failed')));
      final errorVm = ChatViewModel(ragService: errorRag, chatService: chatService, chatSourceService: chatSourceService);

      await errorVm.sendMessage('test');

      expect(errorVm.messages, hasLength(2));
      final aiMsg = errorVm.messages[1];
      expect(aiMsg.isError, true);
      expect(aiMsg.content, contains('Sorry'));
      expect(aiMsg.isLoading, false);
    });

    test('sendMessage does not mark no-results as error', () async {
      final noResultsRag = _FakeRagService(
        onQueryStream: (_) =>
            Stream<String>.error(RagQueryException("I couldn't find any relevant notes for your question.")),
        onGetSourceNotes: (_) async => [],
      );
      final noResultsVm = ChatViewModel(ragService: noResultsRag, chatService: chatService, chatSourceService: chatSourceService);

      await noResultsVm.sendMessage('test');

      expect(noResultsVm.messages, hasLength(2));
      final aiMsg = noResultsVm.messages[1];
      expect(aiMsg.isError, false);
      expect(aiMsg.content, contains("couldn't find any relevant notes"));
      expect(aiMsg.isLoading, false);
    });

    test('isProcessing is false after sendMessage completes', () async {
      await vm.sendMessage('test');
      expect(vm.isProcessing, false);
    });

    test('passes user query to RagService', () async {
      await vm.sendMessage('My specific question');
      expect(fakeRag.lastQuery, 'My specific question');
    });

    test('clearConversation removes all messages', () async {
      await vm.sendMessage('first');
      expect(vm.hasMessages, true);

      vm.clearConversation();
      expect(vm.messages, isEmpty);
      expect(vm.hasMessages, false);
    });

    test('multiple messages accumulate in order', () async {
      final rag = _FakeRagService(
        onQueryStream: (q) => Stream.value('Reply to $q'),
        onGetSourceNotes: (_) async => [],
      );
      final multiVm = ChatViewModel(ragService: rag, chatService: chatService, chatSourceService: chatSourceService);

      await multiVm.sendMessage('first');
      await multiVm.sendMessage('second');

      expect(multiVm.messages, hasLength(4));
      expect(multiVm.messages[0].content, 'first');
      expect(multiVm.messages[1].content, 'Reply to first');
      expect(multiVm.messages[2].content, 'second');
      expect(multiVm.messages[3].content, 'Reply to second');
    });

    test('notifyListeners fires during sendMessage', () async {
      int count = 0;
      vm.addListener(() => count++);

      await vm.sendMessage('test');

      // Must fire at least for: initial add, stream updates, final update
      expect(count, greaterThanOrEqualTo(3));
    });

    test('messages list is unmodifiable', () {
      expect(() => vm.messages.add(ChatMessage(id: '1', content: '', isUser: true)), throwsUnsupportedError);
    });
  });
}
