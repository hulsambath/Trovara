import 'package:logger/logger.dart';
import 'package:trovara/core/repository/interfaces/folder_repository.dart';
import 'package:trovara/core/repository/interfaces/note_repository.dart';
import 'package:trovara/core/services/ai/embedding_service.dart';
import 'package:trovara/core/services/notes/_storypad/storypad_converter.dart';
import 'package:trovara/core/services/notes/note_import_from_adapter.dart' show CreateNoteWithTimestampsFn;
import 'package:trovara/core/services/notes/note_sync_id.dart';
import 'package:trovara/core/services/notes/note_tombstone_registry.dart';
import 'package:trovara/models/folder.dart';
import 'package:trovara/models/note.dart';

/// Callback signature for `NoteService.createFolderWithTimestamps`.
typedef CreateFolderWithTimestampsFn =
    Future<Folder> Function({
      required String folderId,
      required String name,
      String? description,
      String? color,
      DateTime? createdAt,
      DateTime? updatedAt,
      bool isDefault,
      int noteCount,
    });

/// Internal helper for [NoteService]. Do not import from outside `lib/core/services/notes/`.
///
/// Runs the JSON-based import pipeline (Trovara native backups + Storypad-
/// detected backups). Performs upsert keyed by syncId and merges tombstones
/// from the incoming payload before writing.
class NoteImportFromJsonRunner {
  final INoteRepository _noteRepository;
  final IFolderRepository _folderRepository;
  final NoteTombstoneRegistry _tombstones;
  final EmbeddingService? _embeddingService;
  final StorypadConverter _storypadConverter;
  final CreateNoteWithTimestampsFn _createNoteWithTimestamps;
  final CreateFolderWithTimestampsFn _createFolderWithTimestamps;
  final Logger _logger;

  NoteImportFromJsonRunner({
    required INoteRepository noteRepository,
    required IFolderRepository folderRepository,
    required NoteTombstoneRegistry tombstones,
    required StorypadConverter storypadConverter,
    required CreateNoteWithTimestampsFn createNoteWithTimestamps,
    required CreateFolderWithTimestampsFn createFolderWithTimestamps,
    EmbeddingService? embeddingService,
    Logger? logger,
  }) : _noteRepository = noteRepository,
       _folderRepository = folderRepository,
       _tombstones = tombstones,
       _embeddingService = embeddingService,
       _storypadConverter = storypadConverter,
       _createNoteWithTimestamps = createNoteWithTimestamps,
       _createFolderWithTimestamps = createFolderWithTimestamps,
       _logger = logger ?? Logger();

  Future<void> run(Map<String, dynamic> json, {String source = 'unknown', bool verbose = false}) async {
    final workingJson = _maybeConvertStorypad(json, source: source, verbose: verbose);

    final stopwatch = Stopwatch()..start();

    final keys = workingJson.keys.toList()..sort();
    final version = workingJson['version'];
    final exportedAt = workingJson['exportedAt'];

    final foldersRaw = workingJson['folders'];
    final notesRaw = workingJson['notes'];

    final folders = (foldersRaw is List) ? foldersRaw : const <dynamic>[];
    final notes = (notesRaw is List) ? notesRaw : const <dynamic>[];

    _logger.i(
      'Import start (source=$source, verbose=$verbose) '
      'keys=$keys version=$version exportedAt=$exportedAt '
      'folders=${folders.length} notes=${notes.length}',
    );

    if (foldersRaw != null && foldersRaw is! List) {
      _logger.w('Import warning (source=$source): "folders" is not a List (type=${foldersRaw.runtimeType})');
    }
    if (notesRaw != null && notesRaw is! List) {
      _logger.w('Import warning (source=$source): "notes" is not a List (type=${notesRaw.runtimeType})');
    }

    final folderStats = await _importFolders(folders, source: source, verbose: verbose);

    // ── Merge incoming deletedSyncIds tombstones into local registry ──
    final incomingSyncIds = (workingJson['deletedSyncIds'] as List?)?.cast<String>() ?? [];
    if (incomingSyncIds.isNotEmpty) {
      await _tombstones.addAll(incomingSyncIds);
    }

    final noteStats = await _importNotes(notes, source: source, verbose: verbose);

    final activeNotes = _noteRepository.getActiveNotes();
    _logger.i(
      'Import upsert complete (source=$source) '
      'folders: +${folderStats.created}/~${folderStats.updated}/err=${folderStats.errors} '
      'notes: +${noteStats.created}/~${noteStats.updated}/skippedDeleted=${noteStats.skipped}/err=${noteStats.errors} '
      'activeNotes=${activeNotes.length} elapsedMs=${stopwatch.elapsedMilliseconds}',
    );

    try {
      await _embeddingService?.reembedStaleNotes(activeNotes);
    } catch (e, st) {
      _logger.e('Import embedding refresh failed (source=$source): $e', error: e, stackTrace: st);
    }
  }

  Map<String, dynamic> _maybeConvertStorypad(
    Map<String, dynamic> json, {
    required String source,
    required bool verbose,
  }) {
    if (!_storypadConverter.canHandle(json)) return json;
    try {
      _logger.i('Storypad backup detected (source=$source). Converting to Trovara import schema...');
      return _storypadConverter.convert(json, source: source, verbose: verbose);
    } catch (e, st) {
      _logger.e('Storypad conversion failed (source=$source): $e', error: e, stackTrace: st);
      return json;
    }
  }

