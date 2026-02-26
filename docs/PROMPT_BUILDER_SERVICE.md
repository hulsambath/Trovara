# Prompt Builder Service (RAG Step 4)

> Assemble context-rich augmented prompts that combine retrieved note
> content with the user's question, ready for LLM generation.

This document describes the **Prompt Augmentation** layer of Trovara's
RAG pipeline — the component that transforms resolved documents (Step 3)
into a structured prompt for the Gemini LLM (Step 5).

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Files & Classes](#3-files--classes)
4. [Prompt Structure](#4-prompt-structure)
5. [PromptBuilderService API](#5-promptbuilderservice-api)
6. [Dependency Injection](#6-dependency-injection)
7. [Usage Examples](#7-usage-examples)
8. [Context Window Management](#8-context-window-management)
9. [Testing](#9-testing)
10. [Future Improvements](#10-future-improvements)

---

## 1. Overview

After `DocumentResolverService` (Step 3) produces a ranked list of
`RetrievedDocument` objects, we need to assemble them into a prompt that:

1. **Instructs** the LLM on its role and constraints (system prompt)
2. **Provides** note content with rich metadata (title, date, folder, tags)
3. **Asks** the user's question in a clearly delineated section
4. **Limits** context size to keep responses focused and costs low

`PromptBuilderService` handles all of the above and produces a single
string ready to send to `LlmClient` (Step 5).

---

## 2. Architecture

### Data flow

```
DocumentResolverService.resolve()
    │
    ▼
List<RetrievedDocument>         ← hydrated, ranked notes
    │
    ▼
PromptBuilderService.buildFromDocuments()
    │
    ├─ System prompt              "You are a helpful assistant..."
    ├─ Context header             "─── USER'S NOTES ───"
    ├─ Note blocks ×N             [Note 1] Title / Date / Folder / Tags / Content
    ├─ Context footer             "─── END OF NOTES ───"
    └─ User question              "User question: ..."
    │
    ▼
String (augmented prompt)       → Step 5 LLM generator
```

### Convenience path (from raw chunks)

```
List<ScoredEmbedding> (Step 2)
    │
    ▼
PromptBuilderService.buildFromChunks()
    │
    ├─ DocumentResolverService.resolve()   ← auto-resolves
    └─ buildFromDocuments()                ← assembles prompt
    │
    ▼
String (augmented prompt)
```

### Pipeline context

```
Step 1 (Embed)  →  Step 2 (Search)  →  Step 3 (Resolve)  →  Step 4 (Prompt)  →  Step 5 (LLM)
EmbeddingService   VectorSearchService  DocumentResolverService  PromptBuilderService  LlmClient
```

---

## 3. Files & Classes

### New files (Step 4)

| File                                                  | Purpose               |
| ----------------------------------------------------- | --------------------- |
| `lib/core/services/prompt_builder_service.dart`       | Prompt assembly logic |
| `test/core/services/prompt_builder_service_test.dart` | 22 unit tests         |

### Modified files

| File                               | Change                                    |
| ---------------------------------- | ----------------------------------------- |
| `lib/core/di/service_locator.dart` | Added `PromptBuilderService` registration |

---

## 4. Prompt Structure

Every augmented prompt follows a fixed three-section layout:

### Section 1 — System Instructions

```
You are a helpful assistant for a personal note-taking app called Trovara.
The user is asking a question about their own notes.

Answer ONLY based on the provided note context below. If the answer cannot
be found in the notes, say "I couldn't find relevant information in your
notes about this topic."

Be concise, helpful, and reference specific notes by title when possible.
```

**Design decisions:**

- Grounding constraint ("Answer ONLY based on…") prevents hallucination
- Fallback instruction gives the LLM a safe default when notes are irrelevant
- "Reference specific notes by title" enables source attribution in the UI

### Section 2 — Note Context

```
─── USER'S NOTES (most relevant) ───

[Note 1]
Title: Morning Reflection
Date: 2026-02-20
Folder: journal
Tags: mood: happy, grateful | activity: meditation | time: morning
Content:
Meditated for 20 minutes this morning. Felt calm and focused...

[Note 2]
Title: Weekly Review
Date: 2026-02-22
Folder: default
Content:
This week I maintained my meditation practice...

─── END OF NOTES ───
```

**Per-note metadata:**

| Field   | Source                       | Included when            |
| ------- | ---------------------------- | ------------------------ |
| Title   | `note.title`                 | Always                   |
| Date    | `note.createdAt` (ISO date)  | Always                   |
| Folder  | `note.folderId`              | Always                   |
| Tags    | mood, activity, time, growth | At least one tag present |
| Content | `doc.combinedText` (chunks)  | Always                   |

**Tag format:** `category: value1, value2 | category: value3`

Tags are omitted entirely when the note has no tags, keeping the prompt
clean.

### Section 3 — User Question

```
User question: What did I write about meditation?
```

---

## 5. PromptBuilderService API

### Constructor

```dart
PromptBuilderService({
  required DocumentResolverService documentResolver,
});
```

### Constants

| Constant                 | Value    | Description                               |
| ------------------------ | -------- | ----------------------------------------- |
| `defaultMaxNotes`        | 5        | Default cap on notes in prompt            |
| `defaultMaxContextChars` | 20,000   | Default character budget for note content |
| `systemPrompt`           | (string) | Static system instructions                |

### `buildFromChunks()`

The **primary entry point** — takes raw search results and produces a
complete prompt by auto-resolving through `DocumentResolverService`.

```dart
String? buildFromChunks({
  required String userQuery,
  required List<ScoredEmbedding> scoredChunks,
  int maxNotes = defaultMaxNotes,
  int? maxContextChars,
});
```

Returns `null` if:

- `scoredChunks` is empty
- All notes are deleted or missing (resolution returns empty)

### `buildFromDocuments()`

Takes pre-resolved documents and assembles the prompt. Use when you
already have `RetrievedDocument` objects.

```dart
String? buildFromDocuments({
  required String userQuery,
  required List<RetrievedDocument> documents,
});
```

Returns `null` if `documents` is empty.

### `extractSourceTitles()`

Returns note titles in ranked order for source attribution in the chat UI.

```dart
List<String> extractSourceTitles({
  required List<ScoredEmbedding> scoredChunks,
  int maxNotes = defaultMaxNotes,
});
```

### `estimateTokenCount()` (static)

Rough token estimate using the ~4 chars/token heuristic.

```dart
static int estimateTokenCount(String prompt);
```

---

## 6. Dependency Injection

`PromptBuilderService` is registered in `ServiceLocator` with lazy
initialization. It depends on `DocumentResolverService`.

```
ServiceLocator
    │
    ├── documentResolverService ─── DocumentResolverService
    │       │
    │       └── used by ─────────── PromptBuilderService
    │
    └── promptBuilderService ────── PromptBuilderService
```

**Access:**

```dart
final promptBuilder = ServiceLocator().promptBuilderService;
```

The service is stateless — no initialization or dispose is required.

---

## 7. Usage Examples

### Full pipeline (Steps 1 → 2 → 3 → 4)

```dart
final sl = ServiceLocator();

// Step 1: Embed query
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

// Steps 3 + 4: Resolve and build prompt (combined)
final prompt = sl.promptBuilderService.buildFromChunks(
  userQuery: 'What did I write about meditation?',
  scoredChunks: scoredChunks,
  maxNotes: 5,
);

if (prompt != null) {
  print('Prompt length: ${prompt.length} chars');
  print('Est. tokens: ${PromptBuilderService.estimateTokenCount(prompt)}');
  // → Send to LlmClient (Step 5)
}
```

### Source attribution for chat UI

```dart
final titles = sl.promptBuilderService.extractSourceTitles(
  scoredChunks: scoredChunks,
  maxNotes: 3,
);
// → ['Morning Reflection', 'Weekly Review']
// Display as: "📎 Sources: Morning Reflection, Weekly Review"
```

### Pre-resolved documents (manual selection)

```dart
final docs = sl.documentResolverService.resolve(scoredChunks, topN: 3);

// Optionally filter or reorder docs before prompting
final prompt = sl.promptBuilderService.buildFromDocuments(
  userQuery: 'Summarise my week',
  documents: docs,
);
```

---

## 8. Context Window Management

| Model              | Context Window | Target Usage                    |
| ------------------ | -------------- | ------------------------------- |
| `gemini-2.0-flash` | 1M tokens      | Up to ~50 full notes in context |

Even with Gemini's large context window, we limit to **5 notes** by default
to:

- **Keep responses focused** — less noise means better answers
- **Reduce API costs** — fewer input tokens
- **Improve latency** — shorter prompts process faster

### Character budget

The `maxContextChars` parameter (default: 20,000) caps the total combined
text from all notes. At ~4 chars/token, this is roughly **5,000 tokens**
of note context — well within budget for focused answers.

### Token estimation

```dart
final tokens = PromptBuilderService.estimateTokenCount(prompt);
// ~4 chars per token for English text
// Rough heuristic — actual counts depend on model tokenizer
```

---

## 9. Testing

**File:** `test/core/services/prompt_builder_service_test.dart`

Tests use stub implementations of `INoteRepository` and
`IFolderRepository`, injected into a real `NoteService` and
`DocumentResolverService`. No ObjectBox or network dependencies.

### Test coverage (22 tests)

| Group                   | Test                          | Validates                                   |
| ----------------------- | ----------------------------- | ------------------------------------------- |
| **buildFromDocuments**  | empty list → null             | Empty state                                 |
|                         | includes system prompt        | System instructions present                 |
|                         | includes context delimiters   | Header/footer markers                       |
|                         | includes title, date, folder  | Per-note metadata                           |
|                         | includes all tag categories   | Mood, activity, time, growth                |
|                         | omits Tags line when empty    | Clean prompt for untagged notes             |
|                         | includes combined chunk text  | Multi-chunk content                         |
|                         | includes user question at end | Question placement                          |
|                         | numbers multiple notes        | Sequential [Note N] headers                 |
|                         | correct section ordering      | System → header → notes → footer → question |
| **buildFromChunks**     | empty chunks → null           | Empty input handling                        |
|                         | all notes deleted → null      | Deleted note filtering                      |
|                         | end-to-end resolution         | Full chunk → document → prompt pipeline     |
|                         | respects maxNotes             | Note count limiting                         |
| **estimateTokenCount**  | ~4 chars per token            | Heuristic accuracy                          |
|                         | rounds up                     | Ceiling division                            |
|                         | empty string → 0              | Edge case                                   |
| **extractSourceTitles** | ranked order                  | Title ordering by score                     |
|                         | respects maxNotes             | Title count limiting                        |
| **systemPrompt**        | mentions Trovara              | Brand name inclusion                        |
|                         | answer-only constraint        | Grounding instruction                       |
|                         | fallback instruction          | "I couldn't find" message                   |

### Running tests

```bash
flutter test test/core/services/prompt_builder_service_test.dart
```

---

## 10. Future Improvements

**Short-term:**

- Folder name resolution — resolve `note.folderId` to the folder's
  display name via `NoteService.getFolder()` in the prompt block, rather
  than showing the raw folder ID.
- Custom tag inclusion — include user-defined custom tags alongside the
  built-in tag categories.

**Medium-term:**

- Conversation history — support multi-turn chat by including previous
  Q&A pairs in the prompt for contextual follow-up questions.
- Dynamic system prompt — adjust instructions based on query intent
  (e.g. summarisation vs. search vs. analysis).
- Token-aware budgeting — use the Gemini SDK's `countTokens()` method
  for precise token measurement instead of the 4-char heuristic.

**Long-term:**

- Few-shot examples — include example Q&A pairs in the system prompt
  to improve answer quality and formatting consistency.
- Prompt caching — cache assembled prompts for repeated queries to
  avoid redundant resolution and assembly.
- A/B testing — experiment with different system prompt variants and
  measure answer quality metrics.

---

## Relationship to Other RAG Steps

| Step  | Component                 | Status      | Connects to Step 4 via                                             |
| ----- | ------------------------- | ----------- | ------------------------------------------------------------------ |
| 1     | Embedding Model           | ✅ Done     | Generates embeddings for notes and queries                         |
| 2     | Vector Storage & Search   | ✅ Done     | Returns `List<ScoredEmbedding>` — input to `buildFromChunks`       |
| 3     | Top-K Document Resolution | ✅ Done     | Returns `List<RetrievedDocument>` — input to `buildFromDocuments`  |
| **4** | **Prompt Augmentation**   | **✅ Done** | **Outputs augmented prompt string for LLM**                        |
| 5     | LLM Generator             | Planned     | Sends augmented prompt to Gemini, streams response                 |
| 6     | Chat UI                   | Planned     | Displays answer with source attribution from `extractSourceTitles` |

---

_Document created: February 27, 2026_
_Relates to: [RAG_IMPLEMENTATION.md](RAG_IMPLEMENTATION.md) — Step 4_
