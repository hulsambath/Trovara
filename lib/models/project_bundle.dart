import 'package:objectbox/objectbox.dart';
import 'dart:convert';

@Entity()
class ProjectBundle {
  @Id()
  int id = 0;

  /// Project name
  @Index()
  late String name;

  /// Project description
  late String? description;

  /// Ordered list of note IDs (JSON array as string)
  late String noteIdsJson;

  /// Whether this project is shared (read-only)
  bool isShared = false;

  /// Share token (if shared)
  late String? shareToken;

  /// Timestamp when project was created
  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();

  /// Timestamp when project was last modified
  @Property(type: PropertyType.date)
  DateTime updatedAt = DateTime.now();

  ProjectBundle({
    required this.name,
    this.description,
    this.noteIdsJson = '[]',
    this.isShared = false,
  });

  /// Parse note IDs from JSON string
  List<int> get noteIds {
    try {
      final decoded = jsonDecode(noteIdsJson) as List;
      return decoded.cast<int>();
    } catch (_) {
      return [];
    }
  }

  /// Set note IDs
  void setNoteIds(List<int> ids) {
    noteIdsJson = jsonEncode(ids);
  }
}
