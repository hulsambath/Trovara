# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Non-Negotiable Rules

These rules apply to **every** change. Do not bypass them.

1. **Follow MVVM strictly.** Views never call services or repositories. Repositories never know about UI. Use `BaseViewModel` + `ViewModelProvider`. See `lib/views/CLAUDE.md`.
2. **Go through the ServiceLocator.** Never `new` a service or repository directly. Add new services to `lib/core/di/service_locator.dart` as lazy getters.
3. **Repository pattern is mandatory.** Add an interface in `core/repository/interfaces/` first, then the ObjectBox implementation in `core/repository/implementations/`. ViewModels depend on the interface, never the implementation.
4. **No hardcoded user-visible strings.** Use `tr('key')` from `easy_localization`. Add the key to **both** `assets/translations/en.json` AND `assets/translations/km.json` — the `/i18n-check` command verifies parity.
5. **No hardcoded colors or text styles.** Use `Theme.of(context).colorScheme.*` and `Theme.of(context).textTheme.*`.
6. **Icons: `lucide_icons_flutter` only.** Do not use `Icons.*` from Material.
7. **Never edit generated files** (`*.g.dart`, `lib/objectbox.g.dart`, `lib/objectbox-model.json`). Edit the source entity in `lib/models/` and run `./scripts/build_runner.sh`.
8. **Logger, not print.** `avoid_print` lint is enabled — use `package:logger`.
9. **Single quotes, 120 char width, `const` everywhere it compiles.** Enforced by the analyzer.
10. **One primary class per file. Hard limit 300 LOC.** Full rule + refactor recipes in `docs/style_guide/File_Organization_Rules.md`. When a file would cross 300 lines, refactor first using the recipe matching the case (extract widgets to `widgets/`, helpers to a sub-folder, business logic to a service). Especially strict in `lib/core/`.

## Code Principles (DRY · KISS · SOLID)

Apply these as a checklist before declaring any change "done":

### DRY — Don't Repeat Yourself
- Before writing a helper, grep `lib/` for an existing one. Most string parsing, tag formatting, and theme helpers already exist.
- Three similar code blocks → extract a private method. Same pattern across views → extract a widget into `lib/widgets/` (not `lib/views/<feature>/widgets/`, which is feature-scoped).
- Service logic shared across ViewModels lives in `lib/core/services/`, not duplicated in each ViewModel.

### KISS — Keep It Simple, Stupid
- Default to a `StatelessWidget` + a private `_build*` method. Reach for a new class only when state or reuse demands it.
- No premature abstraction. Don't introduce a strategy/factory for one caller.
- Prefer composition over inheritance. The base classes (`BaseViewModel`, `CmChangeNotifier`) are deliberately tiny — keep them that way.
- A 5-line widget is better than a 50-line "configurable" one with three callers.

### SOLID
- **S**ingle Responsibility — One ViewModel per screen, one service per domain (notes, chat, embeddings). If a ViewModel exceeds ~300 lines, extract a service or helper.
- **O**pen/Closed — Add new import sources by implementing `NoteImportAdapter`, never by editing existing adapters. Same for `LlmClient` providers.
- **L**iskov — Any `INoteRepository` implementation must honor the interface contract (no throwing on `getAll()` etc.). Tests in `patrol_test/` define the expected behavior.
- **I**nterface Segregation — Repositories are split (`INoteRepository`, `IFolderRepository`, `IEmbeddingRepository`) instead of one mega-interface. Keep them small.
- **D**ependency Inversion — ViewModels and services depend on **interfaces** from `core/repository/interfaces/`, never on `ObjectBox*Repository` directly. The `ServiceLocator` is the only place implementations are wired.

## Reading Guide — Load These First

When a task touches a specific area, **read the matching CLAUDE.md before editing**:

| If you're editing… | Read first |
|---|---|
| `lib/views/**` | `lib/views/CLAUDE.md` + `docs/style_guide/Views_Style_Guide.md` |
| `lib/core/**` | `lib/core/CLAUDE.md` |
| `lib/core/services/ai/**` | `lib/core/services/ai/CLAUDE.md` |
| Any file growing past ~250 lines | `docs/style_guide/File_Organization_Rules.md` (pick a refactor recipe before crossing 300) |
| `lib/models/**` | This file → "Data Layer" section. Run build_runner after edits. |
| `patrol_test/**` or `integration_test/**` | `patrol_test/CLAUDE.md` + `docs/PATROL_UNIT_TESTING.md` |
| `assets/translations/*.json` | Run `/i18n-check` after edits. |

The subdirectory `CLAUDE.md` files are auto-loaded when files in their directory are read, so you usually don't need to open them manually — but they govern what you write.

## Commands

### Setup
```bash
flutter pub get
./scripts/build_runner.sh          # Generate ObjectBox + flutter_gen code
./scripts/build_runner.sh -d       # Delete conflicting outputs first, then generate
./scripts/install_hooks.sh         # Install git pre-commit hooks
```

### Running
```bash
./scripts/run_app.sh               # Fast run (reuses last config; defaults to staging+debug)
./scripts/run_app.sh --interactive # Prompt for target/env/device
./scripts/run_app.sh --quick       # staging+debug, no prompts
./scripts/run_app.sh --prod-release --android
```

### Linting & Analysis
```bash
flutter analyze
```

### Testing
```bash
# Logic/unit tests (no emulator needed)
flutter test patrol_test
flutter test patrol_test/core/import/converters/markdown_to_quill_test.dart

# Standard widget tests
flutter test test/

# E2E integration tests (requires emulator + Patrol CLI)
dart pub global activate patrol_cli   # one-time install
./scripts/patrol_test.sh              # wraps `patrol test`, injects --flavor staging
```

