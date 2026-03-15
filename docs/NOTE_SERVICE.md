# Note Service

> Core service layer for note CRUD, soft-delete lifecycle, folder management,
> Google Drive trash synchronization, and data import/export.

`NoteService` is the primary business-logic coordinator for everything
note-related in Trovara. It sits between the UI (ViewModels) and the
persistence layer (repositories), enforcing invariants such as folder
counts, soft-delete rules, Drive sync ordering, and embedding generation.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Files & Classes](#3-files--classes)
4. [Dependencies](#4-dependencies)
5. [CRUD Operations](#5-crud-operations)
6. [Soft-Delete / Trash Lifecycle](#6-soft-delete--trash-lifecycle)
7. [Google Drive Trash Sync](#7-google-drive-trash-sync)
8. [User Ownership (Accountability)](#8-user-ownership-accountability)
9. [Import / Export / Merge](#9-import--export--merge)
10. [Read-Only Queries](#10-read-only-queries)
11. [Folder Management](#11-folder-management)
12. [Lifecycle & Listeners](#12-lifecycle--listeners)
13. [Dependency Injection](#13-dependency-injection)

---

## 1. Overview

`NoteService` is the single point of entry for any note operation in the
app. ViewModels never talk to repositories directly; they go through
`NoteService` which ensures:

- Folder note counts stay in sync with creates / deletes / restores.
- Embeddings are generated asynchronously after note creation or update.
- Google Drive trash operations follow a strict "Drive first, then local"
  ordering to keep Drive as the source of truth.
- Soft-deleted notes are purged after 30 days.
- Import/export handles upsert semantics and Storypad backup conversion.

---

## 2. Architecture

```
ViewModel
    │
    ▼
NoteService  ◄── business rules, coordination
    │
    ├──► INoteRepository      (ObjectBox persistence)
    ├──► IFolderRepository    (folder persistence)
    ├──► GoogleDriveService?  (Drive trash API)
    └──► EmbeddingService?    (RAG embedding generation)
```

**Design principles:**

| Principle             | How it's applied                                    |
| --------------------- | --------------------------------------------------- |
| Single Responsibility | Coordinates repos; doesn't do persistence itself    |
| Dependency Inversion  | Depends on `INoteRepository` / `IFolderRepository`  |
| Open/Closed           | New sync targets can be added without changing CRUD |

---

## 3. Files & Classes

| File                                                                 | Purpose                           |
| -------------------------------------------------------------------- | --------------------------------- |
| `lib/core/services/note_service.dart`                                | Service implementation (this doc) |
| `lib/core/repository/interfaces/note_repository.dart`                | Repository contract               |
| `lib/core/repository/implementations/objectbox_note_repository.dart` | ObjectBox implementation          |
| `lib/core/repository/interfaces/folder_repository.dart`              | Folder repository contract        |
| `lib/models/note.dart`                                               | Note entity (ObjectBox)           |
| `lib/models/folder.dart`                                             | Folder entity (ObjectBox)         |
| `lib/core/di/service_locator.dart`                                   | DI registration                   |

---

## 4. Dependencies

```dart
NoteService({
  required INoteRepository noteRepository,
  required IFolderRepository folderRepository,
  GoogleDriveService? driveService,   // optional – Drive trash sync
  EmbeddingService? embeddingService, // optional – RAG embeddings
})
```

All dependencies are injected through the constructor. `GoogleDriveService`
and `EmbeddingService` are optional so the service can function without
Drive or RAG features.

---

## 5. CRUD Operations

### `createNote`

```dart
Future<Note> createNote({
  String? title,
  String? contentJson,
  String? folderId,
  List<int> customTagIds,
  String? userId,
})
```

- Creates a note via the repository.
- Increments the parent folder's `noteCount`.
- Triggers async embedding generation (non-blocking).
- `userId` stamps note ownership; `null` means anonymous.

### `createNoteWithTimestamps`

Same as `createNote` but accepts explicit `createdAt`, `updatedAt`,
`isFavorite`, `isArchived`, `isDeleted`, and `deletedAt` for import
operations. Only increments folder count if the note is not deleted.

### `updateNote`

```dart
Future<void> updateNote(Note note)
```

- Persists the note.
- Re-embeds the note asynchronously.

---

## 6. Soft-Delete / Trash Lifecycle

Notes use a **soft-delete** pattern. Deleted notes remain in the database
with `isDeleted = true` and a `deletedAt` timestamp. They appear in the
"Recently Deleted" screen and are automatically purged after 30 days.

| Method                       | Behaviour                                                                                           |
| ---------------------------- | --------------------------------------------------------------------------------------------------- |
| `softDeleteNote(id)`         | Sets `isDeleted=true`, `deletedAt=now`. Decrements folder count.                                    |
| `restoreNoteFromTrash(id)`   | Sets `isDeleted=false`, clears `deletedAt`. Increments folder count.                                |
| `permanentDeleteNote(id)`    | Removes note from DB. Deletes associated embeddings. Adjusts folder count if note was still active. |
| `purgeExpiredDeletedNotes()` | Removes all soft-deleted notes older than 30 days. Called at app startup.                           |

---

## 7. Google Drive Trash Sync

When a user is signed in and a note has a `driveFileId`, trash operations
follow a **Drive-first** strategy:

1. Call Google Drive API (move to trash / restore / delete).
2. **Only if Drive succeeds** → update local DB.
3. If Drive fails → throw, leave local state unchanged.

| Method                                      | Drive action              | Then local action        |
| ------------------------------------------- | ------------------------- | ------------------------ |
| `softDeleteNoteWithDriveSync(id)`           | `moveFileToTrash()`       | `softDeleteNote(id)`     |
| `restoreNoteFromTrashWithDriveSync(id)`     | `restoreFileFromTrash()`  | `restoreNoteFromTrash()` |
| `permanentDeleteNoteWithDriveSync(id)`      | `permanentlyDeleteFile()` | `permanentDeleteNote()`  |
| `permanentlyDeleteNoteOnDrive(driveFileId)` | `permanentlyDeleteFile()` | _(none — Drive only)_    |

### `reconcileTrashStateWithDrive`

During sync, each note's Drive trash state is compared against local state.
Drive is the source of truth; conflicts are resolved by timestamp.

---

## 8. User Ownership (Accountability)

Every note has an optional `userId` field (the Google account `id`).

- **`null` userId** → anonymous note (created before sign-in).
- **Non-null userId** → note is owned by that Google account.

### Query scoping

User-scoped query methods return notes owned by the given `userId` **plus**
anonymous notes (`userId == null`). This ensures pre-sign-in notes are
always visible to the user who created them.

| Method                                      | Scope                                   |
| ------------------------------------------- | --------------------------------------- |
| `notes`                                     | All active notes (no user filter)       |
| `notesForUser(userId)`                      | Active notes for user + anonymous       |
| `deletedNotes`                              | All soft-deleted notes                  |
| `deletedNotesForUser(userId)`               | Deleted notes for user + anonymous      |
| `favoriteNotesForUser(userId)`              | Favorite notes for user + anonymous     |
| `archivedNotesForUser(userId)`              | Archived notes for user + anonymous     |
| `searchNotesForUser(userId, query)`         | Search scoped to user + anonymous       |
| `getNotesByFolderForUser(userId, folderId)` | Folder notes scoped to user + anonymous |

### Ownership assignment

- New notes are stamped with the current user's `id` at creation time.
- On first Google Drive sync, all anonymous notes are claimed by calling
  `GoogleDriveSyncService._assignUserIdToAnonymousNotes()`.

---

## 9. Import / Export / Merge

### `exportAllToJson()`

Exports all notes (active + soft-deleted) and folders to a JSON map. Each note
includes its stable `syncId` (UUID). The export also includes
`deletedSyncIds`: a list of syncIds for notes that were **permanently** deleted
(tombstones), so other devices/syncs know not to re-import them. Permanently
deleted note bodies are not in the DB and are excluded; only their syncIds are
exported.

### `importAllFromJson(json, {source, verbose})`

Performs an **upsert** import keyed by **syncId** (not integer `id`):

- **SyncId from JSON:** The raw `syncId` is read from each note object _before_
  building a `Note` (because `Note.fromJson` would otherwise assign a new UUID when
  `syncId` is null). If the JSON has no or empty `syncId` (legacy backup), a
  **deterministic** syncId is derived from `title + createdAt` so re-imports
  upsert correctly instead of creating duplicates.
- **Tombstones:** Incoming `deletedSyncIds` are merged into the local registry.
  Any note whose syncId is in that set is **skipped** (never re-imported).
- **Lookup:** Existing note is resolved by `getNoteBySync(syncId)` (stable UUID),
  not by integer id.
- **Update:** If a note with that syncId exists locally, its fields are updated
  only when the incoming `updatedAt` is newer (or when `source == 'google-drive-sync'`).
  Otherwise the local version is kept (local wins).
- **Create:** If no local note has that syncId, the note is created via
  `createNoteWithTimestamps(..., syncId: syncId)` so the same stable ID is
  preserved.
- Supports Storypad backup format detection and conversion.
- Re-embeds stale notes after import.

### `mergeWithRemoteData(remoteData)`

Git-like three-way merge between local and remote data:

- **Notes** are keyed by **syncId**. If a note has no syncId (legacy), a
  deterministic syncId from `title + createdAt` is used so merge keys are stable.
- **Folders** are keyed by `folderId`.
- Conflicts are resolved by `updatedAt` (latest wins). Trash state conflicts
  use `deletedAt` (and restoration vs deletion) so the most recent action wins.

---

## 10. Read-Only Queries

These delegate directly to the repository:

| Getter / Method              | Returns                         |
| ---------------------------- | ------------------------------- |
| `notes`                      | All active notes                |
| `deletedNotes`               | All soft-deleted notes          |
| `favoriteNotes`              | Active favorites                |
| `archivedNotes`              | Active archived notes           |
| `allTags`                    | All unique tags                 |
| `totalNotes`                 | Count of active notes           |
| `totalWords`                 | Sum of word counts              |
| `totalCharacters`            | Sum of character counts         |
| `getNote(id)`                | Single note by ID               |
| `searchNotes(query)`         | Text search across active notes |
| `getNotesByFolder(folderId)` | Notes in a folder               |
| `getNotesByTag(tag)`         | Notes with a specific tag       |

---

## 11. Folder Management

| Method                            | Behaviour                                                       |
| --------------------------------- | --------------------------------------------------------------- |
| `createFolder(...)`               | Creates a new folder.                                           |
| `createFolderWithTimestamps(...)` | Creates a folder with preserved dates (import).                 |
| `updateFolder(folder)`            | Persists folder changes.                                        |
| `deleteFolder(folderId)`          | Moves all notes to the default folder, then deletes the folder. |
| `folders`                         | All folders.                                                    |
| `getFolder(folderId)`             | Single folder by ID.                                            |
| `defaultFolder`                   | The default folder.                                             |

---

## 12. Lifecycle & Listeners

```dart
void addListener(Function() listener)    // registers on both repos
void removeListener(Function() listener)
void dispose()                           // disposes both repos
```

ViewModels register listeners to refresh the UI when the underlying data
changes (e.g. after sync or background import).

---

## 13. Dependency Injection

Registered in `ServiceLocator`:

```dart
NoteService get noteService {
  _noteService ??= NoteService(
    noteRepository: noteRepository,
    folderRepository: folderRepository,
    driveService: googleDriveService,
    embeddingService: embeddingService,
  );
  return _noteService!;
}
```

Access anywhere via `ServiceLocator().noteService`.
