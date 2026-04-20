# LLM Client & RAG Service (RAG Step 5)

> Generate grounded, note-aware answers by sending augmented prompts
> to Google Gemini and orchestrating the full RAG pipeline end-to-end.

This document describes the **LLM Generator** layer of Trovara's RAG
pipeline — the final processing step that turns a context-enriched
prompt (from Step 4) into a natural-language answer, and the orchestrator
that wires Steps 1–5 together into a single callable API.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Files & Classes](#3-files--classes)
4. [LlmClient API](#4-llmclient-api)
5. [RagService API](#5-ragservice-api)
6. [RagResult Model](#6-ragresult-model)
7. [Dependency Injection](#7-dependency-injection)
8. [Usage Examples](#8-usage-examples)
9. [Error Handling](#9-error-handling)
10. [Testing](#10-testing)
11. [Future Improvements](#11-future-improvements)

---

## 1. Overview

Step 5 adds two components:

| Component      | Role                                                                                                                               |
| -------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| **LlmClient**  | Thin wrapper around the Gemini `gemini-2.0-flash` generative model. Handles initialization, single-turn generation, and streaming. |
| **RagService** | Pipeline orchestrator that chains Embedding → Vector Search → Prompt Building → LLM Generation and returns a complete `RagResult`. |

Together they close the loop from _user question_ → _grounded answer_:

```
User question
    │
    ▼
Step 1  EmbeddingService.embedQuery()           → query vector
    │
    ▼
Step 2  VectorSearchService.search()            → scored chunks
    │
    ▼
Steps 3+4  PromptBuilderService.buildFromChunks() → augmented prompt
    │
    ▼
Step 5  LlmClient.generate() / generateStream() → answer text
    │
    ▼
RagResult { answer, sourceNoteTitles, prompt, matchedChunks }
```

---

## 2. Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         RagService                          │
│                                                             │
│  ┌─────────────────┐  ┌───────────────────┐                │
│  │ EmbeddingService │  │ VectorSearchService│                │
│  └────────┬────────┘  └────────┬──────────┘                │
│           │    query vector    │   scored chunks            │
│           ▼                    ▼                            │
│  ┌────────────────────────────────────────┐                 │
│  │       PromptBuilderService             │                 │
│  │  (DocumentResolver inside)             │                 │
│  └────────────────┬───────────────────────┘                 │
│                   │   augmented prompt                      │
│                   ▼                                         │
│  ┌────────────────────────────────────────┐                 │
│  │            LlmClient                   │                 │
│  │   Gemini gemini-2.0-flash              │                 │
│  └────────────────┬───────────────────────┘                 │
│                   │   answer string / stream                │
│                   ▼                                         │
│             RagResult                                       │
└─────────────────────────────────────────────────────────────┘
```

**Design decisions:**

- `LlmClient` is kept thin and model-agnostic in shape — easy to swap
  for a different provider later.
- `RagService` depends only on abstractions it receives through
  constructor injection; no static access to `ServiceLocator`.
- Streaming uses `await for` (not `yield*`) so that LLM stream errors
  are caught by the enclosing `try-catch`.

---

## 3. Files & Classes

| File                                                                                    | Class / Model    | Purpose                           |
| --------------------------------------------------------------------------------------- | ---------------- | --------------------------------- |
| [lib/core/services/llm_client.dart](../lib/core/services/llm_client.dart)               | `LlmClient`      | Gemini generative model wrapper   |
| [lib/core/services/rag_service.dart](../lib/core/services/rag_service.dart)             | `RagService`     | Full pipeline orchestrator        |
| [lib/core/services/rag_service.dart](../lib/core/services/rag_service.dart)             | `RagResult`      | Value object for query results    |
| [lib/core/di/service_locator.dart](../lib/core/di/service_locator.dart)                 | `ServiceLocator` | DI registration (lazy singletons) |
| [test/core/services/rag_service_test.dart](../test/core/services/rag_service_test.dart) | —                | 17 unit tests                     |

---

## 4. LlmClient API

### Constructor

```dart
LlmClient({
  required String apiKey,
  String modelName = 'gemini-2.0-flash',
});
```

| Parameter   | Default            | Description                                        |
| ----------- | ------------------ | -------------------------------------------------- |
| `apiKey`    | _required_         | Gemini API key from `ConfigConstants.geminiApiKey` |
| `modelName` | `gemini-2.0-flash` | Generative model identifier                        |

### Constants (generation defaults)

| Constant                 | Value              | Purpose                                       |
| ------------------------ | ------------------ | --------------------------------------------- |
| `defaultTemperature`     | `0.3`              | Low temperature for factual, grounded answers |
| `defaultTopP`            | `0.8`              | Nucleus sampling threshold                    |
| `defaultMaxOutputTokens` | `1024`             | Cap output length                             |
| `defaultModel`           | `gemini-2.0-flash` | Model identifier                              |

### Methods

#### `initialize()`

```dart
Future<void> initialize()
```

Creates the `GenerativeModel` instance with the configured parameters.
Must be called before `generate()` or `generateStream()`. Skips
silently if no API key is provided (useful in debug/test builds).

Called automatically by `ServiceLocator.initialize()`.

#### `generate(String prompt)`

```dart
Future<String> generate(String prompt)
```

Send the prompt to Gemini and wait for the complete response.

- Returns the generated text, or `'No response generated.'` if the
  model returns an empty response.
- Throws `StateError` if the client is not initialized.
- Rethrows API errors for the caller to handle.

#### `generateStream(String prompt)`

```dart
Stream<String> generateStream(String prompt)
```

Send the prompt to Gemini and yield text chunks as they arrive.
Ideal for real-time chat UI updates.

- Throws `StateError` if the client is not initialized.
- Rethrows API errors for the caller to handle.

#### `isAvailable` (getter)

```dart
bool get isAvailable
```

Returns `true` when the client is initialized and has a valid API key.

---

## 5. RagService API

### Constructor

```dart
RagService({
  required EmbeddingService embeddingService,
  required VectorSearchService vectorSearchService,
  required PromptBuilderService promptBuilderService,
  required LlmClient llmClient,
});
```

All dependencies are injected. `ServiceLocator` wires them
automatically.

### Constants

| Constant            | Value | Purpose                                         |
| ------------------- | ----- | ----------------------------------------------- |
| `defaultSearchTopK` | `10`  | Number of chunks to retrieve from vector search |
| `defaultMinScore`   | `0.3` | Minimum cosine similarity to keep a chunk       |
| `defaultMaxNotes`   | `5`   | Maximum number of notes in the prompt           |

### `query()`

```dart
Future<RagResult> query(
  String userQuestion, {
  int searchTopK = 10,
  double minScore = 0.3,
  int maxNotes = 5,
})
```

Execute the full pipeline and return a complete `RagResult`.

**Step-by-step flow:**

1. **Embed** the user question via `EmbeddingService.embedQuery()`
2. **Search** for matching chunks via `VectorSearchService.search()`
3. **Build prompt** via `PromptBuilderService.buildFromChunks()`
   (internally resolves chunks → documents → augmented prompt)
4. **Extract source titles** for attribution
5. **Generate** the answer via `LlmClient.generate()`

Returns user-friendly error messages (not exceptions) when any step
fails gracefully.

### `queryStream()`

```dart
Stream<String> queryStream(
  String userQuestion, {
  int searchTopK = 10,
  double minScore = 0.3,
  int maxNotes = 5,
})
```

Same pipeline as `query()`, but yields answer text chunks as they
arrive from the LLM. Ideal for a typing-indicator chat experience.

Source titles are **not** available through the stream — use
`getSourceTitles()` separately if needed.

### `getSourceTitles()`

```dart
Future<List<String>> getSourceTitles(
  String userQuestion, {
  int searchTopK = 10,
  double minScore = 0.3,
  int maxNotes = 5,
})
```

Run Steps 1–3 (embed → search → resolve titles) without calling the
LLM. Useful for:

- Showing source attribution after a streaming query
- Previewing which notes would be referenced

### `isAvailable` (getter)

```dart
bool get isAvailable
```

Returns `true` when both `EmbeddingService` and `LlmClient` are
available. The Chat UI should check this to show/hide the chat feature.

---

## 6. RagResult Model

```dart
class RagResult {
  final String answer;              // LLM-generated answer text
  final List<String> sourceNoteTitles; // Titles of referenced notes
  final String prompt;              // Debug transcript of full message list sent to LLM
  final int matchedChunks;          // Number of embedding chunks matched
}
```

| Field              | Description                                                                   |
| ------------------ | ----------------------------------------------------------------------------- |
| `answer`           | The LLM answer, or a user-friendly error message if something failed          |
| `sourceNoteTitles` | Note titles for source attribution in the UI                                  |
| `prompt`           | Full request transcript (system + history + user payload), for debugging only |
| `matchedChunks`    | How many chunks the vector search returned                                    |

`toString()` prints a compact summary:

```
RagResult(sources: 2, chunks: 5, answer: 312 chars)
```

---

## 7. Dependency Injection

Both services are registered as lazy singletons in
`ServiceLocator`:

```dart
// In ServiceLocator

LlmClient? _llmClient;
RagService? _ragService;

LlmClient get llmClient =>
    _llmClient ??= LlmClient(apiKey: ConfigConstants.geminiApiKey);

RagService get ragService =>
    _ragService ??= RagService(
      embeddingService: embeddingService,
      vectorSearchService: vectorSearchService,
      promptBuilderService: promptBuilderService,
      llmClient: llmClient,
    );
```

`LlmClient` is initialized during app startup:

```dart
Future<void> initialize() async {
  // ... other init ...
  await llmClient.initialize();
}
```

Both are cleaned up in `dispose()`:

```dart
void dispose() {
  // ... other cleanup ...
  _llmClient = null;
  _ragService = null;
}
```

---

## 8. Usage Examples

### Non-streaming query

```dart
final rag = serviceLocator.ragService;

if (!rag.isAvailable) {
  print('RAG pipeline not available');
  return;
}

final result = await rag.query('How did my morning routine look this week?');

print(result.answer);
print('Sources: ${result.sourceNoteTitles.join(', ')}');
print('Matched chunks: ${result.matchedChunks}');
```

### Streaming query (for chat UI)

```dart
final rag = serviceLocator.ragService;

final stream = rag.queryStream('What activities made me happiest?');

await for (final chunk in stream) {
  // Append chunk to the chat bubble in real time
  chatController.appendText(chunk);
}

// Optionally fetch source titles after stream completes
final sources = await rag.getSourceTitles('What activities made me happiest?');
chatController.showSources(sources);
```

### Custom search parameters

```dart
final result = await rag.query(
  'What did I write about meditation?',
  searchTopK: 20,    // retrieve more chunks
  minScore: 0.5,     // stricter relevance threshold
  maxNotes: 3,       // fewer notes in context
);
```

---

## 9. Error Handling

The pipeline handles errors **gracefully** — `query()` and
`queryStream()` never throw. Instead, they return/yield user-friendly
messages:

| Failure                   | `query()` result                                    | `queryStream()` yield |
| ------------------------- | --------------------------------------------------- | --------------------- |
| Embedding fails           | `"Sorry, I was unable to process your question..."` | Same message          |
| No matching chunks        | `"I couldn't find any relevant notes..."`           | Same message          |
| All matched notes deleted | `"I couldn't find any relevant notes..."`           | Same message          |
| LLM generation error      | `"Sorry, something went wrong..."`                  | Same message          |
| LLM returns empty         | `"No response generated."`                          | (empty stream)        |

When an LLM error occurs during `query()`, the source titles and
prompt are still included in the `RagResult` — only the `answer`
field contains the error message. This allows the UI to still display
source attribution.

---

## 10. Testing

### Test file

[test/core/services/rag_service_test.dart](../test/core/services/rag_service_test.dart) — **17 tests**

### Test architecture

Tests wire real service instances with lightweight stubs — no mocking
frameworks needed:

| Stub / Fake                   | Purpose                                      |
| ----------------------------- | -------------------------------------------- |
| `StubNoteRepository`          | In-memory note storage                       |
| `StubFolderRepository`        | In-memory folder storage                     |
| `StubEmbeddingRepository`     | In-memory embedding storage                  |
| `FakeEmbeddingService`        | Returns a fixed query vector (no API call)   |
| `UnavailableEmbeddingService` | Simulates missing API key                    |
| `FakeLlmClient`               | Extends `LlmClient`, returns fixed responses |

`FakeLlmClient` extends the real `LlmClient` and overrides
`isAvailable`, `generate()`, and `generateStream()`. This lets it
pass type checks without calling the Gemini API.

### Test coverage

| Group                      | Tests | What's covered                                                                                                                 |
| -------------------------- | ----- | ------------------------------------------------------------------------------------------------------------------------------ |
| **RagResult**              | 2     | Constructor, `toString()`                                                                                                      |
| **RagService.query**       | 8     | Embedding failure, no chunks, deleted notes, full pipeline, multiple sources with ranking, LLM error, maxNotes, prompt content |
| **RagService.queryStream** | 4     | Embedding failure, no chunks, streaming tokens, LLM stream error                                                               |
| **getSourceTitles**        | 2     | Embedding failure, matching notes                                                                                              |
| **isAvailable**            | 1     | Both services available                                                                                                        |

### Running tests

```bash
flutter test test/core/services/rag_service_test.dart
```

---

## 11. Future Improvements

| Improvement                | Description                                                       |
| -------------------------- | ----------------------------------------------------------------- |
| **Conversation history**   | Pass previous messages for multi-turn chat context                |
| **Model selection**        | Let users choose between Gemini models (Flash vs Pro)             |
| **Token counting**         | Track input/output tokens for cost monitoring                     |
| **Response caching**       | Cache answers for identical queries within a time window          |
| **Safety filters**         | Configure Gemini safety settings for content filtering            |
| **Retry logic**            | Automatic retry with exponential backoff for transient API errors |
| **Abort/cancel**           | Cancel in-flight requests when the user navigates away            |
| **Abstract LLM interface** | Extract an interface for easier provider swapping                 |

---

_Last updated: 2025_
