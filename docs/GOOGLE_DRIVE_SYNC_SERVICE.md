# Google Drive Sync Service

The `GoogleDriveSyncService` is a dedicated service for handling Google Drive synchronization operations. It provides a clean, reusable API for syncing data across different screens in the application.

## Features

- **Complete Sync Process**: Handles authentication, data download, merge, and upload
- **Error Handling**: Comprehensive error handling with user-friendly messages
- **Loading UI**: Built-in loading overlay with consistent UX
- **Toast Notifications**: Automatic success/error toast messages
- **Timeout Protection**: Prevents operations from hanging indefinitely
- **Reusable**: Can be used across multiple screens

## API Reference

### Core Methods

#### `syncWithGoogleDrive()`

Performs a complete sync operation without authentication handling.

```dart
final result = await syncService.syncWithGoogleDrive();
if (result.isSuccess) {
  print('Sync successful: ${result.message}');
} else {
  print('Sync failed: ${result.message}');
}
```

#### `syncWithAuthentication()`

Handles authentication and performs sync operation.

```dart
final result = await syncService.syncWithAuthentication();
// Result contains success/error status and message
```

#### `syncWithLoadingOverlay(BuildContext context)`

Performs sync with built-in loading overlay and toast notifications.

```dart
final result = await syncService.syncWithLoadingOverlay(context);
// Loading overlay is automatically shown and dismissed
// Toast notification is automatically displayed
```

#### `showSyncResultToast(BuildContext context, SyncResult result)`

Shows a toast message based on sync result.

```dart
final result = await syncService.syncWithGoogleDrive();
syncService.showSyncResultToast(context, result);
```

## Usage Examples

### Basic Usage in Any Screen

```dart
import 'package:trovara/core/di/service_locator.dart';
import 'package:trovara/core/services/google_drive_sync_service.dart';

class MyScreen extends StatelessWidget {
  final GoogleDriveSyncService _syncService = ServiceLocator().googleDriveSyncService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Screen'),
        actions: [
          IconButton(
            icon: Icon(Icons.sync),
            onPressed: () => _syncWithGoogleDrive(context),
          ),
        ],
      ),
      body: Center(
        child: Text('My Screen Content'),
      ),
    );
  }

  Future<void> _syncWithGoogleDrive(BuildContext context) async {
    // Simple one-liner sync with loading overlay and toast
    await _syncService.syncWithLoadingOverlay(context);
  }
}
```

### Advanced Usage with Custom Handling

```dart
class AdvancedScreen extends StatefulWidget {
  @override
  _AdvancedScreenState createState() => _AdvancedScreenState();
}

class _AdvancedScreenState extends State<AdvancedScreen> {
  final GoogleDriveSyncService _syncService = ServiceLocator().googleDriveSyncService;
  bool _isSyncing = false;

  Future<void> _performSync() async {
    setState(() => _isSyncing = true);

    try {
      final result = await _syncService.syncWithAuthentication();

      if (result.isSuccess) {
        // Handle success
        _showCustomSuccessDialog(result.message);
      } else {
        // Handle error
        _showCustomErrorDialog(result.message);
      }
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  void _showCustomSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sync Successful'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showCustomErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sync Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Advanced Screen'),
        actions: [
          IconButton(
            icon: _isSyncing
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.sync),
            onPressed: _isSyncing ? null : _performSync,
          ),
        ],
      ),
      body: Center(
        child: Text('Advanced Screen Content'),
      ),
    );
  }
}
```

### Integration in ViewModels

```dart
class MyViewModel extends BaseViewModel {
  final GoogleDriveSyncService _syncService = ServiceLocator().googleDriveSyncService;

  Future<void> syncData(BuildContext context) async {
    try {
      final result = await _syncService.syncWithGoogleDrive();

      if (result.isSuccess) {
        // Update UI state
        notifyListeners();
      }

      // Show toast
      _syncService.showSyncResultToast(context, result);
    } catch (e) {
      // Handle unexpected errors
      debugPrint('Unexpected sync error: $e');
    }
  }
}
```

## Error Handling

The service provides comprehensive error handling for common scenarios:

- **Authentication Errors**: "Authentication failed. Please try signing in again."
- **Permission Errors**: "Access denied. Please check your Google Drive permissions."
- **Network Errors**: "Network error. Please check your internet connection."
- **Timeout Errors**: "Download/Upload timeout - please check your internet connection."
- **Storage Errors**: "Google Drive storage quota exceeded. Please free up space."
- **Cancellation**: "Sync was cancelled."

## Timeout Configuration

The service includes built-in timeouts to prevent operations from hanging:

- **Download**: 30 seconds
- **Data Merge**: 60 seconds
- **Data Import**: 60 seconds
- **Upload**: 30 seconds

## Best Practices

1. **Use `syncWithLoadingOverlay()`** for simple sync operations
2. **Use `syncWithAuthentication()`** when you need to handle authentication separately
3. **Use `syncWithGoogleDrive()`** when authentication is already handled
4. **Always check `result.isSuccess`** before proceeding with success logic
5. **Use `showSyncResultToast()`** for consistent toast notifications
6. **Handle context mounting** in async operations

## Migration from SettingViewModel

If you're migrating from the old `SettingViewModel.syncWithGoogleDrive()` method:

### Before (Old Way)

```dart
// In SettingViewModel
Future<void> syncWithGoogleDrive(BuildContext context) async {
  // 100+ lines of complex sync logic
  // Manual error handling
  // Manual loading overlay
  // Manual toast notifications
}
```

### After (New Way)

```dart
// In any ViewModel or Widget
Future<void> syncWithGoogleDrive(BuildContext context) async {
  final result = await _syncService.syncWithLoadingOverlay(context);
  // That's it! Everything is handled automatically
}
```

## Dependencies

The service depends on:

- `GoogleDriveService` - For Google Drive API operations
- `NoteService` - For data export/import operations
- `ServiceLocator` - For dependency injection

Make sure these services are properly initialized in your `ServiceLocator`.