  Future<_ImportStats> _importFolders(
    List<dynamic> folders, {
    required String source,
    required bool verbose,
  }) async {
    int created = 0;
    int updated = 0;
    int errors = 0;

    for (int i = 0; i < folders.length; i++) {
      try {
        final f = folders[i];
        final importFolder = Folder.fromJson(Map<String, dynamic>.from(f as Map));
        final existing = _folderRepository.getFolderById(importFolder.folderId);

        if (existing == null) {
          await _createFolderWithTimestamps(
            folderId: importFolder.folderId,
            name: importFolder.name,
            description: importFolder.description,
            color: importFolder.color,
            createdAt: importFolder.createdAt,
            updatedAt: importFolder.updatedAt,
            isDefault: importFolder.isDefault,
            noteCount: importFolder.noteCount,
          );
          created++;
          if (verbose) {
            _logger.d(
              'Import folder created (source=$source): folderId=${importFolder.folderId} name=${importFolder.name}',
            );
          }
        } else {
          existing
            ..name = importFolder.name
            ..description = importFolder.description
            ..color = importFolder.color
            ..isDefault = importFolder.isDefault
            ..noteCount = importFolder.noteCount
            ..updatedAt = importFolder.updatedAt;
          await _folderRepository.updateFolder(existing);
          updated++;
          if (verbose) {
            _logger.d(
              'Import folder updated (source=$source): folderId=${importFolder.folderId} name=${importFolder.name}',
            );
          }
        }
      } catch (e, st) {
        errors++;
        _logger.e('Import folder failed (source=$source) index=$i error=$e', error: e, stackTrace: st);
      }
    }

    return _ImportStats(created: created, updated: updated, errors: errors);
  }

  Future<_ImportStats> _importNotes(
    List<dynamic> notes, {
    required String source,
    required bool verbose,
  }) async {
    int created = 0;
    int updated = 0;
    int skipped = 0;
    int errors = 0;

    for (int i = 0; i < notes.length; i++) {
      try {
        final n = notes[i];
        final noteMap = Map<String, dynamic>.from(n as Map);

        // Read raw syncId from JSON before constructing Note. Note.fromJson passes
        // syncId into the constructor, which auto-generates a UUID when null, so
        // legacy records would otherwise always get a new ID and duplicate on re-import.
        final rawSyncId = noteMap['syncId'];
        final syncIdFromJson = (rawSyncId is String && rawSyncId.trim().isNotEmpty) ? rawSyncId.trim() : null;

        final importNote = Note.fromJson(noteMap);

        final syncId = syncIdFromJson ?? NoteSyncId.deterministic(importNote.title, importNote.createdAt);

        if (_tombstones.contains(syncId)) {
          skipped++;
          if (verbose) {
            _logger.d('Import note skipped (tombstone, source=$source): syncId=$syncId title=${importNote.title}');
          }
          continue;
        }

        final existing = _noteRepository.getNoteBySync(syncId);

        if (existing != null) {
          final incomingUpdatedAt = importNote.updatedAt;
          if (incomingUpdatedAt.isAfter(existing.updatedAt) || source == 'google-drive-sync') {
            _applyImportedFields(existing, importNote);
            await _noteRepository.updateNote(existing, preserveTimestamps: true);
            updated++;
            if (verbose) {
              _logger.d('Import note updated (source=$source): syncId=$syncId title=${importNote.title}');
            }
          } else if (verbose) {
            _logger.d(
              'Import note skipped (local is newer, source=$source): syncId=$syncId title=${importNote.title}',
            );
          }
          continue;
        }

        await _createNoteWithTimestamps(
          syncId: syncId,
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
          userId: importNote.userId,
          moodTags: importNote.moodTags,
          activityTags: importNote.activityTags,
          timeTags: importNote.timeTags,
          personalGrowthTags: importNote.personalGrowthTags,
        );
        created++;
        if (verbose) {
          _logger.d('Import note created (source=$source): syncId=$syncId title=${importNote.title}');
        }
      } catch (e, st) {
        errors++;
        _logger.e('Import note failed (source=$source) index=$i error=$e', error: e, stackTrace: st);
      }
    }

    return _ImportStats(created: created, updated: updated, skipped: skipped, errors: errors);
  }

  /// Copy all import-relevant fields from [src] to [dst]. Preserves the
  /// local ObjectBox id and the stable syncId (already validated by caller).
  void _applyImportedFields(Note dst, Note src) {
    dst
      ..title = src.title
      ..contentJson = src.contentJson
      ..folderId = src.folderId
      ..customTagIds = src.customTagIds
      ..moodTags = src.moodTags
      ..activityTags = src.activityTags
      ..timeTags = src.timeTags
      ..personalGrowthTags = src.personalGrowthTags
      ..isFavorite = src.isFavorite
      ..isArchived = src.isArchived
      ..isDeleted = src.isDeleted
      ..deletedAt = src.deletedAt
      ..driveFileId = src.driveFileId
      ..userId = src.userId
      ..updatedAt = src.updatedAt;
  }
}

class _ImportStats {
  final int created;
  final int updated;
  final int skipped;
  final int errors;
  const _ImportStats({this.created = 0, this.updated = 0, this.skipped = 0, this.errors = 0});
}
