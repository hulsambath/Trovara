# NoteMinds AI Assistant Guide

This guide helps AI assistants understand the NoteMinds project architecture and conventions for effective contributions.

## Project Overview

NoteMinds is a Flutter-based note-taking app with robust tagging, sync, and analytics features. The app uses:

- Flutter SDK ≥3.8.1
- ObjectBox for local storage
- Google Drive for sync
- Provider for state management
- go_router for navigation

## Key Architecture Components

### 1. Tag System

The app uses a sophisticated tagging system with four types:
- Activity tags (work, home, etc.)
- Mood tags (happy, sad, etc.)
- Time tags (morning, afternoon, etc.)
- Personal growth tags
- Custom tags (user-defined)

File structure:
```
lib/models/
  ├── activity_tag.dart
  ├── mood_tag.dart
  ├── time_tag.dart
  └── personal_growth_tag.dart
```

### 2. Repository Pattern

All data access follows repository pattern with clear interfaces:
```dart
// Example structure in lib/core/repository/
interface INoteRepository { ... }
class ObjectBoxNoteRepository implements INoteRepository { ... }
```

### 3. Service Layer 

Services handle business logic and coordinate between repositories:
```
lib/core/services/
  ├── note_service.dart      // Note operations
  └── sync_service.dart      // Google Drive sync
```

## Development Workflows

### Building & Running

1. Configure environment:
   ```bash
   flutter pub get
   ./scripts/build_runner.sh  # Generate ObjectBox code
   ```

2. Run app:
   ```bash
   ./scripts/run_app.sh --noteminds
   ```

3. Build release:
   ```bash
   ./scripts/build_apk.sh --noteminds  # Android
   ```

### Common Patterns

1. **State Management**: Use Provider with ChangeNotifier
   ```dart
   class NoteViewModel extends ChangeNotifier {
     final INoteRepository _repository;
     // ... 
   }
   ```

2. **Navigation**: Use go_router with named routes
   ```dart
   GoRoute(path: '/notes', name: 'notes', ...)
   ```

3. **Error Handling**: Use NmToast for user feedback
   ```dart
   NmToast.show(context, 'Error message');
   ```

### Integration Points

1. **Google Drive Sync**:
   - Configure in `lib/core/services/sync_service.dart`
   - Handle auth in `lib/core/services/auth_service.dart`
   - Check `SYNC_STRATEGY.md` for merge logic

2. **Custom Tags**:
   - Add new tags through `CustomTagService`
   - Follow color guidelines in `CUSTOM_TAGS_DOCUMENTATION.md`

## Project Conventions

1. **File Naming**:
   - Widgets: `widget_name.dart`
   - Services: `service_name_service.dart`
   - Models: `model_name.dart`

2. **Code Style**:
   - Use single quotes
   - Prefer const constructors
   - Follow analysis_options.yaml rules

3. **Documentation**:
   - Add doc comments for public APIs
   - Keep documentation in `/docs` up to date