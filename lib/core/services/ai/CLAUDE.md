# lib/core/services/ai/ — RAG Pipeline Rules

This directory implements the retrieval-augmented generation pipeline behind `ChatView`. Touch with care — the order matters.

## Pipeline

```
User query
   │
   ▼ QueryRewriteService   (LLM rewrite for retrieval)
   ▼ MultiQueryExpansionService  (1 → N alternative queries)
   ▼ EmbeddingService.embed()    (each query → vector)
   ▼ VectorSearchService.search()  (cosine sim against IEmbeddingRepository)
   ▼ DocumentResolverService.resolve()  (chunk → Note, average scores)
   ▼ PromptBuilderService.build()  (token-budget aware context assembly)
   ▼ LlmClient.streamChat()  (provider-agnostic SSE)
   ▼ RagService.queryStream()  (orchestrates all of the above)
   │
   ▼ ChatViewModel  (in-flight token updates + persist via ChatService)
```

## Provider selection (preserve this order)

`ServiceLocator` selects the LLM/embedding backend in this priority — do not reorder without an explicit reason:

1. **Gemini** — if `ConfigConstants.geminiApiKey` is non-empty (uses `google_generative_ai`)
2. **OpenAI** — if `ConfigConstants.openAiApiKey` is non-empty (HTTP, OpenAI-compatible base URL)
3. **OpenRouter** — fallback (HTTP, OpenAI-compatible)

The `rewriteLlmClient` is a **separate** instance with `temperature: 0.0`, `topP: 1.0`, `maxOutputTokens: 256`. Don't reuse the main `llmClient` for query rewriting — determinism matters there.

## Hard rules

1. **Embedding signatures are SHA-256 of normalized chunk text.** `EmbeddingService.shouldReembed()` skips unchanged content. Don't bypass — re-embedding is expensive.
2. **Chunking is deterministic.** Tests in `patrol_test/core/services/embedding_service_test.dart` lock the chunk boundaries. If you change chunking, expect to re-embed the entire corpus.
3. **Vector search uses cosine similarity** — vectors are L2-normalized at insert time. Don't store unnormalized vectors.
4. **Token budget enforcement is in `PromptBuilderService`.** Never assemble prompts ad-hoc in `RagService` or `ChatViewModel` — always go through the builder.
5. **`RagChatMemory` truncates history**, prioritizing recent turns. Tests lock the boundary — see `patrol_test/core/services/rag_chat_memory_test.dart`.
6. **Streaming**: `RagService.queryStream()` returns a `Stream<String>` of token deltas. ViewModels accumulate; don't pre-buffer in the service.

## Adding a new LLM provider (Open/Closed)

1. Add a value to `LlmProvider` enum in `llm_client.dart`.
2. Add a branch in the constructor that wires the right HTTP/SDK call.
3. Update `ServiceLocator.llmClient` and `rewriteLlmClient` to detect the new provider's API key.
4. Do **not** create a `GeminiLlmClient` / `OpenAiLlmClient` subclass — keep the polymorphism inside the single `LlmClient` class (KISS).

## Don't

- Don't call `ServiceLocator()` from inside the AI services — they're constructed by the locator and receive deps via constructor.
- Don't log full prompt bodies (PII risk). Log token counts and elapsed time.
- Don't bypass `DocumentResolverService` and read notes directly — it averages scores correctly when one note has multiple matching chunks.

## Tests

`patrol_test/core/services/` covers every service with logic-only tests (no emulator). Run them after any change here:

```bash
flutter test patrol_test/core/services/
```
