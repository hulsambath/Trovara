import 'package:flutter/material.dart';

/// Represents a time-based tag with icon and label
class TimeTag {
  final String id;
  final IconData icon;
  final String label;
  final Color color;
  final String description;

  const TimeTag({
    required this.id,
    required this.icon,
    required this.label,
    required this.color,
    required this.description,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TimeTag && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'TimeTag(id: $id, icon: $icon, label: $label)';
}

/// Predefined time-based tags
class TimeTags {
  static const List<TimeTag> all = [
    TimeTag(
      id: 'morning',
      icon: Icons.wb_sunny_outlined,
      label: 'Morning',
      color: Color(0xFFFF9800), // Orange
      description: '6:00 AM - 12:00 PM',
    ),
    TimeTag(
      id: 'afternoon',
      icon: Icons.wb_sunny,
      label: 'Afternoon',
      color: Color(0xFFFFC107), // Amber
      description: '12:00 PM - 6:00 PM',
    ),
    TimeTag(
      id: 'evening',
      icon: Icons.wb_twilight,
      label: 'Evening',
      color: Color(0xFF9C27B0), // Purple
      description: '6:00 PM - 9:00 PM',
    ),
    TimeTag(
      id: 'night',
      icon: Icons.nights_stay_outlined,
      label: 'Night',
      color: Color(0xFF3F51B5), // Indigo
      description: '9:00 PM - 6:00 AM',
    ),
    TimeTag(
      id: 'weekday',
      icon: Icons.work_outline,
      label: 'Weekday',
      color: Color(0xFF2196F3), // Blue
      description: 'Monday - Friday',
    ),
    TimeTag(
      id: 'weekend',
      icon: Icons.weekend_outlined,
      label: 'Weekend',
      color: Color(0xFF4CAF50), // Green
      description: 'Saturday - Sunday',
    ),
  ];

  /// Get a time tag by its ID
  static TimeTag? getById(String id) {
    try {
      return all.firstWhere((tag) => tag.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get time tags by their IDs
  static List<TimeTag> getByIds(List<String> ids) =>
      ids.map((id) => getById(id)).where((tag) => tag != null).cast<TimeTag>().toList();

  /// Check if a time tag exists by ID
  static bool exists(String id) => all.any((tag) => tag.id == id);

  /// Get time-based suggestions based on current DateTime
  static List<String> getTimeBasedSuggestions([DateTime? dateTime]) {
    final now = dateTime ?? DateTime.now();
    final suggestions = <String>[];

    // Time of day suggestions
    final hour = now.hour;
    if (hour >= 6 && hour < 12) {
      suggestions.add('morning');
    } else if (hour >= 12 && hour < 18) {
      suggestions.add('afternoon');
    } else if (hour >= 18 && hour < 21) {
      suggestions.add('evening');
    } else {
      suggestions.add('night');
    }

    // Day of week suggestions
    final weekday = now.weekday;
    if (weekday >= 1 && weekday <= 5) {
      suggestions.add('weekday');
    } else {
      suggestions.add('weekend');
    }

    return suggestions;
  }

  /// Get all time tags except the suggested ones
  static List<TimeTag> getAlternativeTags(List<String> suggestedIds) =>
      all.where((tag) => !suggestedIds.contains(tag.id)).toList();

  /// Get suggested time tags
  static List<TimeTag> getSuggestedTags([DateTime? dateTime]) {
    final suggestedIds = getTimeBasedSuggestions(dateTime);
    return getByIds(suggestedIds);
  }
}
