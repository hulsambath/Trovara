# Document Resolver Service (RAG Step 3)

> Resolve raw embedding search results into fully-hydrated note documents
> with metadata, ready for prompt augmentation.

This document describes the **Top-K Relevant Documents** layer of Trovara's
RAG pipeline — the component that bridges vector search (Step 2) and prompt
building (Step 4).

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Files & Classes](#3-files--classes)
4. [RetrievedDocument Model](#4-retrieveddocument-model)
5. [DocumentResolverService](#5-documentresolverservice)
6. [Dependency Injection](#6-dependency-injection)
7. [Usage Examples](#7-usage-examples)
8. [Testing](#8-testing)
9. [Future Improvements](#9-future-improvements)

---

## 1. Overview

After `VectorSearchService` (Step 2) returns a flat list of scored embedding
chunks, we need to:

1. **Group** chunks that belong to the same note
2. **Hydrate** each group with the full `Note` entity (title, tags, folder, etc.)
3. **Filter** out deleted or missing notes
4. **Rank** notes by their best chunk's similarity score
5. **Limit** results to a top-N set for the prompt context

`DocumentResolverService` performs all of the above and produces a list of
`RetrievedDocument` objects that the prompt builder (Step 4) can consume
directly.

---

## 2. Architecture

### Data flow

```
VectorSearchService.search()
    │
    ▼
List<ScoredEmbedding>           ← flat list of (chunk, score) pairs
    │
    ▼
DocumentResolverService.resolve()
    │
    ├─ Group by noteId
    ├─ Fetch full Note via NoteService.getNote()
    ├─ Skip deleted / missing notes
    ├─ Sort chunks within each note by chunkIndex
    ├─ Rank notes by max similarity score
    ├─ Limit to top-N (default 5)
    └─ Optional: trim by total text length
    │
    ▼
List<RetrievedDocument>         ← hydrated, ranked, ready for prompt
```

### Where it fits in the pipeline

```
Step 1 (Embed)  →  Step 2 (Search)  →  Step 3 (Resolve)  →  Step 4 (Prompt)
EmbeddingService   VectorSearchService  DocumentResolverService  RagService
```

---

## 3. Files & Classes

### New files (Step 3)

| File                                                     | Purpose                             |
| -------------------------------------------------------- | ----------------------------------- |
| `lib/models/retrieved_document.dart`                     | `RetrievedDocument` data class      |
| `lib/core/services/document_resolver_service.dart`       | Resolution, grouping, ranking logic |
| `test/core/services/document_resolver_service_test.dart` | 15 unit tests                       |

### Modified files

| File                               | Change                                       |
| ---------------------------------- | -------------------------------------------- |
| `lib/core/di/service_locator.dart` | Added `DocumentResolverService` registration |

### Class diagram

```
┌────────────────────────────┐
│    RetrievedDocument       │
├────────────────────────────┤
│ + note: Note               │
│ + relevantChunks: List<SE> │
│ + maxScore: double         │
├────────────────────────────┤
│ + combinedText: String     │  ← chunks joined by \n\n
│ + avgScore: double         │
│ + matchedChunkCount: int   │
│ + combinedTextLength: int  │
└────────────────────────────┘

┌─────────────────────────────────┐
│  DocumentResolverService        │
├─────────────────────────────────┤
│ + resolve()                     │  → List<RetrievedDocument>
│ + resolveToTitles()             │  → List<String>
│ + resolveToContextMaps()        │  → List<Map<String, String>>
├─────────────────────────────────┤
│ - _groupByNoteId()              │
│ - _trimByTextLength()           │
└─────────────────────────────────┘

SE = ScoredEmbedding (from vector_search_service.dart)
```

---

## 4. RetrievedDocument Model

**File:** `lib/models/retrieved_document.dart`

A fully-resolved note paired with the relevant embedding chunks that
matched a user query.

### Fields

| Field            | Type                    | Description                                              |
| ---------------- | ----------------------- | -------------------------------------------------------- |
| `note`           | `Note`                  | Full note entity with title, tags, folder, timestamps    |
| `relevantChunks` | `List<ScoredEmbedding>` | Matched chunks sorted by `chunkIndex` (reading order)    |
| `maxScore`       | `double`                | Highest similarity score among chunks — used for ranking |

### Computed properties

| Property             | Type     | Description                               |
| -------------------- | -------- | ----------------------------------------- |
| `combinedText`       | `String` | All chunk texts joined with `\n\n`        |
| `avgScore`           | `double` | Mean similarity across all matched chunks |
| `matchedChunkCount`  | `int`    | Number of chunks that matched             |
| `combinedTextLength` | `int`    | Total character count of combined text    |

### Why max score for ranking?

When a note has multiple chunks, some may be highly relevant and others less
so. Using the **max** score ensures a note with even one highly relevant
chunk is ranked appropriately, rather than being penalised by averaging in
lower-scoring chunks.

---

## 5. DocumentResolverService

**File:** `lib/core/services/document_resolver_service.dart`

### Public API

#### `resolve(scoredChunks, {topN, maxTextLength})`

The main method. Takes raw search results and returns hydrated documents.

```dart
final documents = resolver.resolve(
  scoredChunks,
  topN: 5,            // max documents (default: 5)
  maxTextLength: 20000, // optional char budget
);
```

**Parameters:**

| Parameter       | Type                    | Default | Description                                       |
| --------------- | ----------------------- | ------- | ------------------------------------------------- |
| `scoredChunks`  | `List<ScoredEmbedding>` | —       | Raw search results from Step 2                    |
| `topN`          | `int`                   | 5       | Maximum number of documents to return             |
| `maxTextLength` | `int?`                  | null    | Optional character budget for total combined text |

**Filtering rules:**

- Notes not found in `NoteService` are skipped (embedding orphan)
- Notes with `isDeleted == true` are skipped (trash)
- At least one document is always returned when `maxTextLength` is used,
  even if the single document exceeds the budget

#### `resolveToTitles(scoredChunks, {topN})`

Convenience method that returns just the note titles in ranked order.
Useful for source attribution in chat responses.

```dart
final titles = resolver.resolveToTitles(scoredChunks);
// ['Morning Reflection', 'Weekly Review']
```

#### `resolveToContextMaps(scoredChunks, {topN})`

Returns a list of metadata maps ready for prompt construction. Each map
contains:

```dart
{
  'title': 'Morning Reflection',
  'date': '2026-02-20',
  'folder': 'Journal',
  'tags': 'mood: happy, grateful | activity: meditation | time: morning',
  'text': 'The combined chunk text...',
}
```

### Constants

| Constant               | Value  | Description                           |
| ---------------------- | ------ | ------------------------------------- |
| `defaultTopN`          | 5      | Default number of documents to return |
| `maxCombinedTextChars` | 20,000 | Safety cap for total context text     |

---

## 6. Dependency Injection

`DocumentResolverService` is registered in `ServiceLocator` with lazy
initialization. It depends on `NoteService`.

```
ServiceLocator
    │
    ├── noteService ──────────── NoteService
    │       │
    │       └── used by ──────── DocumentResolverService
    │
    └── documentResolverService ─ DocumentResolverService
```

**Access:**

```dart
final resolver = ServiceLocator().documentResolverService;
```

No explicit initialization is required — the service is stateless and only
calls `NoteService.getNote()` and `NoteService.getFolder()` at resolve time.

---

## 7. Usage Examples

### Full RAG retrieval (Steps 1 → 2 → 3)

```dart
final sl = ServiceLocator();

// Step 1: Embed the user's question
final queryVector = await sl.embeddingService.embedQuery(
  'What did I write about meditation?',
);
if (queryVector == null) return;

// Step 2: Vector search
final scoredChunks = sl.vectorSearchService.search(
  queryVector,
  topK: 10,
  minScore: 0.3,
);

// Step 3: Resolve to documents
final documents = sl.documentResolverService.resolve(
  scoredChunks,
  topN: 5,
);

for (final doc in documents) {
  print('${doc.note.title} (${doc.maxScore.toStringAsFixed(2)})');
  print('  Chunks: ${doc.matchedChunkCount}');
  print('  Text: ${doc.combinedText.substring(0, 80)}...');
}
```

### Source attribution for chat

```dart
final titles = sl.documentResolverService.resolveToTitles(
  scoredChunks,
  topN: 3,
);
// → ['Morning Reflection', 'Weekly Review']
// Display as: "📎 Sources: Morning Reflection, Weekly Review"
```

### Prompt-ready context

```dart
final contextMaps = sl.documentResolverService.resolveToContextMaps(
  scoredChunks,
  topN: 5,
);
for (final ctx in contextMaps) {
  prompt.writeln('Title: ${ctx['title']}');
  prompt.writeln('Date: ${ctx['date']}');
  prompt.writeln('Folder: ${ctx['folder']}');
  prompt.writeln('Tags: ${ctx['tags']}');
  prompt.writeln('Content:\n${ctx['text']}');
}
```

---

## 8. Testing

**File:** `test/core/services/document_resolver_service_test.dart`

Tests use stub implementations of `INoteRepository` and
`IFolderRepository`, injected into a real `NoteService`. No ObjectBox or
network dependencies.

### Test coverage (15 tests)

| Group                | Test                           | Validates                 |
| -------------------- | ------------------------------ | ------------------------- |
| resolve              | empty input → empty list       | Empty state               |
| resolve              | single chunk → single document | Basic resolution          |
| resolve              | multiple chunks → grouped      | Chunk grouping by noteId  |
| resolve              | ranked by max score descending | Ranking correctness       |
| resolve              | deleted notes filtered out     | Trash handling            |
| resolve              | missing notes filtered out     | Orphan embedding handling |
| resolve              | respects topN limit            | Result limiting           |
| resolve              | trims by maxTextLength         | Token budget management   |
| resolve              | always includes ≥ 1 doc        | Edge case for tiny budget |
| resolve              | max score with varying chunks  | Multi-score ranking       |
| RetrievedDocument    | combinedText joins with \\n\\n | Text assembly             |
| RetrievedDocument    | avgScore computed correctly    | Average calculation       |
| resolveToTitles      | titles in ranked order         | Convenience method        |
| resolveToContextMaps | metadata included              | Prompt context            |
| resolveToContextMaps | default folder fallback        | Missing folder            |

### Running tests

```bash
flutter test test/core/services/document_resolver_service_test.dart
```

---

## 9. Future Improvements

**Short-term:**

- Chunk de-overlapping — when two chunks overlap (200 chars), merge the
  overlap region in `combinedText` to avoid duplicate sentences in the prompt.
- Per-note chunk limit — cap the number of chunks per note (e.g. max 3) to
  prevent a single long note from dominating the context.

**Medium-term:**

- Metadata scoring boost — optionally boost the score of notes whose tags
  match query keywords (e.g. query contains "happy" and note has mood tag
  "happy").
- Recency weighting — apply a small boost for more recent notes so the LLM
  prioritises fresh content.

**Long-term:**

- Cross-note deduplication — detect near-duplicate content across different
  notes and consolidate before passing to the prompt.
- Streaming resolution — resolve documents lazily as chunks arrive from a
  streaming search, useful if the vector index grows very large.

---

## Relationship to Other RAG Steps

| Step  | Component                     | Status      | Connects to Step 3 via                                   |
| ----- | ----------------------------- | ----------- | -------------------------------------------------------- |
| 1     | Embedding Model               | ✅ Done     | Generates embeddings stored in ObjectBox                 |
| 2     | Vector Storage & Search       | ✅ Done     | Returns `List<ScoredEmbedding>` — input to resolver      |
| **3** | **Top-K Document Resolution** | **✅ Done** | **Outputs `List<RetrievedDocument>` for prompt builder** |
| 4     | Prompt Augmentation           | Planned     | Consumes `RetrievedDocument` to build LLM prompt         |
| 5     | LLM Generator                 | Planned     | Sends augmented prompt to Gemini                         |
| 6     | Chat UI                       | Planned     | Displays answer with source attribution                  |

---

_Document created: February 27, 2026_
_Relates to: [RAG_IMPLEMENTATION.md](RAG_IMPLEMENTATION.md) — Step 3_
