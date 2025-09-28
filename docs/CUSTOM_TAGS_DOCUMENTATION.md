# Custom Tags Documentation

## Overview

The Custom Tags system in NoteMinds allows users to create, manage, and organize their notes with personalized tags. This system provides both string-based tags (for backward compatibility) and a new CustomTag-based approach with enhanced features like color coding, usage statistics, and smart suggestions.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Models](#models)
3. [Services](#services)
4. [Repositories](#repositories)
5. [UI Components](#ui-components)
6. [Integration](#integration)
7. [Usage Examples](#usage-examples)
8. [API Reference](#api-reference)
9. [Best Practices](#best-practices)
10. [Troubleshooting](#troubleshooting)

## Architecture Overview

The Custom Tags system follows a layered architecture:

```
UI Layer (Widgets)
    ↓
Service Layer (CustomTagService)
    ↓
Repository Layer (ICustomTagRepository)
    ↓
Data Layer (ObjectBox)
```

### Key Components

- **CustomTag Model**: Core data model with color, usage statistics, and metadata
- **CustomTagService**: Business logic layer for tag operations
- **ObjectBoxCustomTagRepository**: Data persistence layer
- **CustomTagsWidget**: Enhanced UI component with existing tag selection
- **CustomTagsIconButton**: App bar integration with dialog interface

## Models

### CustomTag Entity

```dart
@Entity()
class CustomTag {
  int id;
  String name;
  String color;
  DateTime createdAt;
  DateTime updatedAt;
  int usageCount;

  // Constructors and methods
  factory CustomTag.create(String name, {String? color});
  void updateName(String newName);
  void updateColor(String newColor);
  void incrementUsage();
  void decrementUsage();

  // Getters
  Color get displayColor;
  String get displayName;
}
```

### Static CustomTags Class

```dart
class CustomTags {
  static List<CustomTag> get all;
  static List<CustomTag> get mostUsed;
  static List<CustomTag> get sortedByName;
  static List<CustomTag> get newest;

  // Methods
  static CustomTag? getById(int id);
  static CustomTag? getByName(String name);
  static List<CustomTag> getByIds(List<int> ids);
  static bool exists(String name);
  static List<CustomTag> search(String query);
  static void updateCollection(List<CustomTag> tags);
}
```

## Services

### CustomTagService

The main service for managing custom tags:

```dart
class CustomTagService {
  // Initialization
  Future<void> initialize();

  // CRUD Operations
  Future<CustomTag> createOrGetCustomTag(String name, {String? color});
  CustomTag? getCustomTagById(int id);
  CustomTag? getCustomTagByName(String name);
  List<CustomTag> getAllCustomTags();
  Future<void> updateCustomTag(CustomTag tag);
  Future<void> deleteCustomTag(int id);

  // Search and Filtering
  List<CustomTag> searchCustomTags(String query);
  List<CustomTag> getMostUsedCustomTags();
  List<CustomTag> getCustomTagsSortedByName();
  List<CustomTag> getNewestCustomTags();

  // Statistics
  Map<String, int> getCustomTagStatistics();
  List<CustomTag> getUnusedCustomTags();
  List<CustomTag> getCustomTagsInUse();

  // Utility
  bool customTagExists(String name);
  bool customTagExistsById(int id);
  List<CustomTag> getCustomTagsByIds(List<int> ids);
}
```

## Repositories

### ICustomTagRepository Interface

```dart
abstract class ICustomTagRepository {
  Future<void> initialize();

  // CRUD Operations
  Future<CustomTag> createCustomTag(String name, {String? color});
  CustomTag? getCustomTagById(int id);
  CustomTag? getCustomTagByName(String name);
  List<CustomTag> getAllCustomTags();
  Future<void> updateCustomTag(CustomTag customTag);
  Future<void> deleteCustomTag(int id);

  // Search and Filtering
  List<CustomTag> searchCustomTags(String query);
  List<CustomTag> getMostUsedCustomTags();
  List<CustomTag> getCustomTagsSortedByName();
  List<CustomTag> getNewestCustomTags();

  // Statistics
  Map<String, int> getCustomTagStatistics();
  List<CustomTag> getUnusedCustomTags();
  List<CustomTag> getCustomTagsInUse();

  // Utility
  bool customTagExists(String name);
  bool customTagExistsById(int id);
  List<CustomTag> getCustomTagsByIds(List<int> ids);
}
```

### ObjectBoxCustomTagRepository Implementation

```dart
class ObjectBoxCustomTagRepository extends BaseRepository implements ICustomTagRepository {
  late Box<CustomTag> _customTagBox;

  // All interface methods implemented with ObjectBox
  // Includes proper listener management and error handling
}
```

## UI Components

### CustomTagsWidget

The main widget for managing custom tags with enhanced features:

#### Features

- **Existing Tags Section**: Shows all available custom tags for selection
- **Smart Filtering**: Only displays unselected existing tags
- **Usage Statistics**: Shows how many times each tag has been used
- **Color-coded Tags**: Visual identification with assigned colors
- **Text Input**: Create new tags by typing
- **Suggestions**: Auto-complete functionality while typing
- **Selected Tags**: Manage currently selected tags with remove functionality

#### Usage

```dart
// CustomTag-based approach (recommended)
CustomTagsWidget(
  selectedCustomTags: note.customTagObjects,
  onCustomTagsChanged: (customTags) async {
    final tagNames = customTags.map((tag) => tag.name).toList();
    await viewModel.updateCustomTags(tagNames);
  },
  availableTags: viewModel.getAvailableCustomTags(),
  hintText: 'Add custom tags...',
  maxTags: 20,
)

// String-based approach (backward compatibility)
CustomTagsWidget(
  selectedTags: note.tags,
  onTagsChanged: (tags) => viewModel.updateCustomTags(tags),
  hintText: 'Add custom tags...',
  maxTags: 20,
)
```

#### Widget Structure

```
CustomTagsWidget
├── Existing Tags Section (if availableTags provided)
│   ├── Section Header with Icon
│   └── Wrap of Existing Tag Chips
├── Text Input Section
│   ├── TextField with Add Button
│   └── Suggestions Dropdown (if typing)
└── Selected Tags Section
    ├── Section Header with Icon
    └── Wrap of Selected Tag Chips
```

### CompactCustomTagsWidget

Compact version for displaying tags in note cards:

```dart
// CustomTag-based approach
CompactCustomTagsWidget(
  selectedCustomTags: note.customTagObjects,
  maxDisplay: 3,
)

// String-based approach
CompactCustomTagsWidget(
  selectedTags: note.tags,
  maxDisplay: 3,
)
```

### CustomTagsIconButton

App bar integration with dialog interface:

```dart
CustomTagsIconButton(
  selectedTags: note.tags,
  onSelectionChanged: (tags) => viewModel.updateCustomTags(tags),
)
```

#### Dialog Features

- **Full CustomTagsWidget**: Complete functionality in dialog
- **Existing Tags Selection**: Click to add existing tags
- **Tag Management**: Add, remove, and organize tags
- **Responsive Design**: Adapts to screen size

## Integration

### Service Locator Integration

```dart
class ServiceLocator {
  ICustomTagRepository get customTagRepository => ObjectBoxCustomTagRepository();
  CustomTagService get customTagService => CustomTagService(customTagRepository: customTagRepository);

  Future<void> initialize() async {
    await noteService.initialize();
    await customTagService.initialize(); // ✅ Added
  }
}
```

### NoteViewModel Integration

```dart
class NoteViewModel extends BaseViewModel {
  final CustomTagService _customTagService = ServiceLocator().customTagService;

  Future<void> updateCustomTags(List<String> customTags) async {
    if (_currentNote != null) {
      _hasUnsavedChanges = true;

      final List<int> customTagIds = [];
      for (final tagName in customTags) {
        try {
          final customTag = await _customTagService.createOrGetCustomTag(tagName);
          customTagIds.add(customTag.id);
        } catch (e) {
          debugPrint('Error creating custom tag "$tagName": $e');
        }
      }

      _currentNote!.setCustomTags(customTagIds);
      notifyListeners();
    }
  }

  List<CustomTag> getAvailableCustomTags() => _customTagService.getAllCustomTags();
}
```

### Note Model Integration

```dart
@Entity()
class Note {
  List<int> customTagIds;

  // Methods
  void addCustomTag(int customTagId);
  void removeCustomTag(int customTagId);
  void setCustomTags(List<int> newCustomTagIds);

  // Getter
  List<CustomTag> get customTagObjects => CustomTags.getByIds(customTagIds);
}
```

## Usage Examples

### Basic Tag Creation

```dart
// Create a new custom tag
final customTag = await customTagService.createOrGetCustomTag('work');

// Create with custom color
final customTag = await customTagService.createOrGetCustomTag('important', color: '#FF5722');
```

### Tag Selection in UI

```dart
// In note content screen
CustomTagsWidget(
  selectedCustomTags: viewModel.currentNote?.customTagObjects ?? [],
  onCustomTagsChanged: (customTags) async {
    final tagNames = customTags.map((tag) => tag.name).toList();
    await viewModel.updateCustomTags(tagNames);
  },
  availableTags: viewModel.getAvailableCustomTags(),
  hintText: 'Add custom tags...',
  maxTags: 20,
)
```

### Tag Search and Filtering

```dart
// Search tags by name
final searchResults = customTagService.searchCustomTags('work');

// Get most used tags
final popularTags = customTagService.getMostUsedCustomTags();

// Get tags sorted by name
final sortedTags = customTagService.getCustomTagsSortedByName();
```

### Tag Statistics

```dart
// Get tag statistics
final stats = customTagService.getCustomTagStatistics();
print('Total tags: ${stats['total']}');
print('Tags in use: ${stats['inUse']}');
print('Unused tags: ${stats['unused']}');
```

## API Reference

### CustomTagService Methods

| Method                                | Return Type         | Description                          |
| ------------------------------------- | ------------------- | ------------------------------------ |
| `initialize()`                        | `Future<void>`      | Initialize the service and load tags |
| `createOrGetCustomTag(name, {color})` | `Future<CustomTag>` | Create new tag or get existing       |
| `getCustomTagById(id)`                | `CustomTag?`        | Get tag by ID                        |
| `getCustomTagByName(name)`            | `CustomTag?`        | Get tag by name                      |
| `getAllCustomTags()`                  | `List<CustomTag>`   | Get all tags                         |
| `searchCustomTags(query)`             | `List<CustomTag>`   | Search tags by name                  |
| `getMostUsedCustomTags()`             | `List<CustomTag>`   | Get tags sorted by usage             |
| `getCustomTagStatistics()`            | `Map<String, int>`  | Get usage statistics                 |
| `deleteCustomTag(id)`                 | `Future<void>`      | Delete tag by ID                     |

### CustomTagsWidget Properties

| Property              | Type                         | Description                    |
| --------------------- | ---------------------------- | ------------------------------ |
| `selectedCustomTags`  | `List<CustomTag>?`           | Currently selected tags        |
| `onCustomTagsChanged` | `Function(List<CustomTag>)?` | Callback for tag changes       |
| `availableTags`       | `List<CustomTag>?`           | Available tags for selection   |
| `hintText`            | `String?`                    | Placeholder text for input     |
| `maxTags`             | `int`                        | Maximum number of tags allowed |
| `enabled`             | `bool`                       | Whether widget is interactive  |

### CustomTag Model Properties

| Property       | Type       | Description            |
| -------------- | ---------- | ---------------------- |
| `id`           | `int`      | Unique identifier      |
| `name`         | `String`   | Tag name               |
| `color`        | `String`   | Hex color code         |
| `createdAt`    | `DateTime` | Creation timestamp     |
| `updatedAt`    | `DateTime` | Last update timestamp  |
| `usageCount`   | `int`      | Number of times used   |
| `displayColor` | `Color`    | Flutter Color object   |
| `displayName`  | `String`   | Formatted display name |

## Best Practices

### 1. Tag Naming

- Use descriptive, consistent names
- Avoid special characters and spaces
- Use lowercase for consistency
- Keep names concise but clear

```dart
// Good
'work', 'personal', 'important', 'meeting'

// Avoid
'Work Stuff!!!', 'my-tag', 'Tag With Spaces'
```

### 2. Color Selection

- Use consistent color schemes
- Choose colors with good contrast
- Consider color accessibility
- Use semantic colors when possible

```dart
// Good color choices
'#2196F3', '#4CAF50', '#FF9800', '#F44336'

// Avoid
'#000000', '#FFFFFF', '#FF00FF'
```

### 3. Performance Considerations

- Use `getAvailableCustomTags()` sparingly
- Cache tag lists when possible
- Implement proper error handling
- Use async/await correctly

### 4. UI/UX Guidelines

- Show usage statistics to encourage tag reuse
- Provide clear visual feedback
- Use consistent spacing and sizing
- Implement proper loading states

## Troubleshooting

### Common Issues

#### 1. Tags Not Saving

**Problem**: Custom tags are not being saved to ObjectBox.

**Solution**: Ensure CustomTagService is properly initialized and integrated:

```dart
// In ServiceLocator
Future<void> initialize() async {
  await customTagService.initialize();
}

// In NoteViewModel
Future<void> updateCustomTags(List<String> customTags) async {
  // Make sure to await the async operation
  for (final tagName in customTags) {
    final customTag = await _customTagService.createOrGetCustomTag(tagName);
    customTagIds.add(customTag.id);
  }
}
```

#### 2. Existing Tags Not Showing

**Problem**: Existing tags are not displayed in the widget.

**Solution**: Ensure `availableTags` is provided and CustomTagService is working:

```dart
CustomTagsWidget(
  availableTags: viewModel.getAvailableCustomTags(), // ✅ Required
  // ... other properties
)
```

#### 3. Static Collection Not Updated

**Problem**: `CustomTags.getByIds()` returns empty list.

**Solution**: Ensure CustomTagService updates the static collection:

```dart
// In CustomTagService
Future<CustomTag> createOrGetCustomTag(String name, {String? color}) async {
  final customTag = await _customTagRepository.createCustomTag(name, color: color);
  // Update the static collection
  CustomTags.updateCollection(_customTagRepository.getAllCustomTags());
  return customTag;
}
```

#### 4. Dialog Not Showing Existing Tags

**Problem**: Dialog doesn't show existing tags section.

**Solution**: Ensure the dialog uses CustomTag-based approach:

```dart
CustomTagsWidget(
  selectedCustomTags: _currentCustomTags,        // ✅ Use CustomTag objects
  onCustomTagsChanged: _updateCustomTags,        // ✅ CustomTag callback
  availableTags: getAvailableCustomTags(),       // ✅ Provide available tags
)
```

### Debug Tips

1. **Check Service Initialization**: Ensure CustomTagService is initialized
2. **Verify Data Flow**: Check that tags are being created and saved
3. **Inspect Static Collection**: Verify `CustomTags.updateCollection()` is called
4. **Test UI Components**: Ensure widgets receive proper data
5. **Check Error Handling**: Look for exceptions in async operations

### Performance Optimization

1. **Lazy Loading**: Load tags only when needed
2. **Caching**: Cache frequently accessed tag lists
3. **Debouncing**: Implement debouncing for search operations
4. **Pagination**: Consider pagination for large tag lists

## Migration Guide

### From String-based to CustomTag-based

1. **Update Widget Usage**:

```dart
// Before
CustomTagsWidget(
  selectedTags: note.tags,
  onTagsChanged: (tags) => updateTags(tags),
)

// After
CustomTagsWidget(
  selectedCustomTags: note.customTagObjects,
  onCustomTagsChanged: (customTags) async {
    final tagNames = customTags.map((tag) => tag.name).toList();
    await updateCustomTags(tagNames);
  },
  availableTags: getAvailableCustomTags(),
)
```

2. **Update ViewModel Methods**:

```dart
// Before
void updateCustomTags(List<String> customTags) {
  _currentNote!.tags = customTags;
}

// After
Future<void> updateCustomTags(List<String> customTags) async {
  final List<int> customTagIds = [];
  for (final tagName in customTags) {
    final customTag = await _customTagService.createOrGetCustomTag(tagName);
    customTagIds.add(customTag.id);
  }
  _currentNote!.setCustomTags(customTagIds);
}
```

3. **Update Service Integration**:

```dart
// Add to ServiceLocator
CustomTagService get customTagService => CustomTagService(customTagRepository: customTagRepository);

// Initialize in app startup
await customTagService.initialize();
```

## Conclusion

The Custom Tags system provides a comprehensive solution for tag management in NoteMinds. It offers both backward compatibility and enhanced features, making it easy to migrate existing implementations while providing powerful new capabilities for tag organization and management.

For additional support or questions, refer to the code examples in the `/lib/widgets/tages/custom/` directory and the integration examples in the note editing screens.
