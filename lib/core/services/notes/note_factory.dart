import 'package:trovara/core/repository/interfaces/folder_repository.dart';
import 'package:trovara/core/repository/interfaces/note_repository.dart';
import 'package:trovara/core/services/ai/embedding_service.dart';
import 'package:trovara/models/note.dart';

/// Internal helper for [NoteService]. Do not import from outside `lib/core/services/notes/`.
///
/// Encapsulates note creation logic (active + with-timestamps variants) so
/// `NoteService` stays focused on orchestration. Maintains the folder
/// note-count invariant on every successful create.
class NoteFactory {
  final INoteRepository _noteRepository;
  final IFolderRepository _folderRepository;
  final EmbeddingService? _embeddingService;

  const NoteFactory({
    required INoteRepository noteRepository,
    required IFolderRepository folderRepository,
    EmbeddingService? embeddingService,
  }) : _noteRepository = noteRepository,
       _folderRepository = folderRepository,
       _embeddingService = embeddingService;

  Future<Note> create({
    String? title,
    String? contentJson,
    String? folderId,
    List<int> customTagIds = const [],
    String? userId,
  }) async {
    final note = await _noteRepository.createNote(
      title: title,
      contentJson: contentJson,
      folderId: folderId,
      customTagIds: customTagIds,
      userId: userId,
    );

    await _bumpFolderCount(folderId ?? 'default', delta: 1);

    _embeddingService?.embedNote(note);
    return note;
  }

  /// Create a note with preserved timestamps (for import / sync operations).
  Future<Note> createWithTimestamps({
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
    String source = 'trovara',
    List<String>? internalLinks,
  }) async {
    final note = await _noteRepository.createNoteWithTimestamps(
      syncId: syncId,
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
      userId: userId,
      moodTags: moodTags,
      activityTags: activityTags,
      timeTags: timeTags,
      personalGrowthTags: personalGrowthTags,
    );

    // Apply fields the repository interface doesn't expose yet (source + links).
    // Lightweight update — no embedding refresh, no timestamp change.
    if (source != 'trovara' || (internalLinks != null && internalLinks.isNotEmpty)) {
      note
        ..source = source
        ..internalLinks = internalLinks ?? [];
      await _noteRepository.updateNote(note, preserveTimestamps: true);
    }

    if (!isDeleted) {
      await _bumpFolderCount(folderId ?? 'default', delta: 1);
    }

    return note;
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
