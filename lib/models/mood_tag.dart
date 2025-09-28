import 'package:flutter/material.dart';

/// Represents a mood tag with emoji and label
class MoodTag {
  final String id;
  final String emoji;
  final String label;
  final Color color;

  const MoodTag({required this.id, required this.emoji, required this.label, required this.color});

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MoodTag && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'MoodTag(id: $id, emoji: $emoji, label: $label)';
}

/// Predefined mood tags with emoji icons
class MoodTags {
  static const List<MoodTag> all = [
    MoodTag(
      id: 'happy',
      emoji: '😊',
      label: 'Happy',
      color: Color(0xFF4CAF50), // Green
    ),
    MoodTag(
      id: 'sad',
      emoji: '😢',
      label: 'Sad',
      color: Color(0xFF2196F3), // Blue
    ),
    MoodTag(
      id: 'angry',
      emoji: '😠',
      label: 'Angry',
      color: Color(0xFFF44336), // Red
    ),
    MoodTag(
      id: 'calm',
      emoji: '😌',
      label: 'Calm',
      color: Color(0xFF9C27B0), // Purple
    ),
    MoodTag(
      id: 'stressed',
      emoji: '😰',
      label: 'Stressed',
      color: Color(0xFFFF9800), // Orange
    ),
    MoodTag(
      id: 'grateful',
      emoji: '🙏',
      label: 'Grateful',
      color: Color(0xFF795548), // Brown
    ),
  ];

  /// Get a mood tag by its ID
  static MoodTag? getById(String id) {
    try {
      return all.firstWhere((tag) => tag.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get mood tags by their IDs
  static List<MoodTag> getByIds(List<String> ids) =>
      ids.map((id) => getById(id)).where((tag) => tag != null).cast<MoodTag>().toList();

  /// Check if a mood tag exists by ID
  static bool exists(String id) => all.any((tag) => tag.id == id);
}
