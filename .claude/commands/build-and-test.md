---
description: Run flutter analyze + flutter test patrol_test and report a clean summary
---

# Build & Test

Run the project's quality gates and report a concise summary.

## Steps

Run these two commands **in parallel** (they're independent):

1. `flutter analyze`
2. `flutter test patrol_test`

## Report format

After both finish, output a summary like this — nothing else, no preamble:

```
flutter analyze       │ ✅ no issues
flutter test patrol_test │ ✅ 194 tests passed (12.3s)
```

Or, on failure:

```
flutter analyze       │ ❌ 3 errors, 1 warning
  • lib/views/notes/notes_view_model.dart:42:8 — Undefined name 'foo'
  • lib/core/services/ai/rag_service.dart:101:15 — The argument type 'String' can't be assigned to 'int'
  • lib/views/chat/chat_content.dart:88:3 — Missing required parameter 'onTap'

flutter test patrol_test │ ❌ 2 of 194 failed
  • patrol_test/core/services/rag_service_test.dart: "queries return chunks" — Expected: 5  Actual: 4
  • patrol_test/core/import/converters/markdown_to_quill_test.dart: "headings" — RangeError
```

## Behavior

- If `flutter analyze` reports only `info` lints (not `warning` or `error`), still mark ✅ but note the count: `✅ no errors (4 info)`.
- Do NOT attempt to fix failures unless the user asks — this command is read-only reporting.
- Do NOT run `flutter pub get` first; assume deps are current. If pub.yaml is out of date the analyzer will say so.
