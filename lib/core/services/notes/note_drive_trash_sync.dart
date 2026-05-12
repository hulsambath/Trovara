import 'package:logger/logger.dart';
import 'package:trovara/core/repository/interfaces/note_repository.dart';
import 'package:trovara/core/services/auth/google_drive_service.dart';
import 'package:trovara/core/services/notes/note_sync_id.dart';

/// Callback signature for the local-only soft delete / restore / permanent
/// delete operations on `NoteService`. The Drive helper invokes these AFTER
/// the corresponding Drive API call succeeds.
typedef NoteIdAction = Future<void> Function(int noteId);

/// Internal helper for [NoteService]. Do not import from outside `lib/core/services/notes/`.
///
/// Wraps each local trash mutation with a Drive API call FIRST. Drive is the
/// source of truth — if the Drive call fails, the local state is left
/// untouched and the exception is rethrown.
class NoteDriveTrashSync {
  final INoteRepository _noteRepository;
  final GoogleDriveService? _driveService;
  final NoteIdAction _onSoftDeleteLocal;
  final NoteIdAction _onRestoreLocal;
  final NoteIdAction _onPermanentDeleteLocal;
  final Logger _logger;

  NoteDriveTrashSync({
    required INoteRepository noteRepository,
    required GoogleDriveService? driveService,
    required NoteIdAction onSoftDeleteLocal,
    required NoteIdAction onRestoreLocal,
    required NoteIdAction onPermanentDeleteLocal,
    Logger? logger,
  }) : _noteRepository = noteRepository,
       _driveService = driveService,
       _onSoftDeleteLocal = onSoftDeleteLocal,
       _onRestoreLocal = onRestoreLocal,
       _onPermanentDeleteLocal = onPermanentDeleteLocal,
       _logger = logger ?? Logger();

  /// Move a note to trash on Google Drive, then locally. **CRITICAL ORDER:**
  /// Drive first; local state is only mutated after Drive succeeds.
  Future<void> softDeleteWithDriveSync(int noteId) async {
    final note = _noteRepository.getNoteById(noteId);
    if (note == null || note.isDeleted) return;

    final drive = _driveService;
    if (note.driveFileId != null && drive != null && drive.isSignedIn) {
      try {
        await drive.moveFileToTrash(note.driveFileId!);
        _logger.i('Successfully moved note ${note.id} (${note.driveFileId}) to trash on Google Drive');
      } catch (e) {
        _logger.e('Failed to move note to trash on Google Drive: $e');
        rethrow;
      }
    }

    await _onSoftDeleteLocal(noteId);
  }

  /// Restore a note from trash on Google Drive, then locally.
  Future<void> restoreWithDriveSync(int noteId) async {
    final note = _noteRepository.getNoteById(noteId);
    if (note == null || !note.isDeleted) return;

    final drive = _driveService;
    if (note.driveFileId != null && drive != null && drive.isSignedIn) {
      try {
        await drive.restoreFileFromTrash(note.driveFileId!);
        _logger.i('Successfully restored note ${note.id} (${note.driveFileId}) from trash on Google Drive');
      } catch (e) {
        _logger.e('Failed to restore note from trash on Google Drive: $e');
        rethrow;
      }
    }

    await _onRestoreLocal(noteId);
  }

  /// Permanently delete a note from Google Drive, then locally. **IRREVERSIBLE.**
  Future<void> permanentDeleteWithDriveSync(int noteId) async {
    final note = _noteRepository.getNoteById(noteId);
    if (note == null) return;

    final drive = _driveService;
    if (note.driveFileId != null && drive != null && drive.isSignedIn) {
      try {
        await drive.permanentlyDeleteFile(note.driveFileId!);
        _logger.i('Successfully permanently deleted note ${note.id} (${note.driveFileId}) from Google Drive');
      } catch (e) {
        _logger.e('Failed to permanently delete note from Google Drive: $e');
        rethrow;
      }
    }

    await _onPermanentDeleteLocal(noteId);
  }

  /// Permanently delete a Drive file by its [driveFileId] only. Used by sync
  /// when the local note is already gone but the Drive file still exists.
  Future<void> permanentlyDeleteOnDrive(String driveFileId) async {
    final drive = _driveService;
    if (drive == null || !drive.isSignedIn) {
      _logger.w('Cannot delete note from Drive: not signed in or Drive service unavailable');
      return;
    }

    try {
      await drive.permanentlyDeleteFile(driveFileId);
      _logger.i('Successfully permanently deleted file $driveFileId from Google Drive during sync');
    } catch (e) {
      _logger.e('Failed to permanently delete file $driveFileId from Google Drive: $e');
      rethrow;
    }
  }

  /// Reconcile a single Drive note's trash state with the local copy.
  /// Drive is the source of truth; timestamps resolve conflicts.
  Future<void> reconcileTrashStateWithDrive(Map<String, dynamic> driveNoteJson) async {
    final syncId = NoteSyncId.fromNoteJson(driveNoteJson);
    final note = _noteRepository.getNoteBySync(syncId);
    if (note == null) return;

    final isTrashedOnDrive = driveNoteJson['isDeleted'] as bool? ?? false;
    final isLocallyTrashed = note.isDeleted;

    DateTime? driveDeletedAt;
    if (isTrashedOnDrive && driveNoteJson['deletedAt'] != null) {
      final deletedAtStr = driveNoteJson['deletedAt'] as String?;
      if (deletedAtStr != null && deletedAtStr.isNotEmpty) {
        driveDeletedAt = DateTime.tryParse(deletedAtStr);
      }
    }

    bool shouldBeTrashed = isTrashedOnDrive;

    if (isTrashedOnDrive && isLocallyTrashed && driveDeletedAt != null && note.deletedAt != null) {
      final driveIsNewer = driveDeletedAt.isAfter(note.deletedAt!);
      shouldBeTrashed = true;
      if (driveIsNewer) {
        _logger.i(
          'Drive deletion is newer ($driveDeletedAt vs ${note.deletedAt}), '
          'updating local deletedAt for note syncId=$syncId',
        );
        note.deletedAt = driveDeletedAt;
      }
    } else if (isTrashedOnDrive != isLocallyTrashed) {
      shouldBeTrashed = isTrashedOnDrive;
    }

    if (shouldBeTrashed && !isLocallyTrashed) {
      _logger.i('Drive reports note syncId=$syncId is trashed, marking as deleted locally');
      note.softDelete();
      if (driveDeletedAt != null) {
        note.deletedAt = driveDeletedAt;
      }
      await _noteRepository.updateNote(note);
    } else if (!shouldBeTrashed && isLocallyTrashed) {
      _logger.i('Drive reports note syncId=$syncId is active, restoring locally');
      note.restoreFromTrash();
      await _noteRepository.updateNote(note);
    } else if (shouldBeTrashed && isLocallyTrashed && driveDeletedAt != null) {
      if (driveDeletedAt.isAfter(note.deletedAt ?? DateTime.now())) {
        _logger.i('Updating deletedAt from Drive for note syncId=$syncId');
        note.deletedAt = driveDeletedAt;
        await _noteRepository.updateNote(note);
      }
    }

    if (driveNoteJson['driveFileId'] != null) {
      note.driveFileId = driveNoteJson['driveFileId'] as String;
      await _noteRepository.updateNote(note);
    }
  }
}
