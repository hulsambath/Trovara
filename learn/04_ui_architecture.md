# UI Architecture and Components

## MVVM Pattern Implementation

### View Layer
```dart
class NotesView extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ViewModelProvider<NotesViewModel>(
    create: (context) => NotesViewModel(),
    builder: (context, viewModel, child) => _NotesContent(viewModel),
  );
}
```

### ViewModel Layer
```dart
class NotesViewModel extends BaseViewModel {
  final INoteRepository _repository;
  List<Note> notes = [];
  bool isLoading = false;
  
  Future<void> loadNotes() async {
    isLoading = true;
    notifyListeners();
    
    try {
      notes = await _repository.getNotes();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
```

### BaseViewModel
```dart
abstract class BaseViewModel extends ChangeNotifier {
  bool _disposed = false;
  
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
  
  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }
}
```

## Shared Components

### 1. NmToast
Toast notifications with consistent styling:
```dart
class NmToast {
  static void show(BuildContext context, String message) {
    // Implementation...
  }
  
  static void error(BuildContext context, String message) {
    // Implementation...
  }
}
```

### 2. ConnectivityStatus
Network status indicator:
```dart
class ConnectivityStatus extends StatelessWidget {
  @override
  Widget build(BuildContext context) => StreamBuilder<ConnectivityResult>(
    stream: Connectivity().onConnectivityChanged,
    builder: (context, snapshot) {
      // UI implementation...
    },
  );
}
```

### 3. Tag Widgets

#### Activity Tags
```dart
class ActivityTagChips extends StatelessWidget {
  final List<ActivityTag> tags;
  final ValueChanged<ActivityTag>? onSelected;
  
  @override
  Widget build(BuildContext context) => Wrap(
    children: tags.map((tag) => Chip(
      label: Text(tag.label),
      avatar: Icon(tag.icon),
      backgroundColor: tag.color,
      onSelected: () => onSelected?.call(tag),
    )).toList(),
  );
}
```

## Theme System

### 1. Theme Configuration
```dart
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  
  ThemeData get lightTheme => ThemeData(
    colorScheme: ColorScheme.light(
      primary: brandColor,
      // Other colors...
    ),
    // Other theme data...
  );
  
  ThemeData get darkTheme => ThemeData(
    colorScheme: ColorScheme.dark(
      // Dark theme colors...
    ),
  );
}
```

### 2. Theme Usage
```dart
final colors = Theme.of(context).colorScheme;
final textStyles = Theme.of(context).textTheme;
```

## Layout Patterns

### 1. Screen Layout
```dart
Scaffold(
  appBar: AppBar(title: Text('Screen Title')),
  body: SafeArea(
    child: CustomScrollView(
      slivers: [
        SliverAppBar(/* ... */),
        SliverList(/* ... */),
      ],
    ),
  ),
  floatingActionButton: FloatingActionButton(/* ... */),
)
```

### 2. Responsive Design
```dart
LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth > 600) {
      return WideLayout(/* ... */);
    }
    return NarrowLayout(/* ... */);
  },
)
```

## Error Handling

### 1. Loading States
```dart
if (viewModel.isLoading) {
  return Center(child: CircularProgressIndicator());
}

if (viewModel.hasError) {
  return ErrorView(
    message: viewModel.errorMessage,
    onRetry: viewModel.retry,
  );
}
```

### 2. Empty States
```dart
if (items.isEmpty) {
  return EmptyStateView(
    icon: Icons.note_add,
    message: 'No notes yet',
    action: Button(
      onPressed: () => createNote(),
      child: Text('Create Note'),
    ),
  );
}
```

## Internationalization

### 1. Setup
```dart
EasyLocalization(
  path: 'assets/translations',
  supportedLocales: [Locale('en'), Locale('km')],
  fallbackLocale: Locale('en'),
  child: App(),
)
```

### 2. Usage
```dart
Text('note.title'.tr())  // Translation
Text('count'.tr(args: ['5']))  // With parameters
```