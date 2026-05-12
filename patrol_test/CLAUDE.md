# patrol_test/ — Working Rules

**Authoritative spec:** `docs/PATROL_UNIT_TESTING.md`.

## What lives here

Logic-only tests for `lib/core/` (services, repositories, import adapters, converters). They run on the host VM with `flutter test patrol_test` — **no emulator required**.

## Hard rules

1. **Always import the local `test_support.dart`** — it provides the `patrolTest` wrapper and helper functions:
   ```dart
   import 'package:flutter_test/flutter_test.dart';
   import '../../test_support.dart';

   void main() {
     patrolTest('description', ($) async {
       expect(1, 1);
     });
   }
   ```
2. **Use `patrolTest` (the local wrapper), not `patrolWidgetTest` directly.** The wrapper sets up Patrol bindings correctly for logic tests.
3. **Do NOT use `patrolTest` from `package:patrol`** — that one requires the Patrol CLI and an emulator.
4. **No real network calls.** Stub `LlmClient` / `EmbeddingService` via fakes (see `patrol_test/core/services/rag_service_test.dart` for the pattern).
5. **No real ObjectBox store.** Tests use repository fakes implementing the `I*Repository` interface — this is why those interfaces exist.

## Folder mirrors lib/core/

```
patrol_test/core/
├── import/
│   ├── adapters/         ← mirrors lib/core/import/adapters/
│   └── converters/
└── services/             ← mirrors lib/core/services/
```

When you add a service or adapter under `lib/core/`, add a mirroring test file under `patrol_test/core/`.

## Integration vs logic vs widget

| Directory | Runner | Needs emulator? | Use for |
|---|---|---|---|
| `test/` | `flutter test test/` | No | Plain widget/unit tests |
| `patrol_test/` | `flutter test patrol_test` | No | Logic tests with `patrol_finders` |
| `integration_test/` | `./scripts/patrol_test.sh` | **Yes** | E2E flows via Patrol CLI |

## DRY in tests

- Shared fixtures (markdown samples, mock notes) belong in `patrol_test/core/test_support.dart` or a new `*_fixtures.dart` next to the test file.
- Don't copy-paste mock implementations across test files — extract a fake into the shared support file.

## Re-generating the test bundle

`patrol_test/test_bundle.dart` is **generated** by the Patrol CLI. Don't edit it by hand.
