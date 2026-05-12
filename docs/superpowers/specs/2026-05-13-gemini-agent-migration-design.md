# Gemini Firebase AI Migration Design

**Date:** 2026-05-13  
**Status:** Approved  
**Scope:** Replace `google_generative_ai` direct API-key calls with `firebase_ai` (Gemini Developer API backend) across `LlmClient` and `EmbeddingService`.

---

## Goal

Remove the `GEMINI_API_KEY` requirement from the app binary. Users get AI-powered RAG chat for free out of the box, authenticated via the existing Firebase project. No paid API key needed to ship.

---

## Architecture

### What changes

| Layer | Before | After |
|---|---|---|
| LLM generation | `google_generative_ai` + `GEMINI_API_KEY` dart-define | `firebase_ai`, `FirebaseAI.googleAI()` — no key in binary |
| Embedding | `google_generative_ai` embedding + API key | `firebase_ai` `embedContent` via same `FirebaseAI.googleAI()` |
| Primary provider | Gemini (if key set) → OpenAI → OpenRouter | Firebase Gemini (always) → OpenAI → OpenRouter |
| `llm_client.dart` | 667 LOC (over limit) | ~280 LOC — Firebase helpers extracted to `_providers/` |
| `embedding_service.dart` | 493 LOC (over limit) | ~260 LOC — embedding helpers extracted |

### What stays the same

- Entire RAG pipeline: chunking, vector search, query rewriting, prompt builder, streaming
- All public APIs on `LlmClient` and `EmbeddingService` — no caller changes
- `ServiceLocator` getter signatures
- OpenAI and OpenRouter remain as optional user-configured overrides
- All existing tests (behavior unchanged)

### Why it works without an API key

`firebase_ai` authenticates via the Firebase project config already embedded in the app (`google-services.json` / `GoogleService-Info.plist`). Google's Gemini Developer API recognizes the Firebase project and applies its free-tier quota: 1,500 requests/day for `gemini-1.5-flash`, 1,500/day for `text-embedding-004`.

---

## File Structure

```
lib/core/services/ai/
├── _providers/
│   ├── firebase_gemini_llm_provider.dart        ← NEW (~150 LOC)
│   └── firebase_gemini_embedding_provider.dart  ← NEW (~80 LOC)
├── llm_client.dart                              ← MODIFY (trim to ~280 LOC)
├── embedding_service.dart                       ← MODIFY (trim to ~260 LOC)
├── rag_service.dart                             ← no change
├── query_rewrite_service.dart                   ← no change
├── multi_query_expansion_service.dart           ← no change
├── prompt_builder_service.dart                  ← no change
├── vector_search_service.dart                   ← no change
└── document_resolver_service.dart               ← no change

lib/core/di/
└── service_locator.dart                         ← MODIFY: Firebase Gemini as primary path

lib/constants/
└── config_constants.dart                        ← MODIFY: GEMINI_API_KEY becomes unused

pubspec.yaml                                     ← MODIFY: remove google_generative_ai, add firebase_ai
```

---

## Component Details

### `firebase_gemini_llm_provider.dart` (new)

Private class `_FirebaseGeminiLlmProvider`. Owns all `firebase_ai` import surface for generation.

```dart
class _FirebaseGeminiLlmProvider {
  final String modelName;      // default: 'gemini-1.5-flash'
  final double temperature;
  final double topP;
  final int maxOutputTokens;

  GenerativeModel _buildModel(String systemPrompt) =>
      FirebaseAI.googleAI().generativeModel(
        model: modelName,
        systemInstruction: systemPrompt.isEmpty ? null : Content.system(systemPrompt),
        generationConfig: GenerationConfig(
          temperature: temperature, topP: topP, maxOutputTokens: maxOutputTokens,
        ),
      );

  Future<String> generateWithMessages({
    required String systemPrompt,
    required List<LlmChatMessage> history,
    required String userMessage,
  }) async { ... }

  Stream<String> generateStreamWithMessages({
    required String systemPrompt,
    required List<LlmChatMessage> history,
    required String userMessage,
  }) async* { ... }
}
```

`LlmClient` holds a `_FirebaseGeminiLlmProvider?` field. When `_provider == LlmProvider.gemini`, it delegates fully to the provider. The `_apiKey` field and `http.Client` are only used for `openAiCompatible`.

The long "Gemini blocked in this region" fallback chains in `generateWithMessages` and `generateStreamWithMessages` are **removed** — Firebase AI routes through Firebase infra and does not have geo-restrictions.

### `firebase_gemini_embedding_provider.dart` (new)

Private class `_FirebaseGeminiEmbeddingProvider`.

```dart
class _FirebaseGeminiEmbeddingProvider {
  final String modelName; // default: 'text-embedding-004'

  Future<List<double>?> embed(String text) async {
    final model = FirebaseAI.googleAI().generativeModel(model: modelName);
    final result = await model.embedContent(Content.text(text));
    return result.embedding.values;
  }
}
```

