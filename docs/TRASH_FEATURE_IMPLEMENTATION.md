# NoteMyMinds Trash/Recently Deleted Feature Implementation

## Overview

This document describes the complete implementation of the "Recently Deleted" / Trash feature for NoteMyMinds, which mirrors Google Drive Trash behavior. The feature ensures that:

- **Google Drive is always the source of truth**
- Notes are soft-deleted (moved to trash), not immediately removed
- Soft-deleted notes can be restored or permanently deleted
- External Drive changes are synchronized
- Trash state is reconciled during sync operations

## Architecture

### Core Components

#### 1. **Data Model**

- **File**: `lib/models/note.dart`
- **Key Fields**:
  - `isDeleted` (bool): Marks note as soft-deleted
  - `deletedAt` (DateTime?): Timestamp of soft deletion
  - `driveFileId` (String?): Google Drive file ID for Drive sync operations

#### 2. **Google Drive API Integration**

- **File**: `lib/core/services/google_drive_service.dart`
- **New Methods**:
  - `moveFileToTrash(String driveFileId)`: Move file to trash on Drive
  - `restoreFileFromTrash(String driveFileId)`: Restore file from trash on Drive
  - `permanentlyDeleteFile(String driveFileId)`: Permanently delete file from Drive
  - `isFileTrashed(String driveFileId)`: Check if file is trashed on Drive

#### 3. **Note Service Layer**

- **File**: `lib/core/services/note_service.dart`
- **Key Methods**:
  - `softDeleteNoteWithDriveSync(int noteId)`: Move note to trash with Drive sync
  - `restoreNoteFromTrashWithDriveSync(int noteId)`: Restore note from trash with Drive sync
  - `permanentDeleteNoteWithDriveSync(int noteId)`: Permanently delete with Drive sync
  - `reconcileTrashStateWithDrive(Map driveNoteJson)`: Reconcile trash state during sync

#### 4. **UI Components**

- **Recently Deleted View**: `lib/views/notes/deleted_notes_view.dart`
  - Lists all soft-deleted notes
  - Shows "Deleted X time ago" indicator
  - Swipe to restore (left) or delete forever (right)
  - Confirmation dialog for permanent deletion

- **Notes View**: `lib/views/notes/notes_content.dart`
  - "Recently Deleted" button in app bar
  - "Move to Bin" option in note context menu

- **Note Card**: `lib/views/notes/widgets/note_card.dart`
  - Displays "Deleted X time ago" for deleted notes
  - Helper method for relative time formatting

#### 5. **Sync Integration**

- **File**: `lib/core/services/google_drive_sync_service.dart`
- **New Method**: `_reconcileTrashState(Map mergedData)`
  - Ensures Drive trash state is reflected locally after sync
  - Drive state always overrides local state

## Operation Flow

### 1. Move Note to Bin

```
User taps "Delete" on note
  ↓
_deleteNote() in NotesViewModel
  ↓
Check if note has driveFileId and user is signed in
  ├─ YES: softDeleteNoteWithDriveSync()
  └─ NO: softDeleteNote() (local only)
  ↓
[With Drive Sync]:
  1. Call Drive API: PATCH /drive/v3/files/{fileId} { trashed: true }
  2. IF success:
     - Update local DB: isDeleted=true, deletedAt=now()
     - Decrement folder note count
  3. IF failure:
     - Do NOT update local DB
     - Throw error to UI
  ↓
Show snackbar: "Note moved to Recently Deleted"
Remove note from active list
```

**CRITICAL**: Google Drive operation MUST succeed before updating local DB.

### 2. Recently Deleted Screen

```
User taps trash icon in Notes view
  ↓
Navigate to DeletedNotesView
  ↓
DeletedNotesViewModel:
  1. Purge expired notes (older than 30 days)
  2. Load all deleted notes
  3. Sort by deletedAt DESC
  4. Show list with relative times
  ↓
User interactions:
  - Swipe LEFT: Restore note
  - Swipe RIGHT: Delete forever (with confirmation)
```

### 3. Restore from Trash

```
User swipes left on deleted note
  ↓
restoreNote() in DeletedNotesViewModel
  ↓
Check if note has driveFileId and user is signed in
  ├─ YES: restoreNoteFromTrashWithDriveSync()
  └─ NO: restoreNoteFromTrash() (local only)
  ↓
[With Drive Sync]:
  1. Call Drive API: PATCH /drive/v3/files/{fileId} { trashed: false }
  2. IF success:
     - Update local DB: isDeleted=false, deletedAt=null
     - Increment folder note count
  3. IF failure:
     - Do NOT update local DB
     - Throw error to UI
  ↓
Show snackbar: "Note restored"
Remove from deleted list
Reappear in active notes
```

