# Trovara — Project Context (LLM Source)

Use this document as factual context for the Trovara codebase. It is derived from the repository only; gaps are marked **Unknown / Needs clarification**.

---

## 1. Project Overview

- **Project name:** `trovara` (Dart package), product name **Trovara**.
- **Purpose:** Cross-platform note-taking with rich text (Quill), tagging, local persistence (ObjectBox), Google Drive AppData backup/sync, insights over notes, and RAG-style chat over the user’s notes (embeddings + LLM).
- **Target users:** Not explicitly defined in code. **Locales:** English (`en`) and Khmer (`km`) — `lib/constants/app_constants.dart`, `assets/translations/`. **Unknown / Needs clarification:** product positioning, personas.
- **Core features:**
  - Notes: Quill JSON, folders, favorite/archive, soft-delete/trash, `syncId` for merge/sync.
  - Tags: mood, activity, time, personal growth + custom tags.
  - Google Drive: Sign-In, JSON in AppData (`trovara_backup.json` notes, `trovara_chat_backup.json` chat).
  - Insights: entries/day, tag frequency, mood-based sentiment heuristics.
  - Chat/RAG: retrieval + LLM over note chunks.
  - Import: Obsidian, Notion, Storypad adapters (`lib/core/import/`).

---

## 2. Tech Stack

| Layer        | Technology                                                                                                              |
| ------------ | ----------------------------------------------------------------------------------------------------------------------- |
| App          | Flutter / Dart (`pubspec.yaml`: SDK `^3.8.1`, Flutter `>=3.41.2 <4.0.0`)                                                |
| Routing      | `go_router` — `lib/core/route/app_router.dart`                                                                          |
| Local DB     | ObjectBox — `lib/objectbox-model.json`, `lib/core/repository/`                                                          |
| Prefs        | `shared_preferences` — `lib/core/storage/`                                                                              |
| State        | `provider` + `ChangeNotifier` view models — `lib/core/base/`, `lib/provider_scope.dart`                                 |
| i18n         | `easy_localization` — `lib/app_scope.dart`, `assets/translations/`                                                      |
| Rich text    | `flutter_quill`                                                                                                         |
| Charts       | `fl_chart` — `lib/views/insights/`                                                                                      |
| Drive / Auth | `google_sign_in`, `googleapis`, `googleapis_auth`                                                                       |
| AI           | `google_generative_ai` + HTTP to OpenAI-compatible APIs — `lib/core/services/llm_client.dart`, `embedding_service.dart` |
| Firebase     | `firebase_core` — optional init via flavor mains — `lib/initializer.dart`                                               |
| Updates      | `in_app_update` (Android) — `lib/core/provider/in_app_update_provider.dart`                                             |

**Backend:** None in-repo — client-only app calling Google APIs and LLM/embedding HTTP APIs.

**Hosting / release:** GitHub Actions (`.github/workflows/`), Shorebird config (`shorebird.yaml`). Signing/credentials: sibling `../credentials` — see `android/app/build.gradle.kts`, `scripts/run_app.sh`.

---

## 3. Architecture

- **Style:** Monolithic Flutter app, MVVM-ish: Views → ViewModels (`ChangeNotifier`) → Services → Repositories → ObjectBox.
- **Composition root:** `ServiceLocator` singleton — `lib/core/di/service_locator.dart` (lazy singletons, `initialize()` / `dispose()`).
- **Typical RAG chat flow:** `ChatViewModel.sendMessage` → `ChatService` (persist user msg) → `RagService` (rewrite → multi-query expansion → embed queries → `VectorSearchService` → RRF fusion → `DocumentResolverService` → `PromptBuilderService` → `LlmClient` stream) → `ChatService` (persist assistant) → UI refresh.
- **Typical Drive sync (notes):** `GoogleDriveSyncService.syncWithGoogleDrive` → download `trovara_backup.json` → `NoteService.mergeWithRemoteData` / `importAllFromJson` → trash reconciliation / tombstones → upload merged JSON → then `ChatDriveSyncService.syncChatWithGoogleDrive` — `lib/core/services/google_drive_sync_service.dart`.

---

## 4. Folder Structure (high signal)

| Path                                          | Role                                                                      |
| --------------------------------------------- | ------------------------------------------------------------------------- |
| `lib/main.dart`                               | Entry: deferred imports, `Initializer.load`, `runApp`.                    |
| `lib/main_staging.dart`, `lib/main_prod.dart` | Flavor + Firebase options → `main()`.                                     |
| `lib/app.dart`, `lib/app_scope.dart`          | MaterialApp.router, localization, provider wrapper.                       |
| `lib/core/di/service_locator.dart`            | DI wiring.                                                                |
| `lib/core/services/`                          | Business orchestration (notes, drive, RAG, chat, embeddings).             |
| `lib/core/repository/`                        | Interfaces + ObjectBox implementations.                                   |
| `lib/views/`                                  | Screens: main, notes, note editor, chat, insights, trash, settings.       |
| `lib/models/`                                 | Domain models.                                                            |
| `lib/widgets/`                                | Shared UI.                                                                |
| `lib/objectbox-model.json`                    | Persisted entity schema.                                                  |
| `scripts/`                                    | `run_app.sh`, `build_runner.sh`, `flutterfire.sh`, Android build scripts. |
| `docs/`, `learn/`                             | Human docs (may drift vs code).                                           |

---

## 5. Key Features — Files & Flow

### Notes & editor

