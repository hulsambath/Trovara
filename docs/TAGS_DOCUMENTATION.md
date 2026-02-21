# notemyminds Tags System Documentation

This document provides comprehensive documentation for the tag system in the notemyminds Flutter application. The app supports four types of tags: Activity, Mood, Time, and Personal Growth tags.

## Table of Contents

1. [Overview](#overview)
2. [Tag Types](#tag-types)
   - [Activity Tags](#activity-tags)
   - [Mood Tags](#mood-tags)
   - [Time Tags](#time-tags)
   - [Personal Growth Tags](#personal-growth-tags)
3. [Widget Components](#widget-components)
4. [Integration Guide](#integration-guide)
5. [API Reference](#api-reference)
6. [Usage Examples](#usage-examples)

## Overview

The notemyminds tag system allows users to categorize and organize their notes using predefined tags. Each tag type serves a specific purpose and provides different ways to filter and organize content.

### Key Features

- **Multi-selection**: Users can select multiple tags of each type
- **Visual Feedback**: Selected tags are highlighted with their respective colors
- **Consistent UI**: All tag types follow the same design patterns
- **State Management**: Tags automatically update the note object
- **Persistence**: Tags are saved with notes and persist across sessions

## Tag Types

### Activity Tags

Activity tags help categorize notes based on what the user was doing when they wrote the note.

#### Available Tags

| ID        | Label   | Icon | Color            | Description                |
| --------- | ------- | ---- | ---------------- | -------------------------- |
| `work`    | Work    | 💼   | Blue (#2196F3)   | Work-related activities    |
| `home`    | Home    | 🏠   | Green (#4CAF50)  | Home and family activities |
| `travel`  | Travel  | ✈️   | Purple (#9C27B0) | Travel and transportation  |
| `hobbies` | Hobbies | 🎨   | Orange (#FF9800) | Recreational activities    |
| `health`  | Health  | ❤️   | Red (#F44336)    | Health and fitness         |
| `food`    | Food    | 🍽️   | Brown (#795548)  | Food and dining            |

#### Model Structure

```dart
class ActivityTag {
  final String id;
  final IconData icon;
  final String label;
  final Color color;
}
```

### Mood Tags

Mood tags capture the emotional state when writing the note using emoji representations.

#### Available Tags

| ID         | Label    | Emoji | Color            | Description                 |
| ---------- | -------- | ----- | ---------------- | --------------------------- |
| `happy`    | Happy    | 😊    | Green (#4CAF50)  | Positive, cheerful mood     |
| `sad`      | Sad      | 😢    | Blue (#2196F3)   | Melancholy, down mood       |
| `angry`    | Angry    | 😠    | Red (#F44336)    | Frustrated, upset mood      |
| `calm`     | Calm     | 😌    | Purple (#9C27B0) | Peaceful, relaxed mood      |
| `stressed` | Stressed | 😰    | Orange (#FF9800) | Anxious, overwhelmed mood   |
| `grateful` | Grateful | 🙏    | Brown (#795548)  | Thankful, appreciative mood |

#### Model Structure

```dart
class MoodTag {
  final String id;
  final String emoji;
  final String label;
  final Color color;
}
```

### Time Tags

Time tags categorize notes based on when they were written, with automatic suggestions based on current time.

#### Available Tags

| ID          | Label     | Icon | Color            | Time Range         | Description          |
| ----------- | --------- | ---- | ---------------- | ------------------ | -------------------- |
| `morning`   | Morning   | ☀️   | Orange (#FF9800) | 6:00 AM - 12:00 PM | Early day activities |
| `afternoon` | Afternoon | ☀️   | Amber (#FFC107)  | 12:00 PM - 6:00 PM | Mid-day activities   |
| `evening`   | Evening   | 🌆   | Purple (#9C27B0) | 6:00 PM - 9:00 PM  | Late day activities  |
| `night`     | Night     | 🌙   | Indigo (#3F51B5) | 9:00 PM - 6:00 AM  | Night activities     |
| `weekday`   | Weekday   | 💼   | Blue (#2196F3)   | Monday - Friday    | Work days            |
| `weekend`   | Weekend   | 🏖️   | Green (#4CAF50)  | Saturday - Sunday  | Weekend days         |

#### Special Features

- **Automatic Suggestions**: Time tags automatically suggest relevant tags based on current time
- **Smart Selection**: New notes get time-based suggestions pre-selected
- **Context Awareness**: Suggestions change based on creation time

#### Model Structure

```dart
class TimeTag {
  final String id;
  final IconData icon;
  final String label;
  final Color color;
  final String description;
}
```

### Personal Growth Tags

Personal growth tags help categorize notes related to self-improvement and development.

#### Available Tags

| ID            | Label       | Icon | Color            | Description                                  |
| ------------- | ----------- | ---- | ---------------- | -------------------------------------------- |
| `learning`    | Learning    | 🎓   | Blue (#2196F3)   | Educational activities and skill development |
| `goals`       | Goals       | 🏁   | Green (#4CAF50)  | Personal and professional objectives         |
| `self-care`   | Self-Care   | 🧘   | Purple (#9C27B0) | Mental and physical wellness activities      |
| `creativity`  | Creativity  | 🎨   | Orange (#FF9800) | Artistic and creative pursuits               |
| `reflection`  | Reflection  | 🧠   | Brown (#795548)  | Self-reflection and mindfulness              |
| `achievement` | Achievement | 🏆   | Amber (#FFC107)  | Accomplishments and milestones               |

#### Model Structure

```dart
class PersonalGrowthTag {
  final String id;
  final IconData icon;
  final String label;
  final Color color;
  final String description;
}
```

## Widget Components

Each tag type has two main widget components:

### 1. Chips Widgets

Display tags as selectable chips in the note editing interface.

#### Available Chips Widgets

- `ActivityChips` - Wrap layout for activity tags
- `MoodChips` - Wrap layout for mood tags
- `TimeChips` - Smart time tags with auto-suggestions
- `PersonalGrowthChips` - Horizontal scrollable layout

#### Common Properties

```dart
class TagChips extends StatelessWidget {
  final List<String> selectedTagIds;
  final ValueChanged<List<String>> onSelectionChanged;
  final bool isCompact;
}
```

### 2. Icon Button Widgets

Compact icon buttons for app bars that show selected tags and open selection dialogs.

#### Available Icon Button Widgets

- `ActivityIconButton`
- `MoodIconButton`
- `TimeIconButton`
- `PersonalGrowthIconButton`

#### Common Properties

```dart
class TagIconButton extends StatelessWidget {
  final List<String> selectedTagIds;
  final ValueChanged<List<String>> onSelectionChanged;
}
```

### 3. Compact Chips Widgets

Smaller versions of chips for use in note cards and lists.

#### Available Compact Widgets

- `CompactActivityChips`
- `CompactMoodChips`
- `CompactTimeChips`
- `CompactPersonalGrowthChips`

## Integration Guide

### Adding Tags to Note Editing Screen

1. **Import the required widgets**:

```dart
import 'package:notemyminds/widgets/tages/activity/activity_icon_button.dart';
import 'package:notemyminds/widgets/tages/mood/mood_icon_button.dart';
import 'package:notemyminds/widgets/tages/time/time_icon_button.dart';
import 'package:notemyminds/widgets/tages/personal_growth/personal_growth_icon_button.dart';
```

2. **Add icon buttons to app bar**:

```dart
AppBar(
  actions: [
    TimeIconButton(
      selectedTimeIds: viewModel.currentNote?.timeTags ?? [],
      onSelectionChanged: viewModel.updateTimeTags,
      creationTime: viewModel.currentNote?.createdAt,
      showSuggestions: viewModel.isNewNote,
    ),
    ActivityIconButton(
      selectedActivityIds: viewModel.currentNote?.activityTags ?? [],
      onSelectionChanged: viewModel.updateActivityTags,
    ),
    MoodIconButton(
      selectedMoodIds: viewModel.currentNote?.moodTags ?? [],
      onSelectionChanged: viewModel.updateMoodTags,
    ),
    PersonalGrowthIconButton(
      selectedPersonalGrowthIds: viewModel.currentNote?.personalGrowthTags ?? [],
      onSelectionChanged: viewModel.updatePersonalGrowthTags,
    ),
  ],
)
```

3. **Add update methods to view model**:

```dart
void updateActivityTags(List<String> activityTagIds) {
  if (_currentNote != null) {
    _hasUnsavedChanges = true;
    _currentNote!.setActivityTags(activityTagIds);
    notifyListeners();
  }
}

void updateMoodTags(List<String> moodTagIds) {
  if (_currentNote != null) {
    _hasUnsavedChanges = true;
    _currentNote!.setMoodTags(moodTagIds);
    notifyListeners();
  }
}

void updateTimeTags(List<String> timeTagIds) {
  if (_currentNote != null) {
    _hasUnsavedChanges = true;
    _currentNote!.setTimeTags(timeTagIds);
    notifyListeners();
  }
}

void updatePersonalGrowthTags(List<String> personalGrowthTagIds) {
  if (_currentNote != null) {
    _hasUnsavedChanges = true;
    _currentNote!.setPersonalGrowthTags(personalGrowthTagIds);
    notifyListeners();
  }
}
```

### Adding Chips to Note Body

For better user experience, you can also add chips directly to the note editing body:

```dart
// Import chips widgets
import 'package:notemyminds/widgets/tages/activity/activity_chips.dart';
import 'package:notemyminds/widgets/tages/mood/mood_chips.dart';
import 'package:notemyminds/widgets/tages/time/time_chips.dart';
import 'package:notemyminds/widgets/tages/personal_growth/personal_growth_chips.dart';

// Add to note body
Column(
  children: [
    // Title field
    TextFormField(...),

    // Activity tags
    ActivityChips(
      selectedActivityIds: viewModel.currentNote?.activityTags ?? [],
      onSelectionChanged: viewModel.updateActivityTags,
    ),

    // Mood tags
    MoodChips(
      selectedMoodIds: viewModel.currentNote?.moodTags ?? [],
      onSelectionChanged: viewModel.updateMoodTags,
    ),

    // Time tags
    TimeChips(
      selectedTimeIds: viewModel.currentNote?.timeTags ?? [],
      onSelectionChanged: viewModel.updateTimeTags,
      creationTime: viewModel.currentNote?.createdAt,
      showSuggestions: viewModel.isNewNote,
    ),

    // Personal growth tags
    PersonalGrowthChips(
      selectedPersonalGrowthIds: viewModel.currentNote?.personalGrowthTags ?? [],
      onSelectionChanged: viewModel.updatePersonalGrowthTags,
    ),

    // Note editor
    Expanded(child: QuillEditor(...)),
  ],
)
```

## API Reference

### Note Model Methods

The `Note` class provides methods for managing all tag types:

#### Activity Tags

```dart
void addActivityTag(String activityTagId)
void removeActivityTag(String activityTagId)
void setActivityTags(List<String> newActivityTags)
List<ActivityTag> get activityTagObjects
```

#### Mood Tags

```dart
void addMoodTag(String moodTagId)
void removeMoodTag(String moodTagId)
void setMoodTags(List<String> newMoodTags)
List<MoodTag> get moodTagObjects
```

#### Time Tags

```dart
void addTimeTag(String timeTagId)
void removeTimeTag(String timeTagId)
void setTimeTags(List<String> newTimeTags)
List<TimeTag> get timeTagObjects
```

#### Personal Growth Tags

```dart
void addPersonalGrowthTag(String personalGrowthTagId)
void removePersonalGrowthTag(String personalGrowthTagId)
void setPersonalGrowthTags(List<String> newPersonalGrowthTags)
List<PersonalGrowthTag> get personalGrowthTagObjects
```

### Tag Collection Methods

Each tag type provides utility methods:

```dart
// Get tag by ID
static TagType? getById(String id)

// Get multiple tags by IDs
static List<TagType> getByIds(List<String> ids)

// Check if tag exists
static bool exists(String id)

// Get all available tags
static List<TagType> get all
```

### Time Tags Special Methods

Time tags include additional smart features:

```dart
// Get time-based suggestions
static List<String> getTimeBasedSuggestions([DateTime? dateTime])

// Get suggested tag objects
static List<TimeTag> getSuggestedTags([DateTime? dateTime])

// Get alternative tags (non-suggested)
static List<TimeTag> getAlternativeTags(List<String> suggestedIds)
```

## Usage Examples

### Basic Tag Selection

```dart
// Create a note with tags
final note = Note(
  title: 'My Note',
  contentJson: '[{"insert":"\\n"}]',
  activityTags: ['work', 'home'],
  moodTags: ['happy', 'calm'],
  timeTags: ['morning'],
  personalGrowthTags: ['learning', 'goals'],
);

// Add a tag
note.addActivityTag('travel');

// Remove a tag
note.removeMoodTag('sad');

// Set multiple tags
note.setPersonalGrowthTags(['creativity', 'self-care', 'reflection']);
```

### Using Tag Objects

```dart
// Get tag objects for display
final activityTags = note.activityTagObjects;
final moodTags = note.moodTagObjects;
final timeTags = note.timeTagObjects;
final personalGrowthTags = note.personalGrowthTagObjects;

// Display tag information
for (final tag in activityTags) {
  print('${tag.label}: ${tag.icon} (${tag.color})');
}
```

### Time-based Suggestions

```dart
// Get current time suggestions
final suggestions = TimeTags.getTimeBasedSuggestions();

// Get suggestions for specific time
final morningSuggestions = TimeTags.getTimeBasedSuggestions(
  DateTime(2024, 1, 1, 9, 0) // 9:00 AM
);

// Get suggested tag objects
final suggestedTags = TimeTags.getSuggestedTags();
```

### Widget Integration

```dart
// In a note card widget
class NoteCard extends StatelessWidget {
  final Note note;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Text(note.title),
          Text(note.content),

          // Show compact tags
          if (note.activityTags.isNotEmpty)
            CompactActivityChips(
              selectedActivityIds: note.activityTags,
              maxDisplay: 2,
            ),

          if (note.moodTags.isNotEmpty)
            CompactMoodChips(
              selectedMoodIds: note.moodTags,
              maxDisplay: 3,
            ),
        ],
      ),
    );
  }
}
```

## Best Practices

1. **Consistent Usage**: Use the same tag selection pattern across all screens
2. **Visual Hierarchy**: Use compact chips in lists and full chips in editing screens
3. **Smart Defaults**: Leverage time-based suggestions for new notes
4. **User Feedback**: Provide visual feedback when tags are selected/deselected
5. **Performance**: Use `isCompact` flag for better performance in lists
6. **Accessibility**: Ensure all tags have proper labels and tooltips

## File Structure

```
lib/
├── models/
│   ├── activity_tag.dart
│   ├── mood_tag.dart
│   ├── time_tag.dart
│   ├── personal_growth_tag.dart
│   └── note.dart
└── widgets/
    └── tages/
        ├── activity/
        │   ├── activity_chips.dart
        │   └── activity_icon_button.dart
        ├── mood/
        │   ├── mood_chips.dart
        │   └── mood_icon_button.dart
        ├── time/
        │   ├── time_chips.dart
        │   └── time_icon_button.dart
        └── personal_growth/
            ├── personal_growth_chips.dart
            ├── personal_growth_icon_button.dart
            └── README.md
```

This documentation provides a complete guide to the notemyminds tag system. For specific implementation details, refer to the individual widget and model files.
