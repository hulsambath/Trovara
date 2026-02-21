# NM Widgets Documentation

The NM (trovara) widgets are reusable UI components that provide consistent styling and behavior across the application. They follow the `nm` prefix naming convention and are designed to be easily integrated into any screen or service.

## Available Widgets

### 1. NmToast

A utility class for showing toast messages with consistent styling and behavior.

**Location**: `/lib/widgets/nm_toast.dart`

#### Features

- **Consistent Styling**: All toasts follow the same design pattern
- **Multiple Types**: Success, error, info, and warning toasts
- **Context Safety**: Automatically checks if context is still mounted
- **Customizable Duration**: Configurable display duration
- **Auto-dismiss**: Can be dismissed by tapping the close button

#### API Reference

##### Static Methods

```dart
// Basic toast with custom parameters
static void show(
  BuildContext context,
  String message, {
  bool isError = false,
  Duration duration = const Duration(seconds: 4),
})

// Success toast (green styling)
static void success(BuildContext context, String message)

// Error toast (red styling)
static void error(BuildContext context, String message)

// Info toast (neutral styling)
static void info(BuildContext context, String message)

// Warning toast (red styling)
static void warning(BuildContext context, String message)

// Clear all current toasts
static void clear(BuildContext context)
```

#### Usage Examples

##### Basic Usage

```dart
import 'package:trovara/widgets/nm_toast.dart';

// Show success toast
NmToast.success(context, 'Operation completed successfully!');

// Show error toast
NmToast.error(context, 'Something went wrong!');

// Show info toast
NmToast.info(context, 'Information message');

// Show warning toast
NmToast.warning(context, 'Warning message');
```

##### Advanced Usage

```dart
// Custom duration and styling
NmToast.show(
  context,
  'Custom message',
  isError: true,
  duration: Duration(seconds: 6),
);

// Clear all toasts
NmToast.clear(context);
```

##### In ViewModels

```dart
class MyViewModel extends BaseViewModel {
  Future<void> performAction(BuildContext context) async {
    try {
      // Perform some action
      await someAsyncOperation();
      NmToast.success(context, 'Action completed successfully!');
    } catch (e) {
      NmToast.error(context, 'Action failed: $e');
    }
  }
}
```

### 2. NmLoadingOverlay

A utility class for showing loading overlays with consistent styling and behavior.

**Location**: `/lib/widgets/nm_loading_overlay.dart`

#### Features

- **Consistent Styling**: All loading overlays follow the same design pattern
- **Multiple Types**: Sync, processing, saving, and loading overlays
- **Context Safety**: Automatically checks if context is still mounted
- **Custom Widgets**: Support for custom loading widgets
- **Auto-cleanup**: Automatically removes overlay when operation completes

#### API Reference

##### Static Methods

```dart
// Basic loading overlay with custom message
static Future<T> show<T>(
  BuildContext context,
  Future<T> Function() action, {
  String message = 'Loading...',
  bool barrierDismissible = false,
})

// Custom loading widget
static Future<T> showCustom<T>(
  BuildContext context,
  Future<T> Function() action, {
  required Widget loadingWidget,
  bool barrierDismissible = false,
})

// Predefined overlay types
static Future<T> showSync<T>(BuildContext context, Future<T> Function() action)
static Future<T> showProcessing<T>(BuildContext context, Future<T> Function() action)
static Future<T> showSaving<T>(BuildContext context, Future<T> Function() action)
static Future<T> showLoading<T>(BuildContext context, Future<T> Function() action)
```

#### Usage Examples

##### Basic Usage

```dart
import 'package:trovara/widgets/nm_loading_overlay.dart';

// Show loading overlay with custom message
await NmLoadingOverlay.show(
  context,
  () async {
    // Your async operation
    await someAsyncOperation();
    return 'Result';
  },
  message: 'Processing...',
);

// Show sync overlay
await NmLoadingOverlay.showSync(context, () async {
  await syncData();
  return true;
});

// Show processing overlay
await NmLoadingOverlay.showProcessing(context, () async {
  await processData();
  return 'Processed';
});
```

##### Advanced Usage

```dart
// Custom loading widget
await NmLoadingOverlay.showCustom(
  context,
  () async {
    await complexOperation();
    return 'Done';
  },
  loadingWidget: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircularProgressIndicator(),
      SizedBox(height: 16),
      Text('Custom Loading...'),
      LinearProgressIndicator(),
    ],
  ),
);

// With error handling
try {
  final result = await NmLoadingOverlay.showSync(context, () async {
    return await syncWithGoogleDrive();
  });
  NmToast.success(context, 'Sync completed: $result');
} catch (e) {
  NmToast.error(context, 'Sync failed: $e');
}
```

