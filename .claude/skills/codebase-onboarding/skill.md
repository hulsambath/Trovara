---
name: codebase-onboarding
description: Use when a developer needs orientation to the Trovara codebase — new team member, returning after a gap, or asking "how does X work", "where is Y", or "how do I add a new feature".
allowed-tools: Read, Grep, Glob, Bash
model: sonnet
---

# Trovara Codebase Onboarding

Orients a developer to Trovara's architecture, conventions, and key workflows. Ground every answer in the actual code — no generic Flutter advice.

## Step 1 — Identify Their Need

Before exploring, ask or infer:
- New to project, or returning after a gap?
- What area: notes, AI/RAG, sync, UI, testing, adding a feature?
- Understanding existing code, or building something new?

Tailor the tour to that scope.

## Step 2 — Load Relevant CLAUDE.md

| Area | Read first |
|------|-----------|
| Views / UI | `lib/views/CLAUDE.md` + `docs/style_guide/Views_Style_Guide.md` |
| Core services / DI | `lib/core/CLAUDE.md` |
| AI / RAG / embeddings | `lib/core/services/ai/CLAUDE.md` |
| Testing | `patrol_test/CLAUDE.md` + `docs/PATROL_UNIT_TESTING.md` |
| File near ~250 LOC | `docs/style_guide/File_Organization_Rules.md` |

## Step 3 — Project at a Glance

**Trovara** — Flutter note-taking app with AI-powered RAG, Google Drive sync, and rich-text editing.

Stack: Flutter ≥3.8.1 · ObjectBox (local DB) · Provider (MVVM) · go_router · easy_localization (English + Khmer) · firebase_ai / Gemini / OpenAI-compatible HTTP · Google Drive API · Shorebird OTA.

Two flavors: **staging** (`lib/main_staging.dart`) and **prod** (`lib/main_prod.dart`), both delegate to `lib/main.dart`. API keys via `--dart-define` → `lib/constants/config_constants.dart`.

Startup sequence (`lib/initializer.dart`): EasyLocalization → Firebase → ThemeModeStorage → `ServiceLocator().initialize()` → Google Drive session restore → Shorebird OTA check.

## Step 4 — Core Patterns

### MVVM (The Law)

```dart
// View — UI only, no logic
class NotesView extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ViewModelProvider<NotesViewModel>(
    create: (context) => NotesViewModel(),
    root: true,
    builder: (context, viewModel, child) => _NotesContent(viewModel),
  );
}
// ViewModel — gets services via ServiceLocator, never calls ObjectBox directly
class NotesViewModel extends BaseViewModel {
  final NoteService _noteService = ServiceLocator().noteService;
}
```

Folder structure per view:
```
lib/views/<feature>/
├── <feature>_view.dart        # ViewModelProvider shell (< 30 lines)
├── <feature>_view_model.dart  # business logic (< 300 lines)
├── <feature>_content.dart     # part file: private _<Feature>Content
└── widgets/                   # part files for sub-widgets
```

### Repository Pattern

Interface → Implementation → ServiceLocator. ViewModels only see the interface.

```
lib/core/repository/interfaces/note_repository.dart     → INoteRepository (abstract)
lib/core/repository/implementations/objectbox_note_repository.dart → ObjectBoxNoteRepository
lib/core/di/service_locator.dart                       → lazy getter wiring
```

### Dependency Injection — ServiceLocator

`lib/core/di/service_locator.dart` is the **only place** implementations are wired.

```dart
// Add a new service:
MyService? _myService;
MyService get myService {
  _myService ??= MyService(noteRepository: noteRepository);
  return _myService!;
}
// In a ViewModel:
final _service = ServiceLocator().myService;
```

### Navigation (go_router)

```dart
context.push('/note?noteId=42&readOnly=true');   // push
context.go('/');                                  // replace
```

Routes declared in `lib/core/route/app_router.dart`.

### AI / RAG Pipeline (`lib/core/services/ai/`)

1. QueryRewriteService → MultiQueryExpansionService (LLM query rewriting)
2. EmbeddingService (chunks notes, SHA-256 change detection, calls embedding API)
3. VectorSearchService (cosine similarity)
4. DocumentResolverService (maps chunk hits back to notes)
5. PromptBuilderService (token-budget prompt assembly)
6. RagService (orchestrates 1–5, streams to ChatView)
7. LlmClient (provider-agnostic: Gemini native or OpenAI-compatible HTTP)

## Step 5 — Non-Negotiable Rules

Before touching any code, internalize these:

- **MVVM**: Views → ViewModels → Services → Repositories. Never skip a layer.
- **ServiceLocator**: No `MyService()` constructors outside `service_locator.dart`.
- **Interfaces**: ViewModels use `INoteRepository`, never `ObjectBoxNoteRepository`.
- **i18n**: `tr('domain.key')` always. Add to both `en.json` AND `km.json`.
- **Colors**: `Theme.of(context).colorScheme.*` only.
- **Icons**: `LucideIcons.*` from `lucide_icons_flutter` — never `Icons.*`.
- **Generated files**: Never edit `*.g.dart`. Run `./scripts/build_runner.sh` after model changes.
- **Logging**: `package:logger` — `avoid_print` is enforced.
- **File size**: 300 LOC hard limit. One primary class per file.

## Step 6 — Key Commands

```bash
# Setup
flutter pub get
./scripts/build_runner.sh        # Generate ObjectBox + flutter_gen code
./scripts/install_hooks.sh       # Pre-commit hooks

# Run
./scripts/run_app.sh --quick     # staging + debug, no prompts

# Quality
flutter analyze
flutter test patrol_test         # logic tests, no emulator
./scripts/patrol_test.sh         # E2E tests (requires emulator)

# Build
./scripts/build_apk.sh --trovara
./scripts/build_ipa.sh
```

Slash commands: `/new-view <feature>` · `/i18n-check` · `/build-and-test`

## Step 7 — Definition of Done

A change is **not done** until:
1. `flutter analyze` — zero new errors
2. `flutter test patrol_test` — all green
3. New user-visible strings in **both** `en.json` and `km.json`
4. New ObjectBox entity fields have had `build_runner` run
5. No new file exceeds 300 LOC
