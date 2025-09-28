import 'package:flutter/material.dart';

/// Represents a personal growth tag with icon and label
class PersonalGrowthTag {
  final String id;
  final IconData icon;
  final String label;
  final Color color;
  final String description;

  const PersonalGrowthTag({
    required this.id,
    required this.icon,
    required this.label,
    required this.color,
    required this.description,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PersonalGrowthTag && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PersonalGrowthTag(id: $id, icon: $icon, label: $label)';
}

/// Predefined personal growth tags
class PersonalGrowthTags {
  static const List<PersonalGrowthTag> all = [
    PersonalGrowthTag(
      id: 'learning',
      icon: Icons.school_outlined,
      label: 'Learning',
      color: Color(0xFF2196F3), // Blue
      description: 'Educational activities and skill development',
    ),
    PersonalGrowthTag(
      id: 'goals',
      icon: Icons.flag_outlined,
      label: 'Goals',
      color: Color(0xFF4CAF50), // Green
      description: 'Personal and professional objectives',
    ),
    PersonalGrowthTag(
      id: 'self-care',
      icon: Icons.spa_outlined,
      label: 'Self-Care',
      color: Color(0xFF9C27B0), // Purple
      description: 'Mental and physical wellness activities',
    ),
    PersonalGrowthTag(
      id: 'creativity',
      icon: Icons.palette_outlined,
      label: 'Creativity',
      color: Color(0xFFFF9800), // Orange
      description: 'Artistic and creative pursuits',
    ),
    PersonalGrowthTag(
      id: 'reflection',
      icon: Icons.psychology_outlined,
      label: 'Reflection',
      color: Color(0xFF795548), // Brown
      description: 'Self-reflection and mindfulness',
    ),
    PersonalGrowthTag(
      id: 'achievement',
      icon: Icons.emoji_events_outlined,
      label: 'Achievement',
      color: Color(0xFFFFC107), // Amber
      description: 'Accomplishments and milestones',
    ),
  ];

  /// Get a personal growth tag by its ID
  static PersonalGrowthTag? getById(String id) {
    try {
      return all.firstWhere((tag) => tag.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get personal growth tags by their IDs
  static List<PersonalGrowthTag> getByIds(List<String> ids) =>
      ids.map((id) => getById(id)).where((tag) => tag != null).cast<PersonalGrowthTag>().toList();

  /// Check if a personal growth tag exists by ID
  static bool exists(String id) => all.any((tag) => tag.id == id);
}
