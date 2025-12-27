# NoteMinds Development Workflows

## Common Development Tasks

### Running the App
```bash
# Development
./scripts/run_app.sh --noteminds

# With specific device
./scripts/run_app.sh --noteminds -d chrome
```

### Building Releases
```bash
# Android APK
./scripts/build_apk.sh --noteminds

# Run build_runner
./scripts/build_runner.sh
```

### Testing
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart
```

## File Organization

### Adding New Features
1. Create view files:
   ```
   views/new_feature/
   ├── new_feature_view.dart
   ├── new_feature_content.dart
   └── new_feature_view_model.dart
   ```

2. Add route:
   ```dart
   GoRoute(
     path: '/new-feature',
     name: 'newFeature',
     pageBuilder: (context, state) => NewFeatureView(),
   )
   ```

### Adding New Models
1. Create model class with ObjectBox annotations
2. Run build_runner to generate code
3. Add repository interface and implementation

## Code Generation
- ObjectBox models
- Assets (flutter_gen)
- Localizations
- Build configuration

## Release Process
1. Update version in pubspec.yaml
2. Run tests and checks
3. Build release versions
4. Deploy to stores