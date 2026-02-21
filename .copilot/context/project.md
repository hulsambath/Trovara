# trovara Project Context

## Project Overview

trovara is a Flutter-based note-taking application with advanced features including:

- Rich text editing with flutter_quill
- Comprehensive tagging system (Activity, Mood, Time, Personal Growth tags)
- Google Drive synchronization
- Analytics and insights
- Internationalization support (English, Khmer)

## Technical Stack

- Flutter SDK ≥3.8.1
- ObjectBox for local storage
- Provider for state management
- go_router for navigation
- easy_localization for i18n
- Google Drive API for cloud sync

## Key Dependencies

```yaml
dependencies:
  go_router: ^14.6.2
  connectivity_plus: ^6.1.5
  easy_localization: ^3.0.8
  flutter_quill: ^11.4.2
  objectbox: ^4.3.0
  provider: ^6.1.5+1
  google_sign_in: ^6.2.1
  googleapis: ^13.2.0
```

## Project Structure

```
lib/
├── core/          # Core functionality
├── models/        # Data models
├── views/         # UI screens
├── widgets/       # Reusable widgets
└── constants/     # App constants
```

## Environment Configuration

The app uses `configs/trovara.json` for environment configuration:

```json
{
  "APP_NAME": "trovara",
  "APP_SCHEME": "trovara",
  "APP_COLOR": "#2196F3"
}
```
