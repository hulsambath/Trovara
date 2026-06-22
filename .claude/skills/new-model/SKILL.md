---
name: new-model
description: Use when adding a new persistable data entity to Trovara — scaffolds the ObjectBox model class, repository interface, ObjectBox implementation, and ServiceLocator wiring, then runs codegen.
allowed-tools: Read, Grep, Bash, Edit, Write
model: sonnet
---

# New ObjectBox Model

Scaffolds a complete data entity: model class → repository interface → ObjectBox implementation → ServiceLocator → codegen.

## Steps

### 1 — Create `lib/models/<name>.dart`

```dart
import 'package:objectbox/objectbox.dart';
import 'package:uuid/uuid.dart';

@Entity()
class <Name> {
  int id = 0;                     // Required by ObjectBox; auto-assigned on put()

  @Index()                        // Add @Index() on any field used in queries
  String syncId;

  String title;
  DateTime createdAt;
  DateTime updatedAt;
  // ... domain fields

  <Name>({
    this.id = 0,
    String? syncId,
    required this.title,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : syncId = syncId ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Manual serialization — no freezed/json_serializable in this project
  Map<String, dynamic> toJson() => {
    'id': id,
    'syncId': syncId,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory <Name>.fromJson(Map<String, dynamic> json) => <Name>(
    syncId: json['syncId'] as String?,
    title: json['title'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  )..<fieldAssignments>;
}
```

**Key rules:**
- `int id = 0` — ObjectBox assigns the real ID on first `box.put()`.
- Annotate every field used in `.query(Field_.equals(...))` with `@Index()`.
- Use `@Unique()` when a field must be globally unique (e.g., `syncId`).
- DateTime fields are stored as `int` internally by ObjectBox; use `DateTime` in Dart.
- List fields (`List<String>`, `List<int>`) are stored as byte arrays; keep them small.

### 2 — Run build_runner to generate query classes

```bash
cd /Users/apple/Documents/project/Trovara
./scripts/build_runner.sh -d      # -d deletes conflicting outputs first
```

This regenerates `lib/objectbox.g.dart` and `lib/objectbox-model.json`. **Never edit these files.**

After running, the generated query class `<Name>_` (e.g., `Note_`) becomes available for querying.

### 3 — Create the repository interface `lib/core/repository/interfaces/<name>_repository.dart`

```dart
import 'package:trovara/models/<name>.dart';

abstract class I<Name>Repository {
  Future<void> initialize();

  // Queries (synchronous — ObjectBox reads are sync)
  List<<Name>> getAll();
  <Name>? getById(int id);
  <Name>? getBySync(String syncId);

  // Mutations (asynchronous)
  Future<<Name>> create({required String title});
  Future<void> update(<Name> item);
  Future<void> delete(int id);

  int get totalCount;

  void addListener(Function() listener);
  void removeListener(Function() listener);
  void dispose();
}
```

### 4 — Create the ObjectBox implementation `lib/core/repository/implementations/objectbox_<name>_repository.dart`

```dart
import 'package:trovara/core/repository/base/base_repository.dart';
import 'package:trovara/core/repository/base/objectbox_store_manager.dart';
import 'package:trovara/core/repository/interfaces/<name>_repository.dart';
import 'package:trovara/models/<name>.dart';
import 'package:trovara/objectbox.g.dart';

class ObjectBox<Name>Repository extends BaseRepository implements I<Name>Repository {
  late Box<<Name>> _box;
  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    final store = await ObjectBoxStoreManager().store;
    _box = store.box<<Name>>();
    _isInitialized = true;
  }

  @override
  List<<Name>> getAll() => _box.getAll();

  @override
  <Name>? getById(int id) => _box.get(id);

  @override
  <Name>? getBySync(String syncId) {
    final q = _box.query(<Name>_.syncId.equals(syncId)).build();
    final result = q.findFirst();
    q.close();
    return result;
  }

  @override
  Future<<Name>> create({required String title}) async {
    final item = <Name>(title: title);
    final id = _box.put(item);
    item.id = id;
    super.notifyListeners();
    return item;
  }

  @override
  Future<void> update(<Name> item) async {
    item.updatedAt = DateTime.now();
    _box.put(item);
    super.notifyListeners();
  }

  @override
  Future<void> delete(int id) async {
    _box.remove(id);
    super.notifyListeners();
  }

  @override
  int get totalCount => _box.count();
}
```

### 5 — Register in `lib/core/di/service_locator.dart`

```dart
// Field (lazy)
I<Name>Repository? _<name>Repository;

// Getter
I<Name>Repository get <name>Repository {
  _<name>Repository ??= ObjectBox<Name>Repository();
  return _<name>Repository!;
}
```

Add to `dispose()`:
```dart
_<name>Repository?.dispose();
_<name>Repository = null;
```

Add `await <name>Repository.initialize();` to `initialize()` if the repository needs async setup before first use.

### 6 — Verify

```bash
flutter analyze          # no new errors
flutter test patrol_test # no regressions
```

## Rules

- Never edit `lib/objectbox.g.dart` or `lib/objectbox-model.json` — always regenerate with `build_runner`.
- Always close queries: `final q = _box.query(...).build(); final r = q.findFirst(); q.close();`
- Call `super.notifyListeners()` (from `BaseRepository`) after every mutation so services/VMs refresh.
- Serialization is manual (`toJson`/`fromJson`) — do not add `json_serializable` annotations.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Querying without closing the `Query` object | Always call `q.close()` after `find()`/`findFirst()` |
| Editing `objectbox.g.dart` directly | Delete the edit; run `./scripts/build_runner.sh -d` |
| Forgetting `@Index()` on a frequently-queried field | Add annotation; re-run build_runner |
| `id` field not defaulting to `0` | ObjectBox requires `int id = 0` or `@Id() int id = 0` |
| Running `build_runner` without `-d` after field removal | Stale generated code causes build errors; use `-d` flag |
