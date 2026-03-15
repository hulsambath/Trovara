# Mock Data Service

> Utility service for seeding the local database with mock notes for
> development and testing.

`MockDataService` generates timestamped mock notes distributed across
specified years and months. It is intended for **development only** and
should not be used in production builds.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Files & Classes](#2-files--classes)
3. [Public API](#3-public-api)
4. [Seeding Behaviour](#4-seeding-behaviour)

---

## 1. Overview

When developing features that depend on having a populated note database
(analytics charts, search, RAG testing), `MockDataService` can quickly
fill the database with realistic-looking entries spread over time.

---

## 2. Files & Classes

| File                                       | Purpose                |
| ------------------------------------------ | ---------------------- |
| `lib/core/services/mock_data_service.dart` | Service implementation |

Uses `ServiceLocator().noteService` and `ServiceLocator().noteRepository`
internally.

---

## 3. Public API

### `seedNotesForYears`

```dart
Future<void> seedNotesForYears({
  List<int> years = const [2024, 2025],
  int notesPerMonth = 6,
  bool skipIfNotEmpty = false,
  bool patchIfExists = true,
})
```

| Parameter        | Default        | Description                                                               |
| ---------------- | -------------- | ------------------------------------------------------------------------- |
| `years`          | `[2024, 2025]` | Years to generate notes for                                               |
| `notesPerMonth`  | `6`            | Number of notes per month per year                                        |
| `skipIfNotEmpty` | `false`        | If `true`, skips seeding when the DB already has data                     |
| `patchIfExists`  | `true`         | If `true`, updates existing notes matching the same `createdAt` timestamp |

---

## 4. Seeding Behaviour

1. Builds a lookup map of existing notes keyed by `createdAt` timestamp.
2. For each year → each month → generates `notesPerMonth` notes:
   - Random day within the month, random hour/minute.
   - Title: `Mock Note YYYY-MM-DD #N`.
   - Content: simple Quill JSON with a single line.
   - Folder: `default`.
3. If a note with the same `createdAt` already exists and `patchIfExists`
   is true, the existing note is updated (title, content, `updatedAt`).
4. Otherwise a new note is created via `NoteService.createNoteWithTimestamps`.

Uses a fixed random seed (`Random(42)`) for deterministic output.

**Example:** 2 years × 12 months × 6 notes = 144 notes.
