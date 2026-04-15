# Trovara — Note Data Model & Import/Export Architecture

> **Design principle:** treat the system like a compiler.
> `External formats → Normalize → Internal format → Store / Embed / Render`

---

## 1. What Already Exists (Inventory)

| Layer                  | File                                                                                                 | Status                                                                    |
| ---------------------- | ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| **Internal model**     | [lib/models/note.dart](lib/models/note.dart)                                                         | ✅ Quill-Delta JSON content, robust `syncId` UUID, full `toJson/fromJson` |
| **Embedding model**    | [lib/models/note_embedding.dart](lib/models/note_embedding.dart)                                     | ✅ Chunk-based, SHA-256 content signature, model version                  |
| **Text extraction**    | [lib/core/services/text_parser_service.dart](lib/core/services/text_parser_service.dart)             | ✅ Quill Delta → plain text                                               |
| **Embedding pipeline** | [lib/core/services/embedding_service.dart](lib/core/services/embedding_service.dart)                 | ✅ Chunking, hashing, OpenAI + Gemini, pending queue                      |
| **RAG pipeline**       | [lib/core/services/rag_service.dart](lib/core/services/rag_service.dart)                             | ✅ Query rewrite → multi-query → RRF → LLM                                |
| **Import / sync**      | [lib/core/services/note_service.dart](lib/core/services/note_service.dart)                           | ✅ Trovara JSON + **Storypad adapter** (already built)                    |
| **Drive sync**         | [lib/core/services/google_drive_sync_service.dart](lib/core/services/google_drive_sync_service.dart) | ✅ JSON serialization round-trip                                          |
| **Storage**            | ObjectBox (local) + Google Drive JSON (cloud)                                                        | ✅                                                                        |

### What is MISSING

