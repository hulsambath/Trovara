# The View Style Guide

When creating or modifying views within `lib/views/`, you MUST strictly adhere to the following 3-file MVVM structure, as defined by the project's VS Code snippets (`.vscode/dart.code-snippets`). 

Every new view (e.g., `feature`) should be placed in its own directory (`lib/views/feature/`) and consist of three specific files:

## 1. The View File (`feature_view.dart`)
This is the public entry point. It sets up the dependency injection for the ViewModel using `ViewModelProvider` and delegates the actual UI building to the private content widget.

**Rules:**
*   Must be named `[feature_name]_view.dart`.
*   Must define a public `StatelessWidget` named `[FeatureName]View`.
*   Must declare the content file as a part: `part '[feature_name]_content.dart';`
*   Must use `ViewModelProvider<[FeatureName]ViewModel>` in its `build` method.
*   Must pass the instantiated view model to `_[FeatureName]Content(viewModel)`.
*   Must **not** contain UI layout logic.
*   Route must be registered in `lib/core/route/app_router.dart`.

**Template:**
```dart
import 'package:flutter/material.dart';
import 'package:trovara/core/base/view_model_provider.dart';

import 'feature_view_model.dart';

part 'feature_content.dart';

class FeatureView extends StatelessWidget {
  const FeatureView({super.key});

  @override
  Widget build(BuildContext context) => ViewModelProvider<FeatureViewModel>(
    create: (context) => FeatureViewModel(),
    builder: (context, viewModel, child) => _FeatureContent(viewModel),
  );
}
```

## 2. The Content File (`feature_content.dart`)
This file contains the actual UI layout and consumes the ViewModel.

**Rules:**
*   Must be named `[feature_name]_content.dart`.
*   Must be a `part of '[feature_name]_view.dart';`. Do NOT import anything here; all imports belong in `feature_view.dart`.
*   Must define a **private** `StatelessWidget` named `_[FeatureName]Content`.
*   Must accept `[FeatureName]ViewModel` as a final field via its constructor.
*   All UI layout and widget tree construction belongs here.

**Template:**
```dart
part of 'feature_view.dart';

class _FeatureContent extends StatelessWidget {
  const _FeatureContent(this.viewModel);

  final FeatureViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return const Placeholder(); // Build your UI here using viewModel
  }
}
```

## 3. The ViewModel File (`feature_view_model.dart`)
This file contains the state and business logic for the view.

**Rules:**
*   Must be named `[feature_name]_view_model.dart`.
*   Must define a class named `[FeatureName]ViewModel` that extends `BaseViewModel` (from `package:trovara/core/base/base_view_model.dart`).
*   Must handle state changes and notify listeners.
*   Must use `go_router` (e.g., `context.push`, `context.go`) for navigation if passing `BuildContext` to methods, though ideally navigation should be triggered by the UI based on state or via router services if applicable.

**Template:**
```dart
import 'package:flutter/material.dart';
import 'package:trovara/core/base/base_view_model.dart';

class FeatureViewModel extends BaseViewModel {
  // Add state variables and business logic here
}
```

## Summary Checklist for New Views
1. Create `lib/views/feature_name/` directory.
2. Create the 3 files using the exact naming and structural conventions above.
3. Keep `feature_content.dart` as a `part` file.
4. Put all UI in `feature_content.dart`.
5. Put all Logic in `feature_view_model.dart`.
6. Add the route to `app_router.dart`.