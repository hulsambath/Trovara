# Trash Feature - Quick Integration Guide

## For Developers

### Understanding the Critical Pattern

The entire trash feature follows one critical principle:

**Google Drive = Source of Truth**

This means:

1. Call Drive API FIRST
2. Only update local DB if Drive succeeds
3. Throw exception if Drive fails
4. Never update local without Drive confirmation

### Code Flow Examples

#### Moving a Note to Trash

```dart
// This is what happens:
await noteService.softDeleteNoteWithDriveSync(noteId);

// Under the hood:
// 1. Check if note has driveFileId and user is signed in
// 2. Call Drive API: PATCH /drive/v3/files/{fileId} { trashed: true }
// 3. IF success: Update local DB
// 4. IF failure: Throw error (DB NOT updated)
```

#### Restoring from Trash

```dart
await noteService.restoreNoteFromTrashWithDriveSync(noteId);

// Same pattern:
// 1. Call Drive API: PATCH /drive/v3/files/{fileId} { trashed: false }
// 2. Only update local if Drive succeeds
```

#### Permanent Delete

```dart
await noteService.permanentDeleteNoteWithDriveSync(noteId);

// Same pattern:
// 1. Call Drive API: DELETE /drive/v3/files/{fileId}
// 2. Only delete locally if Drive succeeds
// 3. This is IRREVERSIBLE
```

### Using the Feature Programmatically

#### Check if Note is Deleted

```dart
final note = noteService.getNote(noteId);
if (note?.isDeleted ?? false) {
  print('Note is in trash');
  print('Deleted: ${note!.deletedAt}');
}
```

#### Get All Deleted Notes

```dart
final deletedNotes = noteService.deletedNotes;
for (final note in deletedNotes) {
  print('${note.title} - deleted ${note.deletedAt}');
}
```

#### Query Specific Conditions

```dart
// Notes deleted today
final today = DateTime.now();
final deletedToday = deletedNotes.where(
  (note) => note.deletedAt?.day == today.day &&
            note.deletedAt?.month == today.month &&
            note.deletedAt?.year == today.year
).toList();

// Notes approaching 30-day limit
final almostExpired = deletedNotes.where((note) {
  if (note.deletedAt == null) return false;
  final daysOld = DateTime.now().difference(note.deletedAt!).inDays;
  return daysOld >= 27; // Within 3 days of expiration
}).toList();
```

## For UI/UX Designers

### User Flows

#### 1. Delete a Note

```
User long-presses note
  ↓
Bottom sheet appears with options
  ├─ "Edit"
  ├─ "Add/Remove from favorites"
  └─ "Delete" (red)
  ↓
User taps "Delete"
  ↓
Confirmation dialog
  "Are you sure you want to delete [title]?"
  ├─ Cancel
  └─ Delete (red)
  ↓
Note disappears from list
  ↓
Snackbar: "Note moved to Recently Deleted.
          It will be permanently removed after 30 days."
```

#### 2. View Recently Deleted

```
User taps trash icon (app bar)
  ↓
Recently Deleted screen opens
  ↓
List of all deleted notes with:
  - Note title
  - Content preview
  - Tags
  - "Deleted X time ago"
  ↓
User can:
  - Swipe left: Restore
  - Swipe right: Delete forever
  - Tap note: View (read-only)
```

#### 3. Restore a Note

```
User swipes left on deleted note
  ↓
Green background with restore icon
  ↓
User releases gesture
  ↓
Note is restored
  ↓
Snackbar: "Note restored"
  ↓
Note reappears in active notes
  ↓
Recently Deleted list updated
```

#### 4. Permanently Delete a Note

```
User swipes right on deleted note
  ↓
Red background with delete_forever icon
  ↓
Confirmation dialog (appears before release)
  "This note will be permanently removed
   and cannot be recovered. Continue?"
  ├─ Cancel (swipe cancelled)
  └─ Delete Forever (red)
  ↓
Note is deleted from Drive and locally
  ↓
Snackbar: "Note permanently deleted"
  ↓
Note removed from Recently Deleted list
```

### Information Display

#### Recently Deleted Screen Header

```
Icon: delete_outline
Title: "Recently Deleted"

Info box:
"Notes you delete appear here and are kept for 30 days
before being removed forever. Items older than 30 days
may already have been removed and are no longer recoverable."

Divider
```

#### Note Card in Recently Deleted

```
┌─────────────────────────────────┐
│ [Title]                    [❤]  │
├─────────────────────────────────┤
│ [Content preview...]            │
├─────────────────────────────────┤
│ [Tags if present]               │
├─────────────────────────────────┤
│ ⏱️ Deleted: 2 days ago            │
└─────────────────────────────────┘

Swipe LEFT (green):  ↩️ Restore
Swipe RIGHT (red):  🗑️ Delete Forever
```

#### Active Note Card (Normal View)

```
┌─────────────────────────────────┐
│ [Title]                    [❤]  │
├─────────────────────────────────┤
│ [Content preview...]            │
├─────────────────────────────────┤
│ [Tags if present]               │
├─────────────────────────────────┤
│ ⏱️ Created: 15/2/2025 • Updated: 10/2/2025 │
└─────────────────────────────────┘
```

## For QA/Testing

### Test Scenarios

#### Scenario 1: Local Delete (No Sign-in)

1. **Setup**: User NOT signed in to Google Drive
2. **Action**: Delete a note
3. **Expected**:
   - Note moves to Recently Deleted
   - No Drive API calls made
   - Note visible in Recently Deleted view
   - Can restore locally
4. **Verification**: Check app logs for "Drive-integrated" methods not called

#### Scenario 2: Drive Delete (Signed In)

