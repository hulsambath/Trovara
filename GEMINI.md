# Trovara Project Context

## Project Overview

Trovara is a comprehensive, offline-first note-taking application built with Flutter. It features rich text editing, an advanced tagging system (activity, mood, time, personal growth, custom), analytics/insights generation, and Google Drive synchronization for cross-device access.

### Key Architecture Components

- **Architecture Pattern**: MVVM (Model-View-ViewModel).
- **State Management**: Provider (`ChangeNotifier` with ViewModels).
- **Navigation**: `go_router` for declarative routing with named routes.
- **Data Layer**: ObjectBox for fast local persistence, abstracting data access through the Repository Pattern.
- **Service Layer**: Handles business logic and coordinates between repositories (e.g., `NoteService`, `SyncService`).

### Technology Stack

- **Flutter**: SDK ≥3.8.1
- **Local Storage**: `objectbox` & `objectbox_flutter_libs`
- **State Management**: `provider`
- **Routing**: `go_router`
- **Rich Text**: `flutter_quill`
- **Sync**: `googleapis`, `google_sign_in`
- **Internationalization**: `easy_localization`

## Building and Running

### Setup

1.  Ensure you have Flutter SDK ≥3.8.1 installed.
2.  Install dependencies:
    ```bash
    flutter pub get
    ```
3.  Generate ObjectBox models and other generated code:
    ```bash
    ./scripts/build_runner.sh
    ```

### Running the App

Use the provided scripts for running the application, which include environment and credential management:

- **Fast Run** (reuses last config, defaults to staging+debug):
  ```bash
  ./scripts/run_app.sh
  ```
- **Interactive Run**:
  ```bash
  ./scripts/run_app.sh --interactive
  ```
- **Run with Specific Environment**:
  ```bash
  ./scripts/run_app.sh --prod-release --android
  ./scripts/run_app.sh --staging-debug --web
  ```

### Building Releases

- **Android APK** (automatically decrypts credentials if configured):
  ```bash
  ./scripts/build_apk.sh --trovara --prod
  ```

### Testing

- Run all tests: `flutter test`
- Run a specific test: `flutter test path/to/test_file.dart`

## Development Conventions

### File Organization

- `lib/core/`: Core functionality, services, and repositories.
- `lib/models/`: ObjectBox data models (run `build_runner.sh` after modifications).
- `lib/views/`: UI screens (following MVVM structure).
- `lib/widgets/`: Reusable, shared UI widgets.
- `lib/constants/`: App-wide constants.

### Naming Conventions

- **Widgets**: `widget_name.dart`
- **Services**: `service_name_service.dart`
- **Models**: `model_name.dart`

### Code Style

- Follow the rules defined in `analysis_options.yaml`.
- Prefer `const` constructors where possible.
- Use single quotes for strings.
- Write explicit doc comments for public APIs.
- Show user feedback using `NmToast.show(context, 'message');`.

### Credentials Management

The project uses SOPS-encrypted credentials stored in `../credentials/` for secure environment separation (dev vs prod). The run scripts handle the decryption implicitly. If you are modifying credentials, refer to the development workflows in `learn/05_development_workflows.md`.

## Additional Resources
For deeper architectural details, check the `docs/` and `learn/` directories within the project. Note that `learn/01_project_overview.md` and `docs/SYNC_STRATEGY.md` contain critical domain logic information.

### Local Style Guides
*   **[The View Style Guide](lib/views/GEMINI.md)**: When working on UI components in `lib/views/`, you MUST adhere to the strict 3-file MVVM structure documented here.
