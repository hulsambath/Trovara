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
4. **Run the app**: `./scripts/run_app.sh --trovara`

## Development

### Scripts
- `./scripts/run_app.sh --trovara` - Run the application
- `./scripts/build_apk.sh --trovara` - Build Android APK
- `./scripts/build_runner.sh` - Generate code

### Credentials Management
The app uses a sophisticated credentials management system:
- **Location**: `../credentials/` (encrypted credential storage)
- **Security**: SOPS encryption with strong random passwords
- **Multi-environment**: Separate dev/prod configurations
- **CI/CD Integration**: Automated credential handling

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