`EmbeddingService` holds a `_FirebaseGeminiEmbeddingProvider?` field and delegates `_generateEmbedding()` to it when `_provider == EmbeddingProvider.gemini`.

### `LlmClient` (modified)

- Removes all `google_generative_ai` imports
- Adds `_FirebaseGeminiLlmProvider?` field
- In `initialize()`: when `_provider == LlmProvider.gemini`, instantiates the provider (no API key arg)
- In `generateWithMessages()` / `generateStreamWithMessages()`: delegates to provider for Gemini; HTTP path for OpenAI-compatible unchanged
- `_apiKey` field retained for OpenAI-compatible branch only
- `allowUnauthenticatedGemini` flag and `_resolveGeminiModelForGeneration()` removed (not needed with Firebase)
- Target: ~280 LOC

### `EmbeddingService` (modified)

- Removes all `google_generative_ai` imports
- Adds `_FirebaseGeminiEmbeddingProvider?` field
- In `initialize()`: when `_provider == EmbeddingProvider.gemini`, instantiates the provider
- `_generateEmbedding()` delegates to provider for Gemini; HTTP path for OpenAI-compatible unchanged
- `allowUnauthenticatedGemini` flag removed
- Target: ~260 LOC

### `ServiceLocator` — new provider selection logic

**`llmClient` and `rewriteLlmClient`:**
```
if OPENAI_API_KEY present  → LlmClient(openAiCompatible, OpenAI)
else if OPENROUTER_API_KEY present → LlmClient(openAiCompatible, OpenRouter)
else → LlmClient(provider: gemini)  ← Firebase Gemini, DEFAULT, no key
```

**`embeddingService`:**
```
if OPENAI_API_KEY present  → EmbeddingService(openAiCompatible, OpenAI)
else if OPENROUTER_API_KEY present → EmbeddingService(openAiCompatible, OpenRouter)
else → EmbeddingService(provider: gemini)  ← Firebase Gemini, DEFAULT
```

`GEMINI_API_KEY` is no longer read in `ServiceLocator`. The `useGeminiFree*` branches are removed.

### `ConfigConstants` (modified)

`GEMINI_API_KEY`, `USE_GEMINI_FREE_MODEL`, and all `GEMINI_FREE_*` constants are marked as unused. They are not deleted in this PR (backward-compatible build scripts) but are flagged for removal in a follow-up cleanup.

---

## Firebase Project Setup (one-time, manual)

Before the code change lands:

1. Firebase Console → project → **Build → AI** → enable **Gemini Developer API**
2. No changes to `google-services.json` or `GoogleService-Info.plist`
3. No additional Dart auth wiring — `Firebase.initializeApp()` (already called in `initializer.dart`) is sufficient

---

## Error Handling

| Error | Handling |
|---|---|
| Quota exceeded (1,500 req/day) | `LlmApiException(statusCode: 429, code: quota_exceeded)` — same as before |
| Firebase not initialized | `StateError` at call site — impossible in practice; `initializer.dart` guarantees Firebase init before `ServiceLocator` |
| Network offline | Exception propagates to ViewModel — same as before |
| Gemini model not found | `LlmApiException(statusCode: 404)` — firebase_ai surfaces this |
| Geo-restrictions | Non-issue — Firebase AI routes through Firebase infra |

The Gemini-blocked regional fallback chain (previously ~120 LOC in `LlmClient`) is deleted entirely.

---

## pubspec.yaml changes

```yaml
dependencies:
  # Remove:
  # google_generative_ai: ^x.x.x

  # Add:
  firebase_ai: ^2.0.0   # or latest stable
```

`firebase_ai` version to confirm against `firebase_core` version in use at implementation time.

---

## Testing

- No existing test behavior changes — mocks don't touch `firebase_ai`
- New unit tests for `_FirebaseGeminiLlmProvider` and `_FirebaseGeminiEmbeddingProvider` in `patrol_test/core/services/`
- Use `firebase_ai`'s test utilities or a thin stub wrapper to avoid real network calls
- Run `flutter test patrol_test/core/services/` after implementation

---

## Definition of Done

1. `flutter analyze` passes with no new errors
2. `flutter test patrol_test` passes
3. `firebase_ai` added, `google_generative_ai` removed from `pubspec.yaml`
4. `llm_client.dart` ≤ 300 LOC, `embedding_service.dart` ≤ 300 LOC
5. Gemini Developer API enabled in Firebase Console (both staging and prod projects)
6. Chat view works end-to-end with no API key dart-define set

---

## Out of Scope

- Removing `GEMINI_API_KEY` from build scripts (cleanup PR)
- Firebase App Check integration
- Vertex AI backend (separate decision)
- On-device embeddings
