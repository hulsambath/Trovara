# notemyminds Sync Strategy Documentation

## Overview

notemyminds implements a Git-like sync strategy that ensures data integrity across multiple devices while automatically resolving conflicts. The sync process follows a **Pull → Merge → Push** workflow similar to version control systems.

## Sync Workflow

```
1. Pull from Drive    → Download current data from Google Drive
2. Merge with Local   → Intelligently merge local and remote data
3. Push to Drive      → Upload the merged result back to Google Drive
```

## Merge Strategy

### Conflict Resolution Rules

#### For Folders:

- **Key**: `folderId` (unique identifier)
- **Resolution**: Latest `updatedAt` timestamp wins
- **Behavior**:
  - If only exists locally → keep local
  - If only exists remotely → add remote
  - If exists in both → use the one with latest `updatedAt`

#### For Notes:

- **Key**: `title + createdAt` (combination for uniqueness)
- **Resolution**: Latest `updatedAt` timestamp wins
- **Behavior**:
  - If only exists locally → keep local
  - If only exists remotely → add remote
  - If exists in both → use the one with latest `updatedAt`
  - If same timestamp → prefer local (user's current state)

## Sync Scenarios

### Scenario 1: First-Time Sync

**When**: User syncs for the first time with no existing data in Google Drive

**Process**:

1. Pull from Drive → No data found
2. Merge → Use local data as base
3. Push to Drive → Upload local data

**Result**: Local data is backed up to Google Drive

**User Message**: "Synced with Google Drive (data backed up to cloud)"

---

### Scenario 2: Local Changes Only

**When**: User has made changes locally, but no changes exist in Google Drive

**Process**:

1. Pull from Drive → Get existing remote data
2. Merge → Local changes are newer (higher `updatedAt`)
3. Push to Drive → Upload merged data with local changes

**Result**: Local changes are preserved and uploaded to Drive

**User Message**: "Synced with Google Drive (data merged and synchronized)"

---

### Scenario 3: Remote Changes Only

**When**: Another device has made changes, but local device has no changes

**Process**:

1. Pull from Drive → Get newer remote data
2. Merge → Remote changes are newer (higher `updatedAt`)
3. Push to Drive → Upload merged data (same as remote)

**Result**: Remote changes are applied locally and preserved in Drive

**User Message**: "Synced with Google Drive (data merged and synchronized)"

---

### Scenario 4: Conflicting Changes

**When**: Both local and remote devices have made changes to the same items

**Process**:

1. Pull from Drive → Get remote changes
2. Merge → Compare `updatedAt` timestamps for each item
   - Item A: Local `updatedAt` = 2:00 PM, Remote `updatedAt` = 3:00 PM → Use Remote
   - Item B: Local `updatedAt` = 4:00 PM, Remote `updatedAt` = 1:00 PM → Use Local
3. Push to Drive → Upload merged result

**Result**: All changes are preserved based on timestamps

**User Message**: "Synced with Google Drive (data merged and synchronized)"

---

### Scenario 5: New Items on Both Sides

**When**: Local device has new notes, remote device has different new notes

**Process**:

1. Pull from Drive → Get remote data with new notes
2. Merge → Combine all unique items
   - Local new note: "Meeting Notes" → Add to merged result
   - Remote new note: "Shopping List" → Add to merged result
3. Push to Drive → Upload combined data

**Result**: All new items from both sources are preserved

**User Message**: "Synced with Google Drive (data merged and synchronized)"

---

### Scenario 6: Deleted Items

**When**: Items are deleted on one device but still exist on another

**Process**:

1. Pull from Drive → Get current remote state
2. Merge → Handle deletions based on timestamps
   - If item was deleted locally after remote update → Keep remote version
   - If item was deleted remotely after local update → Keep local version
3. Push to Drive → Upload final state

**Result**: Deletions are handled intelligently based on timing

---

### Scenario 7: Authentication Issues

**When**: User's authentication has expired or failed

**Process**:

1. Detect authentication failure
2. Automatically attempt re-authentication
3. Retry sync operation
4. If successful → Continue with normal sync
5. If failed → Show error message

**Result**: Seamless authentication recovery or clear error feedback

**User Message**: "Authentication failed. Please try signing in again."

---

### Scenario 8: Network Issues

**When**: No internet connection or network timeout

**Process**:

1. Attempt sync operation
2. Detect network failure
3. Show appropriate error message
4. Preserve local data

**Result**: Local data remains intact, sync retry when network available

**User Message**: "Network error. Please check your internet connection."

---

### Scenario 9: Storage Quota Exceeded

**When**: Google Drive storage quota is full

**Process**:

1. Attempt upload to Drive
2. Detect quota exceeded error
3. Show error message
4. Preserve local data

**Result**: Local data remains intact, user needs to free up Drive space

**User Message**: "Google Drive storage quota exceeded. Please free up space."

---

### Scenario 10: Permission Issues

**When**: Google Drive permissions are insufficient

**Process**:

1. Attempt Drive operation
2. Detect permission error
3. Show error message
4. Preserve local data

**Result**: Local data remains intact, user needs to check Drive permissions

**User Message**: "Access denied. Please check your Google Drive permissions."

## Technical Implementation

### Merge Algorithm

```dart
Future<Map<String, dynamic>> mergeWithRemoteData(Map<String, dynamic> remoteData) async {
  // 1. Export current local data
  final localData = exportAllToJson();

  // 2. Create merged result structure
  final mergedData = {
    'version': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'notes': <Map<String, dynamic>>[],
    'folders': <Map<String, dynamic>>[],
  };

  // 3. Merge folders by folderId
  // 4. Merge notes by title + createdAt
  // 5. Resolve conflicts by updatedAt timestamp

  return mergedData;
}
```

### Sync Function Flow

```dart
Future<void> syncWithGoogleDrive(BuildContext context) async {
  // Step 1: Pull data from Google Drive
  final driveData = await _driveService.downloadJsonFromAppData('notemyminds_backup.json');

  // Step 2: Merge local and remote data
  Map<String, dynamic> mergedData;
  if (driveData != null) {
    mergedData = await _noteService.mergeWithRemoteData(driveData);
    await _noteService.importAllFromJson(mergedData);
  } else {
    mergedData = _noteService.exportAllToJson();
  }

  // Step 3: Push merged data to Google Drive
  await _driveService.uploadJsonToAppData(fileName: 'notemyminds_backup.json', json: mergedData);
}
```

## Benefits

### Data Integrity

- **No data loss**: All changes are preserved across devices
- **Conflict resolution**: Automatic resolution based on timestamps
- **Atomic operations**: Sync either completes fully or fails safely

### User Experience

- **Single button**: One "Sync" button handles all scenarios
- **Transparent**: Users don't need to understand the complexity
- **Reliable**: Works consistently across different network conditions

### Developer Experience

- **Debug logging**: Comprehensive logging for troubleshooting
- **Error handling**: Specific error messages for different failure types
- **Maintainable**: Clean separation of concerns

## Best Practices

### For Users

1. **Regular syncs**: Sync frequently to minimize conflicts
2. **Stable connection**: Ensure good internet connection before syncing
3. **Check permissions**: Verify Google Drive permissions if sync fails

### For Developers

1. **Monitor logs**: Check merge logs for debugging
2. **Test scenarios**: Test all scenarios with different data states
3. **Error handling**: Always provide clear error messages to users

## Troubleshooting

### Common Issues

1. **"Authentication failed"**
   - Solution: Re-authenticate with Google account

2. **"Network error"**
   - Solution: Check internet connection and retry

3. **"Access denied"**
   - Solution: Check Google Drive permissions in account settings

4. **"Storage quota exceeded"**
   - Solution: Free up space in Google Drive

5. **Data not syncing**
   - Solution: Check logs for merge conflicts or errors

### Debug Information

The sync process logs detailed information:

- Number of local vs remote items
- Items added vs merged
- Conflict resolution decisions
- Error details

Check the console logs for detailed sync information when troubleshooting.
