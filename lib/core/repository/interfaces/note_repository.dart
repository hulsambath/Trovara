import 'package:notemyminds/models/note.dart';

/// Interface for note repository operations.
///
/// All query methods that return "active" notes MUST exclude soft-deleted notes
/// (isDeleted == true). Deleted notes are only returned through [getDeletedNotes].
///
/// Follows Interface Segregation Principle - only note-related operations.
abstract class INoteRepository {
  /// Initialize the repository
  Future<void> initialize();

  // ───────────────────── Active note queries ─────────────────────

  /// Get all **active** (non-deleted) notes.
  List<Note> getActiveNotes();

  /// Get all notes **including** deleted ones.
  ///
  /// Use sparingly -- prefer [getActiveNotes] or [getDeletedNotes].
  /// Mainly needed for export / sync operations.
  List<Note> getAllNotes();

  /// Get a note by ID (regardless of deleted state).
  Note? getNoteById(int id);

  /// Search **active** notes by query.
  List<Note> searchNotes(String query);

  /// Get **active** notes in a specific folder.
  List<Note> getNotesByFolder(String folderId);

  /// Get **active** favorite notes.
  List<Note> getFavoriteNotes();

  /// Get **active** archived notes.
  List<Note> getArchivedNotes();

  /// Get **active** notes by tag.
  List<Note> getNotesByTag(String tag);

  /// Get all unique tags (from active notes only).
  List<String> getAllTags();

  // ───────────────────── Trash / soft-delete queries ─────────────────────

  /// Get all soft-deleted notes (the "Recently Deleted" / trash bin).
  List<Note> getDeletedNotes();

  // ───────────────────── Mutations ─────────────────────

  /// Create a new note.
  Future<Note> createNote({String? title, String? contentJson, String? folderId, List<int> customTagIds});

  /// Create a new note with preserved timestamps (for import operations).
  Future<Note> createNoteWithTimestamps({
    String? title,
    String? contentJson,
    String? folderId,
    List<int> customTagIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool isFavorite,
    bool isArchived,
    bool isDeleted,
    DateTime? deletedAt,
  });

  /// Update an existing note.
  Future<void> updateNote(Note note);

  /// Permanently remove a note from the database.
  Future<void> deleteNote(int id);

  // ───────────────────── Statistics (active notes only) ─────────────────────

  /// Total count of **active** notes.
  int get totalNotes;

  /// Total word count across **active** notes.
  int get totalWords;

  /// Total character count across **active** notes.
  int get totalCharacters;

  // ───────────────────── Lifecycle ─────────────────────

  /// Add a listener for data changes.
  void addListener(Function() listener);

  /// Remove a listener.
  void removeListener(Function() listener);

  /// Dispose the repository.
  void dispose();
}
