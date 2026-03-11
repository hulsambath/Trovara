# Google Drive Service

> Handles Google authentication and Drive AppData backup/restore operations.

`GoogleDriveService` manages the full lifecycle of Google Sign-In and
provides low-level Drive API operations for uploading, downloading, and
managing files in the hidden AppData folder.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Files & Classes](#3-files--classes)
4. [Authentication](#4-authentication)
5. [Drive AppData Operations](#5-drive-appdata-operations)
6. [Trash Operations](#6-trash-operations)
7. [Persisted Auth State](#7-persisted-auth-state)
8. [Dependency Injection](#8-dependency-injection)
9. [Error Handling](#9-error-handling)

---

## 1. Overview

`GoogleDriveService` is the lowest-level service for interacting with
Google. Higher-level services (`GoogleDriveSyncService`,
`ChatDriveSyncService`) build on top of it to implement merge-based sync
workflows.

**Scopes requested:**

| Scope           | Purpose                              |
| --------------- | ------------------------------------ |
| `drive.appdata` | Read/write the hidden AppData folder |
| `email`         | Identify the user's email            |
| `profile`       | Display name and photo in the UI     |

---

## 2. Architecture

```
GoogleDriveSyncService / ChatDriveSyncService
            │
            ▼
    GoogleDriveService          ◄── this service
            │
            ├──► GoogleSignIn   (google_sign_in package)
            └──► DriveApi       (googleapis/drive/v3)
                    │
                    └──► AppData folder on Google Drive
```

---

## 3. Files & Classes

| File                                              | Purpose                             |
| ------------------------------------------------- | ----------------------------------- |
| `lib/core/services/google_drive_service.dart`     | Service implementation              |
| `lib/core/storage/google_drive_auth_storage.dart` | SharedPreferences wrappers for auth |
| `_GoogleAuthClient` (private, same file)          | HTTP client injecting auth headers  |

---

## 4. Authentication

### `initialize()`

Called once at app startup. If the user was previously signed in
(persisted via `GoogleDriveSignedInStorage`), attempts a silent
re-authentication. If silent sign-in fails, clears the persisted state.

### `signIn()`

```dart
Future<GoogleSignInAccount?> signIn()
```

1. Tries `signInSilently()` first.
2. Falls back to interactive `signIn()`.
3. On success, persists account metadata (email, id, displayName, photoUrl).
4. Initialises the Drive API client.

### `signOut()`

```dart
Future<void> signOut()
```

Disconnects the Google account and clears all persisted auth state.

### `isSignedIn` / `currentUser`

```dart
bool get isSignedIn          // true when GoogleSignIn has a currentUser
GoogleSignInAccount? get currentUser
```

`currentUser.id` is used as the user identifier (`userId`) on notes.

### `ensureAuthenticatedDriveApi()`

Ensures the Drive API client is available. If authentication has expired,
triggers a re-sign-in automatically. Called internally before every
Drive API operation.

---

## 5. Drive AppData Operations

All data is stored in Google Drive's **AppData** folder — a hidden,
app-specific folder invisible to the user in their Drive UI.

### `uploadJsonToAppData`

```dart
Future<void> uploadJsonToAppData({
  required String fileName,
  required Map<String, dynamic> json,
})
```

- Checks if a file with `fileName` already exists in AppData.
- If it exists → updates the file content.
- If not → creates a new file.
- Content is JSON-encoded to UTF-8.

### `downloadJsonFromAppData`

```dart
Future<Map<String, dynamic>?> downloadJsonFromAppData(String fileName)
```

- Searches for `fileName` in AppData.
- Returns `null` if the file doesn't exist.
- Downloads and JSON-decodes the content.

**Files used by the app:**

| File name                  | Service                  | Content             |
| -------------------------- | ------------------------ | ------------------- |
| `trovara_backup.json`      | `GoogleDriveSyncService` | Notes + folders     |
| `trovara_chat_backup.json` | `ChatDriveSyncService`   | Chat threads + msgs |

---

## 6. Trash Operations

These methods operate on individual Drive files by their `driveFileId`,
used by `NoteService` for note-level trash sync.

| Method                               | Drive API call                    | Returns        |
| ------------------------------------ | --------------------------------- | -------------- |
| `moveFileToTrash(driveFileId)`       | `files.update({trashed: true})`   | Updated `File` |
| `restoreFileFromTrash(driveFileId)`  | `files.update({trashed: false})`  | Updated `File` |
| `permanentlyDeleteFile(driveFileId)` | `files.delete(id)`                | `void`         |
| `isFileTrashed(driveFileId)`         | `files.get(id)` → check `trashed` | `bool?`        |

All methods call `ensureAuthenticatedDriveApi()` before making API calls
and throw on failure so callers can decide whether to proceed locally.

---

## 7. Persisted Auth State

Auth state is persisted in SharedPreferences so the app can silently
restore the session on next launch:

| Storage class                       | Type     | Purpose                |
| ----------------------------------- | -------- | ---------------------- |
| `GoogleDriveSignedInStorage`        | `bool`   | Was the user signed in |
| `GoogleDriveAccountEmailStorage`    | `String` | User's email           |
| `GoogleDriveAccountIdStorage`       | `String` | User's Google ID       |
| `GoogleDriveAccountNameStorage`     | `String` | Display name           |
| `GoogleDriveAccountPhotoUrlStorage` | `String` | Profile photo URL      |

---

## 8. Dependency Injection

```dart
GoogleDriveService get googleDriveService {
  _googleDriveService ??= GoogleDriveService();
  return _googleDriveService!;
}
```

Access via `ServiceLocator().googleDriveService`. The service is also
injected into `NoteService` as an optional dependency.

---

## 9. Error Handling

- `signIn()` rethrows exceptions so the UI can handle them.
- `signOut()` catches and logs errors (non-critical).
- `ensureAuthenticatedDriveApi()` retries once via `signIn()`.
- `isFileTrashed()` returns `null` on failure instead of throwing.
- All other Drive operations throw on failure.
