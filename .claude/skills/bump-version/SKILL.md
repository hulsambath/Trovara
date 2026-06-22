---
name: bump-version
description: Use when incrementing the Trovara app version before a release — updates the semver and build number in pubspec.yaml following the project's versioning convention.
allowed-tools: Read, Edit, Bash
disable-model-invocation: false
---

# Bump Version

Updates `version` in `pubspec.yaml` following the format `MAJOR.MINOR.PATCH+BUILD`.

## Version Format

```
1.0.0+6
│ │ │  └── build number  (increment on every release; iOS + Android share this counter)
│ │ └───── patch          (bug fixes)
│ └─────── minor          (new features)
└───────── major          (breaking changes — rare)
```

## Which Component to Bump

| Change type | Bump |
|-------------|------|
| Bug fix / crash fix | patch (`1.0.1+7`) |
| New feature (notes import, graph, quiz, etc.) | minor (`1.1.0+7`) |
| Breaking data migration or API change | major (`2.0.0+7`) |
| Release candidate / re-submit with no feature change | build only (`1.0.0+7`) |

Always increment the build number regardless of which semver part changes.

## Steps

### 1 — Read current version

```bash
grep '^version:' pubspec.yaml
```

### 2 — Edit `pubspec.yaml`

```yaml
# Before
version: 1.0.0+6

# After (example: minor bump)
version: 1.1.0+7
```

Only the `version:` line changes — nothing else in pubspec.yaml.

### 3 — Verify the file parses correctly

```bash
flutter pub get       # will fail loudly if pubspec.yaml is malformed
```

### 4 — Confirm the version surfaces in the app

The version is read at runtime via `package_info_plus`:
```dart
final info = await PackageInfo.fromPlatform();
print('${info.version}+${info.buildNumber}');  // e.g. "1.1.0+7"
```

No code changes are needed — `package_info_plus` reads from the platform manifest, which is populated by Flutter from `pubspec.yaml` during build.

## Rules

- Never reset the build number to 0 — it must always increase monotonically.
- After a major bump, reset minor and patch to 0 (`2.0.0`). After a minor bump, reset patch to 0 (`1.1.0`).
- Both the App Store (iOS) and Play Store (Android) use the build number; keep them in sync.
- Do not add leading zeros to any component.
