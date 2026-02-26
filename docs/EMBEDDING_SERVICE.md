# Embedding Service (RAG Step 1)

> Convert Trovara note content into vector embeddings and persist them for
> retrieval in the RAG pipeline.

This document describes the EmbeddingService implementation (Step 1 of the
RAG plan): how note text is extracted, chunked, embedded using Gemini,
stored in ObjectBox, and managed across the note lifecycle.

---

## Table of Contents

1. Overview
2. Files & Classes
3. Chunking strategy
4. Embedding generation
5. Persistence & Repository
6. Service API
7. Lifecycle integration
8. Offline & retry handling
9. Configuration & API key
10. Testing
11. Future improvements

---

## 1. Overview

`EmbeddingService` is responsible for converting Trovara's Quill Delta note
content into fixed-size embedding vectors (Gemini `text-embedding-004`) and
persisting them as `NoteEmbedding` entities in ObjectBox. These embeddings
are later loaded by the Retriever (Step 2) to perform vector search.

Goals:

- Chunk long notes into semantically coherent segments
- Produce 768-dimensional vectors for each chunk
- Store chunk text + metadata so retrieved context is human-readable
- Avoid blocking note saves; support offline queuing and retries

---

## 2. Files & Classes

| File                                                                      | Purpose                                                          |
| ------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| `lib/core/services/embedding_service.dart`                                | Embedding orchestration (chunking, embedding calls, persistence) |
| `lib/models/note_embedding.dart`                                          | ObjectBox entity for storing embeddings and metadata             |
| `lib/core/repository/interfaces/embedding_repository.dart`                | Storage contract                                                 |
| `lib/core/repository/implementations/objectbox_embedding_repository.dart` | ObjectBox-backed repository                                      |
| `lib/core/di/service_locator.dart`                                        | Registers `EmbeddingService` in the DI container                 |

Key model: `NoteEmbedding` stores:

- `noteId`, `chunkIndex`, `chunkText`
- `embeddingData` (comma-separated string)
- `modelVersion`, `createdAt`, `noteUpdatedAt`

---

## 3. Chunking strategy

Rules used by `_chunkText()`:

- Max chunk size: 2000 chars (~500 tokens).
- Overlap: 200 chars between adjacent chunks to preserve context.
- Prefer breaking at sentence boundaries (`. `) or newline when possible.
- Skip empty chunks after trimming.

Example: a 5000-char note becomes 3 chunks:

- Chunk 0: chars 0–2000 (break at sentence)
- Chunk 1: chars 1800–3800 (200-char overlap)
- Chunk 2: chars 3600–5000 (remainder)

Rationale: Gemini embedding context and token constraints; overlapping
improves cross-chunk retrieval quality.

---

## 4. Embedding generation

- Model: `text-embedding-004` (Gemini). Produces 768-dim vectors.
- SDK: `google_generative_ai` used in `EmbeddingService`.
- Embedding call flow:
  1. Convert Quill Delta JSON to plain text using `TextParserService.parseQuillContent()`.
  2. Chunk text with `_chunkText()`.
  3. For each chunk, call Gemini `embedContent(Content.text(chunk))` to get a vector.
  4. Serialize vector to comma-separated string via `NoteEmbedding.serializeEmbedding()` and persist.

Error handling:

- If Gemini returns an error or device is offline, the note is queued into `_pendingQueue` for retry.
- Embedding failures are logged and retried later with exponential backoff (future enhancement).

---

## 5. Persistence & Repository

- Store: `NoteEmbedding` entity saved via `IEmbeddingRepository`.
- Implementation: `ObjectBoxEmbeddingRepository` uses `ObjectBoxStoreManager` to access the `NoteEmbedding` box.
- Storage format: embeddings stored as a comma-separated string because ObjectBox Dart does not support float-list columns.
- `NoteEmbedding` includes `noteUpdatedAt` to detect stale embeddings when a note changes.

Tradeoffs:

