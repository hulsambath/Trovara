import 'package:flutter/foundation.dart';
import 'package:noteminds/core/repository/interfaces/folder_repository.dart';
import 'package:noteminds/core/repository/interfaces/note_repository.dart';
import 'package:noteminds/models/folder.dart';
import 'package:noteminds/models/note.dart';

/// Service layer for note operations
/// Follows Single Responsibility Principle - coordinates between repositories
/// Follows Dependency Inversion Principle - depends on abstractions
class NoteService {
  final INoteRepository _noteRepository;
  final IFolderRepository _folderRepository;

  NoteService({required INoteRepository noteRepository, required IFolderRepository folderRepository})
    : _noteRepository = noteRepository,
      _folderRepository = folderRepository;

  /// Initialize both repositories
  Future<void> initialize() async {
    await _noteRepository.initialize();
    await _folderRepository.initialize();
  }

  /// Export all notes and folders to a serializable JSON map.
  Map<String, dynamic> exportAllToJson() {
    final notes = _noteRepository.getAllNotes().map((n) => n.toJson()).toList();
    final folders = _folderRepository.getAllFolders().map((f) => f.toJson()).toList();
    return {'version': 1, 'exportedAt': DateTime.now().toIso8601String(), 'notes': notes, 'folders': folders};
  }

  /// Import notes and folders from JSON map. This performs an upsert.
  Future<void> importAllFromJson(Map<String, dynamic> json) async {
    try {
      final List<dynamic> folders = (json['folders'] as List<dynamic>? ?? []);
      for (final f in folders) {
        final importFolder = Folder.fromJson(Map<String, dynamic>.from(f as Map));

        // Match by folderId; do not reuse imported numeric ID for new inserts
        final existing = _folderRepository.getFolderById(importFolder.folderId);
        if (existing == null) {
          // Use createFolderWithTimestamps to preserve original timestamps
          await createFolderWithTimestamps(
            folderId: importFolder.folderId,
            name: importFolder.name,
            description: importFolder.description,
            color: importFolder.color,
            createdAt: importFolder.createdAt,
            updatedAt: importFolder.updatedAt,
            isDefault: importFolder.isDefault,
            noteCount: importFolder.noteCount,
          );
        } else {
          // Preserve existing.id, update fields
          existing
            ..name = importFolder.name
            ..description = importFolder.description
            ..color = importFolder.color
            ..isDefault = importFolder.isDefault
            ..noteCount = importFolder.noteCount
            ..updatedAt = importFolder.updatedAt; // Preserve original updatedAt
          await _folderRepository.updateFolder(existing);
        }
      }

      final List<dynamic> notes = (json['notes'] as List<dynamic>? ?? []);
      for (final n in notes) {
        final importNote = Note.fromJson(Map<String, dynamic>.from(n as Map));

        if (importNote.id != 0) {
          final existing = _noteRepository.getNoteById(importNote.id);
          if (existing != null) {
            await _noteRepository.updateNote(importNote);
            continue;
          }
        }

        // Use createNoteWithTimestamps to preserve original timestamps
        await createNoteWithTimestamps(
          title: importNote.title,
          contentJson: importNote.contentJson,
          folderId: importNote.folderId,
          tags: importNote.tags,
          createdAt: importNote.createdAt,
          updatedAt: importNote.updatedAt,
          isFavorite: importNote.isFavorite,
          isArchived: importNote.isArchived,
        );
      }
    } finally {}
  }

  /// Merge local and remote data intelligently (Git-like merge behavior)
  Future<Map<String, dynamic>> mergeWithRemoteData(Map<String, dynamic> remoteData) async {
    final localData = exportAllToJson();

    final mergedData = <String, dynamic>{
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'notes': <Map<String, dynamic>>[],
      'folders': <Map<String, dynamic>>[],
    };

    // Merge folders
    final localFolders = Map<String, Map<String, dynamic>>.fromEntries(
      (localData['folders'] as List<dynamic>).map((f) => MapEntry(f['folderId'] as String, f as Map<String, dynamic>)),
    );
    final remoteFolders = Map<String, Map<String, dynamic>>.fromEntries(
      (remoteData['folders'] as List<dynamic>).map((f) => MapEntry(f['folderId'] as String, f as Map<String, dynamic>)),
    );

    // Merge folders - prefer the one with the latest updatedAt
    final allFolderIds = <String>{...localFolders.keys, ...remoteFolders.keys};
    int foldersAdded = 0;
    int foldersMerged = 0;
    for (final folderId in allFolderIds) {
      final localFolder = localFolders[folderId];
      final remoteFolder = remoteFolders[folderId];

      if (localFolder == null) {
        // Only exists remotely
        mergedData['folders'].add(remoteFolder!);
        foldersAdded++;
      } else if (remoteFolder == null) {
        // Only exists locally
        mergedData['folders'].add(localFolder);
        foldersAdded++;
      } else {
        // Exists in both - merge based on updatedAt
        final localUpdatedAt = DateTime.parse(localFolder['updatedAt'] as String);
        final remoteUpdatedAt = DateTime.parse(remoteFolder['updatedAt'] as String);

        if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
          mergedData['folders'].add(remoteFolder);
        } else {
          mergedData['folders'].add(localFolder);
        }
        foldersMerged++;
      }
    }
    if (kDebugMode) {
      print(
        'Folder merge complete - Added: $foldersAdded, Merged: $foldersMerged, Total: ${mergedData['folders'].length}',
      );
    }