### Building
```bash
./scripts/build_apk.sh --trovara
./scripts/build_ipa.sh
```

## Architecture

### Entry Points & Flavors
The app has two flavors: **staging** (`lib/main_staging.dart`) and **prod** (`lib/main_prod.dart`). Each loads the matching `firebase_options/{staging,prod}.dart` before delegating to `lib/main.dart`. API keys and feature config are injected at build time via `--dart-define` and read from `lib/constants/config_constants.dart` (using `String.fromEnvironment`).

Startup sequence in `lib/initializer.dart`:
1. `EasyLocalization.ensureInitialized()`
2. Firebase init (flavor-specific options)
3. `ThemeModeStorage.initialize()`
4. `ServiceLocator().initialize()` (repositories, services, LLM clients)
5. Google Drive silent session restore
6. Shorebird OTA update check (background, non-blocking)

### Dependency Injection
`lib/core/di/service_locator.dart` — a singleton manual DI container with lazy-initialized properties. Repositories are created first, then services are wired by composing repositories. The LLM backend (Gemini → OpenAI → OpenRouter) is selected at runtime based on which API key is set.

### MVVM Pattern
- **Model**: ObjectBox entities in `lib/models/`
- **ViewModel**: classes extending `BaseViewModel` (extends `ChangeNotifier`) in each view folder
- **View**: widgets consume ViewModels via `ViewModelProvider<T>` (wraps `ChangeNotifierProvider`)
- `lib/core/base/base_view_model.dart` and `view_model_provider.dart` define the base infrastructure

Global providers (theme, in-app updates) live in `lib/provider_scope.dart` and are registered above the router.

### Navigation
`lib/core/route/app_router.dart` — declarative `go_router` with named routes:
- `/` → `MainView` (tab shell: Notes, Insights, Chat)
- `/note?title=` → `NoteView` (flutter_quill editor)
- `/chat` → `ChatView`
- `/search` → `SearchView` (vertical slide transition)

### Data Layer
- **ObjectBox** for all local persistence. Generated code is in `lib/objectbox.g.dart` — regenerate with `./scripts/build_runner.sh` after changing entity models.
- `ObjectBoxStoreManager` is a shared singleton Store; all repositories use it.
- Repository interfaces live in `lib/core/repository/interfaces/`; ObjectBox implementations in `lib/core/repository/implementations/`.

### AI / RAG Pipeline
Located in `lib/core/services/ai/`. The full pipeline:
1. **EmbeddingService** — chunks notes, computes SHA-256 signatures to skip unchanged content, calls Gemini/OpenAI/OpenRouter embedding API
2. **VectorSearchService** — cosine similarity search over stored embeddings
3. **DocumentResolverService** — maps chunk hits back to source notes, averages scores
4. **QueryRewriteService** / **MultiQueryExpansionService** — LLM-powered query rewriting
5. **PromptBuilderService** — assembles context-aware prompts with token budget enforcement
6. **RagService** — orchestrates 1–5, streams LLM responses to `ChatView`
7. **LlmClient** — provider-agnostic wrapper (Gemini native API or OpenAI-compatible HTTP)

### Import Pipeline
`lib/core/import/` — adapters implement `NoteImportAdapter`, emit `ImportedNote` (Markdown), which flows through `MarkdownToQuillConverter` → ObjectBox Note → `EmbeddingService`. Adapters: Obsidian, Notion, Storypad.

### Sync
`lib/core/services/sync/google_drive_sync_service.dart` and `chat/chat_drive_sync_service.dart` handle bidirectional Google Drive sync. Auth is managed by `GoogleDriveService` (silent sign-in restore on startup).

## Testing Structure

| Directory | Purpose | Runner |
|---|---|---|
| `test/` | Widget + unit tests | `flutter test` |
| `patrol_test/` | Logic tests using `patrol_finders` | `flutter test patrol_test` |
| `integration_test/` | Full E2E tests using Patrol CLI | `./scripts/patrol_test.sh` |

**patrol_test** uses `patrolWidgetTest` (not `patrolTest` from the Patrol CLI) so tests run without an emulator. Import `test_support.dart` and use the local `patrolTest` wrapper defined there.

## Code Style

- Line width: 120 characters (enforced by formatter)
- Single quotes for strings
- `const` constructors and literals preferred
- `avoid_print: true` — use `logger` package for debug output
- Generated files (`*.g.dart`) are excluded from analysis

## Workflow Aids

- `/new-view <feature>` — scaffold a new view folder following `Views_Style_Guide.md`.
- `/i18n-check` — verify `en.json` and `km.json` have identical keys.
- `/build-and-test` — run `flutter analyze` + `flutter test patrol_test` and report a clean summary.
- `style-reviewer` subagent — invoke with `Agent(subagent_type: "style-reviewer", ...)` to audit a feature against all style guides + DRY/KISS/SOLID. Use it before opening a PR.

## Definition of Done

A change is **not** done until:

1. `flutter analyze` passes with no new errors (the Stop hook enforces this).
2. Affected tests still pass (`flutter test patrol_test`).
3. Any new user-visible string exists in **both** `en.json` and `km.json`.
4. Any new ObjectBox entity field has had `./scripts/build_runner.sh` run.
5. The change conforms to the relevant style guide (run `style-reviewer` if unsure).
6. No new file exceeds the soft limits in `Views_Style_Guide.md` § 12.

## Commit Convention

Format: `type(scope): subject`

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`  
Scopes: `notes`, `sync`, `ui`, `tags`, `auth`, `core`, `deps`

The pre-commit hook auto-generates a structured message template. Install hooks via `./scripts/install_hooks.sh`.