### 4. Permanent Delete

```
User swipes right on deleted note
  ↓
Show confirmation dialog
  ↓
User confirms "Delete Forever"
  ↓
deleteNoteForever() in DeletedNotesViewModel
  ↓
Check if note has driveFileId and user is signed in
  ├─ YES: permanentDeleteNoteWithDriveSync()
  └─ NO: permanentDeleteNote() (local only)
  ↓
[With Drive Sync]:
  1. Call Drive API: DELETE /drive/v3/files/{fileId}
  2. IF success:
     - Delete note from local DB
  3. IF failure:
     - Do NOT delete from local DB
     - Throw error to UI
  ↓
Show snackbar: "Note permanently deleted"
Remove from recently deleted list
```

**WARNING**: This action is IRREVERSIBLE. The note is completely removed.

### 5. Sync Trash Reconciliation

During `syncWithGoogleDrive()`:

```
1. Download backup from Drive
2. Merge local and remote data
3. Import merged data locally
4. [NEW] Reconcile trash state:
   - For each note in merged data:
     - If Drive says isDeleted=true and local=false:
       → Mark as deleted locally
     - If Drive says isDeleted=false and local=true:
       → Restore locally
     - Update driveFileId if present
5. Upload merged data back to Drive
6. Return sync result
```

**Principle**: Drive is always the source of truth for trash state.

## Key Implementation Details

### 1. Google Drive Scope

The GoogleDriveService uses:

- `driveAppdataScope`: For AppData backup/restore
- The same authenticated client handles trash operations

### 2. Error Handling

All Drive operations include:

- Try-catch blocks
- Logging with Logger
- Rethrow on failure to prevent local updates
- User-friendly error messages in UI

### 3. Transaction Safety

The critical pattern for all Drive operations:

```dart
// Step 1: Remote operation FIRST
try {
  await driveService.moveFileToTrash(driveFileId);
} catch (e) {
  // If remote fails, don't update locally
  rethrow;
}

// Step 2: Local update ONLY after remote succeeds
await noteService.softDeleteNote(noteId);
```

### 4. Dependency Injection

- `GoogleDriveService` injected into `NoteService`
- `GoogleDriveService` and `NoteService` injected into ViewModels
- All through `ServiceLocator` singleton

### 5. Auto-Purging

- Called at app startup: `NoteService.initialize()`
- Called when opening Recently Deleted view
- Deletes notes trashed > 30 days ago
- Can be configured with `maxAge` parameter

## UI Elements

### 1. Recently Deleted Button

- Location: Notes view app bar
- Icon: `Icons.delete_outline`
- Tooltip: "Recently Deleted"
- Action: Navigate to DeletedNotesView

### 2. Deleted Notes List

- Grid: ListView with dismissible items
- Each item shows:
  - Note title
  - Note content preview
  - Tags (if present)
  - **"Deleted X time ago"** indicator
  - Created/Updated dates

### 3. Swipe Actions

- **Left swipe (green)**: Restore
  - Icon: `Icons.restore`
  - Action: Call `restoreNote()`

- **Right swipe (red)**: Delete Forever
  - Icon: `Icons.delete_forever`
  - Action: Show confirmation dialog → `deleteNoteForever()`

### 4. Context Menu (Notes View)

- "Delete" option (red text)
- Confirmation dialog before soft delete
- Shows "Move to Bin" message in snackbar

## Testing Checklist

### Local Operations

- [ ] Move note to bin (local only, no Drive)
- [ ] Restore from bin (local only)
- [ ] Delete forever (local only)
- [ ] Recently Deleted screen shows notes
- [ ] Swipe gestures work correctly
- [ ] Relative time display works

### Google Drive Sync Operations

- [ ] Move note to bin (signed in, has driveFileId)
  - [ ] Verify Drive file is trashed
  - [ ] Verify local DB updated
  - [ ] Verify fails gracefully if Drive error

- [ ] Restore from bin (signed in)
  - [ ] Verify Drive file is un-trashed
  - [ ] Verify local DB updated
  - [ ] Verify fails gracefully if Drive error