    // Merge notes using intelligent conflict resolution
    final localNotes = (localData['notes'] as List<dynamic>).cast<Map<String, dynamic>>();
    final remoteNotes = (remoteData['notes'] as List<dynamic>).cast<Map<String, dynamic>>();

    // Create maps for quick lookup
    final localNotesMap = <String, Map<String, dynamic>>{};
    final remoteNotesMap = <String, Map<String, dynamic>>{};

    // Index local notes by title + createdAt (more reliable than just title)
    for (final note in localNotes) {
      final key = '${note['title']}_${note['createdAt']}';
      localNotesMap[key] = note;
    }

    // Index remote notes by title + createdAt
    for (final note in remoteNotes) {
      final key = '${note['title']}_${note['createdAt']}';
      remoteNotesMap[key] = note;
    }

    // Merge notes
    final allNoteKeys = <String>{...localNotesMap.keys, ...remoteNotesMap.keys};
    int notesAdded = 0;
    int notesMerged = 0;
    for (final noteKey in allNoteKeys) {
      final localNote = localNotesMap[noteKey];
      final remoteNote = remoteNotesMap[noteKey];

      if (localNote == null) {
        // Only exists remotely - add it
        mergedData['notes'].add(remoteNote!);
        notesAdded++;
      } else if (remoteNote == null) {
        // Only exists locally - add it
        mergedData['notes'].add(localNote);
        notesAdded++;
      } else {
        // Exists in both - resolve conflict based on updatedAt
        final localUpdatedAt = DateTime.parse(localNote['updatedAt'] as String);
        final remoteUpdatedAt = DateTime.parse(remoteNote['updatedAt'] as String);

        if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
          // Remote is newer - use remote version
          mergedData['notes'].add(remoteNote);
        } else if (localUpdatedAt.isAfter(remoteUpdatedAt)) {
          // Local is newer - use local version
          mergedData['notes'].add(localNote);
        } else {
          // Same timestamp - prefer local version (user's current state)
          mergedData['notes'].add(localNote);
        }
        notesMerged++;
      }
    }
    if (kDebugMode) {
      print('Note merge complete - Added: $notesAdded, Merged: $notesMerged, Total: ${mergedData['notes'].length}');
    }

    return mergedData;
  }

  Future<Note> createNote({String? title, String? contentJson, String? folderId, List<String> tags = const []}) async {
    final note = await _noteRepository.createNote(
      title: title,
      contentJson: contentJson,
      folderId: folderId,
      tags: tags,
    );

    // Update folder note count
    final folder = _folderRepository.getFolderById(folderId ?? 'default');
    if (folder != null) {
      folder.incrementNoteCount();
      await _folderRepository.updateFolder(folder);
    }

    return note;
  }

  /// Create a note with preserved timestamps (for import operations)
  Future<Note> createNoteWithTimestamps({
    String? title,
    String? contentJson,
    String? folderId,
    List<String> tags = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
    bool isFavorite = false,
    bool isArchived = false,
  }) async {
    final note = await _noteRepository.createNoteWithTimestamps(
      title: title,
      contentJson: contentJson,
      folderId: folderId,
      tags: tags,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isFavorite: isFavorite,
      isArchived: isArchived,
    );

    // Update folder note count
    final folder = _folderRepository.getFolderById(folderId ?? 'default');
    if (folder != null) {
      folder.incrementNoteCount();
      await _folderRepository.updateFolder(folder);
    }

    return note;
  }

  /// Create a folder with preserved timestamps (for import operations)
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
    final folder = await _folderRepository.createFolderWithTimestamps(
      folderId: folderId,
      name: name,
      description: description,
      color: color,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isDefault: isDefault,
      noteCount: noteCount,
    );

    return folder;
  }

  /// Delete a note and update folder count
  Future<void> deleteNote(int noteId) async {
    final note = _noteRepository.getNoteById(noteId);
    if (note != null) {
      // Update folder note count
      final folder = _folderRepository.getFolderById(note.folderId);
      if (folder != null) {
        folder.decrementNoteCount();
        await _folderRepository.updateFolder(folder);
      }

      await _noteRepository.deleteNote(noteId);
    }
  }

  /// Delete a folder and move notes to default folder
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

  // Delegate other operations to repositories
  List<Note> get notes => _noteRepository.getAllNotes();
  List<Note> get favoriteNotes => _noteRepository.getFavoriteNotes();
  List<Note> get archivedNotes => _noteRepository.getArchivedNotes();
  List<String> get allTags => _noteRepository.getAllTags();
  int get totalNotes => _noteRepository.totalNotes;
  int get totalWords => _noteRepository.totalWords;
  int get totalCharacters => _noteRepository.totalCharacters;

  Note? getNote(int noteId) => _noteRepository.getNoteById(noteId);
  List<Note> searchNotes(String query) => _noteRepository.searchNotes(query);
  List<Note> getNotesByFolder(String folderId) => _noteRepository.getNotesByFolder(folderId);
  List<Note> getNotesByTag(String tag) => _noteRepository.getNotesByTag(tag);

  Future<void> updateNote(Note note) => _noteRepository.updateNote(note);
  Future<Folder> createFolder({required String name, String? description, String? color}) =>
      _folderRepository.createFolder(name: name, description: description, color: color);
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
}
