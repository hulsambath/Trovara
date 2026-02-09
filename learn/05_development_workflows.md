# Development Workflows

## Project Setup

### 1. Environment Setup

```bash
# Install Flutter SDK ≥3.8.1
flutter channel stable
flutter upgrade

# Get dependencies
flutter pub get

# Generate code
./scripts/build_runner.sh
```

### 2. Configuration

Edit `configs/notemyminds.json`:

```json
{
  "APP_NAME": "notemyminds",
  "APP_SCHEME": "notemyminds",
  "APP_COLOR": "#2196F3"
}
```

## Development Scripts

### 1. Enhanced App Runner (with Credentials Management)

```bash
# Run with development credentials (default)
./scripts/run_app.sh --notemyminds

# Run with production credentials
./scripts/run_app.sh --notemyminds --prod

# Run with development credentials explicitly
./scripts/run_app.sh --notemyminds --dev

# Run without automatic credential decryption
./scripts/run_app.sh --notemyminds --no-decrypt

# With specific device
./scripts/run_app.sh --notemyminds -d chrome
```

**Features:**

- Automatic credential decryption for specified environment
- Environment validation and error handling
- Progress indicators and clear feedback
- Support for both dev and prod environments

### 2. Enhanced APK Builder (with Credentials Management)

```bash
# Build with development credentials (default)
./scripts/build_apk.sh --notemyminds

# Build with production credentials
./scripts/build_apk.sh --notemyminds --prod

# Build without automatic credential decryption
./scripts/build_apk.sh --notemyminds --no-decrypt
```

**Features:**

- Automatic credential decryption before build
- Environment-specific APK generation
- Production-ready signed APKs
- Comprehensive error handling and validation

### 3. Code Generation

```bash
# Run build_runner
./scripts/build_runner.sh

# Clean and rebuild
./scripts/build_runner.sh -c
```

## Code Style

### 1. Analysis Options

From `analysis_options.yaml`:

```yaml
linter:
  rules:
    avoid_print: true
    prefer_single_quotes: true
    prefer_const_constructors: true
    prefer_const_literals_to_create_immutables: true
    use_build_context_synchronously: false
```

### 2. File Organization

```
lib/
├── core/          # Core functionality
├── models/        # Data models
├── views/         # UI screens
├── widgets/       # Reusable widgets
└── constants/     # App constants
```

## Testing

### 1. Widget Tests

```dart
// test/widget_test.dart
void main() {
  testWidgets('Notes view test', (tester) async {
    await tester.pumpWidget(const NotesView());
    // Test implementation...
  });
}
```

### 2. Run Tests

```bash
flutter test          # All tests
flutter test path/to/test_file.dart  # Single file
```

## Debug Tools

### 1. Performance Monitoring

- Flutter DevTools
- Performance Overlay
- Memory Profiling

### 2. Logging

```dart
import 'package:logger/logger.dart';

final logger = Logger();
logger.d('Debug message');
logger.i('Info message');
logger.e('Error message');
```

## Credentials Management

### 1. Android Signing Credentials

The project uses a sophisticated credentials management system with SOPS encryption:

#### Project Structure

```
project/
├── notemyminds/                    # Main app
└── credentials/                  # Encrypted credentials
    ├── android/notemyminds/
    │   ├── dev/                  # Development credentials
    │   └── prod/                 # Production credentials
    └── scripts/
        ├── generate-keystore.sh  # Generate keystores with random passwords
        └── generate-age-key.sh   # Generate age keys for SOPS
```

#### Generate New Keystore

```bash
# Generate keystore with strong random passwords
cd project/credentials/scripts
./generate-keystore.sh --project notemyminds --env prod

# This creates:
# - upload.jks (keystore file)
# - keystore.properties (configuration)
# - Strong random passwords (32-char base64)
```

#### Encrypt for Git Storage

```bash
# Encrypt files with SOPS (requires age keys)
sops --encrypt android/notemyminds/prod/upload.jks > android/notemyminds/prod/upload.jks.enc
sops --encrypt android/notemyminds/prod/keystore.properties > android/notemyminds/prod/keystore.properties.enc

# Remove plaintext files (only keep .enc files)
rm android/notemyminds/prod/upload.jks android/notemyminds/prod/keystore.properties
```

#### Development Workflow

```bash
# Decrypt credentials for local development
cd project/notemyminds
./scripts/keystore.sh --env prod

# Run app with production credentials
./scripts/run_app.sh --notemyminds --prod

# Build APK with production credentials
./scripts/build_apk.sh --notemyminds --prod
```

### 2. Security Features

#### Strong Passwords

- **32-character cryptographically secure** random passwords
- **Environment isolation** (dev ≠ prod passwords)
- **PKCS12 compatibility** (same password for store and key)

#### Encryption Model

- **SOPS + Age encryption** for files at rest
- **Private keys never stored** in repository
- **Git-safe storage** (only encrypted `.enc` files committed)

## Common Tasks

### 1. Adding New View

1. Create files:

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
     pageBuilder: (context, state) => MaterialPage(
       child: NewFeatureView(),
     ),
   ),
   ```

### 2. Adding New Model

1. Create model class:

   ```dart
   @Entity()
   class NewModel {
     int id;
     String name;
     // Properties...
   }
   ```

2. Run code generation:
   ```bash
   ./scripts/build_runner.sh
   ```

### 3. Adding New Translation

1. Add to `assets/translations/en.json`:

   ```json
   {
     "newFeature": {
       "title": "New Feature",
       "description": "Description"
     }
   }
   ```

2. Add to other language files (km.json)

## Release Process

### 1. Version Update

Update in `pubspec.yaml`:

```yaml
version: 0.2.0 # Semantic versioning
```

### 2. Build Release

```bash
# Android (with credentials management)
./scripts/build_apk.sh --notemyminds --prod
# ✅ Automatically decrypts production credentials
# ✅ Builds signed production APK

# Android (legacy method)
./scripts/build_apk.sh --notemyminds

# iOS
flutter build ios --release
```

### 3. Testing Checklist

- [ ] Run all tests
- [ ] Check performance metrics
- [ ] Verify translations
- [ ] Test sync functionality
- [ ] Validate offline behavior

## Troubleshooting

### 1. Common Issues

- ObjectBox generation errors
- Build failures
- Sync conflicts
- State management bugs
- Credentials decryption issues
- Keystore compatibility problems

### 2. Debug Steps

1. Check logs
2. Verify configuration
3. Clean build
4. Reset state
5. Clear cache

### 3. Credentials Troubleshooting

```bash
# Check if credentials project exists
ls ../credentials/

# Verify encrypted credentials exist
ls ../credentials/android/notemyminds/prod/*.enc

# Test keystore decryption
./scripts/keystore.sh --env prod

# Check keystore file validity
keytool -list -keystore ../credentials/android/notemyminds/prod/upload.jks -storepass [PASSWORD]

# Regenerate keystore if corrupted
cd ../credentials/scripts
./generate-keystore.sh --project notemyminds --env prod
```