##### In Services

```dart
class MyService {
  Future<String> performSync(BuildContext context) async {
    return await NmLoadingOverlay.showSync(context, () async {
      // Sync logic here
      await downloadData();
      await processData();
      await uploadData();
      return 'Sync completed';
    });
  }
}
```

## Integration Examples

### Complete Example: Sync Operation

```dart
import 'package:trovara/widgets/nm_loading_overlay.dart';
import 'package:trovara/widgets/nm_toast.dart';

class SyncScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sync'),
        actions: [
          IconButton(
            icon: Icon(Icons.sync),
            onPressed: () => _performSync(context),
          ),
        ],
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _performSync(context),
          child: Text('Sync Data'),
        ),
      ),
    );
  }

  Future<void> _performSync(BuildContext context) async {
    try {
      final result = await NmLoadingOverlay.showSync(context, () async {
        // Simulate sync operation
        await Future.delayed(Duration(seconds: 2));
        return 'Data synced successfully';
      });

      NmToast.success(context, result);
    } catch (e) {
      NmToast.error(context, 'Sync failed: $e');
    }
  }
}
```

### Example: Form Submission

```dart
class FormScreen extends StatefulWidget {
  @override
  _FormScreenState createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  Future<void> _submitForm(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      NmToast.warning(context, 'Please fill in all required fields');
      return;
    }

    try {
      await NmLoadingOverlay.showSaving(context, () async {
        // Simulate form submission
        await Future.delayed(Duration(seconds: 1));
        await submitToServer(_controller.text);
      });

      NmToast.success(context, 'Form submitted successfully!');
      _controller.clear();
    } catch (e) {
      NmToast.error(context, 'Submission failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Form')),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              TextFormField(
                controller: _controller,
                decoration: InputDecoration(labelText: 'Name'),
                validator: (value) => value?.isEmpty == true ? 'Required' : null,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _submitForm(context),
                child: Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

## Best Practices

### 1. Context Safety

Always ensure the context is valid before showing toasts or overlays:

```dart
// Good
if (context.mounted) {
  NmToast.success(context, 'Success!');
}

// The widgets handle this automatically, but it's good to be aware
```

### 2. Error Handling

Always wrap async operations in try-catch blocks:

```dart
try {
  await NmLoadingOverlay.showSync(context, () async {
    return await riskyOperation();
  });
  NmToast.success(context, 'Operation completed');
} catch (e) {
  NmToast.error(context, 'Operation failed: $e');
}
```

### 3. Consistent Messaging

Use consistent message patterns:

```dart
// Good
NmToast.success(context, 'Data synced successfully');
NmToast.error(context, 'Sync failed: Network error');

// Avoid
NmToast.success(context, 'Done!');
NmToast.error(context, 'Oops!');
```

### 4. Appropriate Overlay Types

Use the most appropriate overlay type for the operation:

```dart
// For sync operations
NmLoadingOverlay.showSync(context, () async => await sync());

// For data processing
NmLoadingOverlay.showProcessing(context, () async => await process());

// For saving operations
NmLoadingOverlay.showSaving(context, () async => await save());

// For general loading
NmLoadingOverlay.showLoading(context, () async => await load());
```

## Migration Guide

### From Custom Toast Implementations

**Before:**

```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('Success!'),
    backgroundColor: Colors.green,
  ),
);
```

**After:**

```dart
NmToast.success(context, 'Success!');
```

### From Custom Loading Dialogs

**Before:**

```dart
showDialog(
  context: context,
  barrierDismissible: false,
  builder: (context) => AlertDialog(
    content: Row(
      children: [
        CircularProgressIndicator(),
        SizedBox(width: 16),
        Text('Loading...'),
      ],
    ),
  ),
);
```

**After:**

```dart
await NmLoadingOverlay.showLoading(context, () async {
  // Your operation
});
```

## Dependencies

The NM widgets have minimal dependencies:

- `flutter/material.dart` - For basic Flutter widgets
- No external packages required

## File Structure

```
lib/
  widgets/
    nm_toast.dart          # Toast utility class
    nm_loading_overlay.dart # Loading overlay utility class
  docs/
    NM_WIDGETS_DOCUMENTATION.md # This documentation
```

## Contributing

When adding new NM widgets:

1. Follow the `nm_` prefix naming convention
2. Include comprehensive documentation
3. Add usage examples
4. Ensure consistent styling with existing widgets
5. Handle context safety properly
6. Add appropriate error handling
