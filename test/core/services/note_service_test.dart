import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trovara/core/import/import_adapter.dart';
import 'package:trovara/core/repository/interfaces/folder_repository.dart';
import 'package:trovara/core/repository/interfaces/note_repository.dart';
import 'package:trovara/core/services/note_service.dart';
import 'package:trovara/models/folder.dart';
import 'package:trovara/models/note.dart';
import 'package:uuid/uuid.dart';

class _FakeNoteRepository implements INoteRepository {
  final Map<int, Note> _notesById = <int, Note>{};
  int _nextId = 1;
  final List<Function()> _listeners = <Function()>[];

  void seed(Note note) {
    final id = note.id == 0 ? _nextId++ : note.id;
    _notesById[id] = note..id = id;
  }

  @override
  Future<void> initialize() async {}

  @override
  List<Note> getActiveNotes() => _notesById.values.where((n) => !n.isDeleted).toList();

  @override
  List<Note> getActiveNotesForUser(String? userId) =>
      _notesById.values.where((n) => !n.isDeleted && (n.userId == null || n.userId == userId)).toList();

  @override
  List<Note> getAllNotes() => _notesById.values.toList();

  @override
  Note? getNoteById(int id) => _notesById[id];

  @override
  Note? getNoteBySync(String syncId) => _notesById.values.where((n) => n.syncId == syncId).firstOrNull;

  @override
  List<Note> searchNotes(String query) {
    final q = query.toLowerCase();
    return _notesById.values.where((n) => !n.isDeleted && n.title.toLowerCase().contains(q)).toList();
  }

  @override
  List<Note> searchNotesForUser(String? userId, String query) {
    final q = query.toLowerCase();
    return _notesById.values
        .where((n) => !n.isDeleted && (n.userId == null || n.userId == userId) && n.title.toLowerCase().contains(q))
        .toList();
  }

  @override
  List<Note> getNotesByFolder(String folderId) =>
      _notesById.values.where((n) => !n.isDeleted && n.folderId == folderId).toList();

  @override
  List<Note> getNotesByFolderForUser(String? userId, String folderId) => _notesById.values
      .where((n) => !n.isDeleted && n.folderId == folderId && (n.userId == null || n.userId == userId))
      .toList();

  @override
  List<Note> getFavoriteNotes() => _notesById.values.where((n) => !n.isDeleted && n.isFavorite).toList();

  @override
  List<Note> getFavoriteNotesForUser(String? userId) => _notesById.values
      .where((n) => !n.isDeleted && n.isFavorite && (n.userId == null || n.userId == userId))
      .toList();

  @override
  List<Note> getArchivedNotes() => _notesById.values.where((n) => !n.isDeleted && n.isArchived).toList();

  @override
  List<Note> getArchivedNotesForUser(String? userId) => _notesById.values
      .where((n) => !n.isDeleted && n.isArchived && (n.userId == null || n.userId == userId))
      .toList();

  @override
  List<Note> getNotesByTag(String tag) => _notesById.values.where((n) => !n.isDeleted && n.allTags.contains(tag)).toList();

  @override
  List<String> getAllTags() => _notesById.values.where((n) => !n.isDeleted).expand((n) => n.allTags).toSet().toList();

  @override
  List<Note> getDeletedNotes() => _notesById.values.where((n) => n.isDeleted).toList();

  @override
  List<Note> getDeletedNotesForUser(String? userId) =>
      _notesById.values.where((n) => n.isDeleted && (n.userId == null || n.userId == userId)).toList();

