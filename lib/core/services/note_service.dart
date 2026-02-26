import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:trovara/core/repository/interfaces/folder_repository.dart';
import 'package:trovara/core/repository/interfaces/note_repository.dart';
import 'package:trovara/core/services/embedding_service.dart';
import 'package:trovara/core/services/google_drive_service.dart';
import 'package:trovara/models/folder.dart';
import 'package:trovara/models/note.dart';

/// Service layer for note operations.
///
/// Follows Single Responsibility Principle - coordinates between repositories
/// and encapsulates business rules (soft-delete, folder counts, sync merge).
///
/// Follows Dependency Inversion Principle - depends on abstractions
/// ([INoteRepository], [IFolderRepository]).
///
/// Also handles Google Drive trash synchronization to keep local state
/// in sync with Google Drive trash operations.
class NoteService {
  final INoteRepository _noteRepository;
  final IFolderRepository _folderRepository;
  final GoogleDriveService? _driveService;
  final EmbeddingService? _embeddingService;
  final Logger _logger = Logger();

  NoteService({
    required INoteRepository noteRepository,
    required IFolderRepository folderRepository,
    GoogleDriveService? driveService,
    EmbeddingService? embeddingService,
  }) : _noteRepository = noteRepository,
       _folderRepository = folderRepository,
       _driveService = driveService,
       _embeddingService = embeddingService;

