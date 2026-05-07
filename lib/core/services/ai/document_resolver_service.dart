import 'dart:math';

import 'package:logger/logger.dart';
import 'package:trovara/core/services/ai/vector_search_service.dart';
import 'package:trovara/core/services/notes/note_service.dart';
import 'package:trovara/models/retrieved_document.dart';

/// Resolves raw [ScoredEmbedding] chunks from vector search into
/// fully-hydrated [RetrievedDocument] objects.
///
/// This is **Step 3** of the RAG pipeline:
///
/// ```
/// ScoredEmbedding list (Step 2)
///     │
///     ▼
/// Group by noteId  ──► Fetch full Note  ──► Rank  ──► Top-N
///     │
///     ▼
/// List<RetrievedDocument> (→ Step 4 prompt builder)
/// ```
///
/// Responsibilities:
/// - Group scored chunks by their parent note
/// - Fetch the full [Note] entity for each group
/// - Filter out deleted or inaccessible notes
/// - Sort chunks within each note by reading order
/// - Rank notes by highest similarity score
/// - Limit results to a configurable top-N
class DocumentResolverService {
  final NoteService _noteService;
  final Logger _logger = Logger();

  /// Default maximum number of documents to return.
  static const int defaultTopN = 5;

  /// Maximum combined text length (chars) to include in the prompt context.
  /// Prevents excessive token usage even with Gemini's large context window.
  static const int maxCombinedTextChars = 20000;

  DocumentResolverService({required NoteService noteService}) : _noteService = noteService;

  // ═══════════════════════════════════════════════════════════════════════════
  //  Public API
  // ═══════════════════════════════════════════════════════════════════════════

  /// Resolve scored embedding chunks into ranked [RetrievedDocument]s.
  ///
  /// 1. Groups [scoredChunks] by `noteId`
  /// 2. Fetches the full [Note] for each group
  /// 3. Filters out deleted or missing notes
  /// 4. Sorts chunks within each note by `chunkIndex` (reading order)
  /// 5. Ranks notes by max similarity score (descending)
  /// 6. Returns the top-[topN] documents
  ///
  /// If [maxTextLength] is provided, the result list is further trimmed so
  /// the total combined text does not exceed that limit.
  List<RetrievedDocument> resolve(List<ScoredEmbedding> scoredChunks, {int topN = defaultTopN, int? maxTextLength}) {
    if (scoredChunks.isEmpty) return [];

    // Step 1: Group chunks by noteId
    final noteGroups = _groupByNoteId(scoredChunks);

    // Step 2 & 3: Fetch notes and build RetrievedDocuments
    final documents = <RetrievedDocument>[];

    for (final entry in noteGroups.entries) {
      final note = _noteService.getNote(entry.key);

      // Skip missing or deleted notes
      if (note == null) {
        _logger.d('Skipping missing note ${entry.key}');
        continue;
      }
      if (note.isDeleted) {
        _logger.d('Skipping deleted note ${entry.key}');
        continue;
      }

      // Step 4: Sort chunks by chunkIndex for reading order
      final chunks = entry.value..sort((a, b) => a.embedding.chunkIndex.compareTo(b.embedding.chunkIndex));

      // Compute the max score for ranking
      final maxScore = chunks.map((c) => c.score).reduce(max);

      documents.add(RetrievedDocument(note: note, relevantChunks: chunks, maxScore: maxScore));
    }

    // Step 5: Rank by descending max score
    documents.sort((a, b) => b.maxScore.compareTo(a.maxScore));

    // Step 6: Limit to top-N
    final topDocuments = documents.take(topN).toList();

    // Optional: trim by total text length
    if (maxTextLength != null) {
      return _trimByTextLength(topDocuments, maxTextLength);
    }

    _logger.d(
      'Resolved ${scoredChunks.length} chunks → '
      '${documents.length} notes → '
      '${topDocuments.length} returned',
    );

    return topDocuments;
  }

  /// Convenience method: resolve and return only the note titles.
  ///
  /// Useful for source attribution in chat responses.
  List<String> resolveToTitles(List<ScoredEmbedding> scoredChunks, {int topN = defaultTopN}) {
    final docs = resolve(scoredChunks, topN: topN);
    return docs.map((d) => d.note.title).toList();
  }

