---
name: widget-test
description: Use when writing a test for a Trovara service, converter, or ViewModel — scaffolds a patrol_test file with stub repositories, the correct patrolTest wrapper, and test_support imports.
allowed-tools: Read, Grep, Bash, Edit, Write
model: sonnet
---

# Widget / Logic Test

Scaffolds tests under `patrol_test/` using the project's local `patrolTest` wrapper and stub repositories. No emulator needed.

## Anatomy of a Trovara Test File

```
patrol_test/
├── test_support.dart             # Import this in every test file
├── core/
│   ├── services/                 # Test mirrors lib/core/services/
│   │   └── <name>_service_test.dart
│   └── import/
│       └── converters/
│           └── <converter>_test.dart
└── views/                        # ViewModel/widget logic tests
    └── <feature>/
        └── <feature>_view_model_test.dart
```

## Step 1 — Create the test file

Mirror the source path. Service at `lib/core/services/notes/tag_service.dart` → test at `patrol_test/core/services/tag_service_test.dart`.

## Step 2 — Scaffold stubs for every repository the subject uses

```dart
import 'package:trovara/core/repository/interfaces/<dep>_repository.dart';
import 'package:trovara/models/<dep>.dart';

class Stub<Dep>Repository implements I<Dep>Repository {
  final List<<Dep>> _items = [];

  void seed(List<<Dep>> items) => _items.addAll(items);

  @override Future<void> initialize() async {}
  @override List<<Dep>> getAll() => List.unmodifiable(_items);
  @override <Dep>? getById(int id) => _items.firstWhere((i) => i.id == id, orElse: () => throw StateError('not found'));
  @override Future<<Dep>> create({required String title}) async {
    final item = <Dep>(title: title)..id = _items.length + 1;
    _items.add(item);
    return item;
  }
  @override Future<void> update(<Dep> item) async {
    final idx = _items.indexWhere((i) => i.id == item.id);
    if (idx >= 0) _items[idx] = item;
  }
  @override Future<void> delete(int id) async => _items.removeWhere((i) => i.id == id);
  @override int get totalCount => _items.length;
  @override void addListener(Function() l) {}
  @override void removeListener(Function() l) {}
  @override void dispose() {}
}
```

Implement **every** method declared in the interface — `unimplemented` stubs cause runtime failures.

## Step 3 — Write the test body

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/services/<domain>/<name>_service.dart';
import '../../test_support.dart';    // adjust relative path

void main() {
  late Stub<Dep>Repository repo;
  late <Name>Service service;

  setUp(() {
    repo = Stub<Dep>Repository();
    service = <Name>Service(<dep>Repository: repo);
  });

  group('<Name>Service', () {
    patrolTest('returns empty list when repository is empty', ($) async {
      expect(service.getAll(), isEmpty);
    });

    patrolTest('creates item and notifies', ($) async {
      repo.seed([]);
      final item = await service.create(title: 'Test');
      expect(item.title, 'Test');
      expect(service.getAll(), hasLength(1));
    });
  });
}
```

**`patrolTest` is the local wrapper from `test_support.dart`** — do NOT import from `package:patrol` directly.

## Step 4 — Run the test

```bash
# Single file
flutter test patrol_test/core/services/<name>_service_test.dart

# Full logic suite (no emulator)
flutter test patrol_test
```

## Patterns

### Testing a converter (no repository needed)

```dart
import 'package:trovara/core/import/converters/markdown_to_quill.dart';
import '../../../test_support.dart';

void main() {
  group('MarkdownToQuillConverter', () {
    patrolTest('converts heading to insert with attributes', ($) async {
      final result = MarkdownToQuillConverter.convert('# Hello');
      expect(result, contains('"Hello"'));
    });
  });
}
```

Helpers available from `test_support.dart`:
- `deltaFromMarkdown(String)` → parsed Quill delta map
- `quillOpsFromMarkdown(String)` → list of Quill ops
- `markdownFromQuillOps(List<Map>)` → back to markdown string
- `fileInput({path, content})` → import fixture map

### Testing a ViewModel (no ObjectBox)

```dart
// ViewModel must be constructed with stub services, not ServiceLocator
// Pass services as constructor args, or override ServiceLocator in tests
patrolTest('loading flag starts true and becomes false after init', ($) async {
  final vm = <Feature>ViewModel.withService(<name>Service: FakeService());
  expect(vm.isLoading, isTrue);
  await Future.microtask(() {});   // let microtask queue flush
  expect(vm.isLoading, isFalse);
});
```

If the ViewModel calls `ServiceLocator()` directly, prefer testing through the service layer instead.

## Rules

- Always import `test_support.dart` — never import `patrol_finders` directly.
- Never create a real ObjectBox store in tests — use stub repositories.
- Never call real APIs or network endpoints — stub at the repository/HTTP-client level.
- Call `await Future.microtask(() {})` or `await pumpAndSettle()` to flush async initialization.
- Each `patrolTest` group has its own `setUp()` to reset state; never share mutable state across tests.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Importing `patrolTest` from `package:patrol` | Use local wrapper from `test_support.dart` |
| Stub repository missing an interface method | Implement all methods; Dart will error at compile time |
| Testing through `ServiceLocator` singleton | Isolate via constructor-injected fakes |
| Asserting on observable UI state without pumping | Flush microtasks/futures before asserting |
| File placed in `test/` instead of `patrol_test/` | Logic tests live in `patrol_test/`; widget/golden tests in `test/` |
