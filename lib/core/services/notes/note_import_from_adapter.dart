import 'package:logger/logger.dart';
import 'package:trovara/core/import/converters/markdown_to_quill.dart';
import 'package:trovara/core/import/import_adapter.dart';
import 'package:trovara/core/repository/interfaces/note_repository.dart';
import 'package:trovara/core/services/ai/embedding_service.dart';
import 'package:trovara/core/services/notes/custom_tag_service.dart';
import 'package:trovara/core/services/notes/note_sync_id.dart';
import 'package:trovara/core/services/notes/note_tombstone_registry.dart';
import 'package:trovara/models/note.dart';

/// Internal helper for [NoteService]. Do not import from outside `lib/core/services/notes/`.
///
/// Runs the adapter-based import pipeline:
///   adapter.parse → MarkdownToQuillConverter → upsert (syncId-keyed merge)
///   → hash-gated re-embed
class NoteImportFromAdapterRunner {
  final INoteRepository _noteRepository;
  final NoteTombstoneRegistry _tombstones;
  final CustomTagService? _customTagService;
  final EmbeddingService? _embeddingService;
  final CreateNoteWithTimestampsFn _createNoteWithTimestamps;
  final UpdateNoteFn _updateNote;
  final Logger _logger;

  NoteImportFromAdapterRunner({
    required INoteRepository noteRepository,
    required NoteTombstoneRegistry tombstones,
    required CreateNoteWithTimestampsFn createNoteWithTimestamps,
    required UpdateNoteFn updateNote,
    CustomTagService? customTagService,
    EmbeddingService? embeddingService,
    Logger? logger,
  }) : _noteRepository = noteRepository,
       _tombstones = tombstones,
       _customTagService = customTagService,
       _embeddingService = embeddingService,
       _createNoteWithTimestamps = createNoteWithTimestamps,
       _updateNote = updateNote,
       _logger = logger ?? Logger();

  Future<ImportResult> run(
    NoteImportAdapter adapter,
    dynamic rawInput, {
    String? targetFolderId,
    bool verbose = false,
  }) async {
    _logger.i('importFromAdapter: adapter=${adapter.sourceName}');
    final stopwatch = Stopwatch()..start();

    final List<ImportedNote> importedNotes;
    try {
      importedNotes = await adapter.parse(rawInput);
    } catch (e, st) {
      _logger.e('importFromAdapter: parse failed adapter=${adapter.sourceName}: $e', error: e, stackTrace: st);
      return const ImportResult(created: 0, updated: 0, skipped: 0, errors: ['Parse failed']);
    }

    _logger.i('importFromAdapter: parsed ${importedNotes.length} note(s) from ${adapter.sourceName}');

    int created = 0, updated = 0, skipped = 0;
    final errors = <String>[];

    for (int i = 0; i < importedNotes.length; i++) {
      final imported = importedNotes[i];
      try {
        final contentJson = MarkdownToQuillConverter.convert(imported.markdownContent);

        final importedCustomTagIds = await _resolveImportedCustomTagIds(imported.tags);

        final stableCreatedAt = imported.createdAt ?? NoteSyncId.syntheticForImport(imported);
        final syncId = NoteSyncId.deterministic(imported.title, stableCreatedAt);

        if (_tombstones.contains(syncId)) {
          skipped++;
          if (verbose) _logger.d('importFromAdapter: skipped (tombstone) title=${imported.title}');
          continue;
        }

        final existing = _noteRepository.getNoteBySync(syncId);

        if (existing != null) {
          // Always merge imported tags into the existing note, even when we skip
          // content updates due to timestamps. Keeps the UI promise that tags
          // are preserved on re-import without making the note look newer.
          final mergedCustomTagIds = {...existing.customTagIds, ...importedCustomTagIds}.toList();
          final tagsChanged = mergedCustomTagIds.length != existing.customTagIds.length;

          // If the source doesn't provide updatedAt (common for plain Markdown),
          // treat it as "no known modification time" rather than "updated now"
          // so repeated imports don't clobber local edits.
          final incomingUpdated = imported.updatedAt ?? imported.createdAt ?? stableCreatedAt;
          if (incomingUpdated.isAfter(existing.updatedAt)) {
            existing
              ..title = imported.title
              ..contentJson = contentJson
              ..folderId = targetFolderId ?? imported.folderId ?? existing.folderId
              ..source = adapter.sourceName
              ..internalLinks = imported.internalLinks
              ..customTagIds = mergedCustomTagIds
              ..updatedAt = incomingUpdated;
            await _noteRepository.updateNote(existing, preserveTimestamps: true);
            updated++;
            if (verbose) _logger.d('importFromAdapter: updated syncId=$syncId title=${imported.title}');
          } else {
            if (tagsChanged) {
              existing.customTagIds = mergedCustomTagIds;
              await _updateNote(existing, skipEmbeddingRefresh: true, preserveTimestamps: true);
            }
            skipped++;
            if (verbose) _logger.d('importFromAdapter: skipped (local newer) title=${imported.title}');
          }
        } else {
          await _createNoteWithTimestamps(
            syncId: syncId,
            title: imported.title,
            contentJson: contentJson,
            folderId: targetFolderId ?? imported.folderId ?? 'default',
            customTagIds: importedCustomTagIds,
            createdAt: stableCreatedAt,
            updatedAt: imported.updatedAt ?? imported.createdAt ?? stableCreatedAt,
            source: adapter.sourceName,
            internalLinks: imported.internalLinks,
          );
          created++;
          if (verbose) _logger.d('importFromAdapter: created syncId=$syncId title=${imported.title}');
        }
      } catch (e, st) {
        errors.add('note[$i] title="${imported.title}": $e');
        _logger.e('importFromAdapter: note failed index=$i title=${imported.title}: $e', error: e, stackTrace: st);
      }
    }

    _logger.i(
      'importFromAdapter complete adapter=${adapter.sourceName} '
      'created=$created updated=$updated skipped=$skipped errors=${errors.length} '
      'elapsedMs=${stopwatch.elapsedMilliseconds}',
    );

    try {
      await _embeddingService?.reembedStaleNotes(_noteRepository.getActiveNotes());
    } catch (e, st) {
      _logger.e('importFromAdapter: post-import embedding failed: $e', error: e, stackTrace: st);
    }

    return ImportResult(created: created, updated: updated, skipped: skipped, errors: errors);
  }

  Future<List<int>> _resolveImportedCustomTagIds(List<String> rawTags) async {
    if (rawTags.isEmpty) return const [];
    final svc = _customTagService;
    if (svc == null) return const [];

    final normalized = rawTags.map((t) => t.replaceAll('#', '').trim()).where((t) => t.isNotEmpty).toSet().toList();

    if (normalized.isEmpty) return const [];

    final ids = <int>[];
    for (final name in normalized) {
      final tag = await svc.createOrGetCustomTag(name);
      ids.add(tag.id);
    }
    return ids;
  }
}

/// Callback signature for `NoteService.createNoteWithTimestamps`.
typedef CreateNoteWithTimestampsFn =
    Future<Note> Function({
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
      String source,
      List<String>? internalLinks,
    });

/// Callback signature for `NoteService.updateNote`.
typedef UpdateNoteFn = Future<void> Function(Note note, {bool skipEmbeddingRefresh, bool preserveTimestamps});
