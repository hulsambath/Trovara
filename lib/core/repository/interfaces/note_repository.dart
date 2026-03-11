import 'package:trovara/models/note.dart';

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

  /// Get **active** notes that belong to [userId].
  /// Also includes anonymous notes (userId == null).
  List<Note> getActiveNotesForUser(String? userId);

  /// Get all notes **including** deleted ones.
  ///
  /// Use sparingly -- prefer [getActiveNotes] or [getDeletedNotes].
  /// Mainly needed for export / sync operations.
  List<Note> getAllNotes();

  /// Get a note by ID (regardless of deleted state).
  Note? getNoteById(int id);

  /// Get a note by its stable sync UUID (regardless of deleted state).
  /// Returns null if no note with that syncId exists locally.
  Note? getNoteBySync(String syncId);

  /// Search **active** notes by query.
  List<Note> searchNotes(String query);

  /// Search **active** notes by query, scoped to [userId] (includes anonymous).
  List<Note> searchNotesForUser(String? userId, String query);

  /// Get **active** notes in a specific folder.
  List<Note> getNotesByFolder(String folderId);

  /// Get **active** notes in a specific folder, scoped to [userId] (includes anonymous).
  List<Note> getNotesByFolderForUser(String? userId, String folderId);

  /// Get **active** favorite notes.
  List<Note> getFavoriteNotes();

  /// Get **active** favorite notes, scoped to [userId] (includes anonymous).
  List<Note> getFavoriteNotesForUser(String? userId);

  /// Get **active** archived notes.
  List<Note> getArchivedNotes();

  /// Get **active** archived notes, scoped to [userId] (includes anonymous).
  List<Note> getArchivedNotesForUser(String? userId);

  /// Get **active** notes by tag.
  List<Note> getNotesByTag(String tag);

  /// Get all unique tags (from active notes only).
  List<String> getAllTags();

  // ───────────────────── Trash / soft-delete queries ─────────────────────

  /// Get all soft-deleted notes (the "Recently Deleted" / trash bin).
  List<Note> getDeletedNotes();

  /// Get soft-deleted notes for [userId] (includes anonymous).
  List<Note> getDeletedNotesForUser(String? userId);

  // ───────────────────── Mutations ─────────────────────

  /// Create a new note.
  Future<Note> createNote({
    String? title,
    String? contentJson,
    String? folderId,
    List<int> customTagIds,
    String? userId,
  });

  /// Create a new note with preserved timestamps (for import operations).
  Future<Note> createNoteWithTimestamps({
    String? syncId,
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
    String? userId,
    List<String>? moodTags,
    List<String>? activityTags,
    List<String>? timeTags,
    List<String>? personalGrowthTags,
  });

  /// Update an existing note.
  ///
  /// When [preserveTimestamps] is true, [note.updatedAt] is not overwritten
  /// (for import/sync so merged timestamps are preserved).
  Future<void> updateNote(Note note, {bool preserveTimestamps = false});

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
