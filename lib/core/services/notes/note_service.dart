import 'package:logger/logger.dart';
import 'package:trovara/core/import/import_adapter.dart';
import 'package:trovara/core/repository/interfaces/folder_repository.dart';
import 'package:trovara/core/repository/interfaces/note_repository.dart';
import 'package:trovara/core/services/auth/google_drive_service.dart';
import 'package:trovara/core/services/ai/embedding_service.dart';
import 'package:trovara/core/services/notes/_storypad/storypad_converter.dart';
import 'package:trovara/core/services/notes/custom_tag_service.dart';
import 'package:trovara/core/services/notes/note_drive_trash_sync.dart';
import 'package:trovara/core/services/notes/note_factory.dart';
import 'package:trovara/core/services/notes/note_import_from_adapter.dart';
import 'package:trovara/core/services/notes/note_import_from_json.dart';
import 'package:trovara/core/services/notes/note_merge_engine.dart';
import 'package:trovara/core/services/notes/note_sync_id.dart';
import 'package:trovara/core/services/notes/note_tombstone_registry.dart';
import 'package:trovara/core/services/notes/note_trash_operations.dart';
import 'package:trovara/models/folder.dart';
import 'package:trovara/models/note.dart';

/// Coordinates note + folder repositories and orchestrates the helpers in this
/// folder (factory, trash ops, importers, merge, Drive sync). Public API is
/// preserved across the file split — callers (ViewModels, ServiceLocator,
/// sync services, tests) need no changes.
class NoteService {
  final INoteRepository _noteRepository;
  final IFolderRepository _folderRepository;
  final EmbeddingService? _embeddingService;
  final Logger _logger = Logger();

  late final NoteTombstoneRegistry _tombstones;
  late final NoteFactory _factory;
  late final NoteTrashOperations _trash;
  late final StorypadConverter _storypadConverter;
  late final NoteImportFromAdapterRunner _adapterImport;
  late final NoteImportFromJsonRunner _jsonImport;
  late final NoteDriveTrashSync _driveTrashSync;

  NoteService({
    required INoteRepository noteRepository,
    required IFolderRepository folderRepository,
    GoogleDriveService? driveService,
    EmbeddingService? embeddingService,
    CustomTagService? customTagService,
  }) : _noteRepository = noteRepository,
       _folderRepository = folderRepository,
       _embeddingService = embeddingService {
    _tombstones = NoteTombstoneRegistry(logger: _logger);
    _factory = NoteFactory(
      noteRepository: _noteRepository,
      folderRepository: _folderRepository,
      embeddingService: _embeddingService,
    );
    _trash = NoteTrashOperations(
      noteRepository: _noteRepository,
      folderRepository: _folderRepository,
      tombstones: _tombstones,
      embeddingService: _embeddingService,
    );
    _storypadConverter = StorypadConverter(logger: _logger);
    _adapterImport = NoteImportFromAdapterRunner(
      noteRepository: _noteRepository,
      tombstones: _tombstones,
      customTagService: customTagService,
      embeddingService: _embeddingService,
      createNoteWithTimestamps: createNoteWithTimestamps,
      updateNote: updateNote,
      logger: _logger,
    );
    _jsonImport = NoteImportFromJsonRunner(
      noteRepository: _noteRepository,
      folderRepository: _folderRepository,
      tombstones: _tombstones,
      embeddingService: _embeddingService,
      storypadConverter: _storypadConverter,
      createNoteWithTimestamps: createNoteWithTimestamps,
      createFolderWithTimestamps: createFolderWithTimestamps,
      logger: _logger,
    );
    _driveTrashSync = NoteDriveTrashSync(
      noteRepository: _noteRepository,
      driveService: driveService,
      onSoftDeleteLocal: _trash.softDelete,
      onRestoreLocal: _trash.restore,
      onPermanentDeleteLocal: _trash.permanentDelete,
      logger: _logger,
    );
  }

  Future<void> initialize() async {
    await _noteRepository.initialize();
    await _folderRepository.initialize();
    await loadTombstonesFromDisk();
    // One-time migration: assign syncIds to legacy notes that have none.
    await _backfillSyncIdsIfNeeded();
  }

  // ── Export / Import / Merge / Sync ID ──────────────────────────────────────