| Gap                                                                                      | Priority                          |
| ---------------------------------------------------------------------------------------- | --------------------------------- |
| **Obsidian adapter** — parse [.md](README.md) + YAML frontmatter vault                   | 🔴 High                           |
| **Notion adapter** — parse Notion Markdown/CSV export                                    | 🔴 High                           |
| **Markdown ↔ Quill-Delta converter**                                                     | 🔴 High (needed by both adapters) |
| **Export to Markdown** (Obsidian-compatible)                                             | 🟡 Medium                         |
| **Export to JSON backup** (already partially done via Drive sync)                        | 🟢 Low                            |
| **File-picker import flow** (UI)                                                         | 🟡 Medium                         |
| **`source` field on [Note](lib/models/note.dart#L10-L275)** (track where note came from) | 🔴 High (small model change)      |

---

## 2. Canonical Internal Format (Already Yours)

The existing [Note](lib/models/note.dart#L10-L275) model is already very close to the canonical form described in the plan. Here it is aligned:

```
Proposed canonical type     │  Trovara Note field
────────────────────────────┼────────────────────────────────
id: string                  │  syncId: String  (UUID)
title: string               │  title: String
content: string  // markdown │  contentJson: String (Quill Delta)
tags: string[]              │  moodTags, activityTags, timeTags, personalGrowthTags, customTagIds
createdAt: string           │  createdAt: DateTime
updatedAt: string           │  updatedAt: DateTime
source: "obsidian" | ...    │  ❌ MISSING — needs a new `source` field
links: string[]             │  ❌ MISSING — internal [[wikilinks]] references
```

### 2.1 Required Model Change — `source` & `links`

Add to [Note](lib/models/note.dart#L10-L275):

```dart
// Source of truth for where this note came from
String source; // 'trovara' | 'obsidian' | 'notion' | 'storypad' | 'manual'

// [[WikiLink]] internal references preserved from Obsidian/Notion
List<String> internalLinks;
```

> [!IMPORTANT]
> Adding new ObjectBox fields requires running `flutter pub run build_runner build` to regenerate [objectbox.g.dart](lib/objectbox.g.dart) and [objectbox-model.json](lib/objectbox-model.json). Only add fields that are truly needed at the model layer — `source` and `internalLinks` qualify.

---

## 3. Content Format Decision: Quill Delta vs. Markdown

The plan recommends **Markdown as the internal storage format**. Trovara currently uses **Quill Delta JSON**. This is the single biggest architectural tension.

### Recommendation: Keep Quill Delta internally, use Markdown at the boundary

|                     | Quill Delta (current)                                                                      | Plain Markdown                       |
| ------------------- | ------------------------------------------------------------------------------------------ | ------------------------------------ |
| **Rich editing**    | ✅ Native to `flutter_quill`                                                               | ❌ Needs custom renderer             |
| **Embedding input** | [TextParserService](lib/core/services/text_parser_service.dart#L5-L62) extracts plain text | Direct                               |
| **Import friendly** | Needs converter                                                                            | Native                               |
| **Export friendly** | Needs converter                                                                            | Native                               |
| **Sync format**     | JSON                                                                                       | Would require parser on every device |

**Solution:** Build a `MarkdownConverter` service that:

- **Import**: `Markdown string → Quill Delta JSON` (used by Obsidian/Notion adapters)
- **Export**: `Quill Delta JSON → Markdown string` (used by export feature + Drive sync plain-text)

---

## 4. Adapter Architecture

### Pattern: Abstract `NoteImportAdapter`

```
lib/core/import/
  import_adapter.dart           ← abstract interface
  adapters/
    obsidian_adapter.dart       ← .md vault → Note
    notion_adapter.dart         ← Notion export zip/md → Note
    storypad_adapter.dart       ← (already in note_service.dart, extract it)
  converters/
    markdown_to_quill.dart      ← MD → Quill Delta
    quill_to_markdown.dart      ← Quill Delta → MD
```

### 4.1 Abstract Interface

```dart
// lib/core/import/import_adapter.dart
abstract class NoteImportAdapter {
  /// Human-readable name (e.g., "Obsidian", "Notion")
  String get sourceName;

  /// Whether the adapter can handle the given raw content
  bool canHandle(dynamic rawInput);

  /// Convert raw input to a list of normalized ImportedNote objects
  Future<List<ImportedNote>> parse(dynamic rawInput);
}

class ImportedNote {
  final String title;
  final String markdownContent;  // always Markdown at this stage
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<String> tags;
  final List<String> internalLinks;   // [[wikilinks]] / @mentions
  final String? folderId;
  final Map<String, dynamic> rawMetadata; // preserve original frontmatter
}
```

### 4.2 Obsidian Adapter

**Input**: A ZIP of [.md](README.md) files (file picker) or a folder path.

**Strategy**:

1. List all [.md](README.md) files in the vault
2. For each file:
   - Parse YAML frontmatter (id, title, tags, dates)
   - Extract `[[wikilinks]]` → `internalLinks`
   - Extract `#tags` from body
   - Keep the rest as Markdown content
3. Preserve folder structure as Trovara folders

```dart
// Frontmatter parsing via simple RegExp (no heavy dep needed)
static Map<String, dynamic> _parseFrontmatter(String markdown) { ... }
static List<String> _extractWikilinks(String markdown) {
  return RegExp(r'\[\[([^\]]+)\]\]')
      .allMatches(markdown)
      .map((m) => m.group(1)!)
      .toList();
}
```

> [!TIP]
> Use the [yaml](build.yaml) pub package (`yaml: ^3.1.2`) for safe YAML frontmatter parsing. It's already a transitive dependency via `easy_localization`.

### 4.3 Notion Adapter

**Input**: Notion Markdown export (zip with [.md](README.md) + `.csv` files).

**Strategy**:

1. Walk the exported folder
2. For each [.md](README.md) file:
   - Strip Notion-specific metadata headers
   - Convert Notion toggle syntax `> ` blocks → collapsible md
   - Parse database CSV files as structured notes
3. Map Notion tags (multi-select) → Trovara tags

**Pain points to handle**:

- Notion embeds UUIDs in filenames: `My Note abc123def456.md` → strip UUID from title
- Notion databases export as `.csv` alongside the [.md](README.md) index — handle both

```dart
static String _stripNotionUuidFromTitle(String filename) {
  // "My Note abc123def456.md" → "My Note"
  return filename.replaceAll(RegExp(r'\s[a-f0-9]{32}(\.md)?$'), '');
}
```

### 4.4 Storypad Adapter (Refactor)

The Storypad logic currently lives inside [note_service.dart](lib/core/services/note_service.dart) (methods [\_looksLikeStorypadBackup](lib/core/services/note_service.dart#L295-L304), [\_convertStorypadBackupToTrovaraJson](lib/core/services/note_service.dart#L305-L450), and many helpers).

**Action**: Extract these into `adapters/storypad_adapter.dart` and have `NoteService.importAllFromJson` delegate to it. This reduces [note_service.dart](lib/core/services/note_service.dart) from ~1,400 lines.

---

## 5. Markdown ↔ Quill Delta Converter

This is the critical bridge between external formats and Trovara's internal representation.

### 5.1 Markdown → Quill Delta

```dart
// lib/core/import/converters/markdown_to_quill.dart
class MarkdownToQuillConverter {
  /// Convert a Markdown string to a Quill Delta JSON string.
  static String convert(String markdown) {
    final ops = <Map<String, dynamic>>[];
    // Line-by-line parsing:
    // # Heading   → insert with {'header': 1} attribute
    // **bold**    → insert with {'bold': true}
    // - item      → insert with {'list': 'bullet'}
    // plain text  → plain insert
    // [[link]]    → insert with custom link attribute
    return jsonEncode({'ops': ops});
  }
}
```

### 5.2 Quill Delta → Markdown (Export)

```dart
// lib/core/import/converters/quill_to_markdown.dart
class QuillToMarkdownConverter {
  static String convert(String quillDeltaJson) {
    // Walk ops, reconstruct Markdown:
    // {'header': 1}  → # prefix
    // {'bold': true} → **...**
    // {'list': 'bullet'} → - prefix
    // Plain text     → as-is
  }
}
```

> [!NOTE]
> For a production-quality converter, consider `flutter_quill`'s built-in `Document.toPlainText()` as a starting point. A full Markdown round-trip (with headers, lists, bold) requires custom traversal of the Delta ops list.

---

## 6. Updated `NoteService.importFromAdapter`

Add a new entry point that accepts any `NoteImportAdapter`:

```dart
Future<ImportResult> importFromAdapter(
  NoteImportAdapter adapter,
  dynamic rawInput, {
  String? targetFolderId,
}) async {
  final importedNotes = await adapter.parse(rawInput);

  int created = 0, updated = 0, skipped = 0;
  for (final imported in importedNotes) {
    final contentJson = MarkdownToQuillConverter.convert(imported.markdownContent);
    final note = Note(
      title: imported.title,
      contentJson: contentJson,
      createdAt: imported.createdAt ?? DateTime.now(),
      updatedAt: imported.updatedAt ?? DateTime.now(),
      folderId: targetFolderId ?? imported.folderId ?? 'default',
      source: adapter.sourceName.toLowerCase(),
    );
    // upsert via existing importAllFromJson logic ...
  }

  // Trigger re-embedding for new/changed notes
  await _embeddingService?.reembedStaleNotes(_noteRepository.getActiveNotes());

  return ImportResult(created: created, updated: updated, skipped: skipped);
}
```

---

## 7. Export Strategy

```
lib/core/export/
  export_service.dart          ← orchestrates all export formats
  exporters/
    markdown_exporter.dart     ← Note → .md file (Obsidian-compatible)
    json_exporter.dart         ← already in NoteService.exportAllToJson()
    notion_exporter.dart       ← Note → Notion-compatible MD (future)
```

### Markdown Export (Priority)

```dart
// lib/core/export/exporters/markdown_exporter.dart
class MarkdownExporter {
  static String exportNote(Note note) {
    final frontmatter = '''
---
id: ${note.syncId}
title: ${note.title}
created_at: ${note.createdAt.toIso8601String()}
updated_at: ${note.updatedAt.toIso8601String()}
tags: [${note.allTags.join(', ')}]
source: ${note.source}
---
''';
    final body = QuillToMarkdownConverter.convert(note.contentJson);
    return '$frontmatter\n$body';
  }
}
```

---

## 8. Embedding Pipeline — Already Correct ✅

The existing [EmbeddingService](lib/core/services/embedding_service.dart#L24-L457) already implements the "cost optimization" pattern from the plan:

| Plan recommendation              | Trovara implementation                                                                                                   |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| Chunk markdown into sections     | [\_chunkText()](lib/core/services/embedding_service.dart#L334-L375) — 2000 char chunks with 200 char overlap             |
| Hash content                     | [computeContentSignature()](lib/core/services/embedding_service.dart#L313-L333) — SHA-256 of all chunks + model + params |
| Only embed if changed            | [isNoteStale()](lib/core/services/embedding_service.dart#L201-L233) — compares stored signature to current               |
| Fire-and-forget with retry queue | `_pendingQueue` + [processPendingEmbeddings()](lib/core/services/embedding_service.dart#L251-L265)                       |

**No changes needed here.**

---

## 9. Storage Architecture — Already Correct ✅

| Plan recommendation                  | Trovara implementation                                                        |
| ------------------------------------ | ----------------------------------------------------------------------------- |
| Local: IndexedDB (web)               | ObjectBox (mobile/desktop), same concept                                      |
| Cloud: S3/Supabase/Firebase          | Google Drive JSON sync                                                        |
| Sync format: JSON (not raw markdown) | [exportAllToJson()](lib/core/services/note_service.dart#L58-L80) + Drive sync |

**No changes needed here.**

---

## 10. Implementation Plan (Phased)

### Phase 1 — Foundation (1–2 days)

| #   | Task                                                                     | File(s)                                      |
| --- | ------------------------------------------------------------------------ | -------------------------------------------- |
| 1.1 | Add `source` field to [Note](lib/models/note.dart#L10-L275) model        | [lib/models/note.dart](lib/models/note.dart) |
| 1.2 | Add `internalLinks` field to [Note](lib/models/note.dart#L10-L275) model | [lib/models/note.dart](lib/models/note.dart) |
| 1.3 | Regenerate ObjectBox bindings                                            | Run `build_runner build`                     |
| 1.4 | Create `ImportedNote` DTO                                                | `lib/core/import/import_adapter.dart`        |
| 1.5 | Create abstract `NoteImportAdapter` interface                            | `lib/core/import/import_adapter.dart`        |

### Phase 2 — Converters (2–3 days)

| #   | Task                                                                                    | File(s)                                             |
| --- | --------------------------------------------------------------------------------------- | --------------------------------------------------- |
| 2.1 | Implement `MarkdownToQuillConverter` (basic: paragraphs, headers, bullets, bold/italic) | `lib/core/import/converters/markdown_to_quill.dart` |
| 2.2 | Implement `QuillToMarkdownConverter`                                                    | `lib/core/import/converters/quill_to_markdown.dart` |
| 2.3 | Write unit tests for both converters                                                    | `test/core/import/converters/`                      |

### Phase 3 — Adapters (3–4 days)

| #   | Task                                                                                      | File(s)                                          |
| --- | ----------------------------------------------------------------------------------------- | ------------------------------------------------ |
| 3.1 | Implement `ObsidianAdapter` ([.md](README.md) + YAML frontmatter + `[[wikilinks]]`)       | `lib/core/import/adapters/obsidian_adapter.dart` |
| 3.2 | Implement `NotionAdapter` (MD export + CSV database rows)                                 | `lib/core/import/adapters/notion_adapter.dart`   |
| 3.3 | Extract `StorypadAdapter` out of [note_service.dart](lib/core/services/note_service.dart) | `lib/core/import/adapters/storypad_adapter.dart` |
| 3.4 | Write unit tests for each adapter                                                         | `test/core/import/adapters/`                     |

### Phase 4 — NoteService Integration (1 day)

| #   | Task                                                                                      | File(s)                                                                    |
| --- | ----------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| 4.1 | Add `importFromAdapter()` to [NoteService](lib/core/services/note_service.dart#L24-L1383) | [lib/core/services/note_service.dart](lib/core/services/note_service.dart) |
| 4.2 | Route Storypad detection to `StorypadAdapter`                                             | [lib/core/services/note_service.dart](lib/core/services/note_service.dart) |

### Phase 5 — Export (1–2 days)

| #   | Task                                                 | File(s)                                            |
| --- | ---------------------------------------------------- | -------------------------------------------------- |
| 5.1 | Implement `MarkdownExporter` (with YAML frontmatter) | `lib/core/export/exporters/markdown_exporter.dart` |
| 5.2 | Implement `ExportService` (orchestrator)             | `lib/core/export/export_service.dart`              |

### Phase 6 — UI (2–3 days)

| #   | Task                            | Description                                      |
| --- | ------------------------------- | ------------------------------------------------ |
| 6.1 | File picker import flow         | Select ZIP/folder, detect adapter, show progress |
| 6.2 | Import progress + result dialog | Shows created/updated/skipped counts             |
| 6.3 | Export menu                     | "Export as Markdown", "Export as JSON backup"    |

---

## 11. Architecture Diagram

```
[Obsidian .md vault]  ─┐
[Notion export ZIP]   ─┼──> NoteImportAdapter.parse()
[Storypad JSON]       ─┘         │
[Trovara JSON backup] ──────────▶ NoteService.importFromAdapter()
                                  │
                              MarkdownToQuillConverter
                                  │
                              Note (internal model)
                             / syncId, title, contentJson,
                            /  tags, source, internalLinks
                           │
               ┌───────────┼───────────────────┐
               ▼           ▼                   ▼
          ObjectBox    EmbeddingService     Google Drive
          (local)      (chunk + hash        (JSON sync)
                        + embed only
                         if stale)
                             │
                        VectorSearchService
                             │
                         RagService
                             │
                          LlmClient
                             │
                         Chat UI
```

---

## 12. What We Must NOT Do

| ❌ Anti-pattern                                                                      | ✅ Trovara alternative                                                                                                                          |
| ------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| Support raw Notion API first                                                         | Use Notion's Markdown/ZIP export                                                                                                                |
| Design a new rich-text format                                                        | Keep Quill Delta internally                                                                                                                     |
| Embed before normalization                                                           | Always normalize to [Note](lib/models/note.dart#L10-L275) first, then [reembedStaleNotes()](lib/core/services/embedding_service.dart#L234-L250) |
| Keep multiple formats internally                                                     | Single [Note](lib/models/note.dart#L10-L275) model, single `contentJson` field                                                                  |
| Embed every time a note is touched                                                   | SHA-256 signature check gates re-embedding                                                                                                      |
| Put all import logic in [NoteService](lib/core/services/note_service.dart#L24-L1383) | Adapter pattern — each platform in its own class                                                                                                |