  @override
  Future<Note> createNote({
    String? title,
    String? contentJson,
    String? folderId,
    List<int> customTagIds = const [],
    String? userId,
  }) async {
    final note = Note(
      id: _nextId++,
      title: title ?? 'Untitled',
      contentJson: contentJson ?? '[{"insert":"\\n"}]',
      folderId: folderId ?? 'default',
      customTagIds: customTagIds,
      userId: userId,
    );
    _notesById[note.id] = note;
    _notify();
    return note;
  }

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
  }) async {
    final note = Note(
      id: _nextId++,
      syncId: syncId,
      title: title ?? 'Untitled',
      contentJson: contentJson ?? '[{"insert":"\\n"}]',
      folderId: folderId ?? 'default',
      customTagIds: customTagIds,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isFavorite: isFavorite,
      isArchived: isArchived,
      isDeleted: isDeleted,
      deletedAt: deletedAt,
      userId: userId,
      moodTags: moodTags,
      activityTags: activityTags,
      timeTags: timeTags,
      personalGrowthTags: personalGrowthTags,
    );
    _notesById[note.id] = note;
    _notify();
    return note;
  }

  @override
  Future<void> updateNote(Note note, {bool preserveTimestamps = false}) async {
    _notesById[note.id] = note;
    _notify();
  }

  @override
  Future<void> deleteNote(int id) async {
    _notesById.remove(id);
    _notify();
  }

  @override
  int get totalNotes => getActiveNotes().length;

  @override
  int get totalWords => getActiveNotes().fold(0, (sum, n) => sum + n.wordCount);

  @override
  int get totalCharacters => getActiveNotes().fold(0, (sum, n) => sum + n.characterCount);

  @override
  void addListener(Function() listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(Function() listener) {
    _listeners.remove(listener);
  }

  @override
  void dispose() {
    _listeners.clear();
  }

  void _notify() {
    for (final listener in _listeners) {
      listener();
    }
  }
}

class _FakeFolderRepository implements IFolderRepository {
  final Map<String, Folder> _foldersById = <String, Folder>{};

  void seed(Folder folder) {
    _foldersById[folder.folderId] = folder;
  }

  @override
  Future<void> initialize() async {}

  @override
  List<Folder> getAllFolders() => _foldersById.values.toList();

  @override
  Folder? getFolderById(String folderId) => _foldersById[folderId];

  @override
  Future<Folder> createFolder({required String name, String? description, String? color}) async {
    final folder = Folder(folderId: 'folder_${_foldersById.length + 1}', name: name, description: description, color: color);
    _foldersById[folder.folderId] = folder;
    return folder;
  }

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
  }) async {
    final folder = Folder(
      folderId: folderId,
      name: name,
      description: description,
      color: color,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isDefault: isDefault,
      noteCount: noteCount,
    );
    _foldersById[folder.folderId] = folder;
    return folder;
  }

  @override
  Future<void> updateFolder(Folder folder) async {
    _foldersById[folder.folderId] = folder;
  }

  @override
  Future<void> deleteFolder(String folderId) async {
    _foldersById.remove(folderId);
  }

  @override
  Folder? getDefaultFolder() => _foldersById.values.where((f) => f.isDefault).firstOrNull;

  @override
  void addListener(Function() listener) {}

  @override
  void removeListener(Function() listener) {}

  @override
  void dispose() {}
}

class _FakeAdapter implements NoteImportAdapter {
  final List<ImportedNote> _notes;
  @override
  final String sourceName;

  _FakeAdapter({required List<ImportedNote> notes, this.sourceName = 'fake-adapter'}) : _notes = notes;

  @override
  bool canHandle(dynamic rawInput) => true;

  @override
  Future<List<ImportedNote>> parse(dynamic rawInput) async => _notes;
}

