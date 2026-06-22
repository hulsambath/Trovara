---
name: new-provider
description: Use when adding a new service class, REST API wrapper, or domain-logic coordinator to Trovara — scaffolds the service, wires constructor-injected dependencies, and registers in ServiceLocator.
allowed-tools: Read, Grep, Bash, Edit, Write
model: sonnet
---

# New Service / Provider

Scaffolds a domain service in `lib/core/services/`, wires dependencies via constructor injection, and registers it in `ServiceLocator`.

## Steps

### 1 — Create `lib/core/services/<domain>/<name>_service.dart`

**Simple service (no UI observation):**
```dart
import 'package:logger/logger.dart';
import 'package:trovara/core/repository/interfaces/<dep>_repository.dart';

class <Name>Service {
  final I<Dep>Repository _<dep>Repository;
  final Logger _logger = Logger();
  bool _isInitialized = false;

  <Name>Service({required I<Dep>Repository <dep>Repository})
      : _<dep>Repository = <dep>Repository;

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _<dep>Repository.initialize();
    _isInitialized = true;
    _logger.d('<Name>Service initialized');
  }

  void dispose() {
    // release resources, cancel subscriptions
  }

  // Domain methods...
}
```

**Observable service (notifies ViewModels on change):**
```dart
import 'package:trovara/global_widgets/cm_change_notifier.dart';

class <Name>Service extends CmChangeNotifier {
  // same constructor injection...

  void _onChanged() {
    notifyListeners();   // safe even after dispose (CmChangeNotifier guards this)
  }
}
```

Use `CmChangeNotifier` only when ViewModels will call `addListener()` on this service. For pure computation services, use a plain class.

### 2 — Choose the right domain folder

| Domain | Folder |
|--------|--------|
| Note CRUD, tag operations | `lib/core/services/notes/` |
| AI, RAG, LLM, embeddings | `lib/core/services/ai/` |
| Google Drive sync | `lib/core/services/sync/` |
| Chat threads/messages | `lib/core/services/chat/` |
| Export (PDF, Markdown) | `lib/core/services/export/` |
| Knowledge graph | `lib/core/services/graph/` |
| In-app purchases | `lib/core/services/billing/` |
| Quiz generation | `lib/core/services/quiz/` |
| Cross-cutting / app lifecycle | `lib/core/services/app/` |

Create a new folder only if the service belongs to a completely new domain.

### 3 — Wire HTTP calls (if this is an API wrapper)

Use `dart:io` + `http` package. Do **not** add `dio` or `retrofit` — they are not in pubspec.yaml.

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class <Name>ApiService {
  final String _baseUrl;
  final String _apiKey;
  final http.Client _client;

  <Name>ApiService({
    required String baseUrl,
    required String apiKey,
    http.Client? client,
  })  : _baseUrl = baseUrl,
        _apiKey = apiKey,
        _client = client ?? http.Client();

  Future<Map<String, dynamic>> fetchData(String endpoint) async {
    final uri = Uri.parse('$_baseUrl/$endpoint');
    final response = await _client.get(uri, headers: {
      'Authorization': 'Bearer $_apiKey',
      'Content-Type': 'application/json',
    });

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  void dispose() => _client.close();
}
```

The `apiKey` comes from `lib/constants/config_constants.dart` (read from `--dart-define`), not hardcoded.

### 4 — Register in `lib/core/di/service_locator.dart`

```dart
// 1. Declare the nullable backing field (after the last similar field)
<Name>Service? _<name>Service;

// 2. Add a lazy getter (after the last similar getter)
<Name>Service get <name>Service {
  _<name>Service ??= <Name>Service(<dep>Repository: <dep>Repository);
  return _<name>Service!;
}
```

If the service needs async initialization, add to `initialize()`:
```dart
Future<void> initialize() async {
  // ... existing inits
  await <name>Service.initialize();
}
```

If the service holds resources, add to `dispose()`:
```dart
void dispose() {
  // ... existing disposals
  _<name>Service?.dispose();
  _<name>Service = null;
}
```

### 5 — Consume in a ViewModel

```dart
final <Name>Service _<name>Service = ServiceLocator().<name>Service;
```

Never call `ServiceLocator()` from inside a `part` file or a repository implementation.

### 6 — Verify

```bash
flutter analyze          # zero new errors
flutter test patrol_test # no regressions
```

## Rules

- Services receive **repository interfaces** (not `ObjectBox*Repository` concretions) via constructor injection.
- Services never import `package:flutter/material.dart` — they are pure Dart.
- No `ServiceLocator()` calls inside service constructors; all deps come through constructor params.
- API keys are read from `lib/constants/config_constants.dart` using `String.fromEnvironment(...)`.
- Use `Logger` from `package:logger` — never `print()`.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Calling `ServiceLocator().noteService` inside service constructor | Pass as constructor parameter instead |
| Using `http.Client` without closing it | Call `_client.close()` in `dispose()` |
| Hardcoding an API key | Read from `ConfigConstants.*` (sourced from `--dart-define`) |
| Forgetting to add `initialize()` to `ServiceLocator.initialize()` | Services that need async setup must be explicitly initialized |
| Extending `CmChangeNotifier` for a service no VM observes | Use plain class; `CmChangeNotifier` only when VMs call `addListener()` |
