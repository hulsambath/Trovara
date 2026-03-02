# RAG Implementation Plan for Trovara

> **Retrieval-Augmented Generation** — Let users ask natural-language questions about
> their notes and receive AI-generated answers grounded in their own content.

```
User Query
    ↓
Embedding Model          ← Step 1
    ↓
Vector Search (Retriever)← Step 2
    ↓
Top-K Relevant Documents ← Step 3
    ↓
Prompt Augmentation      ← Step 4
    ↓
LLM (Generator)          ← Step 5
    ↓
Final Answer             ← Step 6 (Chat UI)
```

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Step 1 — Embedding Model](#2-step-1--embedding-model)
3. [Step 2 — Vector Storage & Search (Retriever)](#3-step-2--vector-storage--search-retriever)
4. [Step 3 — Top-K Relevant Documents](#4-step-3--top-k-relevant-documents)
5. [Step 4 — Prompt Augmentation](#5-step-4--prompt-augmentation)
6. [Step 5 — LLM (Generator)](#6-step-5--llm-generator)
7. [Step 6 — Chat UI](#7-step-6--chat-ui)
8. [Cross-Cutting Concerns](#8-cross-cutting-concerns)

---

## 1. Architecture Overview

### How RAG fits into the existing Trovara architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Trovara App                          │
│                                                             │
│  ┌──────────────┐   ┌──────────────┐   ┌────────────────┐  │
│  │  Notes View   │   │  Insights    │   │  Chat View     │  │
│  │  (existing)   │   │  (existing)  │   │  (new - Step6) │  │
│  └──────┬───────┘   └──────────────┘   └───────┬────────┘  │
│         │                                       │           │
│  ┌──────┴───────────────────────────────────────┴────────┐  │
│  │                    ViewModel Layer                     │  │
│  │  NotesViewModel (existing)    ChatViewModel (new)     │  │
│  └──────┬───────────────────────────────────────┬────────┘  │
│         │                                       │           │
│  ┌──────┴───────────────────────────────────────┴────────┐  │
│  │                    Service Layer                       │  │
│  │  NoteService       EmbeddingService    RagService     │  │
│  │  (existing)        (new - Step 1)      (new - Step 4) │  │
│  └──────┬───────────────────────┬──────────────┬─────────┘  │
│         │                       │              │            │
│  ┌──────┴──────┐  ┌────────────┴───────┐  ┌───┴──────────┐ │
│  │ Note Repo   │  │ Embedding Repo     │  │ LLM Client   │ │
│  │ (ObjectBox)  │  │ (ObjectBox)        │  │ (Gemini API) │ │
│  │ (existing)   │  │ (new - Step 2)     │  │ (new-Step 5) │ │
│  └─────────────┘  └────────────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### New files to create (all steps)

```
lib/
├── core/
│   ├── di/
│   │   └── service_locator.dart          ← MODIFY (register new services)
│   ├── repository/
│   │   ├── interfaces/
│   │   │   └── embedding_repository.dart ← NEW (Step 2)
│   │   └── implementations/
│   │       └── objectbox_embedding_repository.dart ← NEW (Step 2)
│   └── services/
│       ├── embedding_service.dart        ← NEW (Step 1)
│       ├── vector_search_service.dart    ← NEW (Step 2)
│       ├── rag_service.dart              ← NEW (Step 4 + 5)
│       └── llm_client.dart              ← NEW (Step 5)
├── models/
│   ├── note_embedding.dart               ← NEW (Step 1)
│   └── chat_message.dart                ← NEW (Step 6)
└── views/
    └── chat/
        ├── chat_view.dart               ← NEW (Step 6)
        ├── chat_view_model.dart         ← NEW (Step 6)
        └── widgets/
            ├── chat_bubble.dart         ← NEW (Step 6)
            └── chat_input.dart          ← NEW (Step 6)
```

### Provider choice: Google Gemini

| Criteria            | Gemini                               | OpenAI                               | On-Device          |
| ------------------- | ------------------------------------ | ------------------------------------ | ------------------ |
| Ecosystem alignment | ✅ Google Sign-In already integrated | ❌ New vendor                        | ❌ No Dart support |
| Free tier           | ✅ Generous (1500 req/day)           | ❌ Paid only                         | ✅ Free            |
| Embedding model     | `text-embedding-004` (768 dims)      | `text-embedding-3-small` (1536 dims) | N/A                |
| Generative model    | `gemini-2.0-flash`                   | `gpt-4o-mini`                        | N/A                |
| Dart SDK            | ✅ `google_generative_ai`            | ❌ No official SDK                   | N/A                |

**Decision: Gemini** — native Dart SDK, aligns with existing Google infra, generous free tier.

---

## 2. Step 1 — Embedding Model

> **Goal:** Convert note content (Quill Delta JSON) into vector embeddings
> and persist them locally for retrieval.

### 2.1 Dependencies to add

```yaml
# pubspec.yaml
dependencies:
  google_generative_ai: ^0.4.6 # Gemini SDK (embeddings + generation)
```

### 2.2 New model: `NoteEmbedding`

**File:** `lib/models/note_embedding.dart`

```dart
import 'package:objectbox/objectbox.dart';

/// Stores a single embedding vector for a chunk of a note's content.
///
/// A note may have multiple NoteEmbedding entries if it's long enough
/// to be split into multiple chunks.
@Entity()
class NoteEmbedding {
  @Id()
  int id;

  /// The ID of the Note this embedding belongs to.
  int noteId;

  /// Index of this chunk within the note (0-based).
  /// A short note has a single chunk (index 0).
  int chunkIndex;

  /// The plain-text chunk that was embedded.
  /// Stored so we can return it as context without re-parsing the note.
  String chunkText;

  /// The embedding vector, serialized as a comma-separated string.
  /// Gemini text-embedding-004 produces 768-dimensional vectors.
  ///
  /// ObjectBox Dart does not support float-list/HNSW indexes,
  /// so we store as String and deserialize for in-memory search.
  String embeddingData;

  /// The embedding model version used (e.g. "text-embedding-004").
  /// Used to detect stale embeddings when the model is upgraded.
  String modelVersion;

  /// Timestamp when this embedding was generated.
  DateTime createdAt;

  /// The updatedAt of the Note at the time of embedding.
  /// Used to detect if the note has changed and needs re-embedding.
  DateTime noteUpdatedAt;

  NoteEmbedding({
    this.id = 0,
    required this.noteId,
    required this.chunkIndex,
    required this.chunkText,
    required this.embeddingData,
    required this.modelVersion,
    DateTime? createdAt,
    required this.noteUpdatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Deserialize the embedding string back to a List<double>.
  List<double> get embedding =>
      embeddingData.split(',').map((s) => double.parse(s.trim())).toList();

  /// Serialize a List<double> into the storage format.
  static String serializeEmbedding(List<double> vector) =>
      vector.map((d) => d.toStringAsFixed(8)).join(',');
}
```

### 2.3 New service: `EmbeddingService`

**File:** `lib/core/services/embedding_service.dart`

```dart
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:logger/logger.dart';
import 'package:trovara/core/repository/interfaces/embedding_repository.dart';
import 'package:trovara/core/services/text_parser_service.dart';
import 'package:trovara/models/note.dart';
import 'package:trovara/models/note_embedding.dart';

/// Converts note content into vector embeddings via Google Gemini API.
///
/// Responsibilities:
/// - Chunk long notes into ~500-token segments with overlap
/// - Call Gemini text-embedding-004 to generate vectors
/// - Persist embeddings via [IEmbeddingRepository]
/// - Re-embed notes when their content changes
/// - Queue failed embeddings for retry
class EmbeddingService {
  static const String _modelVersion = 'text-embedding-004';
  static const int _maxChunkChars = 2000;   // ~500 tokens
  static const int _overlapChars = 200;     // overlap between chunks

  final IEmbeddingRepository _embeddingRepository;
  final String _apiKey;
  final Logger _logger = Logger();

  late final GenerativeModel _embeddingModel;

  EmbeddingService({
    required IEmbeddingRepository embeddingRepository,
    required String apiKey,
  })  : _embeddingRepository = embeddingRepository,
        _apiKey = apiKey;

  /// Initialize the Gemini embedding model.
  Future<void> initialize() async {
    _embeddingModel = GenerativeModel(
      model: _modelVersion,
      apiKey: _apiKey,
    );
    _logger.i('EmbeddingService initialized with model $_modelVersion');
  }

  // ─────────────────────── Public API ───────────────────────

  /// Generate and store embeddings for a single note.
  ///
  /// 1. Extract plain text via TextParserService
  /// 2. Split into chunks
  /// 3. Generate embeddings for each chunk
  /// 4. Save to repository (replacing old embeddings for this note)
  Future<void> embedNote(Note note) async {
    try {
      final plainText = TextParserService.parseQuillContent(note.contentJson);
      if (plainText.trim().isEmpty) {
        _logger.d('Skipping empty note ${note.id}');
        return;
      }

      // Delete old embeddings for this note
      await _embeddingRepository.deleteByNoteId(note.id);

      // Chunk the text
      final chunks = _chunkText(plainText);

      // Generate embeddings for each chunk
      for (int i = 0; i < chunks.length; i++) {
        final vector = await _generateEmbedding(chunks[i]);
        if (vector == null) continue;

        final noteEmbedding = NoteEmbedding(
          noteId: note.id,
          chunkIndex: i,
          chunkText: chunks[i],
          embeddingData: NoteEmbedding.serializeEmbedding(vector),
          modelVersion: _modelVersion,
          noteUpdatedAt: note.updatedAt,
        );

        await _embeddingRepository.saveEmbedding(noteEmbedding);
      }

      _logger.i('Embedded note ${note.id}: ${chunks.length} chunk(s)');
    } catch (e) {
      _logger.e('Failed to embed note ${note.id}: $e');
      // Add to retry queue (Step 1 enhancement)
      rethrow;
    }
  }

  /// Re-embed all notes that are stale (note updated after embedding).
  Future<void> reembedStaleNotes(List<Note> notes) async {
    for (final note in notes) {
      if (await _isStale(note)) {
        await embedNote(note);
      }
    }
  }

  /// Embed a user query for similarity comparison.
  /// Returns the raw vector (not stored).
  Future<List<double>?> embedQuery(String query) async {
    return _generateEmbedding(query);
  }

  /// Remove all embeddings for a note (called on permanent delete).
  Future<void> deleteEmbeddingsForNote(int noteId) async {
    await _embeddingRepository.deleteByNoteId(noteId);
  }

  // ─────────────────────── Private helpers ───────────────────────

  /// Split text into overlapping chunks of ~500 tokens.
  List<String> _chunkText(String text) {
    if (text.length <= _maxChunkChars) return [text];

    final chunks = <String>[];
    int start = 0;

    while (start < text.length) {
      int end = start + _maxChunkChars;
      if (end >= text.length) {
        chunks.add(text.substring(start));
        break;
      }

      // Try to break at a sentence boundary
      final segment = text.substring(start, end);
      final lastPeriod = segment.lastIndexOf('. ');
      final lastNewline = segment.lastIndexOf('\n');
      final breakPoint = [lastPeriod, lastNewline]
          .where((p) => p > _maxChunkChars ~/ 2)
          .fold<int>(-1, (a, b) => b > a ? b : a);

      if (breakPoint > 0) {
        end = start + breakPoint + 1;
      }

      chunks.add(text.substring(start, end).trim());
      start = end - _overlapChars; // overlap
    }

    return chunks.where((c) => c.isNotEmpty).toList();
  }

  /// Call Gemini API to generate an embedding vector.
  Future<List<double>?> _generateEmbedding(String text) async {
    try {
      final result = await _embeddingModel.embedContent(
        Content.text(text),
      );
      return result.embedding.values;
    } catch (e) {
      _logger.e('Gemini embedding API error: $e');
      return null;
    }
  }

  /// Check if a note's embeddings are outdated.
  Future<bool> _isStale(Note note) async {
    final embeddings = _embeddingRepository.getEmbeddingsByNoteId(note.id);
    if (embeddings.isEmpty) return true;

    // If note was updated after the embedding was created, it's stale
    return embeddings.first.noteUpdatedAt.isBefore(note.updatedAt);
  }
}
```

### 2.4 Text chunking strategy

Notes in Trovara are stored as **Quill Delta JSON**. The existing
`TextParserService.parseQuillContent()` already converts this to plain text.

**Chunking rules:**

| Property         | Value                               | Rationale                                 |
| ---------------- | ----------------------------------- | ----------------------------------------- |
| Max chunk size   | 2000 chars (~500 tokens)            | Gemini embedding window is 2048 tokens    |
| Overlap          | 200 chars (~50 tokens)              | Preserves context across chunk boundaries |
| Break preference | Sentence boundary (`. `) or newline | Avoids splitting mid-sentence             |
| Minimum chunk    | Non-empty after trim                | Skip empty chunks                         |

**Example:** A 5000-character note produces 3 chunks:

```
Chunk 0: chars 0–2000    (break at sentence)
Chunk 1: chars 1800–3800  (200-char overlap, break at sentence)
Chunk 2: chars 3600–5000  (remainder)
```

### 2.5 Metadata enrichment

Each embedding stores the **plain-text chunk** alongside the vector. When
building the prompt (Step 4), we also pull metadata from the parent `Note`:

```
Metadata available per chunk:
├── note.title            → "Morning Reflection"
├── note.createdAt        → 2026-02-20
├── note.folderId         → "journal"
├── note.moodTags         → ["happy", "grateful"]
├── note.activityTags     → ["meditation"]
├── note.timeTags         → ["morning"]
├── note.personalGrowthTags → ["mindfulness"]
└── note.customTags       → ["daily-routine"]
```

This metadata is NOT embedded but IS included in the augmented prompt for
richer LLM context.

### 2.6 Note lifecycle integration

Hook `EmbeddingService` into `NoteService` at these points:

| NoteService method       | Embedding action            | Timing                          |
| ------------------------ | --------------------------- | ------------------------------- |
| `createNote()`           | `embedNote()`               | async, non-blocking             |
| `updateNote()`           | `embedNote()` (re-embed)    | async, non-blocking (debounced) |
| `permanentDeleteNote()`  | `deleteEmbeddingsForNote()` | before DB delete                |
| `softDeleteNote()`       | No action                   | Embeddings kept for restore     |
| `restoreNoteFromTrash()` | No action                   | Embeddings still valid          |
| `importAllFromJson()`    | `reembedStaleNotes()`       | after full import               |
| `mergeWithRemoteData()`  | `reembedStaleNotes()`       | after merge complete            |

**Debouncing:** Note auto-saves every 30 seconds (in `NoteViewModel`). We
should NOT re-embed on every auto-save. Instead, mark the note as
"embedding-dirty" and re-embed when the user navigates away from the note
editor, or at most once per 5 minutes.

### 2.7 ServiceLocator registration

```dart
// In lib/core/di/service_locator.dart — additions:

IEmbeddingRepository? _embeddingRepository;
EmbeddingService? _embeddingService;

IEmbeddingRepository get embeddingRepository {
  _embeddingRepository ??= ObjectBoxEmbeddingRepository();
  return _embeddingRepository!;
}

EmbeddingService get embeddingService {
  _embeddingService ??= EmbeddingService(
    embeddingRepository: embeddingRepository,
    apiKey: _geminiApiKey,  // from config
  );
  return _embeddingService!;
}

// In initialize():
await embeddingService.initialize();
```

### 2.8 API key management

Store the Gemini API key in the existing config files:

```json
// configs/trovara_prod.json
{
  "gemini_api_key": "YOUR_PRODUCTION_KEY"
}

// configs/trovara_staging.json
{
  "gemini_api_key": "YOUR_STAGING_KEY"
}
```

Alternatively, use `--dart-define=GEMINI_API_KEY=xxx` at build time (same
pattern as the existing app icon/flavor configs).

### 2.9 Offline handling

When the device is offline:

1. Note creation/update proceeds normally (no blocking)
2. Embedding generation is queued in a `pendingEmbeddings` list (in-memory)
3. When connectivity is restored (`connectivity_plus` — already a dependency),
   process the queue
4. On app startup, check for notes without embeddings and queue them

```
┌──────────┐     online?     ┌──────────────┐     ┌──────────┐
│ Note Save ├───────yes──────►│ Embed Now     ├────►│ Save to  │
│           │                 │ (Gemini API)  │     │ ObjectBox│
└─────┬─────┘                 └──────────────┘     └──────────┘
      │ no
      ▼
┌─────────────────┐    connectivity restored    ┌──────────────┐
│ Add to pending   ├──────────────────────────►│ Process queue │
│ queue (in-memory)│                            │ (batch embed) │
└─────────────────┘                            └──────────────┘
```

---

## 3. Step 2 — Vector Storage & Search (Retriever)

> **Goal:** Store embeddings in ObjectBox and perform cosine-similarity
> search to find the most relevant note chunks for a query.

### 3.1 New repository interface: `IEmbeddingRepository`

**File:** `lib/core/repository/interfaces/embedding_repository.dart`

```dart
import 'package:trovara/models/note_embedding.dart';

/// Interface for embedding persistence operations.
abstract class IEmbeddingRepository {
  Future<void> initialize();

  /// Save a single embedding.
  Future<void> saveEmbedding(NoteEmbedding embedding);

  /// Save multiple embeddings in a batch.
  Future<void> saveEmbeddings(List<NoteEmbedding> embeddings);

  /// Get all embeddings for a specific note.
  List<NoteEmbedding> getEmbeddingsByNoteId(int noteId);

  /// Get all stored embeddings (for brute-force search).
  List<NoteEmbedding> getAllEmbeddings();

  /// Delete all embeddings for a specific note.
  Future<void> deleteByNoteId(int noteId);

  /// Delete all embeddings (e.g., on model version upgrade).
  Future<void> deleteAll();

  /// Count total embeddings stored.
  int get totalEmbeddings;

  void dispose();
}
```

### 3.2 ObjectBox implementation

**File:** `lib/core/repository/implementations/objectbox_embedding_repository.dart`

```dart
import 'package:trovara/core/repository/base/objectbox_store_manager.dart';
import 'package:trovara/core/repository/interfaces/embedding_repository.dart';
import 'package:trovara/models/note_embedding.dart';
import 'package:trovara/objectbox.g.dart';

class ObjectBoxEmbeddingRepository implements IEmbeddingRepository {
  late Box<NoteEmbedding> _box;
  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    final store = await ObjectBoxStoreManager().store;
    _box = store.box<NoteEmbedding>();
    _isInitialized = true;
  }

  @override
  Future<void> saveEmbedding(NoteEmbedding embedding) async {
    _box.put(embedding);
  }

  @override
  Future<void> saveEmbeddings(List<NoteEmbedding> embeddings) async {
    _box.putMany(embeddings);
  }

  @override
  List<NoteEmbedding> getEmbeddingsByNoteId(int noteId) =>
      _box.query(NoteEmbedding_.noteId.equals(noteId))
          .build()
          .find();

  @override
  List<NoteEmbedding> getAllEmbeddings() => _box.getAll();

  @override
  Future<void> deleteByNoteId(int noteId) async {
    final embeddings = getEmbeddingsByNoteId(noteId);
    _box.removeMany(embeddings.map((e) => e.id).toList());
  }

  @override
  Future<void> deleteAll() async {
    _box.removeAll();
  }

  @override
  int get totalEmbeddings => _box.count();

  @override
  void dispose() {}
}
```

### 3.3 New service: `VectorSearchService`

**File:** `lib/core/services/vector_search_service.dart`

Since ObjectBox Dart does **not** support HNSW vector indexes, we implement
**in-memory brute-force cosine similarity**. This is acceptable for a
personal note-taking app (typically < 10,000 chunks).

```dart
import 'dart:math';
import 'package:trovara/core/repository/interfaces/embedding_repository.dart';
import 'package:trovara/models/note_embedding.dart';

/// Performs cosine-similarity search over stored embeddings.
///
/// Uses brute-force in-memory search. Performance is acceptable for
/// personal note collections (< 10K chunks). If scale increases,
/// consider switching to an ANN library or external vector DB.
class VectorSearchService {
  final IEmbeddingRepository _repository;

  VectorSearchService({required IEmbeddingRepository repository})
      : _repository = repository;

  /// Find the top-K most similar chunks to the query embedding.
  ///
  /// Returns a list of (NoteEmbedding, similarity_score) pairs,
  /// sorted by descending similarity.
  List<ScoredEmbedding> search(
    List<double> queryEmbedding, {
    int topK = 5,
    double minScore = 0.3,
  }) {
    final allEmbeddings = _repository.getAllEmbeddings();
    final scored = <ScoredEmbedding>[];

    for (final emb in allEmbeddings) {
      final score = _cosineSimilarity(queryEmbedding, emb.embedding);
      if (score >= minScore) {
        scored.add(ScoredEmbedding(embedding: emb, score: score));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(topK).toList();
  }

  /// Cosine similarity between two vectors.
  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    final denominator = sqrt(normA) * sqrt(normB);
    if (denominator == 0) return 0.0;
    return dotProduct / denominator;
  }
}

/// A NoteEmbedding paired with its similarity score.
class ScoredEmbedding {
  final NoteEmbedding embedding;
  final double score;

  ScoredEmbedding({required this.embedding, required this.score});
}
```

### 3.4 Performance considerations

| Metric                              | Estimate     | Notes                               |
| ----------------------------------- | ------------ | ----------------------------------- |
| Avg note size                       | ~300 words   | 1 chunk per note                    |
| Large note                          | ~3000 words  | ~3 chunks                           |
| 500 notes                           | ~600 chunks  | ~1.8 MB embedding data              |
| 2000 notes                          | ~2500 chunks | ~7.5 MB embedding data              |
| Search time (2500 chunks, 768 dims) | ~5–15 ms     | Brute-force cosine, single-threaded |

For a personal note app, brute-force is performant enough. If the app scales
to 10,000+ chunks, consider:

- Pre-loading embeddings into a typed `Float64List` for SIMD-friendly access
- Using `Isolate.run()` to move search off the main thread
- External vector DB (Pinecone, Qdrant) for cloud-scale

---

## 4. Step 3 — Top-K Relevant Documents

> **Goal:** Given scored chunks from Step 2, resolve them back to full
> notes with metadata and deduplicate.

### 4.1 Document resolution logic

After vector search returns top-K `ScoredEmbedding` results, we:

1. **Group by noteId** — multiple chunks from the same note are merged
2. **Fetch full Note** — get title, tags, folder, timestamps from `NoteService`
3. **Rank notes** — max similarity score per note, then sort descending
4. **Limit to top-N notes** — typically 3–5 notes for the prompt context

```dart
/// In RagService (Step 4), document resolution:

List<RetrievedDocument> resolveDocuments(
  List<ScoredEmbedding> scoredChunks,
  NoteService noteService,
) {
  // Group chunks by noteId
  final noteGroups = <int, List<ScoredEmbedding>>{};
  for (final sc in scoredChunks) {
    noteGroups.putIfAbsent(sc.embedding.noteId, () => []).add(sc);
  }

  // Build RetrievedDocument per note
  final docs = <RetrievedDocument>[];
  for (final entry in noteGroups.entries) {
    final note = noteService.getNote(entry.key);
    if (note == null || note.isDeleted) continue;

    final chunks = entry.value..sort(
      (a, b) => a.embedding.chunkIndex.compareTo(b.embedding.chunkIndex),
    );
    final maxScore = chunks.map((c) => c.score).reduce(max);

    docs.add(RetrievedDocument(
      note: note,
      relevantChunks: chunks,
      maxScore: maxScore,
    ));
  }

  docs.sort((a, b) => b.maxScore.compareTo(a.maxScore));
  return docs;
}
```

### 4.2 `RetrievedDocument` model

```dart
/// A note with its relevant chunks and similarity scores.
class RetrievedDocument {
  final Note note;
  final List<ScoredEmbedding> relevantChunks;
  final double maxScore;

  RetrievedDocument({
    required this.note,
    required this.relevantChunks,
    required this.maxScore,
  });

  /// Combined text of all relevant chunks (in order).
  String get combinedText =>
      relevantChunks.map((c) => c.embedding.chunkText).join('\n\n');
}
```

---

## 5. Step 4 — Prompt Augmentation

> **Goal:** Build a context-rich prompt that combines the user's question
> with retrieved note content and metadata.

### 5.1 Prompt template

```
You are a helpful assistant for a personal note-taking app called Trovara.
The user is asking a question about their own notes.

Answer ONLY based on the provided note context below. If the answer cannot
be found in the notes, say "I couldn't find relevant information in your
notes about this topic."

Be concise, helpful, and reference specific notes by title when possible.

─── USER'S NOTES (most relevant) ───

[Note 1]
Title: {title}
Date: {createdAt}
Folder: {folderName}
Tags: {mood: happy, grateful | activity: meditation | time: morning}
Content:
{chunk_text}

[Note 2]
Title: {title}
...

─── END OF NOTES ───

User question: {user_query}
```

### 5.2 Prompt builder

**In:** `lib/core/services/rag_service.dart`

```dart
String buildAugmentedPrompt({
  required String userQuery,
  required List<RetrievedDocument> documents,
  required NoteService noteService,
}) {
  final buffer = StringBuffer();

  buffer.writeln('You are a helpful assistant for a personal note-taking '
      'app called Trovara. The user is asking a question about their '
      'own notes.');
  buffer.writeln();
  buffer.writeln('Answer ONLY based on the provided note context below. '
      'If the answer cannot be found in the notes, say "I couldn\'t find '
      'relevant information in your notes about this topic."');
  buffer.writeln();
  buffer.writeln('Be concise, helpful, and reference specific notes by '
      'title when possible.');
  buffer.writeln();
  buffer.writeln('─── USER\'S NOTES (most relevant) ───');
  buffer.writeln();

  for (int i = 0; i < documents.length; i++) {
    final doc = documents[i];
    final note = doc.note;
    final folder = noteService.getFolder(note.folderId);

    buffer.writeln('[Note ${i + 1}]');
    buffer.writeln('Title: ${note.title}');
    buffer.writeln('Date: ${note.createdAt.toIso8601String().split("T")[0]}');
    buffer.writeln('Folder: ${folder?.name ?? "Default"}');

    // Build tag string
    final tags = <String>[];
    if (note.moodTags.isNotEmpty) tags.add('mood: ${note.moodTags.join(", ")}');
    if (note.activityTags.isNotEmpty) tags.add('activity: ${note.activityTags.join(", ")}');
    if (note.timeTags.isNotEmpty) tags.add('time: ${note.timeTags.join(", ")}');
    if (note.personalGrowthTags.isNotEmpty) {
      tags.add('growth: ${note.personalGrowthTags.join(", ")}');
    }
    if (tags.isNotEmpty) buffer.writeln('Tags: ${tags.join(" | ")}');

    buffer.writeln('Content:');
    buffer.writeln(doc.combinedText);
    buffer.writeln();
  }

  buffer.writeln('─── END OF NOTES ───');
  buffer.writeln();
  buffer.writeln('User question: $userQuery');

  return buffer.toString();
}
```

### 5.3 Context window management

| Model              | Context window | Target usage                    |
| ------------------ | -------------- | ------------------------------- |
| `gemini-2.0-flash` | 1M tokens      | Up to ~50 full notes in context |

Even with Gemini's large context window, we limit to **top 5 notes** to:

- Keep responses focused and grounded
- Reduce API costs (input tokens)
- Improve answer quality (less noise)

If a single note exceeds 4000 chars, include only the **most relevant chunks**
rather than the full note content.

---

## 6. Step 5 — LLM (Generator)

> **Goal:** Send the augmented prompt to Gemini and stream the response
> back to the user.

### 6.1 New service: `LlmClient`

**File:** `lib/core/services/llm_client.dart`

```dart
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:logger/logger.dart';

/// Client for Gemini generative model.
///
/// Handles:
/// - Single-turn Q&A (for RAG responses)
/// - Streaming responses (for real-time UI updates)
/// - Error handling and retries
class LlmClient {
  static const String _modelName = 'gemini-2.0-flash';

  final String _apiKey;
  final Logger _logger = Logger();
  late final GenerativeModel _model;

  LlmClient({required String apiKey}) : _apiKey = apiKey;

  Future<void> initialize() async {
    _model = GenerativeModel(
      model: _modelName,
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.3,       // Low temperature for factual answers
        topP: 0.8,
        maxOutputTokens: 1024,
      ),
    );
    _logger.i('LlmClient initialized with model $_modelName');
  }

  /// Generate a complete response (non-streaming).
  Future<String> generate(String prompt) async {
    try {
      final response = await _model.generateContent([
        Content.text(prompt),
      ]);
      return response.text ?? 'No response generated.';
    } catch (e) {
      _logger.e('LLM generation error: $e');
      rethrow;
    }
  }

  /// Stream a response token-by-token.
  Stream<String> generateStream(String prompt) async* {
    try {
      final response = _model.generateContentStream([
        Content.text(prompt),
      ]);

      await for (final chunk in response) {
        if (chunk.text != null) {
          yield chunk.text!;
        }
      }
    } catch (e) {
      _logger.e('LLM streaming error: $e');
      rethrow;
    }
  }
}
```

### 6.2 Orchestrator: `RagService`

**File:** `lib/core/services/rag_service.dart`

```dart
/// Orchestrates the full RAG pipeline:
/// Query → Embed → Search → Resolve → Augment → Generate → Answer
class RagService {
  final EmbeddingService _embeddingService;
  final VectorSearchService _vectorSearchService;
  final NoteService _noteService;
  final LlmClient _llmClient;

  RagService({
    required EmbeddingService embeddingService,
    required VectorSearchService vectorSearchService,
    required NoteService noteService,
    required LlmClient llmClient,
  })  : _embeddingService = embeddingService,
        _vectorSearchService = vectorSearchService,
        _noteService = noteService,
        _llmClient = llmClient;

  /// Full RAG query: returns the final answer string.
  Future<String> query(String userQuestion) async {
    // Step 1: Embed the user query
    final queryVector = await _embeddingService.embedQuery(userQuestion);
    if (queryVector == null) {
      return 'Sorry, I was unable to process your question. Please try again.';
    }

    // Step 2: Vector search
    final scoredChunks = _vectorSearchService.search(
      queryVector,
      topK: 10,
      minScore: 0.3,
    );

    if (scoredChunks.isEmpty) {
      return 'I couldn\'t find any relevant notes for your question.';
    }

    // Step 3: Resolve to documents
    final documents = resolveDocuments(scoredChunks, _noteService);

    // Step 4: Build augmented prompt
    final prompt = buildAugmentedPrompt(
      userQuery: userQuestion,
      documents: documents.take(5).toList(),
      noteService: _noteService,
    );

    // Step 5: Generate response
    return _llmClient.generate(prompt);
  }

  /// Streaming version for real-time UI.
  Stream<String> queryStream(String userQuestion) async* {
    final queryVector = await _embeddingService.embedQuery(userQuestion);
    if (queryVector == null) {
      yield 'Sorry, I was unable to process your question.';
      return;
    }

    final scoredChunks = _vectorSearchService.search(
      queryVector,
      topK: 10,
      minScore: 0.3,
    );

    if (scoredChunks.isEmpty) {
      yield 'I couldn\'t find any relevant notes for your question.';
      return;
    }

    final documents = resolveDocuments(scoredChunks, _noteService);
    final prompt = buildAugmentedPrompt(
      userQuery: userQuestion,
      documents: documents.take(5).toList(),
      noteService: _noteService,
    );

    yield* _llmClient.generateStream(prompt);
  }
}
```

---

## 7. Step 6 — Chat UI ✅

> **Status:** Complete · **Tests:** 22 passing · **Files:** 8 created, 3 modified

### 7.1 `ChatMessage` model

**File:** `lib/models/chat_message.dart`

Immutable data model representing a single message in the chat conversation.
Updated from the original plan to include `isError` for error-state rendering.

```dart
class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final List<String> sourceNoteTitles; // non-nullable, defaults to []
  final bool isLoading;
  final bool isError;                  // added: error state

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    DateTime? timestamp,
    this.sourceNoteTitles = const [],
    this.isLoading = false,
    this.isError = false,
  }) : timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({ ... }); // immutable updates for streaming
}
```

### 7.2 `ChatViewModel`

**File:** `lib/views/chat/chat_view_model.dart`

Extends `BaseViewModel` (dispose-safe `ChangeNotifier`). Manages the full
message lifecycle: user input → streaming AI response → source attribution.

```dart
class ChatViewModel extends BaseViewModel {
  // Testable: accepts optional RagService for dependency injection
  ChatViewModel({RagService? ragService})
      : _ragService = ragService ?? ServiceLocator().ragService;

  // --- Public getters ---
  List<ChatMessage> get messages;   // unmodifiable
  bool get isProcessing;
  bool get isAvailable;             // delegates to RagService
  bool get hasMessages;

  // --- Public API ---
  Future<void> sendMessage(String question);  // streams via queryStream()
  void clearConversation();

  // --- Static ---
  static const List<String> suggestedQuestions = [ ... ];
}
```

**Message flow in `sendMessage()`:**

```
1. Trim + validate input
2. Add user ChatMessage
3. Add AI placeholder (isLoading: true)
4. Stream chunks via RagService.queryStream()
   → Update AI message content on each chunk
5. Fetch source titles via RagService.getSourceTitles()
6. Final update: content + sources, isLoading: false
7. On error: isError: true, friendly message
```

### 7.3 Chat UI widgets

Follows the project's 3-file pattern (`*_view.dart` + `*_content.dart` part
file + widget part files):

| File                                              | Purpose                                                        |
| ------------------------------------------------- | -------------------------------------------------------------- |
| `lib/views/chat/chat_view.dart`                   | `ViewModelProvider<ChatViewModel>` entry point                 |
| `lib/views/chat/chat_content.dart`                | Scaffold, AppBar ("Ask your notes"), message list + input      |
| `lib/views/chat/widgets/chat_bubble.dart`         | User (right, primary) / AI (left, surface) bubbles with avatar |
| `lib/views/chat/widgets/chat_input_field.dart`    | Multi-line TextField + circular send button                    |
| `lib/views/chat/widgets/source_attribution.dart`  | "Sources" label with note-title chips below AI bubbles         |
| `lib/views/chat/widgets/suggested_questions.dart` | Empty-state card list with tappable question suggestions       |

**UI wireframe:**

```
┌──────────────────────────────────────┐
│  ← Ask your notes        🗑️  ⋮     │  AppBar (clear button when messages)
├──────────────────────────────────────┤
│                                      │
│     ┌─────────────────────────┐      │
│     │ What did I write about  │──────│  User bubble (right, primary)
│     │ meditation last week?   │      │
│     └─────────────────────────┘      │
│                                      │
│  ✨ ┌─────────────────────────┐      │
│  │  │ Based on your notes...  │──────│  AI bubble (left, surface)
│  │  │                         │      │
│  │  │ 📎 Sources:             │──────│  Source attribution chips
│  │  │ [Morning Reflection]    │      │
│  │  │ [Weekly Review]         │      │
│     └─────────────────────────┘      │
│                                      │
│  ┌────────────────────── ──── ┐      │
│  │ ✨ Ask your notes anything │      │  Empty state (suggested questions)
│  │                            │      │
│  │ Try asking:                │      │
│  │ ○ What have I been writing │      │
│  │ ○ Activities that made me  │      │
│  │ ○ Summarize my mornings    │      │
│  │ ○ Goals in my notes        │      │
│  └────────────────────────────┘      │
│                                      │
├──────────────────────────────────────┤
│  ┌────────────────────────┐  ┌──┐   │
│  │ Ask about your notes...│  │↑ │   │  Input + send button
│  └────────────────────────┘  └──┘   │
└──────────────────────────────────────┘
```

### 7.4 Navigation integration

**Route:** Added to `lib/core/route/app_router.dart`:

```dart
GoRoute(
  path: '/chat',
  name: 'chat',
  pageBuilder: (context, state) => const MaterialPage(child: ChatView()),
),
```

**Entry point:** Chat icon button (✨ `auto_awesome_outlined`) added to the
notes AppBar actions in `lib/views/notes/notes_content.dart`:

```dart
IconButton(
  icon: const Icon(Icons.auto_awesome_outlined),
  tooltip: 'Ask your notes',
  onPressed: () => context.push('/chat'),
),
```

### 7.5 Testing

**File:** `test/views/chat/chat_view_model_test.dart` · **22 tests passing**

| Group         | Tests | What's covered                                                                                                                                                                                                        |
| ------------- | ----- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ChatMessage   | 8     | Constructor fields, defaults, `copyWith`, `toString`                                                                                                                                                                  |
| ChatViewModel | 14    | Initial state, `isAvailable` delegation, `sendMessage` flow, streaming, source titles, whitespace trimming, empty input, error handling, `clearConversation`, multiple messages, `notifyListeners`, unmodifiable list |

Testing approach: `_FakeRagService extends RagService` with overridden
`isAvailable`, `queryStream()`, and `getSourceTitles()`. Constructor
dependencies are satisfied with lightweight stub repositories.

---

## 8. Cross-Cutting Concerns

### 8.1 Privacy & data handling

| Concern                   | Approach                                                        |
| ------------------------- | --------------------------------------------------------------- |
| Note content sent to API  | Only chunks matching the query are sent (not all notes)         |
| Embeddings stored locally | On-device only (ObjectBox), not synced to Drive                 |
| API key security          | Stored via `--dart-define`, not in source code                  |
| User consent              | Show an opt-in dialog before enabling RAG features              |
| Data deletion             | When a note is permanently deleted, embeddings are also deleted |

### 8.2 Error handling strategy

```
┌────────────────┬──────────────────────────────────────────┐
│ Error          │ Handling                                 │
├────────────────┼──────────────────────────────────────────┤
│ No API key     │ Disable chat feature, show setup prompt  │
│ API rate limit │ Queue and retry with exponential backoff │
│ Network error  │ Show offline message, use cached results │
│ Empty results  │ "No relevant notes found" message        │
│ API error      │ Log, show generic error, retry option    │
│ Timeout        │ 30-second timeout, cancel and retry      │
└────────────────┴──────────────────────────────────────────┘
```

### 8.3 Testing strategy

| Layer                                     | Test type   | What to test                             |
| ----------------------------------------- | ----------- | ---------------------------------------- |
| `NoteEmbedding`                           | Unit        | Serialization/deserialization of vectors |
| `EmbeddingService._chunkText()`           | Unit        | Chunking boundary cases                  |
| `VectorSearchService._cosineSimilarity()` | Unit        | Math correctness                         |
| `VectorSearchService.search()`            | Unit        | Ranking, topK, minScore filtering        |
| `buildAugmentedPrompt()`                  | Unit        | Prompt format, metadata inclusion        |
| `RagService.query()`                      | Integration | Full pipeline with mocked API            |
| `EmbeddingRepository`                     | Integration | ObjectBox CRUD operations                |
| `ChatViewModel`                           | Widget      | Message flow, loading states             |

### 8.4 Implementation order & timeline

| Step  | Description               | Dependencies                   | Est. effort    | Status   |
| ----- | ------------------------- | ------------------------------ | -------------- | -------- |
| **1** | Embedding Model           | `google_generative_ai` package | 2–3 days       | ✅       |
| **2** | Vector Storage & Search   | Step 1 complete                | 1–2 days       | ✅       |
| **3** | Top-K Document Resolution | Step 2 complete                | 0.5 day        | ✅       |
| **4** | Prompt Augmentation       | Step 3 complete                | 1 day          | ✅       |
| **5** | LLM Generator             | Step 4 complete, API key ready | 1 day          | ✅       |
| **6** | Chat UI                   | Step 5 complete                | 2–3 days       | ✅       |
|       | **Total**                 |                                | **~8–10 days** | **Done** |

### 8.5 Future enhancements

1. **Conversation memory** — multi-turn chat with history context
2. **Suggested questions** — auto-generate questions from recent notes
3. **Tag-filtered search** — "What did I write when I was happy?" uses mood tag filter
4. **On-device embeddings** — eliminate API dependency for privacy-conscious users
5. **Embedding sync** — sync embeddings via Google Drive to avoid re-computing
6. **Semantic note search** — replace the current `String.contains()` search with vector search in the main notes view

---

_Document created: Feb 26, 2026_
_Last updated: Jun 18, 2025_ — Step 6 (Chat UI) complete, all 6 steps done
