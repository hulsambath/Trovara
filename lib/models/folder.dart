import 'package:objectbox/objectbox.dart';

@Entity()
class Folder {
  int id;
  String folderId;
  String name;
  String? description;
  String? color;
  DateTime createdAt;
  DateTime updatedAt;
  bool isDefault;
  int noteCount;

  Folder({
    this.id = 0,
    required this.folderId,
    required this.name,
    this.description,
    this.color,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isDefault = false,
    this.noteCount = 0,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  void updateName(String newName) {
    name = newName;
    updatedAt = DateTime.now();
  }

  void updateDescription(String? newDescription) {
    description = newDescription;
    updatedAt = DateTime.now();
  }

  void updateColor(String? newColor) {
    color = newColor;
    updatedAt = DateTime.now();
  }

  void incrementNoteCount() {
    noteCount++;
    updatedAt = DateTime.now();
  }

  void decrementNoteCount() {
    if (noteCount > 0) {
      noteCount--;
      updatedAt = DateTime.now();
    }
  }

  Folder copyWith({
    int? id,
    String? folderId,
    String? name,
    String? description,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDefault,
    int? noteCount,
  }) => Folder(
    id: id ?? this.id,
    folderId: folderId ?? this.folderId,
    name: name ?? this.name,
    description: description ?? this.description,
    color: color ?? this.color,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isDefault: isDefault ?? this.isDefault,
    noteCount: noteCount ?? this.noteCount,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Folder && other.folderId == folderId;
  }

  @override
  int get hashCode => folderId.hashCode;

  @override
  String toString() => 'Folder(id: $id, folderId: $folderId, name: $name, noteCount: $noteCount)';

  Map<String, dynamic> toJson() => {
    'id': id,
    'folderId': folderId,
    'name': name,
    'description': description,
    'color': color,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isDefault': isDefault,
    'noteCount': noteCount,
  };

  factory Folder.fromJson(Map<String, dynamic> json) => Folder(
    id: json['id'] as int? ?? 0,
    folderId: json['folderId'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    color: json['color'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    isDefault: json['isDefault'] as bool? ?? false,
    noteCount: json['noteCount'] as int? ?? 0,
  );
}
