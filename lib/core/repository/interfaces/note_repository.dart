import 'package:noteminds/models/note.dart';

/// Interface for note repository operations
/// Follows Interface Segregation Principle - only note-related operations
abstract class INoteRepository {
  /// Initialize the repository
  Future<void> initialize();

  /// Get all notes
  List<Note> getAllNotes();

  /// Get a note by ID
  Note? getNoteById(int id);

  /// Create a new note
  Future<Note> createNote({String? title, String? contentJson, String? folderId, List<String> tags});

  /// Create a new note with preserved timestamps (for import operations)
  Future<Note> createNoteWithTimestamps({
    String? title,
    String? contentJson,
    String? folderId,
    List<String> tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool isFavorite,
    bool isArchived,
  });

  /// Update an existing note
  Future<void> updateNote(Note note);

  /// Delete a note by ID
  Future<void> deleteNote(int id);

  /// Search notes by query
  List<Note> searchNotes(String query);

  /// Get notes by folder ID
  List<Note> getNotesByFolder(String folderId);

  /// Get favorite notes
  List<Note> getFavoriteNotes();

  /// Get archived notes
  List<Note> getArchivedNotes();

  /// Get notes by tag
  List<Note> getNotesByTag(String tag);

  /// Get all unique tags
  List<String> getAllTags();

  /// Get total note count
  int get totalNotes;

  /// Get total word count
  int get totalWords;

  /// Get total character count
  int get totalCharacters;

  /// Add a listener for data changes
  void addListener(Function() listener);

  /// Remove a listener
  void removeListener(Function() listener);

  /// Dispose the repository
  void dispose();
}
