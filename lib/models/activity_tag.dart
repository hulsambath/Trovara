import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Represents an activity tag with icon and label
class ActivityTag {
  final String id;
  final IconData icon;
  final String label;
  final Color color;

  const ActivityTag({required this.id, required this.icon, required this.label, required this.color});

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ActivityTag && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ActivityTag(id: $id, icon: $icon, label: $label)';
}

/// Predefined activity tags
class ActivityTags {
  static const List<ActivityTag> all = [
    ActivityTag(
      id: 'work',
      icon: LucideIcons.briefcase,
      label: 'Work',
      color: Color(0xFF2196F3), // Blue
    ),
    ActivityTag(
      id: 'home',
      icon: LucideIcons.house,
      label: 'Home',
      color: Color(0xFF4CAF50), // Green
    ),
    ActivityTag(
      id: 'travel',
      icon: LucideIcons.plane,
      label: 'Travel',
      color: Color(0xFF9C27B0), // Purple
    ),
    ActivityTag(
      id: 'hobbies',
      icon: LucideIcons.palette,
      label: 'Hobbies',
      color: Color(0xFFFF9800), // Orange
    ),
    ActivityTag(
      id: 'health',
      icon: LucideIcons.heart,
      label: 'Health',
      color: Color(0xFFF44336), // Red
    ),
    ActivityTag(
      id: 'food',
      icon: LucideIcons.utensils,
      label: 'Food',
      color: Color(0xFF795548), // Brown
    ),
  ];

  /// Get an activity tag by its ID
  static ActivityTag? getById(String id) {
    try {
      return all.firstWhere((tag) => tag.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get activity tags by their IDs
  static List<ActivityTag> getByIds(List<String> ids) =>
      ids.map((id) => getById(id)).where((tag) => tag != null).cast<ActivityTag>().toList();

  /// Check if an activity tag exists by ID
  static bool exists(String id) => all.any((tag) => tag.id == id);
}
