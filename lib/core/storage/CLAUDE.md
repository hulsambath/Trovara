# lib/core/storage/ — Storage Layer

This directory implements a **type-safe, adapter-based persistence layer** for local (non-database) app state: theme preferences, auth tokens, feature flags, and other user settings.

## Architecture Overview

```
┌─────────────────────────────────────────┐
│  Concrete Storage Classes               │
│  (ThemeModeStorage, GoogleDriveAuth..) │
└──────────────┬──────────────────────────┘
               │ extends
┌──────────────▼──────────────────────────┐
│  TypedStorage<T>                        │
│  (StringStorage, EnumStorage, etc.)     │
└──────────────┬──────────────────────────┘
               │ extends
┌──────────────▼──────────────────────────┐
│  BaseStorage<T>                         │
│  (read/write/remove abstraction)        │
└──────────────┬──────────────────────────┘
               │ uses (composition)
┌──────────────▼──────────────────────────┐
│  BaseStorageAdapter<T>                  │
│  (concrete backends: SharedPrefs, etc.) │
└─────────────────────────────────────────┘
```

## Key Concepts

### BaseStorage<T>

The root abstraction. Provides three methods:

- `read()` → returns `Future<T?>`
- `write(T? value)` → persists to adapter
- `remove()` → clears key

Uses `runtimeType.toString()` as the storage key (immutable per class).

### Typed Storage Classes

Located in `base_storage/`:

- `StringStorage` — for strings
- `EnumStorage<T>` — for enums (must implement `values` getter)
- `IntegerStorage` — for ints
- `BoolStorage` — for booleans
- `SetStorage<T>` — for sets
- `ListStorage<T>` — for lists
- `MapStorage<K, V>` — for maps
- `ObjectStorage<T>` — for JSON-serializable objects

Each typed class handles serialization/deserialization to/from JSON.

### BaseStorageAdapter<T>

Pluggable backend. Two implementations exist:

- `SharePreferencesAdapter` (default) — uses `shared_preferences` package
- `MemoryStorageAdapter` — in-memory only (testing)

Override `validateResult(dynamic data)` to add custom deserialization logic.

## Adding a New Storage Type

### Scenario 1: Simple scalar (String, int, bool)

Use an existing typed storage as a mixin:

```dart
class MyFeatureFlagStorage extends BoolStorage {
  static final MyFeatureFlagStorage instance = MyFeatureFlagStorage();

  Future<void> initialize() async {
    // Optional: load on startup
  }
}
```

Key at rest: `"MyFeatureFlagStorage"` (auto-derived from class name).

### Scenario 2: Enum

Implement `EnumStorage<T>`:

```dart
class ExportFormatStorage extends EnumStorage<ExportFormat> {
  static final ExportFormatStorage instance = ExportFormatStorage();

  @override
  List<ExportFormat> get values => ExportFormat.values;

  Future<void> initialize() async {
    _format = await readEnum();
  }

  ExportFormat? _format;
  ExportFormat get format => _format ?? ExportFormat.json;
}
```

### Scenario 3: Complex object (JSON-serializable)

Use `ObjectStorage<T>`:

```dart
class UserPreferencesStorage extends ObjectStorage<UserPreferences> {
  static final UserPreferencesStorage instance = UserPreferencesStorage();

  @override
  UserPreferences? deserialize(Map<String, dynamic> json) {
    return UserPreferences.fromJson(json);
  }

  Future<void> initialize() async {
    _prefs = await readObject() ?? UserPreferences.empty();
  }

  UserPreferences? _prefs;
  UserPreferences get prefs => _prefs ?? UserPreferences.empty();
}
```

Ensure the object has `toJson()` and `fromJson(Map<String, dynamic>)` methods.

### Scenario 4: Set or List of scalars

Use `SetStorage<T>` or `ListStorage<T>`:

```dart
class TagBlacklistStorage extends SetStorage<String> {
  static final TagBlacklistStorage instance = TagBlacklistStorage();
}
```

## Registration & Initialization

### In ServiceLocator

Add an async getter:

```dart
Future<void> initialize() async {
  // ...existing code...

  await ThemeModeStorage.instance.initialize();
  await MyFeatureFlagStorage.instance.initialize();
}

void dispose() {
  // No disposal needed for storage classes
}
```

Call `initialize()` for any storage that needs to preload on app startup. Storage is lazily instantiated and thread-safe.

### Usage in Views/ViewModels

Access via the singleton instance:

```dart
ThemeModeStorage.instance.themeMode
await ThemeModeStorage.instance.writeEnum(ThemeMode.light)
```

No ServiceLocator injection needed — storage is lightweight and stateless (except for the singleton cache).

## Implementation Patterns

### Caching Pattern (Recommended)

When read performance matters, cache in memory:

```dart
class ThemeModeStorage extends EnumStorage<ThemeMode> {
  ThemeMode? _themeMode; // Cache

  Future<void> initialize() async {
    _themeMode = await readEnum();
  }

  ThemeMode get themeMode => _themeMode ?? ThemeMode.dark;

  @override
  Future<void> writeEnum(ThemeMode value) {
    _themeMode = value; // Update cache
    return super.writeEnum(value);
  }
}
```

### Migration Pattern

If the storage key or type changes:

```dart
@override
Future<T?> read() async {
  T? value = await super.read();
  if (value == null && key == 'NewKeyName') {
    // Try reading from old key
    value = await legacyRead();
    if (value != null) {
      await write(value); // Migrate
    }
  }
  return value;
}
```

## Testing

Use `MemoryStorageAdapter` in tests:

```dart
void setUp() {
  // For tests, inject a memory adapter
  // Most storage classes default to SharedPreferencesAdapter,
  // but you can create a test double if needed.
}
```

When unit-testing services that depend on storage, mock the storage class or use the in-memory adapter.

## DRY & Conventions

1. **One storage class per key.** Don't reuse a StringStorage for multiple unrelated strings; create one class per concern.
2. **Singleton instance.** Use `static final ... instance = ...()` so callers don't import ServiceLocator.
3. **Auto key derivation.** The key is derived from class name; never override unless absolutely necessary.
4. **Null safety.** Storage always returns `T?`. Provide a sensible default in the getter (e.g., `_themeMode ?? ThemeMode.dark`).
5. **No async in property getters.** Use `await initialize()` to preload on app startup, then cache. Sync getters should never block.

## File Organization

```
lib/core/storage/
├── CLAUDE.md                           ← This file
├── theme_mode_storage.dart             ← Concrete storage
├── google_drive_auth_storage.dart      ← Concrete storage
├── base_storage/                       ← Typed storage abstractions
│   ├── string_storage.dart
│   ├── enum_storage.dart
│   ├── list_storage.dart
│   └── ...
├── preference_storage/                 ← Base abstractions
│   ├── base_storage.dart               ← Root: read/write/remove
│   └── default_storage.dart            ← Binds to SharedPrefs
└── storage_adapter/                    ← Pluggable backends
    ├── base_storage_adapter.dart       ← Interface
    ├── share_preference_adapter.dart   ← Default impl
    └── memory_storage_adapter.dart     ← Test impl
```

## Hard Limits & Style

- One primary class per file (except `base_storage.dart` and `default_storage.dart`, which are tight abstractions).
- Keep storage implementations under 100 LOC.
- Use single quotes and enforce 120-char line width.
- No hardcoded strings in storage — if a value is user-visible, store the key in `assets/translations/*.json` instead.
