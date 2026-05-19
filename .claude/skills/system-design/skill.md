---
name: system-design
description: Use when starting a feature that spans more than two files — before any code is written, to produce a file layout, MVVM layer plan, repository interfaces, and ServiceLocator wiring.
allowed-tools: Read, Grep, Glob, Bash
model: sonnet
---

# System Design — Trovara Feature Planner

You produce a concrete implementation plan grounded in Trovara's architecture. No generic Flutter advice — every suggestion must fit the existing DI, MVVM, and repository patterns.

## Step 1 — Read the Architecture First

Load these in parallel before designing anything:

- `CLAUDE.md` — non-negotiable rules
- `lib/core/CLAUDE.md` — service/DI patterns
- `lib/views/CLAUDE.md` — view/viewmodel patterns
- `lib/core/di/service_locator.dart` — current DI wiring (see what's already registered)
- `lib/core/route/app_router.dart` — current routes

If the feature touches AI/RAG, also read `lib/core/services/ai/CLAUDE.md`.

## Step 2 — Understand the Feature

Ask or infer:
1. What user action triggers it?
2. What data does it read/write? (existing models or new ones?)
3. Does it need network/LLM/Drive? (→ determines service complexity)
4. Is it a new screen, a modification to an existing one, or background logic only?

## Step 3 — Produce the Design

Output the plan in exactly this structure:

---

### Feature: `<name>`

#### File Layout

```
lib/
├── views/<feature>/
│   ├── <feature>_view.dart          # ViewModelProvider wrapper only
│   ├── <feature>_content.dart       # _FeatureContent (part of view)
│   ├── <feature>_view_model.dart    # extends BaseViewModel
│   └── widgets/
│       └── <widget>.dart            # only if needed
├── core/
│   ├── services/<domain>/
│   │   └── <feature>_service.dart   # business logic (if needed)
│   └── repository/
│       ├── interfaces/
│       │   └── i_<name>_repository.dart
│       └── implementations/
│           └── objectbox_<name>_repository.dart
└── models/
    └── <model>.dart                  # only if new ObjectBox entity needed
```

Remove rows that don't apply. Fewer files is better.

#### New ObjectBox Entities

List entity fields with types. If none needed, write "None — reuses existing models."

```dart
@Entity()
class MyEntity {
  int id = 0;
  String field; // purpose
}
```

After adding: run `./scripts/build_runner.sh`.

#### Repository Interface

```dart
abstract class IMyRepository {
  Future<List<MyEntity>> getAll();
  Future<void> put(MyEntity entity);
  Future<void> delete(int id);
}
```

Only include methods the feature actually needs. No speculative methods.

#### Service (if needed)

```dart
class MyFeatureService {
  final IMyRepository _repository;
  // other injected dependencies

  MyFeatureService({required IMyRepository repository, ...})
      : _repository = repository;

  // list public methods with one-line purpose each
}
```

If the feature is simple enough to put logic directly in the ViewModel, write "No service needed — logic lives in ViewModel."

#### ViewModel Public API

```dart
class MyFeatureViewModel extends BaseViewModel {
  // State properties the view reads
  List<MyEntity> items = [];
  bool isLoading = false;

  // Commands the view calls
  Future<void> load() async { ... }
  Future<void> doAction(MyEntity entity) async { ... }
}
```

#### ServiceLocator Wiring

Exact lines to add to `lib/core/di/service_locator.dart`:

```dart
late final IMyRepository myRepository = ObjectBoxMyRepository(store: _store);
late final MyFeatureService myFeatureService = MyFeatureService(repository: myRepository);
```

#### Route (if new screen)

Exact GoRoute to add to `lib/core/route/app_router.dart`:

```dart
GoRoute(
  path: '/my-feature',
  name: 'myFeature',
  pageBuilder: (context, state) => const NoTransitionPage(child: MyFeatureView()),
),
```

#### i18n Keys

List every key to add to both `assets/translations/en.json` AND `assets/translations/km.json`:

```json
{
  "my_feature": {
    "title": "...",
    "empty_state": "...",
    "error": "..."
  }
}
```

#### Implementation Order

Ordered checklist — this is the sequence that avoids blocked work:

1. [ ] Add ObjectBox entity (if any) + run build_runner
2. [ ] Create repository interface + ObjectBox implementation
3. [ ] Register repository in ServiceLocator
4. [ ] Create service (if any) + register in ServiceLocator
5. [ ] Create ViewModel (inject service/repo via constructor)
6. [ ] Create view + content files
7. [ ] Add route
8. [ ] Add i18n keys to en.json + km.json
9. [ ] Write patrol_test for service/repository
10. [ ] Run `/build-and-test`

#### Risks & Open Questions

- List any architectural ambiguity that needs a decision before coding
- Call out any non-obvious ObjectBox query that may need a custom index

---

## Step 4 — Validate Against Non-Negotiables

Before presenting the design, check:

- [ ] No service is instantiated with `new` outside ServiceLocator
- [ ] ViewModel only depends on interfaces, never `ObjectBox*` concretions
- [ ] No hardcoded strings — all UI copy has i18n keys
- [ ] No `Icons.*` — only `LucideIcons.*`
- [ ] No file in the plan would exceed 300 LOC when implemented
- [ ] View file contains only `ViewModelProvider` — no UI logic

If any check fails, revise the design before showing it.