  /// Convenience method: resolve and return combined text suitable for
  /// prompt building.
  ///
  /// Each entry is a map with `title`, `text`, `date`, `folder`, and `tags`.
  List<Map<String, String>> resolveToContextMaps(List<ScoredEmbedding> scoredChunks, {int topN = defaultTopN}) {
    final docs = resolve(scoredChunks, topN: topN);
    return docs.map((doc) {
      final note = doc.note;
      final folder = _noteService.getFolder(note.folderId);

      // Build tag string
      final tags = <String>[];
      if (note.moodTags.isNotEmpty) tags.add('mood: ${note.moodTags.join(", ")}');
      if (note.activityTags.isNotEmpty) tags.add('activity: ${note.activityTags.join(", ")}');
      if (note.timeTags.isNotEmpty) tags.add('time: ${note.timeTags.join(", ")}');
      if (note.personalGrowthTags.isNotEmpty) {
        tags.add('growth: ${note.personalGrowthTags.join(", ")}');
      }

      return {
        'title': note.title,
        'date': note.createdAt.toIso8601String().split('T')[0],
        'folder': folder?.name ?? 'Default',
        'tags': tags.join(' | '),
        'text': doc.combinedText,
      };
    }).toList();
  }

  /// Resolve scored embedding chunks into **chunk-level** context maps.
  ///
  /// Unlike [resolveToContextMaps], this does NOT group by note. It returns the
  /// top [topKChunks] chunks globally (in the incoming order) and attaches note
  /// metadata for each chunk.
  ///
  /// Each entry contains: `title`, `date`, `folder`, `tags`, `text`.
  List<Map<String, String>> resolveTopChunksToContext(List<ScoredEmbedding> scoredChunks, {int topKChunks = 3}) {
    if (scoredChunks.isEmpty) return [];

    final limit = topKChunks.clamp(1, 20);

    // Resolve only as many *valid* chunks as needed. We cannot truncate before
    // filtering, otherwise missing/deleted notes can consume the entire window.
    final noteMetaById = <int, Map<String, String>?>{};
    Map<String, String>? getMeta(int noteId) {
      if (noteMetaById.containsKey(noteId)) return noteMetaById[noteId];

      final note = _noteService.getNote(noteId);
      if (note == null || note.isDeleted) {
        noteMetaById[noteId] = null;
        return null;
      }
      final folder = _noteService.getFolder(note.folderId);

      final tags = <String>[];
      if (note.moodTags.isNotEmpty) tags.add('mood: ${note.moodTags.join(", ")}');
      if (note.activityTags.isNotEmpty) tags.add('activity: ${note.activityTags.join(", ")}');
      if (note.timeTags.isNotEmpty) tags.add('time: ${note.timeTags.join(", ")}');
      if (note.personalGrowthTags.isNotEmpty) {
        tags.add('growth: ${note.personalGrowthTags.join(", ")}');
      }

      final meta = <String, String>{
        'title': note.title,
        'date': note.createdAt.toIso8601String().split('T')[0],
        'folder': folder?.name ?? 'Default',
        'tags': tags.join(' | '),
      };
      noteMetaById[noteId] = meta;
      return meta;
    }

    final out = <Map<String, String>>[];
    for (final chunk in scoredChunks) {
      if (out.length >= limit) break;
      final meta = getMeta(chunk.embedding.noteId);
      if (meta == null) continue;
      out.add({...meta, 'text': chunk.embedding.chunkText});
    }

    return out;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Private Helpers
  // ═══════════════════════════════════════════════════════════════════════════

  /// Group scored chunks by their parent noteId.
  Map<int, List<ScoredEmbedding>> _groupByNoteId(List<ScoredEmbedding> chunks) {
    final groups = <int, List<ScoredEmbedding>>{};
    for (final chunk in chunks) {
      groups.putIfAbsent(chunk.embedding.noteId, () => []).add(chunk);
    }
    return groups;
  }

  /// Trim the document list so total combined text stays within [maxLength].
  ///
  /// Documents are already sorted by relevance, so we include as many as
  /// possible within the budget.
  List<RetrievedDocument> _trimByTextLength(List<RetrievedDocument> docs, int maxLength) {
    final result = <RetrievedDocument>[];
    int currentLength = 0;

    for (final doc in docs) {
      final docLength = doc.combinedTextLength;
      if (currentLength + docLength > maxLength && result.isNotEmpty) {
        break;
      }
      result.add(doc);
      currentLength += docLength;
    }

    return result;
  }
}