  Map<String, dynamic> exportAllToJson() => {
    'version': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'notes': _noteRepository.getAllNotes().map((n) => n.toJson()).toList(),
    'folders': _folderRepository.getAllFolders().map((f) => f.toJson()).toList(),
    'deletedSyncIds': _tombstones.asList(),
  };

  Future<ImportResult> importFromAdapter(
    NoteImportAdapter adapter,
    dynamic rawInput, {
    String? targetFolderId,
    bool verbose = false,
  }) => _adapterImport.run(adapter, rawInput, targetFolderId: targetFolderId, verbose: verbose);

  Future<void> importAllFromJson(Map<String, dynamic> json, {String source = 'unknown', bool verbose = false}) =>
      _jsonImport.run(json, source: source, verbose: verbose);

  Future<Map<String, dynamic>> mergeWithRemoteData(Map<String, dynamic> remoteData) async =>
      NoteMergeEngine.merge(exportAllToJson(), remoteData, logger: _logger);

  String getSyncIdFromNoteJson(Map<String, dynamic> noteJson) => NoteSyncId.fromNoteJson(noteJson);

  Future<void> loadTombstonesFromDisk() => _tombstones.load();
  Future<void> registerPermanentlyDeletedSyncId(String syncId) => _tombstones.add(syncId);

  // ── CRUD (active notes) ────────────────────────────────────────────────────

  Future<Note> createNote({
    String? title,
    String? contentJson,
    String? folderId,
    List<int> customTagIds = const [],
    String? userId,
  }) => _factory.create(
    title: title,
    contentJson: contentJson,
    folderId: folderId,
    customTagIds: customTagIds,
    userId: userId,
  );

  Future<Note> createNoteWithTimestamps({
    String? syncId, String? title, String? contentJson, String? folderId,
    List<int> customTagIds = const [], DateTime? createdAt, DateTime? updatedAt,
    bool isFavorite = false, bool isArchived = false, bool isDeleted = false,
    DateTime? deletedAt, String? userId,
    List<String>? moodTags, List<String>? activityTags,
    List<String>? timeTags, List<String>? personalGrowthTags,
    String source = 'trovara', List<String>? internalLinks,
  }) => _factory.createWithTimestamps(
    syncId: syncId, title: title, contentJson: contentJson, folderId: folderId,
    customTagIds: customTagIds, createdAt: createdAt, updatedAt: updatedAt,
    isFavorite: isFavorite, isArchived: isArchived, isDeleted: isDeleted,
    deletedAt: deletedAt, userId: userId,
    moodTags: moodTags, activityTags: activityTags,
    timeTags: timeTags, personalGrowthTags: personalGrowthTags,
    source: source, internalLinks: internalLinks,
  );

  /// Updates a note. Set [skipEmbeddingRefresh] for metadata-only updates;
  /// set [preserveTimestamps] for syncId backfill or import/sync merges.
  Future<void> updateNote(Note note, {bool skipEmbeddingRefresh = false, bool preserveTimestamps = false}) async {
    await _noteRepository.updateNote(note, preserveTimestamps: preserveTimestamps);
    if (!skipEmbeddingRefresh) {
      _embeddingService?.embedNote(note);
    }
  }

  // ── Soft-delete (trash / recently deleted) ─────────────────────────────────

  Future<void> softDeleteNote(int noteId) => _trash.softDelete(noteId);
  Future<void> restoreNoteFromTrash(int noteId) => _trash.restore(noteId);
  Future<void> permanentDeleteNote(int noteId) => _trash.permanentDelete(noteId);
  Future<void> purgeExpiredDeletedNotes({Duration maxAge = const Duration(days: 30)}) =>
      _trash.purgeExpired(maxAge: maxAge, deletedNotes: deletedNotes);

  // ── Google Drive trash sync ────────────────────────────────────────────────

  Future<void> softDeleteNoteWithDriveSync(int noteId) => _driveTrashSync.softDeleteWithDriveSync(noteId);
  Future<void> restoreNoteFromTrashWithDriveSync(int noteId) => _driveTrashSync.restoreWithDriveSync(noteId);
  Future<void> permanentDeleteNoteWithDriveSync(int noteId) => _driveTrashSync.permanentDeleteWithDriveSync(noteId);
  Future<void> permanentlyDeleteNoteOnDrive(String driveFileId) => _driveTrashSync.permanentlyDeleteOnDrive(driveFileId);
  Future<void> reconcileTrashStateWithDrive(Map<String, dynamic> driveNoteJson) =>
      _driveTrashSync.reconcileTrashStateWithDrive(driveNoteJson);

