# Trovara

A Flutter note-taking application with advanced features like tagging, insights, and Google Drive synchronization.

## Overview

Trovara is a comprehensive note-taking application built with Flutter that provides:

- 📝 Advanced note-taking with rich text editing
- 🏷️ Comprehensive tagging system for organization
- 🔄 Google Drive synchronization for cross-device access
- 📊 Analytics and insights for note usage patterns
- 🌍 Internationalization support (English and Khmer)
- 🎨 Theming system with customizable appearance

## Getting Started

1. **Prerequisites**: Flutter SDK ≥3.8.1
2. **Install dependencies**: `flutter pub get`
3. **Generate code**: `./scripts/build_runner.sh`
4. **Run the app**: `./scripts/run_app.sh` (reuses last run config, or defaults to staging + debug)

## Development

### Scripts
- `./scripts/run_app.sh` - Fast no-prompt run (saved config, fallback staging + debug + auto device)
- `./scripts/run_app.sh --interactive` - Run with interactive target/env selection
- `./scripts/run_app.sh --quick` - Run quickly (staging + debug, no prompts)
- `./scripts/run_app.sh --prod-release --android` - Run with production release preset on Android
- `./scripts/run_app.sh --staging-debug --web` - Run with staging debug preset on Web
- `./scripts/build_apk.sh --trovara` - Build Android APK
- `./scripts/build_runner.sh` - Generate code

### Patrol E2E testing
- Install the Patrol CLI separately: `dart pub global activate patrol_cli`
- Run Patrol tests with `patrol test`
- The first smoke test covers app launch and switching between the Notes and Chat tabs

### Credentials Management
The app uses a sophisticated credentials management system:
- **Location**: `../credentials/` (encrypted credential storage)
- **Security**: SOPS encryption with strong random passwords
- **Multi-environment**: Separate dev/prod configurations
- **CI/CD Integration**: Automated credential handling
- **Run behavior**: credential checks are opt-in for run flow (`./scripts/run_app.sh --with-creds` or `--decrypt`)

## Architecture

- **State Management**: Provider pattern with ViewModels
- **Navigation**: go_router for declarative routing
- **Data Layer**: ObjectBox for local persistence
- **UI Architecture**: MVVM pattern implementation
- **Internationalization**: easy_localization

## Features

- Rich text editing with flutter_quill
- Tag-based organization and filtering
- Google Drive synchronization
- Analytics and insights generation
- Cross-platform support (Android, iOS, Web, Desktop)
- Offline-first architecture
