---
name: system-design
description: Use when starting a feature that spans more than two files — before any code is written, to produce a file layout, MVVM layer plan, repository interfaces, ServiceLocator wiring, routes, and i18n keys.
allowed-tools: Read, Grep, Glob, Bash
model: sonnet
---

# System Design — Trovara Feature Planner

Produces a concrete, Trovara-specific implementation plan. No code is written during this step.

## Step 1 — Read the Architecture

```bash
cat CLAUDE.md && cat lib/core/CLAUDE.md && cat lib/views/CLAUDE.md
grep -n 'get ' lib/core/di/service_locator.dart | head -50
cat lib/core/route/app_router.dart
ls lib/core/repository/interfaces/
ls lib/views/
```

## Step 2 — Understand the Feature

Before designing, answer:
1. What data is persisted? (new entity, or operations on existing?)
2. New screen, modal, or panel in an existing view?
3. Network / LLM / Drive calls required?
4. Is it Pro-gated?
5. What loading / empty / error states does the user see?

## Step 3 — Produce the Design

### Feature: `<name>`

#### File Layout

```
lib/
├── models/<model>.dart                             # @Entity — only if new persistence
├── core/
│   ├── repository/
│   │   ├── interfaces/<name>_repository.dart
│   │   └── implementations/objectbox_<name>_repository.dart
│   └── services/<domain>/<name>_service.dart       # only if logic > ViewModel
└── views/<feature>/
    ├── <feature>_view.dart                         # ViewModelProvider shell
    ├── <feature>_view_model.dart                   # extends BaseViewModel
    ├── <feature>_content.dart                      # part file
    └── widgets/<component>.dart

Modified: service_locator.dart, app_router.dart, en.json, km.json
```

#### New ObjectBox Entities

```dart
@Entity()
class <Model> {
  int id = 0;
  @Index() String syncId;
  String fieldName;  // purpose
}
```

After adding: `./scripts/build_runner.sh -d`

#### Repository Interface

```dart
abstract class I<Name>Repository {
  Future<void> initialize();
  List<<Name>> getAll();
  <Name>? getById(int id);
  Future<<Name>> create({required String title});
  Future<void> update(<Name> item);
  Future<void> delete(int id);
  void addListener(Function() l);
  void removeListener(Function() l);
  void dispose();
}
```

Only include methods the feature actually calls.

#### Service (if needed)

```dart
class <Name>Service {
  final I<Name>Repository _repo;
  <Name>Service({required I<Name>Repository <name>Repository}) : _repo = <name>Repository;
}
```

Write "No service — logic lives in ViewModel" if trivial.

#### ViewModel Public API

```dart
class <Feature>ViewModel extends BaseViewModel {
  List<<Model>> items = [];
  bool isLoading = false;
  String? errorMessage;
  Future<void> load() async { ... }
}
```

#### ServiceLocator Wiring

```dart
I<Name>Repository? _<name>Repository;
I<Name>Repository get <name>Repository {
  _<name>Repository ??= ObjectBox<Name>Repository();
  return _<name>Repository!;
}
<Name>Service? _<name>Service;
<Name>Service get <name>Service {
  _<name>Service ??= <Name>Service(<name>Repository: <name>Repository);
  return _<name>Service!;
}
```

Add to `initialize()` and `dispose()` as needed.

#### Route

```dart
GoRoute(
  path: '/<feature>',
  name: '<feature>',
  pageBuilder: (context, state) => MaterialPage(
    key: state.pageKey, restorationId: '<feature>',
    child: const <Feature>View(),
  ),
),
```

#### i18n Keys (add to both en.json and km.json)

```json
"<feature>": { "title": "...", "empty_state": "...", "error": "..." }
```

#### UI State Table

| State   | Trigger                  | i18n key               |
|---------|--------------------------|------------------------|
| loading | `isLoading == true`      | —                      |
| empty   | list empty after load    | `<feature>.empty_state`|
| error   | `errorMessage != null`   | `<feature>.error`      |
| content | data present             | —                      |

#### Test Plan

```
patrol_test/core/repository/objectbox_<name>_repository_test.dart
patrol_test/core/services/<domain>/<name>_service_test.dart
patrol_test/views/<feature>/<feature>_view_model_test.dart
```

#### Implementation Order

1. ObjectBox entity + `./scripts/build_runner.sh -d`
2. Repository interface + ObjectBox implementation
3. Register repository in ServiceLocator
4. Service (if any) + register in ServiceLocator
5. ViewModel
6. View + content + widgets
7. Route in `app_router.dart`
8. i18n keys (en.json + km.json)
9. patrol_test files
10. `/i18n-check` + `/build-and-test`

## Validation Checklist

- [ ] No `new Service()` outside ServiceLocator
- [ ] ViewModels depend on interfaces only
- [ ] No hardcoded strings — every UI copy has an i18n key
- [ ] No `Icons.*` — only `LucideIcons.*`
- [ ] No planned file would exceed 300 LOC
- [ ] View file contains `ViewModelProvider` only
- [ ] Every UI state in the table
- [ ] At least one test per new repository, service, and ViewModel