  // ── Folder hard-delete ─────────────────────────────────────────────────────

  /// Delete a folder and move its notes to the default folder.
  Future<void> deleteFolder(String folderId) async {
    final defaultFolder = _folderRepository.getDefaultFolder();
    if (defaultFolder != null) {
      final notesToMove = _noteRepository.getNotesByFolder(folderId);
      for (final note in notesToMove) {
        note.moveToFolder(defaultFolder.folderId);
        await _noteRepository.updateNote(note);
      }
    }
    await _folderRepository.deleteFolder(folderId);
  }

  // ── Read-only delegates ────────────────────────────────────────────────────

  List<Note> get notes => _noteRepository.getActiveNotes();
  List<Note> notesForUser(String? userId) => _noteRepository.getActiveNotesForUser(userId);
  List<Note> get deletedNotes => _noteRepository.getDeletedNotes();
  List<Note> deletedNotesForUser(String? userId) => _noteRepository.getDeletedNotesForUser(userId);
  List<Note> get favoriteNotes => _noteRepository.getFavoriteNotes();
  List<Note> favoriteNotesForUser(String? userId) => _noteRepository.getFavoriteNotesForUser(userId);
  List<Note> get archivedNotes => _noteRepository.getArchivedNotes();
  List<Note> archivedNotesForUser(String? userId) => _noteRepository.getArchivedNotesForUser(userId);
  List<String> get allTags => _noteRepository.getAllTags();
  int get totalNotes => _noteRepository.totalNotes;
  int get totalWords => _noteRepository.totalWords;
  int get totalCharacters => _noteRepository.totalCharacters;

  Note? getNote(int noteId) => _noteRepository.getNoteById(noteId);
  List<Note> searchNotes(String query) => _noteRepository.searchNotes(query);
  List<Note> searchNotesForUser(String? userId, String query) => _noteRepository.searchNotesForUser(userId, query);
  List<Note> getNotesByFolder(String folderId) => _noteRepository.getNotesByFolder(folderId);
  List<Note> getNotesByFolderForUser(String? userId, String folderId) =>
      _noteRepository.getNotesByFolderForUser(userId, folderId);
  List<Note> getNotesByTag(String tag) => _noteRepository.getNotesByTag(tag);

  Future<Folder> createFolder({required String name, String? description, String? color}) =>
      _folderRepository.createFolder(name: name, description: description, color: color);
  Future<Folder> createFolderWithTimestamps({
    required String folderId,
    required String name,
    String? description,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool isDefault = false,
    int noteCount = 0,
  }) => _folderRepository.createFolderWithTimestamps(
    folderId: folderId,
    name: name,
    description: description,
    color: color,
    createdAt: createdAt,
    updatedAt: updatedAt,
    isDefault: isDefault,
    noteCount: noteCount,
  );
  Future<void> updateFolder(Folder folder) => _folderRepository.updateFolder(folder);

  List<Folder> get folders => _folderRepository.getAllFolders();
  Folder? getFolder(String folderId) => _folderRepository.getFolderById(folderId);
  Folder? get defaultFolder => _folderRepository.getDefaultFolder();

  void addListener(Function() listener) {
    _noteRepository.addListener(listener);
    _folderRepository.addListener(listener);
  }

  void removeListener(Function() listener) {
    _noteRepository.removeListener(listener);
    _folderRepository.removeListener(listener);
  }

  void dispose() {
    _noteRepository.dispose();
    _folderRepository.dispose();
  }

  // ── One-time migration ─────────────────────────────────────────────────────

  /// Assigns deterministic syncId to legacy notes that have none. Without
  /// this, syncId-keyed lookups (`getNoteBySync`) miss them and they
  /// duplicate on first sync.
  Future<void> _backfillSyncIdsIfNeeded() async {
    final allNotes = _noteRepository.getAllNotes();
    for (final note in allNotes) {
      if (note.syncId.isEmpty) {
        note.syncId = NoteSyncId.deterministic(note.title, note.createdAt);
        await updateNote(note, skipEmbeddingRefresh: true, preserveTimestamps: true);
        _logger.d('Backfilled syncId for note id=${note.id} title=${note.title}');
      }
    }
  }
}