- [ ] Delete forever (signed in)
  - [ ] Verify Drive file is permanently deleted
  - [ ] Verify local DB deleted
  - [ ] Verify fails gracefully if Drive error

### Sync Reconciliation

- [ ] Delete note on Drive externally
  - [ ] Sync → local note is deleted

- [ ] Restore note on Drive externally
  - [ ] Sync → local note is restored

- [ ] Move note to Drive trash externally
  - [ ] Sync → local note is marked deleted

- [ ] Merge conflicts handled correctly
  - [ ] Drive state overrides local

### Edge Cases

- [ ] No network connection
  - [ ] Soft delete fails with error
  - [ ] Local-only delete still works

- [ ] Not signed in
  - [ ] Soft delete uses local-only method
  - [ ] No Drive operations attempted

- [ ] Note without driveFileId
  - [ ] Uses local-only methods
  - [ ] No Drive API calls made

- [ ] 30+ day old notes
  - [ ] Auto-purged on app start
  - [ ] Auto-purged on Recently Deleted view open
  - [ ] Removed from Recently Deleted list

## Files Modified

### New Methods Added

1. **lib/core/services/google_drive_service.dart**
   - `moveFileToTrash()`
   - `restoreFileFromTrash()`
   - `permanentlyDeleteFile()`
   - `isFileTrashed()`

2. **lib/core/services/note_service.dart**
   - `softDeleteNoteWithDriveSync()`
   - `restoreNoteFromTrashWithDriveSync()`
   - `permanentDeleteNoteWithDriveSync()`
   - `reconcileTrashStateWithDrive()`

3. **lib/core/services/google_drive_sync_service.dart**
   - `_reconcileTrashState()`

### Modified Files

1. **lib/models/note.dart**
   - Added `driveFileId` field
   - Updated constructor, toJson, fromJson

2. **lib/views/notes/notes_content.dart**
   - Added "Recently Deleted" button to app bar
   - Added `_openRecentlyDeleted()` method

3. **lib/views/notes/notes_view_model.dart**
   - Updated `_deleteNote()` to use Drive-integrated method
   - Added error handling for Drive operations

4. **lib/views/notes/deleted_notes_view_model.dart**
   - Updated `restoreNote()` to use Drive-integrated method
   - Updated `deleteNoteForever()` to use Drive-integrated method
   - Added error handling

5. **lib/views/notes/widgets/note_card.dart**
   - Added "Deleted X time ago" display for deleted notes
   - Added `_getTimeAgoString()` helper method

6. **lib/core/di/service_locator.dart**
   - Updated NoteService instantiation to include GoogleDriveService

### Existing Views (No Changes Needed)

- `lib/views/notes/deleted_notes_view.dart`
- `lib/views/notes/deleted_notes_view_content.dart`

## Security Considerations

1. **Never delete locally before Drive succeeds**
   - Prevents data loss if Drive operation fails
   - User can retry operation

2. **Permanent delete is irreversible**
   - Requires confirmation dialog
   - Immediately removes from all locations

3. **Drive authentication required for sync**
   - Checks `_driveService.isSignedIn` before operations
   - Falls back to local-only if not signed in

4. **No credentials exposed**
   - Uses GoogleSignIn auth headers
   - Credentials never hardcoded or logged

## Performance Considerations

1. **Lazy reconciliation**
   - Trash reconciliation happens during sync only
   - Doesn't impact local operations
   - Can fail gracefully without breaking sync

2. **Efficient queries**
   - `getDeletedNotes()` returns pre-filtered results
   - Sorting by `deletedAt` DESC happens once
   - No repeated queries during rendering

3. **Minimal network calls**
   - One PATCH call to move/restore
   - One DELETE call to permanently remove
   - No unnecessary list operations

## Future Enhancements

1. **Batch operations**
   - Select multiple notes
   - Restore/delete all at once
   - Reduces network round-trips

2. **Trash search**
   - Search within deleted notes
   - Filter by deletion date range

3. **Notifications**
   - Remind user of notes expiring soon
   - Confirm permanent deletion in advance

4. **Restore preview**
   - Show full note before confirming restore
   - Preview which folder note will restore to

## References

- [Google Drive API - Files: update](https://developers.google.com/drive/api/v3/reference/files/update)
- [Google Drive API - Files: delete](https://developers.google.com/drive/api/v3/reference/files/delete)
- [Google Drive API - Trash behavior](https://support.google.com/drive/answer/2375686)
