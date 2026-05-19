---
name: codebase-onboarding
description: Use when a developer needs orientation to the Trovara codebase — new team member, returning after a gap, or asking "how does X work", "where is Y", or "how do I add a new feature".
allowed-tools: Read, Grep, Glob, Bash
model: sonnet
---

# Trovara Codebase Onboarding

You are guiding a developer through the Trovara codebase. Follow this skill to give accurate, contextual answers grounded in the actual code — not generic Flutter advice.

## Step 1 — Identify What They Need

Before exploring, ask or infer:
- Are they new to the project, or returning after a gap?
- What area are they touching? (AI/RAG, notes, sync, UI, testing, a new feature?)
- Are they trying to understand existing code, or add something new?

Tailor your tour to that scope. Don't dump the whole codebase on them.

## Step 2 — Load the Relevant CLAUDE.md

**Always read the area-specific CLAUDE.md before giving guidance:**

| Area | Read first |
|---|---|
| Views / UI screens | `lib/views/CLAUDE.md` + `docs/style_guide/Views_Style_Guide.md` |
| Core services / DI | `lib/core/CLAUDE.md` |
| AI / RAG / embeddings | `lib/core/services/ai/CLAUDE.md` |
| Testing | `patrol_test/CLAUDE.md` + `docs/PATROL_UNIT_TESTING.md` |
| File exceeding ~250 LOC | `docs/style_guide/File_Organization_Rules.md` |

Use the Read tool to load these now, before answering.

## Step 3 — Project Overview

**Trovara** is a Flutter note-taking app with AI-powered RAG (Retrieval-Augmented Generation), Google Drive sync, and rich-text editing.

### Tech Stack
- Flutter ≥3.8.1 / Dart
- ObjectBox — local persistence (generated code, never edit `*.g.dart`)
- Provider — state management via `ViewModelProvider`
- go_router — declarative navigation
- easy_localization — i18n (English + Khmer)
- firebase_ai (Gemini) / OpenAI-compatible HTTP — LLM and embedding backends
- Google Drive API — bidirectional cloud sync

### Flavors
Two build flavors: **staging** (`lib/main_staging.dart`) and **prod** (`lib/main_prod.dart`). Both delegate to `lib/main.dart`. API keys come in via `--dart-define` and are read from `lib/constants/config_constants.dart`.

### Startup Sequence (`lib/initializer.dart`)
1. `EasyLocalization.ensureInitialized()`
2. Firebase init (flavor-specific options)
3. `ThemeModeStorage.initialize()`
4. `ServiceLocator().initialize()` — wires all repos, services, LLM clients
5. Google Drive silent session restore
6. Shorebird OTA update check (background, non-blocking)

## Step 4 — Core Architecture Patterns

### MVVM — The Law

Every screen follows this exact structure. Views never call services or repos directly.

```dart
// ✅ View — UI only, no business logic
class NotesView extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ViewModelProvider<NotesViewModel>(
    create: (context) => NotesViewModel(),
    builder: (context, viewModel, child) => _NotesContent(viewModel),
  );
}

// ✅ ViewModel — presentation logic, depends on interfaces
class NotesViewModel extends BaseViewModel {
  final INoteRepository _repository;
  List<Note> notes = [];

  NotesViewModel({required INoteRepository repository})
      : _repository = repository;

  Future<void> loadNotes() async {
    isLoading = true;
    notifyListeners();
    try {
      notes = await _repository.getAll();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
```

**BaseViewModel** (`lib/core/base/base_view_model.dart`) extends `ChangeNotifier` with `isLoading`, `hasError`, and `errorMessage` built in.

### Repository Pattern

Interface first, implementation second. ViewModels only ever see the interface.

```dart
// Interface: lib/core/repository/interfaces/i_note_repository.dart
abstract class INoteRepository {
  Stream<List<Note>> watchNotes();
  Future<Note?> getNote(int id);
  Future<void> putNote(Note note);
  Future<void> deleteNote(int id);
}

// Implementation: lib/core/repository/implementations/objectbox_note_repository.dart
class ObjectBoxNoteRepository implements INoteRepository {
  final Box<Note> _box;
  // concrete ObjectBox logic here
}
```

### Dependency Injection — ServiceLocator

