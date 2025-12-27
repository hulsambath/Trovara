# Tag System and Analytics

## Tag System Overview

### Tag Types

#### 1. Activity Tags
```dart
class ActivityTag extends Tag {
  static const work = ActivityTag(
    id: 'work',
    label: 'Work',
    icon: Icons.work,
    color: Colors.blue,
  );
  
  // Other predefined tags...
}
```

#### 2. Mood Tags
```dart
class MoodTag extends Tag {
  static const happy = MoodTag(
    id: 'happy',
    label: 'Happy',
    icon: Icons.sentiment_very_satisfied,
    color: Colors.amber,
  );
  
  // Other moods...
}
```

#### 3. Time Tags
```dart
class TimeTag extends Tag {
  static const morning = TimeTag(
    id: 'morning',
    label: 'Morning',
    icon: Icons.wb_sunny,
    color: Colors.orange,
    timeRange: TimeRange(
      start: TimeOfDay(hour: 6, minute: 0),
      end: TimeOfDay(hour: 12, minute: 0),
    ),
  );
  
  // Other time periods...
}
```

#### 4. Custom Tags
```dart
@Entity()
class CustomTag extends Tag {
  String id;
  String label;
  String colorHex;
  int usageCount;
  DateTime lastUsed;
  
  // Generated methods...
}
```

## Analytics System

### 1. Data Collection

#### Note Analytics
```dart
class NoteAnalytics {
  final int totalNotes;
  final Map<String, int> tagCounts;
  final Map<DateTime, int> activityHeatmap;
  final List<TimeSeriesPoint> noteCreationTrend;
  
  Future<void> calculate() async {
    // Implementation...
  }
}
```

#### Tag Usage Analytics
```dart
class TagAnalytics {
  Map<String, int> getTagUsageByType(TagType type);
  List<Tag> getMostUsedTags(int limit);
  Map<DateTime, List<Tag>> getTagTrends();
}
```

### 2. Visualization

#### Activity Heatmap
```dart
class ActivityHeatmap extends StatelessWidget {
  final Map<DateTime, int> data;
  
  Widget build(BuildContext context) => GridView.builder(
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 7,  // Days per week
    ),
    itemBuilder: (context, index) => HeatmapCell(
      intensity: data[dates[index]] ?? 0,
    ),
  );
}
```

#### Tag Distribution Chart
```dart
class TagDistributionChart extends StatelessWidget {
  final Map<String, int> distribution;
  
  Widget build(BuildContext context) => PieChart(
    sections: distribution.entries.map((e) => 
      PieChartSectionData(
        value: e.value.toDouble(),
        title: e.key,
      ),
    ).toList(),
  );
}
```

### 3. Insights Generation

#### Time-based Insights
```dart
class TimeBasedInsights {
  String getMostProductiveTime() {
    // Analysis implementation...
  }
  
  String getMoodTrends() {
    // Analysis implementation...
  }
  
  List<String> getActivityPatterns() {
    // Analysis implementation...
  }
}
```

#### Content Analysis
```dart
class ContentAnalysis {
  Map<String, int> getWordFrequency();
  double getAverageNoteLength();
  List<String> getCommonTopics();
}
```

## Tag Management

### 1. Tag Selection
```dart
class TagSelector extends StatelessWidget {
  final List<Tag> selectedTags;
  final ValueChanged<Tag> onTagSelected;
  
  Widget build(BuildContext context) => Wrap(
    children: [
      ActivityTagSelector(
        selected: selectedTags,
        onSelected: onTagSelected,
      ),
      MoodTagSelector(
        selected: selectedTags,
        onSelected: onTagSelected,
      ),
      TimeTagSelector(
        selected: selectedTags,
        onSelected: onTagSelected,
      ),
      CustomTagSelector(
        selected: selectedTags,
        onSelected: onTagSelected,
      ),
    ],
  );
}
```

### 2. Custom Tag Creation
```dart
class CustomTagCreator extends StatefulWidget {
  Widget build(BuildContext context) => Form(
    child: Column(
      children: [
        TextFormField(
          decoration: InputDecoration(
            labelText: 'Tag Name',
          ),
        ),
        ColorPicker(
          onColorSelected: (color) {
            // Handle color selection
          },
        ),
        ElevatedButton(
          onPressed: () {
            // Save custom tag
          },
          child: Text('Create Tag'),
        ),
      ],
    ),
  );
}
```

### 3. Tag Search and Filtering
```dart
class TagSearchDelegate extends SearchDelegate<Tag> {
  final List<Tag> tags;
  
  @override
  Widget buildResults(BuildContext context) => ListView(
    children: tags
      .where((tag) => tag.label.toLowerCase()
        .contains(query.toLowerCase()))
      .map((tag) => ListTile(
        title: Text(tag.label),
        leading: Icon(tag.icon),
        onTap: () => close(context, tag),
      ))
      .toList(),
  );
}
```

## Data Export

### 1. Analytics Export
```dart
class AnalyticsExporter {
  Future<File> exportToCsv() async {
    // Export implementation...
  }
  
  Future<File> exportToJson() async {
    // Export implementation...
  }
}
```

### 2. Visualization Export
```dart
class ChartExporter {
  Future<File> exportAsImage(Widget chart) async {
    // Export implementation...
  }
  
  Future<File> exportAsPdf(List<Widget> charts) async {
    // Export implementation...
  }
}
```