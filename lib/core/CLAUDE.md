# lib/core/ — Working Rules

This directory holds the **non-UI** layers: services, repositories, DI, routing, theming, storage, import/export.

## Layering (do not violate)

```
ViewModel (lib/views/<f>/*_view_model.dart)
    │  depends on (interface)
    ▼
Service (lib/core/services/**)
    │  depends on (interface)
    ▼
Repository interface (lib/core/repository/interfaces/)
    │  implemented by
    ▼
ObjectBox repository (lib/core/repository/implementations/)
    │  uses
    ▼
ObjectBoxStoreManager (singleton Store)
```

- **Higher layers depend on abstractions, never concrete implementations.**
- The `ServiceLocator` (`lib/core/di/service_locator.dart`) is the **only** place where interfaces are bound to implementations.
- Repositories never know about services. Services never know about ViewModels.

## Adding a new repository

1. Define the interface in `lib/core/repository/interfaces/<name>_repository.dart` (prefix with `I`, e.g. `INoteRepository`). Keep it minimal — add methods only when a real caller needs them.
2. Implement in `lib/core/repository/implementations/objectbox_<name>_repository.dart` using `ObjectBoxStoreManager().store`.
3. Register in `ServiceLocator` as a lazy getter (mirror `noteRepository` getter pattern).
4. Inject into the consuming service via constructor parameter (do not call `ServiceLocator()` from inside services unless they're top-level).

## Adding a new service

1. Place in `lib/core/services/<domain>/<name>_service.dart` (domain folders: `ai/`, `app/`, `auth/`, `chat/`, `notes/`, `sync/`).
2. Constructor accepts dependencies (repositories, other services). Default to `ServiceLocator()` getters only at the top level.
3. If async setup is required, expose `Future<void> initialize()` and call it from `ServiceLocator.initialize()`.
4. If the service notifies UI-layer listeners, extend `CmChangeNotifier` (`lib/global_widgets/cm_change_notifier.dart`) — it's safe against `notifyListeners` after dispose.
5. Register in `ServiceLocator` as a lazy getter and add disposal logic to `ServiceLocator.dispose()`.

## Import/Export

- Every import source implements `NoteImportAdapter` (`lib/core/import/import_adapter.dart`) and emits `ImportedNote` (Markdown body).
- The Markdown → Quill conversion is centralized in `MarkdownToQuillConverter`. **Do not** parse Quill in adapters.
- Tests for adapters live in `patrol_test/core/import/adapters/`. Add fixtures and round-trip tests for any new adapter (Open/Closed: do not modify existing adapters when adding a new source).

## AI / RAG services

See `lib/core/services/ai/CLAUDE.md` for pipeline rules. The high-level wiring (LLM provider selection, embedding provider selection) is in `ServiceLocator` — preserve the Gemini → OpenAI → OpenRouter fallback order.

## DRY/KISS/SOLID specifics

- **DRY**: ObjectBox query helpers (sorting, filtering by user) live on the repository, not in services. Services compose repository calls.
- **KISS**: Don't introduce `Either`/`Result` types. Use `try/catch` and let exceptions propagate to the ViewModel layer where they're translated into UI feedback.
- **SOLID**:
  - New entity? New repository interface + implementation. Don't extend an existing one.
  - New embedding provider? New `EmbeddingProvider` enum value + `LlmClient` branch. Don't subclass `EmbeddingService`.
  - Anything that does two unrelated things → split it. `NoteService` is at the upper edge already.

## File size & one-class-per-file (strict here)

**`lib/core/` is the strictest enforcement zone for `docs/style_guide/File_Organization_Rules.md`.** A bloated service is the most common path to architectural drift in this project.

- **One primary class per file.** Allowed co-residents: an enum / exception / sealed result type used **only** by the primary class, or a private `_Helper` under 30 lines combined.
- **Hard limit: 300 lines.** Crossing it requires a refactor before the change lands.

When a service file is over the limit, use **Recipe R2** from `File_Organization_Rules.md`:

```
lib/core/services/<domain>/
├── <name>_service.dart           ← orchestration only, public API
├── <name>_<concern>.dart         ← extracted helper class (one per file)
└── _internal/                    ← optional sub-folder for non-exported helpers
    └── <name>_<helper>.dart
```

The original service keeps its public methods and **delegates** — callers don't change. Do not break the `ServiceLocator` getter signature when refactoring.

When a switch over a provider/strategy enum balloons the file, use **Recipe R5** (one file per provider in `_providers/`).

Known offenders to avoid piling onto: `note_service.dart` (1564 LOC), `llm_client.dart` (667), `rag_service.dart` (643), `embedding_service.dart` (493). When you touch these, take a slice off using the recipe.

## Generated files

`lib/objectbox.g.dart` and `lib/objectbox-model.json` are generated. **Never edit them.** Edit `@Entity` classes in `lib/models/` and run `./scripts/build_runner.sh` (or `-d` to delete conflicts first).