`lib/core/di/service_locator.dart` is the **only place** implementations are wired. Use lazy getters. Never `new` a service or repo elsewhere.

```dart
// Getting a dependency in a ViewModel
final _repository = ServiceLocator().noteRepository;

// Adding a new service
class ServiceLocator {
  late final MyService myService = MyService(
    repository: noteRepository,
  );
}
```

### Navigation

`lib/core/route/app_router.dart` — go_router with named routes:
- `/` → `MainView` (tab shell: Notes, Insights, Chat)
- `/note?title=` → `NoteView` (flutter_quill editor)
- `/chat` → `ChatView`
- `/search` → `SearchView` (vertical slide transition)

```dart
// Navigate
context.push('/route');
context.push('/note?title=My+Note');
context.go('/');  // replace, not push
```

## Step 5 — AI / RAG Pipeline

Located in `lib/core/services/ai/`. Read `lib/core/services/ai/CLAUDE.md` for full details.

Pipeline flow for a chat query:
1. **QueryRewriteService** / **MultiQueryExpansionService** — LLM rewrites the query
2. **EmbeddingService** — chunks notes, computes SHA-256 to skip unchanged content, calls embedding API
3. **VectorSearchService** — cosine similarity search over stored embeddings
4. **DocumentResolverService** — maps chunk hits back to source notes, averages scores
5. **PromptBuilderService** — assembles context-aware prompt with token budget enforcement
6. **RagService** — orchestrates steps 1–5, streams LLM response to `ChatView`
7. **LlmClient** — provider-agnostic wrapper (firebase_ai Gemini native or OpenAI-compatible HTTP)

The backend is selected at runtime based on which API key is set in `config_constants.dart`.

## Step 6 — Non-Negotiable Rules (Checklist Before Any Change)

Walk the developer through these before they touch code:

- [ ] **MVVM strictly**: Views → ViewModels → Services/Repos. Never skip a layer.
- [ ] **ServiceLocator always**: No `MyService()` constructors outside `service_locator.dart`.
- [ ] **Repository pattern**: Interface in `core/repository/interfaces/`, ObjectBox impl in `core/repository/implementations/`.
- [ ] **No hardcoded strings**: Use `tr('key')` and add to **both** `assets/translations/en.json` AND `assets/translations/km.json`.
- [ ] **No hardcoded colors/styles**: `Theme.of(context).colorScheme.*` and `Theme.of(context).textTheme.*` only.
- [ ] **Icons**: `lucide_icons_flutter` only. Never `Icons.*` from Material.
- [ ] **Generated files**: Never edit `*.g.dart` or `lib/objectbox-model.json`. Edit source entities, then run `./scripts/build_runner.sh`.
- [ ] **Logging**: `package:logger` only. `avoid_print` lint is enabled — `print()` will fail analysis.
- [ ] **File size**: 300 LOC hard limit. One primary class per file. Refactor before crossing 300.
- [ ] **Single quotes, 120 char width, `const` everywhere**.

## Step 7 — Adding a New Feature (Step-by-Step)

### New Screen / View

```
lib/views/my_feature/
├── my_feature_view.dart          # ViewModelProvider wrapper
├── my_feature_content.dart       # _MyFeatureContent StatelessWidget
├── my_feature_view_model.dart    # extends BaseViewModel
└── widgets/                      # feature-scoped sub-widgets (if needed)
```

Or use the scaffold command: `/new-view my_feature`

### New Model / Entity

1. Create `lib/models/my_model.dart` with `@Entity()` annotations
2. Run `./scripts/build_runner.sh` to regenerate `*.g.dart`
3. Add `INoteRepository`-style interface in `core/repository/interfaces/`
4. Implement in `core/repository/implementations/`
5. Register in `ServiceLocator`

### New Service

1. Create `lib/core/services/my_service.dart`
2. Constructor-inject repository interfaces
3. Register as a lazy getter in `ServiceLocator`
4. ViewModels get it via `ServiceLocator().myService`

## Step 8 — Testing

### Test Structure

| Directory | Purpose | Runner |
|---|---|---|
| `test/` | Widget + unit tests | `flutter test` |
| `patrol_test/` | Logic tests with patrol_finders | `flutter test patrol_test` |
| `integration_test/` | Full E2E (requires emulator) | `./scripts/patrol_test.sh` |

