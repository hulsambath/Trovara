# Data Management and Synchronization

## Local Storage (ObjectBox)

### Store Configuration
ObjectBox is initialized during app startup through ServiceLocator:

```dart
class ServiceLocator {
  late final Store _store;
  late final Box<Note> _noteBox;
  late final Box<Folder> _folderBox;
  
  Future<void> initialize() async {
    _store = await openStore();
    _noteBox = _store.box<Note>();
    _folderBox = _store.box<Folder>();
  }
}
```

### Repository Pattern

All data access is abstracted through repositories:

```dart
abstract class INoteRepository {
  Stream<List<Note>> watchNotes();
  Future<Note?> getNote(int id);
  Future<void> putNote(Note note);
  Future<void> deleteNote(int id);
}

class ObjectBoxNoteRepository implements INoteRepository {
  final Box<Note> _box;
  // Implementation...
}
```

## Google Drive Sync

### Authentication
```dart
class GoogleDriveService {
  final GoogleSignIn _googleSignIn;
  final GoogleAuthClient _authClient;
  
  Future<void> signIn() async {
    final account = await _googleSignIn.signIn();
    final auth = await account?.authentication;
    // Setup auth client...
  }
}
```

### Sync Strategy

1. Change Detection:
   - Local changes tracked through ObjectBox observers
   - Remote changes checked on sync trigger

2. Merge Resolution:
   - Timestamp-based conflict detection
   - Last-write-wins with local copy preservation
   - User notification for conflicts

3. Sync Process:
   ```dart
   Future<void> synchronize() async {
     // 1. Get local changes
     final localChanges = await getLocalChanges();
     
     // 2. Fetch remote changes
     final remoteChanges = await fetchRemoteChanges();
     
     // 3. Resolve conflicts
     final mergeResult = await resolveConflicts(
       localChanges, 
       remoteChanges
     );
     
     // 4. Apply merged changes
     await applyChanges(mergeResult);
   }
   ```

### Error Handling

1. Network Issues:
   ```dart
   try {
     await synchronize();
   } on SocketException {
     // Handle offline state
   } on DriveForbidden {
     // Handle authentication issues
   }
   ```

2. Conflict Resolution:
   - User notification through NmToast
   - Option to keep local or remote version
   - Automatic merge for non-conflicting changes

## Data Models

### Note Entity
```dart
@Entity()
class Note {
  int id;
  String title;
  String content;
  DateTime createdAt;
  DateTime modifiedAt;
  List<Tag> tags;
  
  // Sync metadata
  String? driveId;
  String? driveRevision;
  DateTime? lastSynced;
}
```

### Tag System
```dart
abstract class Tag {
  String id;
  String label;
  IconData icon;
  Color color;
}

class ActivityTag extends Tag { ... }
class MoodTag extends Tag { ... }
class TimeTag extends Tag { ... }
class PersonalGrowthTag extends Tag { ... }
```

## Caching Strategy

1. In-Memory Cache:
   - ViewModel state
   - Tag collections
   - Recently accessed notes

2. Persistent Cache:
   - ObjectBox store
   - User preferences
   - Authentication tokens

3. Cache Invalidation:
   - On sync completion
   - After local updates
   - Timer-based refresh