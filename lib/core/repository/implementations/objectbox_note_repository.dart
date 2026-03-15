import 'package:trovara/core/repository/base/base_repository.dart';
import 'package:trovara/core/repository/base/objectbox_store_manager.dart';
import 'package:trovara/core/repository/interfaces/note_repository.dart';
import 'package:trovara/models/note.dart';
import 'package:trovara/objectbox.g.dart';

/// ObjectBox implementation of the note repository.
///
/// Every query method that returns "active" notes applies an
/// `isDeleted == false` condition at the **database level** so the service
/// layer never has to filter in memory.
///
/// Follows Dependency Inversion Principle - depends on abstraction, not
/// concrete implementation.
class ObjectBoxNoteRepository extends BaseRepository implements INoteRepository {
  late Box<Note> _noteBox;
  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    final store = await ObjectBoxStoreManager().store;
    _noteBox = store.box<Note>();
    _isInitialized = true;
  }

  // ───────────────────── Active note queries ─────────────────────

  @override
  List<Note> getActiveNotes() => _noteBox.query(Note_.isDeleted.equals(false)).build().find();

  @override
  List<Note> getActiveNotesForUser(String? userId) {
    if (userId == null) return getActiveNotes();
    final condition = Note_.isDeleted.equals(false) & _userOwnershipCondition(userId);
    return _noteBox.query(condition).build().find();
  }

  @override
  List<Note> getAllNotes() => _noteBox.getAll();

  @override
  Note? getNoteById(int id) => _noteBox.get(id);

  @override
  Note? getNoteBySync(String syncId) => _noteBox.query(Note_.syncId.equals(syncId)).build().findFirst();

  @override
  List<Note> searchNotes(String query) {
    if (query.isEmpty) return getActiveNotes();
    return _filterBySearchQuery(getActiveNotes(), query);
  }

  @override
  List<Note> searchNotesForUser(String? userId, String query) {
    if (query.isEmpty) return getActiveNotesForUser(userId);
    return _filterBySearchQuery(getActiveNotesForUser(userId), query);
  }

  @override
  List<Note> getNotesByFolder(String folderId) =>
      _noteBox.query(Note_.folderId.equals(folderId) & Note_.isDeleted.equals(false)).build().find();

  @override
  List<Note> getNotesByFolderForUser(String? userId, String folderId) {
    if (userId == null) return getNotesByFolder(folderId);
    final condition = Note_.folderId.equals(folderId) & Note_.isDeleted.equals(false) & _userOwnershipCondition(userId);
    return _noteBox.query(condition).build().find();
  }

  @override
  List<Note> getFavoriteNotes() =>
      _noteBox.query(Note_.isFavorite.equals(true) & Note_.isDeleted.equals(false)).build().find();

  @override
  List<Note> getFavoriteNotesForUser(String? userId) {
    if (userId == null) return getFavoriteNotes();
    final condition = Note_.isFavorite.equals(true) & Note_.isDeleted.equals(false) & _userOwnershipCondition(userId);
    return _noteBox.query(condition).build().find();
  }

  @override
  List<Note> getArchivedNotes() =>
      _noteBox.query(Note_.isArchived.equals(true) & Note_.isDeleted.equals(false)).build().find();

  @override
  List<Note> getArchivedNotesForUser(String? userId) {
    if (userId == null) return getArchivedNotes();
    final condition = Note_.isArchived.equals(true) & Note_.isDeleted.equals(false) & _userOwnershipCondition(userId);
    return _noteBox.query(condition).build().find();
  }

  @override
  List<Note> getNotesByTag(String tag) => [];

  @override
  List<String> getAllTags() => [];

  // ───────────────────── Trash / soft-delete queries ─────────────────────

  @override
  List<Note> getDeletedNotes() => _noteBox.query(Note_.isDeleted.equals(true)).build().find();

  @override
  List<Note> getDeletedNotesForUser(String? userId) {
    if (userId == null) return getDeletedNotes();
    final condition = Note_.isDeleted.equals(true) & _userOwnershipCondition(userId);
    return _noteBox.query(condition).build().find();
  }

  // ───────────────────── Private helpers ─────────────────────

  /// Builds an ObjectBox condition that matches notes owned by [userId] or
  /// anonymous notes (userId is null). Only called when [userId] is non-null;
  /// callers bypass the filter and use unscoped queries when userId is null.
  Condition<Note> _userOwnershipCondition(String userId) => Note_.userId.equals(userId) | Note_.userId.isNull();

  List<Note> _filterBySearchQuery(List<Note> notes, String query) {
    final lowercaseQuery = query.toLowerCase();
    return notes
        .where(
          (note) =>
              note.title.toLowerCase().contains(lowercaseQuery) ||
              note.contentJson.toLowerCase().contains(lowercaseQuery) ||
              note.customTagIds.any((tagId) => tagId.toString().contains(lowercaseQuery)),
        )
        .toList();
  }

  // ───────────────────── Mutations ─────────────────────

  @override
  Future<Note> createNote({
    String? title,
    String? contentJson,
    String? folderId,
    List<int> customTagIds = const [],
    String? userId,
  }) async {
    final note = Note(
      title: title ?? 'Untitled',
      contentJson: contentJson ?? '{"ops":[{"insert":"\\n"}]}',
      folderId: folderId ?? 'default',
      customTagIds: customTagIds,
      userId: userId,
    );

    final id = _noteBox.put(note);
    note.id = id;

    notifyListeners();
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
      syncId: syncId,
      title: title ?? 'Untitled',
      contentJson: contentJson ?? '{"ops":[{"insert":"\\n"}]}',
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

    final id = _noteBox.put(note);
    note.id = id;

    notifyListeners();
    return note;
  }

  @override
  Future<void> updateNote(Note note, {bool preserveTimestamps = false}) async {
    if (!preserveTimestamps) {
      note.updatedAt = DateTime.now();
    }
    _noteBox.put(note);
    notifyListeners();
  }

  @override
  Future<void> deleteNote(int id) async {
    _noteBox.remove(id);
    notifyListeners();
  }

  // ───────────────────── Statistics (active notes only) ─────────────────────

  @override
  int get totalNotes => _noteBox.query(Note_.isDeleted.equals(false)).build().count();

  @override
  int get totalWords => getActiveNotes().fold(0, (sum, note) => sum + note.wordCount);

  @override
  int get totalCharacters => getActiveNotes().fold(0, (sum, note) => sum + note.characterCount);

  // ───────────────────── Lifecycle ─────────────────────

  @override
  void dispose() {
    clearListeners();
    // Don't close the store here as it's shared
  }
}