### Key Rule: No Database Mocks in patrol_test

Tests in `patrol_test/` must use real ObjectBox databases — not mocks. This was enforced after mock/prod divergence masked broken migrations. Use the test helpers in `patrol_test/test_support.dart`.

```dart
// ✅ patrol_test style — use patrolWidgetTest, import test_support.dart
import 'test_support.dart';

void main() {
  patrolWidgetTest('description', (tester) async {
    // real database, real service wiring
  });
}
```

### ViewModel Unit Test Pattern

```dart
group('NotesViewModel', () {
  late INoteRepository repository;
  late NotesViewModel viewModel;

  setUp(() {
    repository = ObjectBoxNoteRepository(testBox);  // real ObjectBox
    viewModel = NotesViewModel(repository: repository);
  });

  test('loadNotes populates notes list', () async {
    await viewModel.loadNotes();
    expect(viewModel.notes, isNotEmpty);
  });
});
```

## Step 9 — Dev Workflows

### Environment Setup

```bash
flutter pub get
./scripts/build_runner.sh          # generate ObjectBox + flutter_gen
./scripts/install_hooks.sh         # pre-commit hooks
```

### Running

```bash
./scripts/run_app.sh               # fast run (staging + debug)
./scripts/run_app.sh --interactive # prompt for target/env/device
./scripts/run_app.sh --prod-release --android
```

### Linting + Testing

```bash
flutter analyze                    # must pass before any PR
flutter test patrol_test           # logic tests, no emulator needed
./scripts/patrol_test.sh           # E2E (emulator required)
```

Run `/build-and-test` to get a clean summary of both.

### i18n

```bash
# After adding keys to en.json and km.json:
# Run /i18n-check to verify key parity
```

### Building

```bash
./scripts/build_apk.sh --trovara
./scripts/build_ipa.sh
```

## Step 10 — Code Style Quick Reference

### Class Structure Order

```dart
class MyViewModel extends BaseViewModel {
  // 1. Static constants
  static const _maxRetries = 3;

  // 2. Instance properties (private first)
  final INoteRepository _repository;
  List<Note> notes = [];

  // 3. Constructor
  MyViewModel({required INoteRepository repository})
      : _repository = repository;

  // 4. Public methods
  Future<void> loadNotes() async { ... }

  // 5. Private helpers
  void _handleError(Exception e) { ... }
}
```

### DO / DON'T Reference

```dart
// ✅ Colors
Theme.of(context).colorScheme.primary

// ❌ Never
Colors.blue

// ✅ Text styles
Theme.of(context).textTheme.titleLarge

// ❌ Never
TextStyle(fontSize: 24, fontWeight: FontWeight.bold)

// ✅ Localized strings
tr('notes.empty_state')

// ❌ Never
'No notes yet'

// ✅ Icons
LucideIcons.fileText

// ❌ Never
Icons.description

// ✅ Logging
logger.d('Loading notes');

// ❌ Never
print('Loading notes');
```

## Step 11 — Commit Convention

Format: `type(scope): subject`

**Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`
**Scopes**: `notes`, `sync`, `ui`, `tags`, `auth`, `core`, `deps`, `ai`

Examples:
```
feat(notes): add bulk delete confirmation dialog
fix(ai): handle empty embedding response from Gemini
refactor(core): extract EmbeddingChunker from EmbeddingService
```

## Step 12 — Definition of Done

A change is **not done** until all of these pass:

1. `flutter analyze` — zero new errors
2. `flutter test patrol_test` — all green
3. New user-visible strings exist in **both** `en.json` and `km.json`
4. New ObjectBox entity fields have had `./scripts/build_runner.sh` run
5. No new file exceeds 300 LOC
6. Style guide compliance verified (run `style-reviewer` subagent if unsure)

## Useful Commands Summary

| Command | What it does |
|---|---|
| `/new-view <name>` | Scaffold view folder per Views_Style_Guide.md |
| `/i18n-check` | Verify en.json and km.json key parity |
| `/build-and-test` | Run `flutter analyze` + `flutter test patrol_test` |
| `style-reviewer` (Agent) | Audit feature against all style guides |