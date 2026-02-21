# notemyminds Sync Quick Reference

## Core Files

- **`lib/views/setting/setting_view_model.dart`** - Main sync logic
- **`lib/core/services/note_service.dart`** - Merge algorithm
- **`lib/core/services/google_drive_service.dart`** - Drive API operations

## Key Methods

### Sync Entry Point

```dart
// Main sync function - handles all scenarios
Future<void> syncWithGoogleDrive(BuildContext context)
```

### Merge Algorithm

```dart
// Intelligent merge of local and remote data
Future<Map<String, dynamic>> mergeWithRemoteData(Map<String, dynamic> remoteData)
```

### Drive Operations

```dart
// Upload data to Google Drive
Future<void> uploadJsonToAppData({required String fileName, required Map<String, dynamic> json})

// Download data from Google Drive
Future<Map<String, dynamic>?> downloadJsonFromAppData(String fileName)
```

## Sync Flow

```
1. Authenticate → signIn() if needed
2. Pull → downloadJsonFromAppData()
3. Merge → mergeWithRemoteData()
4. Apply → importAllFromJson()
5. Push → uploadJsonToAppData()
```

## Conflict Resolution

### Folders

- **Key**: `folderId`
- **Winner**: Latest `updatedAt`

### Notes

- **Key**: `title + createdAt`
- **Winner**: Latest `updatedAt`
- **Tie**: Prefer local

## Error Handling

| Error Type     | Message                  | Solution                |
| -------------- | ------------------------ | ----------------------- |
| 401/Auth       | "Authentication failed"  | Re-authenticate         |
| 403/Permission | "Access denied"          | Check Drive permissions |
| Network        | "Network error"          | Check connection        |
| Quota          | "Storage quota exceeded" | Free up Drive space     |
| Cancelled      | "Sync was cancelled"     | User cancelled          |

## Debug Logging

The sync process logs:

- Local vs remote item counts
- Items added vs merged
- Merge decisions
- Error details

Check console for: `Merging data - Local notes: X, Remote notes: Y`

## Testing Scenarios

1. **First sync** - No remote data
2. **Local changes** - Only local modifications
3. **Remote changes** - Only remote modifications
4. **Conflicts** - Both sides modified
5. **New items** - New notes on both sides
6. **Authentication** - Expired tokens
7. **Network** - Connection issues

## Common Issues

### Data not syncing

- Check authentication status
- Verify network connection
- Review console logs for errors

### Merge conflicts

- Check `updatedAt` timestamps
- Verify note keys (title + createdAt)
- Review merge algorithm logs

### Performance

- Large datasets may take time
- Consider pagination for very large note collections
- Monitor memory usage during merge

## Best Practices

1. **Always handle errors gracefully**
2. **Provide clear user feedback**
3. **Log merge decisions for debugging**
4. **Test with various data states**
5. **Monitor sync performance**
