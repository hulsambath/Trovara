# notemyminds Architecture

## Core Architecture Patterns

### 1. MVVM Pattern

```dart
// View
class NotesView extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ViewModelProvider<NotesViewModel>(
    create: (context) => NotesViewModel(),
    builder: (context, viewModel, child) => _NotesContent(viewModel),
  );
}

// ViewModel
class NotesViewModel extends BaseViewModel {
  final INoteRepository _repository;
  List<Note> notes = [];
}
```

### 2. Repository Pattern

```dart
abstract class INoteRepository {
  Stream<List<Note>> watchNotes();
  Future<Note?> getNote(int id);
  Future<void> putNote(Note note);
}

class ObjectBoxNoteRepository implements INoteRepository {
  final Box<Note> _box;
  // Implementation...
}
```

### 3. Service Layer

```dart
class NoteService {
  final INoteRepository _repository;
  final IGoogleDriveService _driveService;

  Future<void> saveNote(Note note) async {
    await _repository.putNote(note);
    await _driveService.sync();
  }
}
```

## Navigation Architecture

- Uses go_router for declarative routing
- Shell route pattern for bottom navigation
- URL-based navigation with parameters

## Data Architecture

- ObjectBox for local storage
- Google Drive for cloud sync
- Repository pattern for data access
- Service layer for business logic

## UI Architecture

- Material Design 3 components
- Responsive layouts
- Custom widget library
- Theme system support
