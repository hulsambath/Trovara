# trovara Coding Instructions

## General Guidelines

1. Always follow MVVM pattern:
   - Views should only contain UI logic
   - ViewModels handle presentation logic
   - Models contain business logic
   - Use ViewModelProvider for dependency injection

2. File Naming:
   - Views: `feature_view.dart`
   - ViewModels: `feature_view_model.dart`
   - Models: `model_name.dart`
   - Widgets: `widget_name.dart`

3. Repository Pattern:
   - Create interface in `core/repository/interfaces`
   - Implement in `core/repository/implementations`
   - Use dependency injection through ServiceLocator

4. Error Handling:
   - Use NmToast for user feedback
   - Handle all async operations properly
   - Show appropriate loading states
   - Implement error recovery where possible

## Code Structure

### Views

```dart
class FeatureView extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ViewModelProvider<FeatureViewModel>(
    create: (context) => FeatureViewModel(),
    builder: (context, viewModel, child) => _FeatureContent(viewModel),
  );
}
```

### ViewModels

```dart
class FeatureViewModel extends BaseViewModel {
  // Properties at the top
  final IRepository _repository;

  // Constructor next
  FeatureViewModel({required IRepository repository}) : _repository = repository;

  // Public methods
  Future<void> loadData() async {
    // Implementation
  }

  // Private methods last
  void _handleError(Exception e) {
    // Error handling
  }
}
```

### Models

```dart
@Entity()
class MyModel {
  int id;
  String name;

  // Constructor
  MyModel({required this.name});

  // Factory methods
  factory MyModel.fromJson(Map<String, dynamic> json) => MyModel(
    name: json['name'] as String,
  );

  // To JSON method
  Map<String, dynamic> toJson() => {
    'name': name,
  };
}
```

## Dependency Injection

Use ServiceLocator for dependency injection:

```dart
final repository = ServiceLocator().repository;
final service = ServiceLocator().myService;
```

## Asynchronous Operations

1. Always show loading state:

```dart
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
```

2. Handle errors properly:

```dart
try {
  await operation();
} on SpecificException catch (e) {
  _handleSpecificError(e);
} on Exception catch (e) {
  _handleGenericError(e);
}
```

## UI Components

1. Use theme colors:

```dart
final colors = Theme.of(context).colorScheme;
final textStyles = Theme.of(context).textTheme;
```

2. Support dark mode:

```dart
Color getColor(BuildContext context) =>
  Theme.of(context).brightness == Brightness.dark
    ? darkColor
    : lightColor;
```

3. Handle screen sizes:

```dart
LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth > 600) {
      return WideLayout();
    }
    return NarrowLayout();
  },
)
```

## Navigation

Use go_router for navigation:

```dart
// Navigate to new screen
context.push('/route');

// With parameters
context.push('/route?param=value');

// Replace current route
context.go('/route');
```