1. **Setup**: User signed in, note has driveFileId
2. **Action**: Delete a note
3. **Expected**:
   - Call Drive API to move to trash
   - Local DB updated only after Drive succeeds
   - Note appears in Recently Deleted
   - Drive file has `trashed: true`
4. **Verification**:
   - Check Drive web UI
   - Verify Drive file in trash
   - Verify local deletedAt timestamp

#### Scenario 3: Restore from Bin

1. **Setup**: Note in Recently Deleted (trashed on Drive)
2. **Action**: Swipe left to restore
3. **Expected**:
   - Drive file un-trashed
   - Local DB updated
   - Note reappears in active list
   - Recently Deleted list updated
4. **Verification**:
   - Check Drive web UI (file no longer trashed)
   - Verify note in active notes

#### Scenario 4: Permanent Delete

1. **Setup**: Note in Recently Deleted
2. **Action**: Swipe right + confirm delete
3. **Expected**:
   - Confirmation dialog shown
   - Drive file permanently deleted
   - Local DB deleted
   - Note completely removed
4. **Verification**:
   - Check Drive web UI (file not in trash, not anywhere)
   - Verify note not in any lists
   - Verify can't restore

#### Scenario 5: Sync Reconciliation

1. **Setup**:
   - Note locally active
   - Same note moved to trash on Drive (externally)
2. **Action**: Sync with Google Drive
3. **Expected**:
   - Local note marked as deleted
   - Recently Deleted list reflects it
4. **Verification**:
   - Before sync: Note in active list
   - After sync: Note in Recently Deleted

#### Scenario 6: Auto-Purge

1. **Setup**: Note deleted 35 days ago
2. **Action**: Open Recently Deleted view
3. **Expected**:
   - Note purged before showing list
   - Note not visible
   - App logs show purge action
4. **Verification**:
   - Note completely gone
   - Can't search for it

### Error Scenarios

#### Scenario 7: Drive Operation Fails (No Network)

1. **Setup**: User signed in, network connection lost
2. **Action**: Try to delete note
3. **Expected**:
   - Drive API call fails
   - Local DB NOT updated
   - Error snackbar shown: "Failed to delete note"
   - Note still in active list
4. **Verification**:
   - Note not moved
   - No local side effects
   - Can retry

#### Scenario 8: Drive Operation Fails (Permission)

1. **Setup**: User's Drive access revoked
2. **Action**: Try to delete note with driveFileId
3. **Expected**:
   - Drive API returns 403 Forbidden
   - Local DB NOT updated
   - Error message: "Access denied. Please check your Google Drive permissions."
4. **Verification**:
   - Prompt user to re-sign in

### Performance Tests

#### Test 1: Bulk Operations

1. Create 100 notes
2. Delete 50 of them
3. Verify Recently Deleted loads in < 2 seconds
4. Verify list scrolls smoothly

#### Test 2: Long-Running Sync

1. Set up 1000 notes (mixed active/deleted)
2. Perform sync
3. Verify reconciliation completes in < 30 seconds
4. Verify no UI freezing

#### Test 3: Memory Usage

1. Open Recently Deleted with 500 deleted notes
2. Monitor memory usage
3. Verify < 100MB increase
4. Verify smooth scrolling

## Troubleshooting

### Issue: Note Not Deleted

**Possible Causes**:

- Network connection lost
- Drive API temporarily unavailable
- User not signed in to Drive
- Note doesn't have driveFileId (shouldn't happen)

**Solution**:

- Check internet connection
- Verify user is signed in
- Retry operation
- Check app logs for specific error

### Issue: Note Appears in Both Lists

**Possible Causes**:

- Sync failed midway
- Local DB not updated after Drive operation
- Bug in query logic

**Solution**:

- Perform sync to reconcile
- Restart app
- Check app logs

### Issue: Can't Restore Deleted Note

**Possible Causes**:

- Note expired (30+ days old, auto-purged)
- Drive file no longer exists
- Network error during restore

**Solution**:

- Verify note deletion date
- Check Drive trash
- Retry with network connection

### Issue: Permanent Delete Failed

**Possible Causes**:

- Drive file already deleted
- Drive API error
- Network timeout

**Solution**:

- Check Drive to verify state
- Retry operation
- Check app logs

## API Reference for Integration

### NoteService Methods

#### softDeleteNoteWithDriveSync(int noteId)

Soft delete with Google Drive sync.

**Parameters**: `noteId` - ID of note to delete

**Returns**: `Future<void>`

**Throws**:

- Exception if Drive operation fails
- Note is NOT updated locally if exception thrown

**Usage**:

```dart
try {
  await noteService.softDeleteNoteWithDriveSync(noteId);
  // Note is now deleted
} catch (e) {
  print('Delete failed: $e');
  // Note was NOT deleted
}
```

#### restoreNoteFromTrashWithDriveSync(int noteId)

Restore from trash with Google Drive sync.

**Parameters**: `noteId` - ID of note to restore

**Returns**: `Future<void>`

**Throws**: Exception if Drive operation fails

#### permanentDeleteNoteWithDriveSync(int noteId)

Permanently delete with Google Drive sync.

**Parameters**: `noteId` - ID of note to permanently delete

**Returns**: `Future<void>`

**Throws**: Exception if Drive operation fails

**WARNING**: This is irreversible!

#### reconcileTrashStateWithDrive(Map driveNoteJson)

Reconcile trash state during sync.

**Parameters**: `driveNoteJson` - Note data from Drive

**Returns**: `Future<void>`

**Usage**: Called automatically during sync

### Properties

#### noteService.deletedNotes

Get all soft-deleted notes.

**Returns**: `List<Note>`

**Usage**:

```dart
final deleted = noteService.deletedNotes;
for (final note in deleted) {
  print('${note.title} - deleted ${note.deletedAt}');
}
```