- **Files:** `lib/views/notes/`, `lib/views/notes/note/`, `lib/models/note.dart`, `lib/core/services/note_service.dart`, `lib/core/repository/implementations/objectbox_note_repository.dart`
- **Flow:** UI/view models → `NoteService` / repositories → ObjectBox.

### Tagging

- **Files:** `lib/widgets/tages/`, `lib/core/services/custom_tag_service.dart`, `lib/models/custom_tag.dart`
- **Flow:** Chip UI updates note tag fields → save via note flows.

### Google Drive (notes + chat)

- **Files:** `lib/core/services/google_drive_service.dart`, `google_drive_sync_service.dart`, `chat/chat_drive_sync_service.dart`, `lib/core/storage/google_drive_auth_storage.dart`, `lib/views/notes/notes_view_model.dart`, `lib/views/setting/setting_view_model.dart`

### Insights

- **Files:** `lib/views/insights/`, `lib/core/repository/analytics_repository.dart`

### Chat / RAG

- **Files:** `lib/views/chat/`, `lib/core/services/rag_service.dart`, `chat/chat_service.dart`, `lib/core/route/app_router.dart` (routes `/`, `/note`, `/chat`)
- **Availability:** `RagService.isAvailable` requires both `EmbeddingService.isAvailable` and `LlmClient.isAvailable` (non-empty API key after init).

### Import

- **Files:** `lib/core/import/import_adapter.dart`, `adapters/*.dart`, `converters/markdown_to_quill.dart`, `NoteService.importFromAdapter`

---

## 6. API / Data Layer (external)

- No first-party REST server in-repo.
- **LLM:** OpenAI-compatible HTTP (default base OpenRouter) or Gemini — `lib/core/services/llm_client.dart`.
- **Embeddings:** OpenAI-compatible or Gemini — `lib/core/services/embedding_service.dart`.
- **Drive:** Google Drive API v3 AppData — `lib/core/services/google_drive_service.dart`.

**Auth:** Google Sign-In for Drive; LLM/embeddings use compile-time API keys, not runtime `.env` in repo.

---

## 7. State Management

- **App-wide:** `ThemeProvider`, `InAppUpdateProvider` — `lib/provider_scope.dart`.
- **Screens:** `ViewModelProvider<T>` + `ChangeNotifier` — `lib/core/base/view_model_provider.dart`, `base_view_model.dart`.
- Some view models expose static singletons (e.g. `NotesViewModel.instance` used from `MainViewModel`).

---

## 8. Environment & Configuration

**Dart defines** (`--dart-define` / `--dart-define-from-file`) — `lib/constants/config_constants.dart`:

- `APP_NAME`, `APP_SCHEME`, `APP_COLOR`
- `GEMINI_API_KEY`, `OPENAI_API_KEY`, `OPENAI_EMBEDDING_MODEL` (default `text-embedding-3-large`)
- `OPENROUTER_API_KEY`, `OPENROUTER_MODEL` (default `openrouter/auto`), `OPENROUTER_SITE_URL`, `OPENROUTER_APP_NAME` (default `Trovara`), `OPENROUTER_EMBEDDING_MODEL` (default `openai/text-embedding-3-large`)

**Gitignored (must be created locally):**

- `configs/trovara_staging.json`, `configs/trovara_prod.json` (and related) — required by `scripts/run_app.sh`
- `lib/firebase_options/staging.dart`, `lib/firebase_options/prod.dart`
- Android/iOS Firebase plist/json per `.gitignore`

**CI stubs:** `.github/workflows/shorebird.yml` generates minimal `lib/firebase_options/staging.dart` / `prod.dart` for CI.

**Firebase project id** (from `firebase.json`): `trovara-team`.

---

## 9. Constraints & Caveats

- `shelf` is in `pubspec.yaml` but unused under `lib/` (as of repo scan).
- `.github/copilot-instructions.md` references non-existent `sync_service.dart` / `auth_service.dart` — stale vs current `google_drive_sync_service.dart` / `google_drive_service.dart`.
- `lib/core/services/deep_link_handler.dart` is fully commented; deep linking not active.
- `InAppUpdateProvider.checkForUpdate` overwrites `_availability` with `updateAvailable` after reading `_updateInfo` — likely bug (`lib/core/provider/in_app_update_provider.dart`).
- README `./scripts/run_app.sh --trovara`: **`run_app.sh` does not accept `--trovara`** (that flag exists on some `build_*.sh` scripts, not `run_app.sh`).

---

## 10. How to Run

1. `flutter pub get`
2. `dart run build_runner build --delete-conflicting-outputs` (see `scripts/build_runner.sh` for intended flags)
3. Add `configs/trovara_staging.json` or `configs/trovara_prod.json` + Firebase options if building flavors
4. `./scripts/run_app.sh` — interactive; runs `flutter run --dart-define-from-file=configs/trovara_<env>.json --target=lib/main_<env>.dart` and `--flavor` on mobile

**CI Flutter version:** 3.41.2 stable (`.github/workflows/tests.yml`).

---

## 11. LLM Usage Guidelines

1. Trust **`lib/` source** over older markdown when they disagree.
2. Trace features through **`ServiceLocator`** → service → repository.
3. Assume **fresh clone may lack** `configs/*.json` and `lib/firebase_options/*.dart`.
4. Follow **`analysis_options.yaml`:** single quotes, const preferences, `page_width: 120`.

---

_Generated from repository structure and key files; regenerate after major refactors._
