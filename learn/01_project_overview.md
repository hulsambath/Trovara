# notemyminds Project Overview

## Introduction

notemyminds is a Flutter-based note-taking application with advanced features like tagging, insights, and Google Drive synchronization.

## Technical Stack

- Flutter SDK ≥3.8.1
- ObjectBox for local storage
- Provider for state management
- go_router for navigation
- easy_localization for internationalization
- flutter_quill for rich text editing
- Google Drive API for cloud sync

## Core Architecture

### 1. Application Structure

```
lib/
├── app.dart               # Main MaterialApp configuration
├── app_scope.dart         # Global app state and initialization
├── provider_scope.dart    # Provider setup
├── initializer.dart       # App initialization logic
└── main.dart             # Entry point with deferred loading
```

### 2. Key Components

#### State Management

- Uses Provider pattern with ViewModelProvider wrapper
- Each view has corresponding ViewModel extending BaseViewModel
- Global state managed through ProviderScope

#### Navigation

- go_router for declarative routing
- Shell route pattern for persistent bottom navigation
- Main routes: notes, insights, settings

#### Data Layer

- ObjectBox for local persistence
- Repository pattern for data access
- Service layer for business logic

#### UI Architecture

- Follows MVVM pattern:
  - View (UI layer)
  - ViewModel (presentation logic)
  - Model (data and business logic)
- Each view module contains:
  ```
  views/module_name/
  ├── module_view.dart
  ├── module_content.dart  # Actual UI implementation
  ├── module_view_model.dart
  └── widgets/            # Module-specific widgets
  ```

### 3. Core Features

#### Tagging System

- Multiple tag types (Activity, Mood, Time, Personal Growth)
- Custom user-defined tags
- Tag-based filtering and organization

#### Notes Management

- Rich text editing with flutter_quill
- Tag-based organization
- Local storage with ObjectBox

#### Google Drive Sync

- Bidirectional synchronization
- Conflict resolution
- OAuth authentication

#### Insights

- Note analytics and visualization
- Activity heatmaps
- Tag usage statistics

### 4. Project Initialization

```dart
// App startup sequence (main.dart)
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializer.loadLibrary();
  await app_scope.loadLibrary();
  await app.loadLibrary();
  await initializer.Initializer.load();
  runApp(app_scope.AppScope(builder: (context) => app.App()));
}
```

### 5. Configuration

Application configuration is managed through:

- `configs/notemyminds.json` - Environment variables
- `lib/constants/` - App-wide constants
- Analysis options for code style