- String serialization simplifies storage but adds deserialization cost at query time.
- This design keeps embeddings on-device for privacy (not synced to Drive).

---

## 6. Service API

Publicly used methods in `EmbeddingService` (high-level):

- `Future<void> initialize()` — Initialize Gemini model and repository.
- `Future<void> embedNote(Note note)` — Generate and save embeddings for a single note. Deletes old embeddings for that note first.
- `Future<void> reembedStaleNotes(List<Note> notes)` — Re-embed notes whose `updatedAt` is newer than stored `noteUpdatedAt`.
- `Future<List<double>?> embedQuery(String query)` — Embed a user query; returns raw vector (not stored).
- `Future<void> deleteEmbeddingsForNote(int noteId)` — Remove embeddings when a note is permanently deleted.

Example: embed a note (pseudo):

```dart
await ServiceLocator().embeddingService.embedNote(note);
```

Example: embed a user query:

```dart
final queryVector = await ServiceLocator().embeddingService.embedQuery('meditation tips');
```

---

## 7. Lifecycle integration

Integrate with `NoteService` operations:

| NoteService method       | Embedding action            | Timing                          |
| ------------------------ | --------------------------- | ------------------------------- |
| `createNote()`           | `embedNote()`               | async, non-blocking             |
| `updateNote()`           | `embedNote()` (re-embed)    | async, non-blocking (debounced) |
| `permanentDeleteNote()`  | `deleteEmbeddingsForNote()` | before DB delete                |
| `softDeleteNote()`       | No action                   | Embeddings kept for restore     |
| `restoreNoteFromTrash()` | No action                   | Embeddings still valid          |

Debouncing: avoid re-embedding on every auto-save. Mark a note as
"embedding-dirty" and re-embed when user navigates away or after a
cooldown (e.g. once per 5 minutes).

---

## 8. Offline & retry handling

When the device is offline or the embedding API fails:

- Embedding generation is queued in a local in-memory `_pendingQueue`.
- On connectivity restore (monitored via `connectivity_plus`), the queue is processed.
- On app startup, the service checks for notes without embeddings and queues them.

Note: the current in-memory queue is transient; for persistence across restarts, persist a small pending list in local storage (future enhancement).

---

## 9. Configuration & API key

- Gemini API key is read from `ConfigConstants.geminiApiKey` (config files under `configs/`) or provided by `--dart-define`.
- Do not store API keys in source control. Prefer environment or build-time defines.

Service registration (in `ServiceLocator`):

```dart
// service_locator.dart
EmbeddingService get embeddingService {
  _embeddingService ??= EmbeddingService(
    embeddingRepository: embeddingRepository,
    apiKey: ConfigConstants.geminiApiKey,
  );
  return _embeddingService!;
}

// initialize called during app startup
await ServiceLocator().initialize();
```

---

## 10. Testing

Suggested unit tests:

- `NoteEmbedding` serialization/deserialization
- `EmbeddingService._chunkText()` — boundary cases for chunking and overlap
- `EmbeddingService.embedQuery()` — mocking the Gemini client to verify returned vectors
- `EmbeddingService.embedNote()` — integration test with `MockEmbeddingRepository` to ensure embeddings saved

Example test approach: mock `GenerativeModel` (or wrap it in an adapter) and `IEmbeddingRepository` to assert behavior without network calls.

---

## 11. Future improvements

Short-term:

- Persist the pending embedding queue across restarts.
- Debounce re-embedding more aggressively to avoid API churn.
- Cache deserialized `List<double>` in `NoteEmbedding` to avoid repeated parsing.

Medium-term:

- Store embeddings as typed `Float64List` in a binary blob to speed deserialization.
- Batch embeddings for multiple notes in one API call to reduce request overhead.

Long-term:

- Support on-device embedding models for privacy-focused users.
- Add a background worker to compute embeddings incrementally (Isolate or native background task).

---

_Related: [RAG_IMPLEMENTATION.md](RAG_IMPLEMENTATION.md) — see Step 1 for the original specification._

_Document created: February 27, 2026_
