import 'package:objectbox/objectbox.dart';

/// Represents a single chat thread in Trovara.
///
/// Threads can either be:
/// - per-note: tied to a specific note (type = 'per_note', noteId != null)
/// - global: not tied to any note (type = 'global', noteId == null)
///
/// We keep simple string `type` values instead of enums to keep
/// ObjectBox schema and JSON exports straightforward and stable.
@Entity()
class ChatThread {
  int id;

  /// Thread type: 'per_note' or 'global'.
  String type;

  /// Note ID for per-note threads. Null for global threads.
  int? noteId;

  /// Optional human-friendly title for the thread.
  String? title;

  DateTime createdAt;
  DateTime updatedAt;

  /// Optional soft-delete flag for future extensibility.
  /// Currently not used by merge logic but reserved so we
  /// can support trashing threads without losing history.
  bool isDeleted;

  /// When the thread was soft-deleted, if ever.
  DateTime? deletedAt;

  ChatThread({
    this.id = 0,
    required this.type,
    this.noteId,
    this.title,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isDeleted = false,
    this.deletedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Mark this thread as softly deleted (not currently used by UI).
  void softDelete() {
    isDeleted = true;
    deletedAt = DateTime.now();
    updatedAt = DateTime.now();
  }

  /// Restore this thread from soft-delete.
  void restore() {
    isDeleted = false;
    deletedAt = null;
    updatedAt = DateTime.now();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'noteId': noteId,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isDeleted': isDeleted,
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory ChatThread.fromJson(Map<String, dynamic> json) => ChatThread(
    id: json['id'] as int? ?? 0,
    type: json['type'] as String? ?? 'global',
    noteId: json['noteId'] as int?,
    title: json['title'] as String?,
    createdAt: _parseDate(json['createdAt']),
    updatedAt: _parseDate(json['updatedAt']),
    isDeleted: json['isDeleted'] as bool? ?? false,
    deletedAt: _parseOptionalDate(json['deletedAt']),
  );

  static DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  static DateTime? _parseOptionalDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
