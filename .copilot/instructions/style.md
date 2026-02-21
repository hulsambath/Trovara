# notemyminds Style Guide

## Code Style

### 1. Naming Conventions

#### Classes and Types

- Use PascalCase for class names
- Add type prefixes for interfaces (`I`) and abstract classes (`Base`)

```dart
class NoteViewModel { }
abstract class BaseViewModel { }
interface class IRepository { }
```

#### Variables and Methods

- Use camelCase for variables and methods
- Private members start with underscore

```dart
final List<Note> notes = [];
final INoteRepository _repository;

void updateNote(Note note) { }
void _handleError(Exception e) { }
```

### 2. File Organization

#### Directory Structure

```
lib/
├── core/          # Core functionality
│   ├── base/      # Base classes
│   ├── di/        # Dependency injection
│   └── services/  # Business services
├── models/        # Data models
├── views/         # UI screens
└── widgets/       # Reusable widgets
```

#### File Naming

- Use snake_case for file names
- Match class name to file name

```
note_view.dart → class NoteView
note_view_model.dart → class NoteViewModel
custom_widget.dart → class CustomWidget
```

### 3. Code Organization

#### Class Structure

```dart
class MyClass {
  // 1. Static properties
  static const defaultValue = 100;

  // 2. Instance properties
  final String name;
  bool _isLoading = false;

  // 3. Constructors
  MyClass({required this.name});

  // 4. Public methods
  void doSomething() { }

  // 5. Private methods
  void _helper() { }
}
```

### 4. Documentation

#### Class Documentation

```dart
/// A service that manages note synchronization with Google Drive.
///
/// Handles:
/// - Bidirectional sync
/// - Conflict resolution
/// - Error recovery
class NoteSyncService {
  // Implementation...
}
```

#### Method Documentation

```dart
/// Synchronizes local notes with Google Drive.
///
/// Returns the number of synchronized notes.
/// Throws [SyncException] if synchronization fails.
///
/// Parameters:
/// - [force] Forces sync even if no changes detected
Future<int> synchronize({bool force = false}) async {
  // Implementation...
}
```

## UI Style

### 1. Widget Structure

#### Stateless Widgets

```dart
class CustomWidget extends StatelessWidget {
  const CustomWidget({
    super.key,
    required this.title,
    this.onTap,
  });

  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Container(
    // Implementation...
  );
}
```

#### Complex Layouts

```dart
Widget build(BuildContext context) => Scaffold(
  appBar: _buildAppBar(context),
  body: _buildBody(context),
  floatingActionButton: _buildFAB(context),
);

Widget _buildAppBar(BuildContext context) => AppBar(
  // Implementation...
);
```

### 2. Theme Usage

#### Colors

```dart
// DO
final primary = Theme.of(context).colorScheme.primary;
final onPrimary = Theme.of(context).colorScheme.onPrimary;

// DON'T
final color = Colors.blue;
```

#### Text Styles

```dart
// DO
Text('Title', style: Theme.of(context).textTheme.titleLarge);

// DON'T
Text('Title', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold));
```

### 3. Responsive Design

#### Screen Size Adaptation

```dart
LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth > 600) {
      return _buildWideLayout();
    }
    return _buildNarrowLayout();
  },
);
```

#### Safe Area Usage

```dart
SafeArea(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: YourWidget(),
  ),
);
```

## Best Practices

### 1. Error Handling

```dart
// DO
try {
  await operation();
} on SpecificException catch (e) {
  _handleSpecificError(e);
} on Exception catch (e) {
  _handleGenericError(e);
}

// DON'T
try {
  await operation();
} catch (e) {
  print(e);  // Avoid generic catches and print statements
}
```

### 2. Async Operations

```dart
// DO
Future<void> loadData() async {
  isLoading = true;
  notifyListeners();
  try {
    // Load data
  } finally {
    isLoading = false;
    notifyListeners();
  }
}

// DON'T
Future<void> loadData() async {
  // No loading state
  await getData();
}
```

### 3. Resource Disposal

```dart
// DO
class MyWidget extends StatefulWidget {
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  late final StreamSubscription _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = stream.listen((_) {});
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
```
