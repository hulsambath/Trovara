import 'package:trovara/core/repository/interfaces/folder_repository.dart';
import 'package:trovara/core/repository/interfaces/note_repository.dart';
import 'package:trovara/core/services/ai/embedding_service.dart';
import 'package:trovara/core/services/notes/note_tombstone_registry.dart';
import 'package:trovara/models/note.dart';

/// Internal helper for [NoteService]. Do not import from outside `lib/core/services/notes/`.
///
/// Local-only soft-delete / restore / permanent-delete / purge.
/// Maintains folder note-count invariants and writes tombstones before
/// permanent removal so future syncs honor the deletion.
///
/// Drive-aware variants live in [NoteDriveTrashSync] which calls these
/// methods AFTER the corresponding Drive API call succeeds.
class NoteTrashOperations {
  final INoteRepository _noteRepository;
  final IFolderRepository _folderRepository;
  final EmbeddingService? _embeddingService;
  final NoteTombstoneRegistry _tombstones;

  const NoteTrashOperations({
    required INoteRepository noteRepository,
    required IFolderRepository folderRepository,
    required NoteTombstoneRegistry tombstones,
    EmbeddingService? embeddingService,
  }) : _noteRepository = noteRepository,
       _folderRepository = folderRepository,
       _tombstones = tombstones,
       _embeddingService = embeddingService;

  Future<void> softDelete(int noteId) async {
    final note = _noteRepository.getNoteById(noteId);
    if (note == null || note.isDeleted) return;

    await _bumpFolderCount(note.folderId, delta: -1);
    note.softDelete();
    await _noteRepository.updateNote(note);
  }

  Future<void> restore(int noteId) async {
    final note = _noteRepository.getNoteById(noteId);
    if (note == null || !note.isDeleted) return;

    note.restoreFromTrash();
    await _noteRepository.updateNote(note);
    await _bumpFolderCount(note.folderId, delta: 1);
  }

  Future<void> permanentDelete(int noteId) async {
    final note = _noteRepository.getNoteById(noteId);
    if (note == null) return;

    // Tombstone BEFORE removing the record so future syncs honor the deletion.
    await _tombstones.add(note.syncId);

    if (!note.isDeleted) {
      await _bumpFolderCount(note.folderId, delta: -1);
    }

    await _embeddingService?.deleteEmbeddingsForNote(noteId);
    await _noteRepository.deleteNote(noteId);
  }

  /// Remove notes that have been in the trash longer than [maxAge].
  Future<void> purgeExpired({Duration maxAge = const Duration(days: 30), required List<Note> deletedNotes}) async {
    final now = DateTime.now();
    final expired = deletedNotes.where(
      (note) => note.deletedAt != null && now.difference(note.deletedAt!).inDays >= maxAge.inDays,
    );

    for (final note in expired.toList()) {
      await _embeddingService?.deleteEmbeddingsForNote(note.id);
      await _noteRepository.deleteNote(note.id);
    }
  }

  Future<void> _bumpFolderCount(String folderId, {required int delta}) async {
    final folder = _folderRepository.getFolderById(folderId);
    if (folder == null) return;
    if (delta > 0) {
      folder.incrementNoteCount();
    } else if (delta < 0) {
      folder.decrementNoteCount();
    }
    await _folderRepository.updateFolder(folder);
  }
}
