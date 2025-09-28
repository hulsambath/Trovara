import 'package:noteminds/core/repository/base/base_repository.dart';
import 'package:noteminds/core/repository/base/objectbox_store_manager.dart';
import 'package:noteminds/core/repository/interfaces/note_repository.dart';
import 'package:noteminds/models/note.dart';
import 'package:noteminds/objectbox.g.dart';

/// ObjectBox implementation of the note repository
/// Follows Dependency Inversion Principle - depends on abstraction, not concrete implementation
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

  @override
  List<Note> getAllNotes() => _noteBox.getAll();

  @override
  Note? getNoteById(int id) => _noteBox.get(id);

  @override
  Future<Note> createNote({
    String? title,
    String? contentJson,
    String? folderId,
    List<int> customTagIds = const [],
  }) async {
    final note = Note(
      title: title ?? 'Untitled',
      contentJson: contentJson ?? '{"ops":[{"insert":"\\n"}]}',
      folderId: folderId ?? 'default',
      customTagIds: customTagIds,
    );

    final id = _noteBox.put(note);
    note.id = id;

    notifyListeners();
    return note;
  }

  /// Create a note with preserved timestamps (for import operations)
  @override
  Future<Note> createNoteWithTimestamps({
    String? title,
    String? contentJson,
    String? folderId,
    List<int> customTagIds = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
    bool isFavorite = false,
    bool isArchived = false,
  }) async {
    final note = Note(
      title: title ?? 'Untitled',
      contentJson: contentJson ?? '{"ops":[{"insert":"\\n"}]}',
      folderId: folderId ?? 'default',
      customTagIds: customTagIds,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isFavorite: isFavorite,
      isArchived: isArchived,
    );

    final id = _noteBox.put(note);
    note.id = id;

    notifyListeners();
    return note;
  }

  @override
  Future<void> updateNote(Note note) async {
    note.updatedAt = DateTime.now();
    _noteBox.put(note);
    notifyListeners();
  }

  @override
  Future<void> deleteNote(int id) async {
    _noteBox.remove(id);
    notifyListeners();
  }

  @override
  List<Note> searchNotes(String query) {
    if (query.isEmpty) return _noteBox.getAll();

    final lowercaseQuery = query.toLowerCase();
    return _noteBox
        .getAll()
        .where(
          (note) =>
              note.title.toLowerCase().contains(lowercaseQuery) ||
              note.contentJson.toLowerCase().contains(lowercaseQuery) ||
              note.customTagIds.any((tagId) => tagId.toString().contains(lowercaseQuery)),
        )
        .toList();
  }

  @override
  List<Note> getNotesByFolder(String folderId) => _noteBox.query(Note_.folderId.equals(folderId)).build().find();

  @override
  List<Note> getFavoriteNotes() => _noteBox.query(Note_.isFavorite.equals(true)).build().find();

  @override
  List<Note> getArchivedNotes() => _noteBox.query(Note_.isArchived.equals(true)).build().find();

  @override
  List<Note> getNotesByTag(String tag) => [];

  @override
  List<String> getAllTags() => [];

  @override
  int get totalNotes => _noteBox.count();

  @override
  int get totalWords => _noteBox.getAll().fold(0, (sum, note) => sum + note.wordCount);

  @override
  int get totalCharacters => _noteBox.getAll().fold(0, (sum, note) => sum + note.characterCount);

  @override
  void dispose() {
    clearListeners();
    // Don't close the store here as it's shared
  }
}
