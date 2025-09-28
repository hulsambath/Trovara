import 'dart:ui';

import 'package:objectbox/objectbox.dart';

/// Model for storing custom tags that can be reused across notes
@Entity()
class CustomTag {
  int id;
  String name;
  String color;
  DateTime createdAt;
  DateTime updatedAt;
  int usageCount; // How many notes use this tag

  CustomTag({
    this.id = 0,
    required this.name,
    this.color = '#2196F3', // Default blue color
    DateTime? createdAt,
    DateTime? updatedAt,
    this.usageCount = 0,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Create a new custom tag
  factory CustomTag.create(String name, {String? color}) => CustomTag(name: name.trim(), color: color ?? '#2196F3');

  /// Update the tag name
  void updateName(String newName) {
    name = newName.trim();
    updatedAt = DateTime.now();
  }

  /// Update the tag color
  void updateColor(String newColor) {
    color = newColor;
    updatedAt = DateTime.now();
  }

  /// Increment usage count when tag is added to a note
  void incrementUsage() {
    usageCount++;
    updatedAt = DateTime.now();
  }

  /// Decrement usage count when tag is removed from a note
  void decrementUsage() {
    if (usageCount > 0) {
      usageCount--;
      updatedAt = DateTime.now();
    }
  }

  /// Check if tag is currently in use
  bool get isInUse => usageCount > 0;

  /// Get display color as Color object
  Color get displayColor {
    try {
      // Remove # if present and parse hex color
      String hexColor = color.replaceAll('#', '');
      if (hexColor.length == 6) {
        return Color(int.parse('FF$hexColor', radix: 16));
      }
    } catch (e) {
      // If parsing fails, return default color
    }
    return const Color(0xFF2196F3); // Default blue
  }

  /// Convert to JSON for export/import
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'usageCount': usageCount,
  };

  /// Create from JSON for import
  factory CustomTag.fromJson(Map<String, dynamic> json) => CustomTag(
    id: json['id'] as int? ?? 0,
    name: json['name'] as String,
    color: json['color'] as String? ?? '#2196F3',
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    usageCount: json['usageCount'] as int? ?? 0,
  );

  @override
  String toString() => 'CustomTag(id: $id, name: $name, usageCount: $usageCount)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CustomTag && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Static class for managing custom tags
class CustomTags {
  static final List<CustomTag> _allTags = [];

  /// Get all custom tags
  static List<CustomTag> get all => List.unmodifiable(_allTags);

  /// Get tags sorted by usage count (most used first)
  static List<CustomTag> get mostUsed => List.from(_allTags)..sort((a, b) => b.usageCount.compareTo(a.usageCount));

  /// Get tags sorted by name
  static List<CustomTag> get sortedByName =>
      List.from(_allTags)..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  /// Get tags sorted by creation date (newest first)
  static List<CustomTag> get newest => List.from(_allTags)..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Find tag by ID
  static CustomTag? getById(int id) {
    try {
      return _allTags.firstWhere((tag) => tag.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Find tag by name (case-insensitive)
  static CustomTag? getByName(String name) {
    try {
      return _allTags.firstWhere((tag) => tag.name.toLowerCase() == name.toLowerCase().trim());
    } catch (e) {
      return null;
    }
  }

  /// Get multiple tags by IDs
  static List<CustomTag> getByIds(List<int> ids) =>
      ids.map((id) => getById(id)).where((tag) => tag != null).cast<CustomTag>().toList();

  /// Check if tag exists by name
  static bool exists(String name) => getByName(name) != null;

  /// Check if tag exists by ID
  static bool existsById(int id) => getById(id) != null;

  /// Search tags by name (partial match)
  static List<CustomTag> search(String query) {
    if (query.isEmpty) return all;

    final lowercaseQuery = query.toLowerCase();
    return _allTags.where((tag) => tag.name.toLowerCase().contains(lowercaseQuery)).toList();
  }

  /// Get unused tags (usageCount = 0)
  static List<CustomTag> get unused => _allTags.where((tag) => tag.usageCount == 0).toList();

  /// Get tags in use (usageCount > 0)
  static List<CustomTag> get inUse => _allTags.where((tag) => tag.usageCount > 0).toList();

  /// Add a new tag to the collection
  static void addTag(CustomTag tag) {
    if (!exists(tag.name)) {
      _allTags.add(tag);
    }
  }

  /// Remove a tag from the collection
  static void removeTag(CustomTag tag) {
    _allTags.remove(tag);
  }

  /// Update the internal collection (called by repository)
  static void updateCollection(List<CustomTag> tags) {
    _allTags.clear();
    _allTags.addAll(tags);
  }

  /// Clear all tags
  static void clear() {
    _allTags.clear();
  }

  /// Get tag statistics
  static Map<String, int> get statistics => {
    'total': _allTags.length,
    'inUse': inUse.length,
    'unused': unused.length,
    'totalUsage': _allTags.fold(0, (sum, tag) => sum + tag.usageCount),
  };
}
