/// Abstract import adapter interface + shared data-transfer objects.
///
/// Every platform adapter (Obsidian, Notion, Storypad, …) must implement
/// [NoteImportAdapter] and produce a list of [ImportedNote] objects.
/// The [NoteService.importFromAdapter] method then normalises them into
/// Trovara's internal [Note] model.
///
/// Pipeline:
///   Raw input (file bytes / JSON / folder path)
///       → [NoteImportAdapter.parse]
///       → `List<ImportedNote>`         (always Markdown content here)
///       → MarkdownToQuillConverter    (converts to Quill Delta)
///       → Note (stored in ObjectBox)
///       → EmbeddingService            (hash-gated re-embed)
library;

/// Platform-neutral intermediate representation produced by every adapter.
///
/// All content is expressed as **Markdown** at this stage so the downstream
/// [MarkdownToQuillConverter] has a single, predictable input format.
class ImportedNote {
  /// Display title.  Never empty; adapters should fall back to the filename.
  final String title;

  /// Note body in Markdown.  May be an empty string for title-only notes.
  final String markdownContent;

  /// Original creation timestamp, if available.
  final DateTime? createdAt;

  /// Last-edited timestamp, if available.
  final DateTime? updatedAt;

  /// Tags extracted from frontmatter (`tags:`), inline `#tag` notation,
  /// or platform-specific label fields.
  final List<String> tags;

  /// Raw `[[wikilink]]` targets (Obsidian) or `@mention` targets (Notion)
  /// found in the note body.  Preserved for graph-RAG relationships.
  final List<String> internalLinks;

  /// Target Trovara folder ID, if the adapter can determine it from the
  /// source folder structure.  Null means "place in the default folder."
  final String? folderId;

  /// All key/value pairs from the original frontmatter or platform metadata.
  /// Stored for debugging and potential future round-trip fidelity.
  final Map<String, dynamic> rawMetadata;

  const ImportedNote({
    required this.title,
    required this.markdownContent,
    this.createdAt,
    this.updatedAt,
    this.tags = const [],
    this.internalLinks = const [],
    this.folderId,
    this.rawMetadata = const {},
  });

  @override
  String toString() =>
      'ImportedNote(title: "$title", '
      'tags: $tags, '
      'links: ${internalLinks.length}, '
      'chars: ${markdownContent.length})';
}

/// Summary returned by [NoteService.importFromAdapter] after all notes have
/// been upserted.
class ImportResult {
  /// Number of notes that did not previously exist locally.
  final int created;

  /// Number of notes whose content was newer in the import payload.
  final int updated;

  /// Number of notes skipped (local copy was newer or tombstoned).
  final int skipped;

  /// Errors encountered (per-note).  Non-fatal; the import continues.
  final List<String> errors;

  const ImportResult({required this.created, required this.updated, required this.skipped, this.errors = const []});

  int get total => created + updated + skipped + errors.length;

  @override
  String toString() =>
      'ImportResult(created: $created, updated: $updated, '
      'skipped: $skipped, errors: ${errors.length})';
}

/// Contract every platform adapter must fulfil.
abstract class NoteImportAdapter {
  /// Short human-readable identifier used as [Note.source].
  ///
  /// Examples: `'obsidian'`, `'notion'`, `'storypad'`
  String get sourceName;

  /// Return true when this adapter is able to handle [rawInput].
  ///
  /// [rawInput] is whatever the UI layer passes in — a `String` of JSON,
  /// a `List<int>` of file bytes, a `Map<String, dynamic>`, etc.
  /// Adapters should do cheap, non-throwing inspection here.
  bool canHandle(dynamic rawInput);

  /// Parse [rawInput] and produce a list of normalised [ImportedNote]s.
  ///
  /// The adapter is free to be async (file I/O, zip extraction, etc.).
  /// It MUST NOT throw; instead, it should include per-note error info
  /// in [ImportedNote.rawMetadata] and simply skip malformed entries.
  Future<List<ImportedNote>> parse(dynamic rawInput);
}