  /// Initialize both repositories
  Future<void> initialize() async {
    await _noteRepository.initialize();
    await _folderRepository.initialize();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Export / Import / Sync
  // ═══════════════════════════════════════════════════════════════════════════

  /// Export notes and folders to a JSON map for Drive backup.
  ///
  /// Includes:
  /// - All active notes
  /// - Soft-deleted notes (in Recently Deleted, not permanently deleted)
  ///
  /// Excludes:
  /// - Permanently deleted notes (not in local DB)
  ///
  /// This ensures permanently deleted notes stay deleted after sync.
  Map<String, dynamic> exportAllToJson() {
    // Use getAllNotes which includes soft-deleted but NOT permanently deleted
    // Permanently deleted notes are NOT in the DB at all
    final notes = _noteRepository.getAllNotes().map((n) => n.toJson()).toList();
    final folders = _folderRepository.getAllFolders().map((f) => f.toJson()).toList();
    return {'version': 1, 'exportedAt': DateTime.now().toIso8601String(), 'notes': notes, 'folders': folders};
  }

  /// Import notes and folders from a JSON map. This performs an upsert.
  Future<void> importAllFromJson(Map<String, dynamic> json) async {
    try {
      final List<dynamic> folders = (json['folders'] as List<dynamic>? ?? []);
      for (final f in folders) {
        final importFolder = Folder.fromJson(Map<String, dynamic>.from(f as Map));

        final existing = _folderRepository.getFolderById(importFolder.folderId);
        if (existing == null) {
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
          existing
            ..name = importFolder.name
            ..description = importFolder.description
            ..color = importFolder.color
            ..isDefault = importFolder.isDefault
            ..noteCount = importFolder.noteCount
            ..updatedAt = importFolder.updatedAt;
          await _folderRepository.updateFolder(existing);
        }
      }

      final List<dynamic> notes = (json['notes'] as List<dynamic>? ?? []);
      for (final n in notes) {
        final importNote = Note.fromJson(Map<String, dynamic>.from(n as Map));

        if (importNote.id != 0) {
          final existing = _noteRepository.getNoteById(importNote.id);
          if (existing != null) {
            // CRITICAL: Don't re-import permanently deleted notes
            // If note was deleted locally (not in DB), keep it deleted
            // Only update if it still exists locally
            await _noteRepository.updateNote(importNote);
            continue;
          } else {
            // CRITICAL: Note doesn't exist locally
            // This means it was permanently deleted locally
            // Skip re-importing it from Drive backup
            _logger.i('Skipping import of permanently deleted note ${importNote.id}');
            continue;
          }
        }

        await createNoteWithTimestamps(
          title: importNote.title,
          contentJson: importNote.contentJson,
          folderId: importNote.folderId,
          customTagIds: importNote.customTagIds,
          createdAt: importNote.createdAt,
          updatedAt: importNote.updatedAt,
          isFavorite: importNote.isFavorite,
          isArchived: importNote.isArchived,
          isDeleted: importNote.isDeleted,
          deletedAt: importNote.deletedAt,
        );
      }
    } finally {}

    // Re-embed any notes that are new or changed after import
    _embeddingService?.reembedStaleNotes(_noteRepository.getActiveNotes());
  }

  /// Merge local and remote data intelligently (Git-like merge behaviour).
  Future<Map<String, dynamic>> mergeWithRemoteData(Map<String, dynamic> remoteData) async {
    final localData = exportAllToJson();

    final mergedData = <String, dynamic>{
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'notes': <Map<String, dynamic>>[],
      'folders': <Map<String, dynamic>>[],
    };

    // ── Merge folders ──
    final localFolders = Map<String, Map<String, dynamic>>.fromEntries(
      (localData['folders'] as List<dynamic>).map((f) => MapEntry(f['folderId'] as String, f as Map<String, dynamic>)),
    );
    final remoteFolders = Map<String, Map<String, dynamic>>.fromEntries(
      (remoteData['folders'] as List<dynamic>).map((f) => MapEntry(f['folderId'] as String, f as Map<String, dynamic>)),
    );

    final allFolderIds = <String>{...localFolders.keys, ...remoteFolders.keys};
    int foldersAdded = 0;
    int foldersMerged = 0;
    for (final folderId in allFolderIds) {
      final localFolder = localFolders[folderId];
      final remoteFolder = remoteFolders[folderId];

      if (localFolder == null) {
        mergedData['folders'].add(remoteFolder!);
        foldersAdded++;
      } else if (remoteFolder == null) {
        mergedData['folders'].add(localFolder);
        foldersAdded++;
      } else {
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
        'Folder merge complete - Added: $foldersAdded, '
        'Merged: $foldersMerged, Total: ${mergedData['folders'].length}',
      );
    }

    // ── Merge notes ──
    final localNotes = (localData['notes'] as List<dynamic>).cast<Map<String, dynamic>>();
    final remoteNotes = (remoteData['notes'] as List<dynamic>).cast<Map<String, dynamic>>();

    final localNotesMap = <String, Map<String, dynamic>>{};
    final remoteNotesMap = <String, Map<String, dynamic>>{};

    for (final note in localNotes) {
      final key = '${note['title']}_${note['createdAt']}';
      localNotesMap[key] = note;
    }
    for (final note in remoteNotes) {
      final key = '${note['title']}_${note['createdAt']}';
      remoteNotesMap[key] = note;
    }

    final allNoteKeys = <String>{...localNotesMap.keys, ...remoteNotesMap.keys};
    int notesAdded = 0;
    int notesMerged = 0;
    for (final noteKey in allNoteKeys) {
      final localNote = localNotesMap[noteKey];
      final remoteNote = remoteNotesMap[noteKey];

      if (localNote == null) {
        mergedData['notes'].add(remoteNote!);
        notesAdded++;
      } else if (remoteNote == null) {
        mergedData['notes'].add(localNote);
        notesAdded++;
      } else {
        final localUpdatedAt = DateTime.parse(localNote['updatedAt'] as String);
        final remoteUpdatedAt = DateTime.parse(remoteNote['updatedAt'] as String);

        // For trash operations, also consider deletedAt timestamp
        final localIsDeleted = localNote['isDeleted'] as bool? ?? false;
        final remoteIsDeleted = remoteNote['isDeleted'] as bool? ?? false;

        Map<String, dynamic> mergedNote;

        if (localIsDeleted != remoteIsDeleted) {
          // Trash state differs: use the one with more recent deletion/restoration time
          DateTime? localDeletedAt;
          DateTime? remoteDeletedAt;

          if (localIsDeleted && localNote['deletedAt'] != null) {
            final deletedAtStr = localNote['deletedAt'] as String?;
            if (deletedAtStr != null && deletedAtStr.isNotEmpty) {
              localDeletedAt = DateTime.tryParse(deletedAtStr);
            }
          }

          if (remoteIsDeleted && remoteNote['deletedAt'] != null) {
            final deletedAtStr = remoteNote['deletedAt'] as String?;
            if (deletedAtStr != null && deletedAtStr.isNotEmpty) {
              remoteDeletedAt = DateTime.tryParse(deletedAtStr);
            }
          }

          // Compare based on most recent action (deletion or restoration)
          if (localDeletedAt != null && remoteDeletedAt != null) {
            // Both are deleted: use the one with more recent deletion
            mergedNote = remoteDeletedAt.isAfter(localDeletedAt) ? remoteNote : localNote;
          } else if (localDeletedAt != null) {
            // Local is deleted, remote is active: compare deletion time vs update time
            mergedNote = localDeletedAt.isAfter(remoteUpdatedAt) ? localNote : remoteNote;
          } else if (remoteDeletedAt != null) {
            // Remote is deleted, local is active: compare deletion time vs update time
            mergedNote = remoteDeletedAt.isAfter(localUpdatedAt) ? remoteNote : localNote;
          } else {
            // Neither has clear deletion time: use updatedAt
            mergedNote = remoteUpdatedAt.isAfter(localUpdatedAt) ? remoteNote : localNote;
          }
        } else {
          // Same trash state: use standard updatedAt comparison
          if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
            mergedNote = remoteNote;
          } else if (localUpdatedAt.isAfter(remoteUpdatedAt)) {
            mergedNote = localNote;
          } else {
            mergedNote = localNote;
          }
        }

        mergedData['notes'].add(mergedNote);
        notesMerged++;
      }
    }
    if (kDebugMode) {
      print(
        'Note merge complete - Added: $notesAdded, '
        'Merged: $notesMerged, Total: ${mergedData['notes'].length}',
      );
    }

    return mergedData;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  CRUD – active notes
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Note> createNote({
    String? title,
    String? contentJson,
    String? folderId,
    List<int> customTagIds = const [],
  }) async {
    final note = await _noteRepository.createNote(
      title: title,
      contentJson: contentJson,
      folderId: folderId,
      customTagIds: customTagIds,
    );

    final folder = _folderRepository.getFolderById(folderId ?? 'default');
    if (folder != null) {
      folder.incrementNoteCount();
      await _folderRepository.updateFolder(folder);
    }

    // Generate embedding asynchronously (non-blocking)
    _embeddingService?.embedNote(note);

    return note;
  }

  /// Create a note with preserved timestamps (for import / sync operations).
  Future<Note> createNoteWithTimestamps({
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
  }) async {
    final note = await _noteRepository.createNoteWithTimestamps(
      title: title,
      contentJson: contentJson,
      folderId: folderId,
      customTagIds: customTagIds,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isFavorite: isFavorite,
      isArchived: isArchived,
      isDeleted: isDeleted,
      deletedAt: deletedAt,
    );

    // Only bump folder count for active notes.
    if (!isDeleted) {
      final folder = _folderRepository.getFolderById(folderId ?? 'default');
      if (folder != null) {
        folder.incrementNoteCount();
        await _folderRepository.updateFolder(folder);
      }
    }

    return note;
  }

  Future<void> updateNote(Note note) async {
    await _noteRepository.updateNote(note);
    // Re-embed asynchronously (non-blocking)
    _embeddingService?.embedNote(note);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Soft-delete (trash / recently deleted)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Soft-delete a note: mark [isDeleted] = true and record [deletedAt].
  ///
  /// The note stays in the database and can be restored via
  /// [restoreNoteFromTrash] until it is purged.
  Future<void> softDeleteNote(int noteId) async {
    final note = _noteRepository.getNoteById(noteId);
    if (note == null || note.isDeleted) return;

    // Decrement folder count – note is no longer "active".
    final folder = _folderRepository.getFolderById(note.folderId);
    if (folder != null) {
      folder.decrementNoteCount();
      await _folderRepository.updateFolder(folder);
    }

    note.softDelete();
    await _noteRepository.updateNote(note);
  }

  /// Restore a note from the trash back to the active list.
  Future<void> restoreNoteFromTrash(int noteId) async {
    final note = _noteRepository.getNoteById(noteId);
    if (note == null || !note.isDeleted) return;

    note.restoreFromTrash();
    await _noteRepository.updateNote(note);

    final folder = _folderRepository.getFolderById(note.folderId);
    if (folder != null) {
      folder.incrementNoteCount();
      await _folderRepository.updateFolder(folder);
    }
  }

  /// Permanently remove a note from the database.
  Future<void> permanentDeleteNote(int noteId) async {
    final note = _noteRepository.getNoteById(noteId);
    if (note == null) return;

    // Only touch folder count if the note is still "active".
    if (!note.isDeleted) {
      final folder = _folderRepository.getFolderById(note.folderId);
      if (folder != null) {
        folder.decrementNoteCount();
        await _folderRepository.updateFolder(folder);
      }
    }

    // Delete embeddings before removing the note
    await _embeddingService?.deleteEmbeddingsForNote(noteId);

    await _noteRepository.deleteNote(noteId);
  }

  /// Remove all notes that have been in the trash longer than [maxAge].
  ///
  /// Call at app startup or when opening the Recently Deleted screen.
  Future<void> purgeExpiredDeletedNotes({Duration maxAge = const Duration(days: 30)}) async {
    final now = DateTime.now();
    final expired = deletedNotes.where(
      (note) => note.deletedAt != null && now.difference(note.deletedAt!).inDays >= maxAge.inDays,
    );

    for (final note in expired.toList()) {
      await _embeddingService?.deleteEmbeddingsForNote(note.id);
      await _noteRepository.deleteNote(note.id);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Google Drive Trash Synchronization
  // ═══════════════════════════════════════════════════════════════════════════

  /// Move a note to trash on Google Drive and sync locally.
  ///
  /// **CRITICAL ORDER:**
  /// 1. Call Google Drive API to move file to trash
  /// 2. ONLY IF Drive succeeds → update local DB
  /// 3. Throw exception if Drive operation fails
  ///
  /// This ensures Google Drive is always the source of truth.
  Future<void> softDeleteNoteWithDriveSync(int noteId) async {
    final note = _noteRepository.getNoteById(noteId);
    if (note == null || note.isDeleted) return;

    // Only attempt Drive sync if we have a driveFileId and GoogleDriveService available
    if (note.driveFileId != null && _driveService != null && _driveService.isSignedIn) {
      try {
        // Step 1: Move file to trash on Google Drive FIRST
        await _driveService.moveFileToTrash(note.driveFileId!);
        _logger.i('Successfully moved note ${note.id} (${note.driveFileId}) to trash on Google Drive');
      } catch (e) {
        // If Drive operation fails, do NOT update local DB
        _logger.e('Failed to move note to trash on Google Drive: $e');
        rethrow;
      }
    }

    // Step 2: Update local DB (only after Drive succeeds or if no Drive sync needed)
    await softDeleteNote(noteId);
  }

  /// Restore a note from trash on Google Drive and sync locally.
  ///
  /// **CRITICAL ORDER:**
  /// 1. Call Google Drive API to restore file from trash
  /// 2. ONLY IF Drive succeeds → update local DB
  /// 3. Throw exception if Drive operation fails
  Future<void> restoreNoteFromTrashWithDriveSync(int noteId) async {
    final note = _noteRepository.getNoteById(noteId);
    if (note == null || !note.isDeleted) return;

    // Only attempt Drive sync if we have a driveFileId and GoogleDriveService available
    if (note.driveFileId != null && _driveService != null && _driveService.isSignedIn) {
      try {
        // Step 1: Restore file on Google Drive FIRST
        await _driveService.restoreFileFromTrash(note.driveFileId!);
        _logger.i('Successfully restored note ${note.id} (${note.driveFileId}) from trash on Google Drive');
      } catch (e) {
        // If Drive operation fails, do NOT update local DB
        _logger.e('Failed to restore note from trash on Google Drive: $e');
        rethrow;
      }
    }

    // Step 2: Update local DB (only after Drive succeeds or if no Drive sync needed)
    await restoreNoteFromTrash(noteId);
  }

  /// Permanently delete a note from Google Drive and local DB.
  ///
  /// **CRITICAL ORDER:**
  /// 1. Call Google Drive API to permanently delete file
  /// 2. ONLY IF Drive succeeds → delete from local DB
  /// 3. Throw exception if Drive operation fails
  /// 4. This action is IRREVERSIBLE
  Future<void> permanentDeleteNoteWithDriveSync(int noteId) async {
    final note = _noteRepository.getNoteById(noteId);
    if (note == null) return;

    // Only attempt Drive sync if we have a driveFileId and GoogleDriveService available
    if (note.driveFileId != null && _driveService != null && _driveService.isSignedIn) {
      try {
        // Step 1: Delete file from Google Drive FIRST
        await _driveService.permanentlyDeleteFile(note.driveFileId!);
        _logger.i('Successfully permanently deleted note ${note.id} (${note.driveFileId}) from Google Drive');
      } catch (e) {
        // If Drive operation fails, do NOT delete from local DB
        _logger.e('Failed to permanently delete note from Google Drive: $e');
        rethrow;
      }
    }

    // Step 2: Delete from local DB (only after Drive succeeds or if no Drive sync needed)
    await permanentDeleteNote(noteId);
  }

  /// Permanently delete a note from Google Drive by driveFileId.
  ///
  /// This is used during sync when a note was deleted locally but still exists on Drive.
  /// If the local deletion is more recent (based on latest deletedAt),
  /// the Drive file should be deleted to maintain consistency.
  ///
  /// Called from: GoogleDriveSyncService._handlePermanentlyDeletedNotes()
  Future<void> permanentlyDeleteNoteOnDrive(String driveFileId) async {
    final driveService = _driveService;
    if (driveService == null || !driveService.isSignedIn) {
      _logger.w('Cannot delete note from Drive: not signed in or Drive service unavailable');
      return;
    }

    try {
      await driveService.permanentlyDeleteFile(driveFileId);
      _logger.i('Successfully permanently deleted file $driveFileId from Google Drive during sync');
    } catch (e) {
      _logger.e('Failed to permanently delete file $driveFileId from Google Drive: $e');
      rethrow;
    }
  }

  /// Reconcile local trash state with Google Drive during sync.
  ///
  /// This is called during the sync process to ensure:
  /// - If Drive says a note is trashed, mark it as trashed locally
  /// - If Drive says a note is not trashed (and previously was), restore it
  /// - If Drive says a note is deleted (removed=true), delete it locally
  /// - Drive state ALWAYS overrides local state (latest timestamp wins)
  ///
  /// This ensures consistency after offline changes or Drive external changes.
  /// Uses timestamps to determine which state is more recent when there's conflict.
  Future<void> reconcileTrashStateWithDrive(Map<String, dynamic> driveNoteJson) async {
    if (driveNoteJson['id'] == null) return;

    final noteId = driveNoteJson['id'] as int;
    final note = _noteRepository.getNoteById(noteId);
    if (note == null) return;

    // Check Drive trash state and timestamps
    final isTrashedOnDrive = driveNoteJson['isDeleted'] as bool? ?? false;
    final isLocallyTrashed = note.isDeleted;

    // Parse timestamps from Drive
    DateTime? driveDeletedAt;
    if (isTrashedOnDrive && driveNoteJson['deletedAt'] != null) {
      final deletedAtStr = driveNoteJson['deletedAt'] as String?;
      if (deletedAtStr != null && deletedAtStr.isNotEmpty) {
        driveDeletedAt = DateTime.tryParse(deletedAtStr);
      }
    }

    // Resolve trash state based on latest timestamp
    bool shouldBeTrashed = isTrashedOnDrive;

    if (isTrashedOnDrive && isLocallyTrashed && driveDeletedAt != null && note.deletedAt != null) {
      // Both trashed: use the latest deletion timestamp
      final driveIsNewer = driveDeletedAt.isAfter(note.deletedAt!);
      shouldBeTrashed = true; // Both are trashed, so definitely trash
      if (driveIsNewer) {
        _logger.i(
          'Drive deletion is newer ($driveDeletedAt vs ${note.deletedAt}), '
          'updating local deletedAt timestamp for note $noteId',
        );
        note.deletedAt = driveDeletedAt;
      }
    } else if (isTrashedOnDrive != isLocallyTrashed) {
      // Different trash states: Drive is source of truth
      shouldBeTrashed = isTrashedOnDrive;
    }

    // Apply the resolved trash state
    if (shouldBeTrashed && !isLocallyTrashed) {
      _logger.i('Drive reports note $noteId is trashed, marking as deleted locally');
      note.softDelete();
      // Use Drive's deletedAt if provided
      if (driveDeletedAt != null) {
        note.deletedAt = driveDeletedAt;
      }
      await _noteRepository.updateNote(note);
    } else if (!shouldBeTrashed && isLocallyTrashed) {
      _logger.i('Drive reports note $noteId is active, restoring locally');
      note.restoreFromTrash();
      await _noteRepository.updateNote(note);
    } else if (shouldBeTrashed && isLocallyTrashed && driveDeletedAt != null) {
      // Both trashed but Drive has newer timestamp: update local
      if (driveDeletedAt.isAfter(note.deletedAt ?? DateTime.now())) {
        _logger.i('Updating deletedAt timestamp from Drive for note $noteId');
        note.deletedAt = driveDeletedAt;
        await _noteRepository.updateNote(note);
      }
    }

    // Update driveFileId if present
    if (driveNoteJson['driveFileId'] != null) {
      note.driveFileId = driveNoteJson['driveFileId'] as String;
      await _noteRepository.updateNote(note);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Hard-delete (legacy – use permanentDeleteNote for new code)
  // ═══════════════════════════════════════════════════════════════════════════

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

  // ═══════════════════════════════════════════════════════════════════════════
  //  Read-only delegates (repository handles filtering)
  // ═══════════════════════════════════════════════════════════════════════════

  /// All active (non-deleted) notes.
  List<Note> get notes => _noteRepository.getActiveNotes();

  /// All soft-deleted notes.
  List<Note> get deletedNotes => _noteRepository.getDeletedNotes();

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
}