void main() {
  group('NoteService core note workflows', () {
    late _FakeNoteRepository noteRepository;
    late _FakeFolderRepository folderRepository;
    late NoteService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      noteRepository = _FakeNoteRepository();
      folderRepository = _FakeFolderRepository()
        ..seed(Folder(folderId: 'default', name: 'Default', isDefault: true))
        ..seed(Folder(folderId: 'work', name: 'Work'));
      service = NoteService(noteRepository: noteRepository, folderRepository: folderRepository);
      await service.initialize();
    });

    test('createNote increments folder noteCount', () async {
      expect(folderRepository.getFolderById('work')?.noteCount, 0);

      await service.createNote(title: 'Task', contentJson: '[{"insert":"hello\\n"}]', folderId: 'work');

      expect(folderRepository.getFolderById('work')?.noteCount, 1);
      expect(service.notes, hasLength(1));
    });

    test('softDeleteNote and restoreNoteFromTrash keep folder counts consistent', () async {
      final note = await service.createNote(title: 'Task', contentJson: '[{"insert":"hello\\n"}]', folderId: 'work');
      expect(folderRepository.getFolderById('work')?.noteCount, 1);

      await service.softDeleteNote(note.id);
      expect(service.getNote(note.id)?.isDeleted, isTrue);
      expect(folderRepository.getFolderById('work')?.noteCount, 0);

      await service.restoreNoteFromTrash(note.id);
      expect(service.getNote(note.id)?.isDeleted, isFalse);
      expect(folderRepository.getFolderById('work')?.noteCount, 1);
    });

    test('permanentDeleteNote removes note and records tombstone syncId', () async {
      final note = await service.createNote(title: 'Disposable', contentJson: '[{"insert":"bye\\n"}]', folderId: 'work');
      final syncId = note.syncId;

      await service.permanentDeleteNote(note.id);
      final exported = service.exportAllToJson();

      expect(service.getNote(note.id), isNull);
      expect(folderRepository.getFolderById('work')?.noteCount, 0);
      expect((exported['deletedSyncIds'] as List<dynamic>).contains(syncId), isTrue);
    });

    test('initialize backfills empty syncId on legacy notes', () async {
      final legacy = Note(id: 10, syncId: '', title: 'Legacy', contentJson: '[{"insert":"legacy\\n"}]');
      noteRepository.seed(legacy);

      final backfillService = NoteService(noteRepository: noteRepository, folderRepository: folderRepository);
      await backfillService.initialize();

      expect(noteRepository.getNoteById(10)?.syncId, isNotEmpty);
    });

    test('importFromAdapter skips notes with tombstoned deterministic syncId', () async {
      final createdAt = DateTime.utc(2025, 1, 1, 12, 0, 0);
      final title = 'Deleted From Another Device';
      final deterministicSyncId = const Uuid().v5(
        Namespace.url.value,
        '${title.trim()}|${createdAt.toUtc().toIso8601String()}',
      );

      await service.registerPermanentlyDeletedSyncId(deterministicSyncId);

      final adapter = _FakeAdapter(
        notes: [
          ImportedNote(title: title, markdownContent: 'Body', createdAt: createdAt, updatedAt: createdAt),
        ],
      );

      final result = await service.importFromAdapter(adapter, <String, dynamic>{});

      expect(result.created, 0);
      expect(result.updated, 0);
      expect(result.skipped, 1);
      expect(service.notes, isEmpty);
    });

    test('importAllFromJson with google-drive-sync forces upsert even when remote is older', () async {
      final local = await service.createNote(
        title: 'Local New Title',
        contentJson: '[{"insert":"local\\n"}]',
        folderId: 'default',
      );
      final localSyncId = local.syncId;
      local.updatedAt = DateTime.utc(2026, 1, 2);
      await noteRepository.updateNote(local, preserveTimestamps: true);

      final remoteJson = <String, dynamic>{
        'version': 1,
        'exportedAt': DateTime.utc(2026, 1, 3).toIso8601String(),
        'folders': <Map<String, dynamic>>[],
        'notes': <Map<String, dynamic>>[
          {
            'id': 0,
            'syncId': localSyncId,
            'title': 'Remote Older Title',
            'contentJson': '[{"insert":"remote\\n"}]',
            'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
            'updatedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
            'isFavorite': false,
            'isArchived': false,
            'isDeleted': false,
            'deletedAt': '',
            'driveFileId': null,
            'userId': null,
            'folderId': 'default',
            'customTagIds': <int>[],
            'moodTags': <String>[],
            'activityTags': <String>[],
            'timeTags': <String>[],
            'personalGrowthTags': <String>[],
          },
        ],
      };

      await service.importAllFromJson(remoteJson, source: 'google-drive-sync');

      final updated = noteRepository.getNoteBySync(localSyncId);
      expect(updated?.title, 'Remote Older Title');
      expect(updated?.contentJson, '[{"insert":"remote\\n"}]');
    });
  });
}
